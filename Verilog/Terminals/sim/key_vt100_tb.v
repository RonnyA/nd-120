//============================================================================
//! Self-checking testbench for key_vt100.v - every marker, byte-exact
//!
//! The console-loop tb proves two sequences end to end through the real
//! UART; this one sweeps ALL of them fast, against a modelled UART. It
//! exists because the two-digit tilde form (ESC [ 1 5 ~ for F5) is its own
//! code path and was otherwise untested - new logic with zero coverage can
//! fail silently.
//!
//! Checks:
//!   - a plain byte passes through unchanged
//!   - all four arrows      -> ESC [ A/B/C/D
//!   - all four PF markers  -> ESC O P/Q/R/S
//!   - all six editing keys -> ESC [ 1~ .. 6~   (one-digit tilde)
//!   - all eight F5-F12     -> ESC [ 15~..24~   (TWO-digit tilde)
//!   - a reserved-family marker (111x_xxxx) produces NOTHING
//!   - a burst of two five-byte sequences back to back survives the FIFO
//!
//! The modelled UART honours the real console_uart_tx contract: ready high
//! when idle, a byte accepted on valid&&ready, ready low for a while after.
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 30-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module key_vt100_tb;

  localparam [7:0] ESC = 8'h1B;

  reg clk = 1'b0;
  reg rst_n = 1'b0;

  reg        key_valid = 1'b0;
  reg  [7:0] key_data = 8'h00;
  wire       out_valid;
  wire [7:0] out_data;

  integer errors = 0;

  always #12.5 clk = ~clk;  // 40 MHz

  //--------------------------------------------------------------------------
  // The modelled UART: idle -> accept on valid&&ready -> busy 40 clocks.
  // 40 clocks, not the real ~35000, so the sweep finishes in simulation
  // time; the CONTRACT (ready drops after accept, rises when done) is the
  // same, and that contract is what key_vt100's pop FSM is written against.
  //--------------------------------------------------------------------------
  reg  [7:0] s_busy_cnt = 8'd0;
  wire       uart_ready = (s_busy_cnt == 8'd0);

  reg [7:0] rx_bytes[0:255];
  integer   rx_count = 0;

  always @(posedge clk) begin
    if (s_busy_cnt != 8'd0) begin
      s_busy_cnt <= s_busy_cnt - 8'd1;
    end else if (out_valid) begin
      rx_bytes[rx_count[7:0]] <= out_data;
      rx_count   <= rx_count + 1;
      s_busy_cnt <= 8'd40;
    end
  end

  key_vt100 DUT (
      .clk(clk), .rst_n(rst_n),
      .key_valid(key_valid), .key_data(key_data),
      .out_valid(out_valid), .out_data(out_data), .out_ready(uart_ready)
  );

  //--------------------------------------------------------------------------
  // Helpers
  //--------------------------------------------------------------------------

  //! Drive on the NEGEDGE, half a clock before the DUT samples. Driving at
  //! the posedge raced: the DUT read key_data directly (fresh value) while
  //! its derived digit wires had not re-evaluated in the same delta, so the
  //! first tilde press emitted the PREVIOUS press's digits (ESC [ 1 9 ~ for
  //! Home). A hardware key_data is a registered decoder output and cannot
  //! do this - the race was this bench's, and negedge driving removes it.
  task press;
    input [7:0] marker;
    begin
      @(negedge clk);
      key_data  = marker;
      key_valid = 1'b1;
      @(negedge clk);
      key_valid = 1'b0;
    end
  endtask

  //! Wait until the byte count stops rising, with a hard cap.
  task drain;
    integer quiet, guard;
    integer last;
    begin
      quiet = 0;
      guard = 0;
      last  = rx_count;
      while (quiet < 200 && guard < 100_000) begin
        @(posedge clk);
        guard = guard + 1;
        if (rx_count == last) quiet = quiet + 1;
        else begin
          quiet = 0;
          last  = rx_count;
        end
      end
    end
  endtask

  //! Press one marker and check the exact byte sequence that comes out.
  //! seq is packed MSB-first; len says how many bytes of it are real.
  task expect_seq;
    input [7:0]  marker;
    input [39:0] seq;      // up to 5 bytes
    input integer len;
    input [1023:0] what;
    integer start, i;
    reg [7:0] want;
    begin
      start = rx_count;
      press(marker);
      drain;
      if (rx_count - start != len) begin
        $display("FAIL: %0s - got %0d bytes, expected %0d (time %0t)",
                 what, rx_count - start, len, $time);
        errors = errors + 1;
      end else begin
        for (i = 0; i < len; i = i + 1) begin
          want = seq[(len-1-i)*8+:8];
          if (rx_bytes[(start+i) % 256] !== want) begin
            $display("FAIL: %0s - byte %0d is 0x%02x, expected 0x%02x (time %0t)",
                     what, i, rx_bytes[(start+i) % 256], want, $time);
            errors = errors + 1;
          end
        end
      end
    end
  endtask

  //--------------------------------------------------------------------------

  integer start;

  initial begin
    $dumpfile("key_vt100_tb.vcd");
    $dumpvars(0, key_vt100_tb);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (4) @(posedge clk);

    // Plain byte passes through.
    expect_seq(8'h41, {32'h0, "A"}, 1, "plain byte A");
    expect_seq(8'h0D, {32'h0, 8'h0D}, 1, "plain CR");

    // Arrows - family 100.
    expect_seq(8'h81, {16'h0, ESC, "[", "A"}, 3, "up arrow");
    expect_seq(8'h82, {16'h0, ESC, "[", "B"}, 3, "down arrow");
    expect_seq(8'h83, {16'h0, ESC, "[", "C"}, 3, "right arrow");
    expect_seq(8'h84, {16'h0, ESC, "[", "D"}, 3, "left arrow");

    // PF1-PF4 - family 101.
    expect_seq(8'hB0, {16'h0, ESC, "O", "P"}, 3, "F1 / PF1");
    expect_seq(8'hB1, {16'h0, ESC, "O", "Q"}, 3, "F2 / PF2");
    expect_seq(8'hB2, {16'h0, ESC, "O", "R"}, 3, "F3 / PF3");
    expect_seq(8'hB3, {16'h0, ESC, "O", "S"}, 3, "F4 / PF4");

    // Editing keys - one-digit tilde.
    expect_seq(8'hC1, {8'h0, ESC, "[", "1", "~"}, 4, "Home / FIND");
    expect_seq(8'hC2, {8'h0, ESC, "[", "2", "~"}, 4, "Insert");
    expect_seq(8'hC3, {8'h0, ESC, "[", "3", "~"}, 4, "Delete / REMOVE");
    expect_seq(8'hC4, {8'h0, ESC, "[", "4", "~"}, 4, "End / SELECT");
    expect_seq(8'hC5, {8'h0, ESC, "[", "5", "~"}, 4, "Page Up");
    expect_seq(8'hC6, {8'h0, ESC, "[", "6", "~"}, 4, "Page Down");

    // F5-F12 - TWO-digit tilde, the path this tb exists for.
    expect_seq(8'hCF, {ESC, "[", "1", "5", "~"}, 5, "F5  = ESC [ 15 ~");
    expect_seq(8'hD1, {ESC, "[", "1", "7", "~"}, 5, "F6  = ESC [ 17 ~");
    expect_seq(8'hD2, {ESC, "[", "1", "8", "~"}, 5, "F7  = ESC [ 18 ~");
    expect_seq(8'hD3, {ESC, "[", "1", "9", "~"}, 5, "F8  = ESC [ 19 ~");
    expect_seq(8'hD4, {ESC, "[", "2", "0", "~"}, 5, "F9  = ESC [ 20 ~");
    expect_seq(8'hD5, {ESC, "[", "2", "1", "~"}, 5, "F10 = ESC [ 21 ~");
    expect_seq(8'hD7, {ESC, "[", "2", "3", "~"}, 5, "F11 = ESC [ 23 ~");
    expect_seq(8'hD8, {ESC, "[", "2", "4", "~"}, 5, "F12 = ESC [ 24 ~");

    // Reserved family 111 - nothing at all.
    start = rx_count;
    press(8'hE5);
    drain;
    if (rx_count != start) begin
      $display("FAIL: reserved marker 0xE5 produced %0d bytes", rx_count - start);
      errors = errors + 1;
    end

    // Burst: two five-byte sequences back to back - ten bytes through the
    // 16-deep FIFO while the UART is slow. Order and content must hold.
    start = rx_count;
    press(8'hCF);                       // F5
    repeat (8) @(negedge clk);          // well inside the first UART frame
    press(8'hD8);                       // F12
    drain;
    if (rx_count - start != 10) begin
      $display("FAIL: burst - got %0d bytes, expected 10", rx_count - start);
      errors = errors + 1;
    end else begin
      if (rx_bytes[(start+0)%256] !== ESC || rx_bytes[(start+2)%256] !== "1" ||
          rx_bytes[(start+3)%256] !== "5" || rx_bytes[(start+4)%256] !== "~" ||
          rx_bytes[(start+5)%256] !== ESC || rx_bytes[(start+7)%256] !== "2" ||
          rx_bytes[(start+8)%256] !== "4" || rx_bytes[(start+9)%256] !== "~") begin
        $display("FAIL: burst - sequences interleaved or corrupted");
        errors = errors + 1;
      end
    end

    if (errors == 0) $display("TB_RESULT: PASS (every marker byte-exact, incl. two-digit tilde)");
    else $display("TB_RESULT: FAIL (%0d errors)", errors);
    $finish;
  end

  initial begin
    #10_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire

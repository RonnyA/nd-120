//============================================================================
//! Self-checking testbench for key_tdv2200.v - every marker, byte-exact
//!
//! Sibling of key_vt100_tb.v - same modelled-UART approach and the same
//! negedge-driven stimulus fix (see the `press` task comment: driving on
//! posedge raced the DUT's derived digit wires in key_vt100_tb.v's history,
//! same risk applies here since s_tens/s_ones are combinational off key_data).
//!
//! Checks:
//!   - plain bytes (letters, and the TDV's bare C0 cursor/Home/Delete codes)
//!     pass through unchanged
//!   - F1-F12 (mapped per ps2_ascii_table_tdv.v: F9=HJELP, F10=FUNK,
//!     F11=SKRIV, F12=ANGRE) each produce ESC [ nn _ byte-exact, unshifted
//!     AND shifted (shift = nn+1, zero-padded two digits always)
//!   - n=0..9 zero-pads correctly (ESC[00_, not ESC[0_)
//!   - a burst of two five-byte sequences back to back survives the FIFO
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 31-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module key_tdv2200_tb;

  localparam [7:0] ESC = 8'h1B;

  reg clk = 1'b0;
  reg rst_n = 1'b0;

  reg        key_valid = 1'b0;
  reg  [7:0] key_data = 8'h00;
  wire       out_valid;
  wire [7:0] out_data;

  integer errors = 0;

  always #12.5 clk = ~clk;  // 40 MHz

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

  key_tdv2200 DUT (
      .clk(clk), .rst_n(rst_n),
      .key_valid(key_valid), .key_data(key_data),
      .out_valid(out_valid), .out_data(out_data), .out_ready(uart_ready)
  );

  //! Drive on the NEGEDGE, half a clock before the DUT samples - see
  //! key_vt100_tb.v's identical task for why (a proven bug class here).
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

  task expect_seq;
    input [7:0]  marker;
    input [47:0] seq;  //! up to 6 bytes - the Alt+key PUSH/FIND/SELECT sequences
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

  integer start;

  initial begin
    $dumpfile("key_tdv2200_tb.vcd");
    $dumpvars(0, key_tdv2200_tb);

    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (4) @(posedge clk);

    // Plain bytes pass through unchanged - letters and the TDV's bare C0
    // cursor/Home/Delete/Enter codes (no marker, no expansion).
    expect_seq(8'h41, {32'h0, "A"}, 1, "plain byte A");
    expect_seq(8'h1C, {32'h0, 8'h1C}, 1, "Up = FS 0x1C (bare, no ESC)");
    expect_seq(8'h0B, {32'h0, 8'h0B}, 1, "Down = VT 0x0B (bare)");
    expect_seq(8'h08, {32'h0, 8'h08}, 1, "Left = BS 0x08 (bare)");
    expect_seq(8'h18, {32'h0, 8'h18}, 1, "Right = CAN 0x18 (bare)");
    expect_seq(8'h1D, {32'h0, 8'h1D}, 1, "Home = GS 0x1D (bare)");
    expect_seq(8'h7F, {32'h0, 8'h7F}, 1, "Delete = DEL 0x7F (bare)");

    // F1-F8: ESC[nn_] unshifted, per TDV2200KeyRegistry.cs.
    expect_seq(8'h80|8'd50, {8'h0, ESC, "[", "5", "0", "_"}, 5, "F1  unshifted ESC[50_");
    expect_seq(8'h80|8'd52, {8'h0, ESC, "[", "5", "2", "_"}, 5, "F2  unshifted ESC[52_");
    expect_seq(8'h80|8'd55, {8'h0, ESC, "[", "5", "5", "_"}, 5, "F3  unshifted ESC[55_");
    expect_seq(8'h80|8'd58, {8'h0, ESC, "[", "5", "8", "_"}, 5, "F4  unshifted ESC[58_");
    expect_seq(8'h80|8'd60, {8'h0, ESC, "[", "6", "0", "_"}, 5, "F5  unshifted ESC[60_");
    expect_seq(8'h80|8'd62, {8'h0, ESC, "[", "6", "2", "_"}, 5, "F6  unshifted ESC[62_");
    expect_seq(8'h80|8'd64, {8'h0, ESC, "[", "6", "4", "_"}, 5, "F7  unshifted ESC[64_");
    expect_seq(8'h80|8'd66, {8'h0, ESC, "[", "6", "6", "_"}, 5, "F8  unshifted ESC[66_");

    // Shifted variants: base+1, per key.
    expect_seq(8'h80|8'd51, {8'h0, ESC, "[", "5", "1", "_"}, 5, "F1  shifted ESC[51_");
    expect_seq(8'h80|8'd67, {8'h0, ESC, "[", "6", "7", "_"}, 5, "F8  shifted ESC[67_");

    // F9-F12: HJELP/FUNK/SKRIV/ANGRE, confirmed against FINDINGS-2026-08-20.md
    // (HJELP=ESC[46_, ANGRE=ESC[30_ - checked end to end against a real host).
    expect_seq(8'h80|8'd46, {8'h0, ESC, "[", "4", "6", "_"}, 5, "F9  -> HJELP ESC[46_");
    expect_seq(8'h80|8'd42, {8'h0, ESC, "[", "4", "2", "_"}, 5, "F10 -> FUNK  ESC[42_");
    expect_seq(8'h80|8'd44, {8'h0, ESC, "[", "4", "4", "_"}, 5, "F11 -> SKRIV ESC[44_");
    expect_seq(8'h80|8'd30, {8'h0, ESC, "[", "3", "0", "_"}, 5, "F12 -> ANGRE ESC[30_");

    // Zero-padding: n=0..9 must still print two digits (ESC[00_, not ESC[0_).
    expect_seq(8'h80|8'd0, {8'h0, ESC, "[", "0", "0", "_"}, 5, "n=0  zero-padded ESC[00_");
    expect_seq(8'h80|8'd9, {8'h0, ESC, "[", "0", "9", "_"}, 5, "n=9  zero-padded ESC[09_");

    // PageUp/PageDown/Insert/End markers (from ps2_ascii_table_tdv.v).
    expect_seq(8'h80|8'd32, {8'h0, ESC, "[", "3", "2", "_"}, 5, "PageUp -> ROLLDN ESC[32_");
    expect_seq(8'h80|8'd28, {8'h0, ESC, "[", "2", "8", "_"}, 5, "PageDown -> ROLLUP ESC[28_");
    expect_seq(8'h80|8'd82, {8'h0, ESC, "[", "8", "2", "_"}, 5, "Insert -> INNS/EXPS ESC[82_");
    expect_seq(8'h80|8'd48, {8'h0, ESC, "[", "4", "8", "_"}, 5, "End -> SLUTT ESC[48_");

    // Burst: two five-byte sequences back to back through the 16-deep FIFO.
    start = rx_count;
    press(8'h80|8'd50);                 // F1
    repeat (8) @(negedge clk);          // well inside the first UART frame
    press(8'h80|8'd67);                 // F8 shifted
    drain;
    if (rx_count - start != 10) begin
      $display("FAIL: burst - got %0d bytes, expected 10", rx_count - start);
      errors = errors + 1;
    end else begin
      if (rx_bytes[(start+0)%256] !== ESC || rx_bytes[(start+2)%256] !== "5" ||
          rx_bytes[(start+3)%256] !== "0" || rx_bytes[(start+4)%256] !== "_" ||
          rx_bytes[(start+5)%256] !== ESC || rx_bytes[(start+7)%256] !== "6" ||
          rx_bytes[(start+8)%256] !== "7" || rx_bytes[(start+9)%256] !== "_") begin
        $display("FAIL: burst - sequences interleaved or corrupted");
        errors = errors + 1;
      end
    end

    // Alt+key family (0xE0-0xF8) - each marker has its OWN fixed sequence,
    // not the ESC[nn_ shape. Found and fixed a real collision here
    // 31-AUG-2026: an earlier cut placed this range at 0xC4, landing
    // directly on Insert's own marker (0x80|82=0xD2) - Insert silently
    // sent SENT instead. That collision is what the Insert test above
    // (n=82, the highest n-based marker in use) now guards against.
    expect_seq(8'hE0, {8'h0, ESC, "[", "4", "6", "_"}, 5, "Alt+H HELP -> ESC[46_");
    expect_seq(8'hE6, {ESC, "[", "1", ";", "2", "R"}, 6, "Alt+F FIND -> ESC[1;2R (user-specified, 6 bytes)");
    expect_seq(8'hF1, {ESC, "P", "N", "1", ESC, "\\"}, 6, "Alt+1 PUSH1 -> ESC P N1 ESC \\ (embedded ESC as data)");
    expect_seq(8'hF8, {ESC, "P", "N", "8", ESC, "\\"}, 6, "Alt+8 PUSH8 -> ESC P N8 ESC \\");

    if (errors == 0) $display("TB_RESULT: PASS (every marker byte-exact, incl. zero-padding)");
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

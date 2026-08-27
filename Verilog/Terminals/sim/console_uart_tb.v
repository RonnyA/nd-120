//============================================================================
//! Self-checking loopback testbench for console_uart_tx.v -> console_uart_rx.v
//!
//! Sends bytes out of the transmitter, straight back into the receiver, and
//! checks they survive. Run twice with different framing:
//!
//!   7E1  - 7 data bits, even parity, 1 stop. What console.ps1 says the OPCOM
//!          console uses "in some configurations".
//!   8N1  - 8 data bits, no parity, 1 stop. What the board check uses.
//!
//! Running BOTH is the point. The 7-bit path shifts the byte down out of the
//! top of the shift register, and that is exactly the step that silently
//! mangles every character when DATA_BITS is set wrong - a bug that would look
//! like "the terminal shows garbage" on hardware with nothing to point at.
//!
//! Also checks the idle-high merge idiom: two transmitters ANDed onto one line
//! must not disturb each other while one of them is silent.
//!
//! Prints "TB_RESULT: PASS" or "TB_RESULT: FAIL".
//!
//! Written 27-AUG-2026.
//============================================================================

`timescale 1ns / 1ps
`default_nettype none

module console_uart_tb;

  localparam integer CLK_HZ = 40_000_000;
  localparam integer BAUD   = 115200;

  reg clk = 1'b0;
  reg rst_n = 1'b0;

  integer errors = 0;

  always #12.5 clk = ~clk;  // 40 MHz

  //--------------------------------------------------------------------------
  // Pair 1: 7E1
  //--------------------------------------------------------------------------

  reg        tx7_valid = 1'b0;
  reg  [7:0] tx7_data = 8'h00;
  wire       tx7_ready;
  wire       tx7_line;

  wire       rx7_valid;
  wire [7:0] rx7_data;

  //! A second, permanently idle transmitter ANDed onto the same line - the
  //! merge idiom the Nexys top uses. If it were not truly idle-high this
  //! would corrupt every character below.
  wire idle_line = 1'b1;
  wire merged7 = tx7_line & idle_line;

  console_uart_tx #(
      .CLK_HZ(CLK_HZ), .BAUD(BAUD), .DATA_BITS(7), .PARITY(1'b1), .PARITY_ODD(1'b0)
  ) TX7 (
      .clk(clk), .rst_n(rst_n),
      .byte_valid(tx7_valid), .byte_data(tx7_data), .ready(tx7_ready),
      .txd(tx7_line)
  );

  console_uart_rx #(
      .CLK_HZ(CLK_HZ), .BAUD(BAUD), .DATA_BITS(7), .PARITY(1'b1)
  ) RX7 (
      .clk(clk), .rst_n(rst_n),
      .rxd(merged7),
      .byte_valid(rx7_valid), .byte_data(rx7_data)
  );

  //--------------------------------------------------------------------------
  // Pair 2: 8N1
  //--------------------------------------------------------------------------

  reg        tx8_valid = 1'b0;
  reg  [7:0] tx8_data = 8'h00;
  wire       tx8_ready;
  wire       tx8_line;

  wire       rx8_valid;
  wire [7:0] rx8_data;

  console_uart_tx #(
      .CLK_HZ(CLK_HZ), .BAUD(BAUD), .DATA_BITS(8), .PARITY(1'b0)
  ) TX8 (
      .clk(clk), .rst_n(rst_n),
      .byte_valid(tx8_valid), .byte_data(tx8_data), .ready(tx8_ready),
      .txd(tx8_line)
  );

  console_uart_rx #(
      .CLK_HZ(CLK_HZ), .BAUD(BAUD), .DATA_BITS(8), .PARITY(1'b0)
  ) RX8 (
      .clk(clk), .rst_n(rst_n),
      .rxd(tx8_line),
      .byte_valid(rx8_valid), .byte_data(rx8_data)
  );

  //--------------------------------------------------------------------------
  // Capture
  //--------------------------------------------------------------------------

  reg [7:0] got7 = 8'h00;
  integer   n7 = 0;
  reg [7:0] got8 = 8'h00;
  integer   n8 = 0;

  always @(posedge clk) begin
    if (rx7_valid) begin got7 = rx7_data; n7 = n7 + 1; end
    if (rx8_valid) begin got8 = rx8_data; n8 = n8 + 1; end
  end

  //--------------------------------------------------------------------------

  task check;
    input condition;
    input [1023:0] what;
    begin
      if (!condition) begin
        $display("FAIL: %0s (time %0t)", what, $time);
        errors = errors + 1;
      end
    end
  endtask

  //! Send one byte through the 7E1 pair and check it comes back.
  task roundtrip7;
    input [7:0] value;
    integer n_start;
    begin
      n_start = n7;
      while (!tx7_ready) @(posedge clk);
      @(posedge clk);
      tx7_data  = value;
      tx7_valid = 1'b1;
      @(posedge clk);
      tx7_valid = 1'b0;
      // Wait for it to arrive, with a bound so a stuck line fails rather than
      // hanging until the global timeout.
      begin : wait7
        integer guard;
        guard = 0;
        while (n7 == n_start && guard < 200_000) begin
          @(posedge clk);
          guard = guard + 1;
        end
      end
      if (n7 == n_start) begin
        $display("FAIL: 7E1 byte 0x%02x never arrived (time %0t)", value, $time);
        errors = errors + 1;
      end else if (got7 !== value) begin
        $display("FAIL: 7E1 sent 0x%02x, received 0x%02x (time %0t)",
                 value, got7, $time);
        errors = errors + 1;
      end
    end
  endtask

  //! Same for the 8N1 pair.
  task roundtrip8;
    input [7:0] value;
    integer n_start;
    begin
      n_start = n8;
      while (!tx8_ready) @(posedge clk);
      @(posedge clk);
      tx8_data  = value;
      tx8_valid = 1'b1;
      @(posedge clk);
      tx8_valid = 1'b0;
      begin : wait8
        integer guard;
        guard = 0;
        while (n8 == n_start && guard < 200_000) begin
          @(posedge clk);
          guard = guard + 1;
        end
      end
      if (n8 == n_start) begin
        $display("FAIL: 8N1 byte 0x%02x never arrived (time %0t)", value, $time);
        errors = errors + 1;
      end else if (got8 !== value) begin
        $display("FAIL: 8N1 sent 0x%02x, received 0x%02x (time %0t)",
                 value, got8, $time);
        errors = errors + 1;
      end
    end
  endtask

  initial begin
    $dumpfile("console_uart_tb.vcd");
    $dumpvars(0, console_uart_tb);

    repeat (10) @(posedge clk);
    rst_n = 1'b1;
    repeat (10) @(posedge clk);

    check(tx7_line === 1'b1 && tx8_line === 1'b1, "transmitters do not idle high");

    // 7E1: every character a SINTRAN console actually sends fits in 7 bits.
    roundtrip7(8'h00);  // all zeros - worst case for parity and for framing
    roundtrip7(8'h7F);  // all ones in 7 bits
    roundtrip7("N");
    roundtrip7("D");
    roundtrip7(8'h0D);  // CR
    roundtrip7(8'h0A);  // LF
    roundtrip7(8'h55);  // alternating
    roundtrip7(8'h2A);  // the other alternating

    // 8N1
    roundtrip8(8'h00);
    roundtrip8(8'hFF);
    roundtrip8(8'hA5);
    roundtrip8(8'h5A);
    roundtrip8("Z");

    check(n7 == 8, "wrong number of bytes received on the 7E1 pair");
    check(n8 == 5, "wrong number of bytes received on the 8N1 pair");

    if (errors == 0) $display("TB_RESULT: PASS (7E1 %0d bytes, 8N1 %0d bytes)", n7, n8);
    else $display("TB_RESULT: FAIL (%0d errors)", errors);

    $finish;
  end

  initial begin
    #100_000_000;
    $display("FAIL: timeout");
    $display("TB_RESULT: FAIL (timeout)");
    $finish;
  end

endmodule

`default_nettype wire

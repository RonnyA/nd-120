/*****************************************************************************
**  kbd_to_uart_tb.v                                                        **
**                                                                          **
**  Full path: Verilog/fpga/mister/sim/kbd_to_uart_tb.v                     **
**                                                                          **
**  WHY (02-SEP-2026). v56 wired the console keyboard through key_tdv2200   **
**  into console_uart_tx, and on the board the keyboard stopped responding  **
**  even though key_tdv2200_tb and the console decode test both pass. Those **
**  tests exercise each module against its OWN model of the other side.     **
**  This bench wires the REAL pair exactly as nd120.sv does - key_tdv2200's **
**  out_valid/out_data/out_ready to console_uart_tx's byte_valid/byte_data/ **
**  ready - pushes one plain key, and counts the bytes that actually leave  **
**  console_uart_tx on txd. Exactly one must come out.                      **
**                                                                          **
**  Verdict: TB_RESULT: PASS / TB_RESULT: FAIL                              **
*****************************************************************************/

`timescale 1ns / 1ps

module kbd_to_uart_tb;

  reg clk = 0;
  reg rst_n = 0;
  always #12.5 clk = ~clk;   // 40 MHz, the board's clk_sys

  // key_tdv2200 -> console_uart_tx, wired as in nd120.sv
  reg        key_valid = 0;
  reg  [7:0] key_data  = 0;
  wire       kbd_valid, kbd_ready;
  wire [7:0] kbd_data;
  wire       txd;

  key_tdv2200 KEYEXP (
      .clk(clk), .rst_n(rst_n),
      .key_valid(key_valid), .key_data(key_data),
      .out_valid(kbd_valid), .out_data(kbd_data), .out_ready(kbd_ready)
  );

  console_uart_tx #(.CLK_HZ(40_000_000), .BAUD(115_200), .DATA_BITS(8),
                    .PARITY(1'b0), .PARITY_ODD(1'b0)) TX (
      .clk(clk), .rst_n(rst_n), .divisor_ovr(16'd0),
      .byte_valid(kbd_valid), .byte_data(kbd_data), .ready(kbd_ready), .txd(txd)
  );

  // A PROPER byte counter: a start is a 1->0 edge on an IDLE line; after it,
  // consume a whole 10-bit frame before looking again, so the 1->0 edges
  // WITHIN a frame (data bits) are not miscounted as new bytes.
  integer starts = 0;
  integer i;
  reg [7:0] rxbyte;
  localparam integer BITNS = 8681;  // 115200 baud bit time

  initial begin
    forever begin
      @(negedge txd);
      if (rst_n) begin
        starts = starts + 1;
        #(BITNS + BITNS/2);                    // middle of data bit 0
        for (i = 0; i < 8; i = i + 1) begin rxbyte[i] = txd; #(BITNS); end
        #(BITNS);                              // stop bit - line back to idle
      end
    end
  end

  integer errors = 0;
  initial begin
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (5) @(posedge clk);

    // push one plain key 'A' (0x41), one-clock strobe, as ps2_decoder_tdv does
    @(posedge clk); key_valid <= 1; key_data <= "A";
    @(posedge clk); key_valid <= 0;

    // one full 8N1 frame at 115200 is ~87 us; wait well past it
    #(BITNS * 14);

    $display("bytes transmitted: %0d, first byte = 0x%02x ('%0s')", starts, rxbyte, rxbyte);
    if (starts == 0) begin errors = errors + 1; $display("  FAIL: the key never reached the serial line (keyboard dead)"); end
    else if (starts > 1) begin errors = errors + 1; $display("  FAIL: the key was transmitted %0d times (repeat)", starts); end
    else if (rxbyte != "A") begin errors = errors + 1; $display("  FAIL: wrong byte 0x%02x, expected 0x41", rxbyte); end

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d)", errors);
    $finish;
  end

  initial begin #5_000_000; $display("TB_RESULT: FAIL (watchdog)"); $finish; end

endmodule

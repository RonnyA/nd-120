/****************************************************************************
** Testbench for the QMTECH XC7A35T standalone memory test.                 **
** Port of ../../../basys3/mem-test/sim/basys3_mem_test_tb.v: drives clk    **
** directly (NO_MMCM), runs the FSM, and DECODES the internal uart_txd net  **
** (no UART pin on this board) back into ASCII so we see the exact serial   **
** stream (W/R/OK/ERR/PASS/FAIL) -- plus checks the internal fail flag and  **
** the LED encoding at the end.                                             **
****************************************************************************/
`timescale 1ns / 1ps
`define NO_MMCM

module qmtech_mem_test_tb;

  localparam integer DF = 8;   // small baud divisor for fast sim

  reg        clk   = 1'b0;
  reg        key_n = 1'b0;     // active-low reset: start pressed
  wire [1:0] led_n;

  qmtech_mem_test_top #(.DF(DF)) dut (
      .sys_clk(clk), .key_n(key_n), .led_n(led_n)
  );

  always #5 clk = ~clk;   // 50 MHz-ish (period irrelevant in sim)

  // ---- internal monitor: print expected vs got at each read ----
  reg [3:0] pstate = 0;
  always @(posedge clk) begin
    pstate <= dut.state;
    if (dut.state == 7 && pstate != 7)   // S_RDMSG entered
      $display("  [check] addr=%05h  wrote=%02h  read=%02h  %s",
               dut.t_addr, dut.t_data, dut.rd_data,
               (dut.rd_data == dut.t_data) ? "OK" : "*** MISMATCH ***");
  end

  // ---- UART RX decoder on the internal uart_txd: reconstruct the bytes ----
  integer bit_i;
  reg [7:0] rxb;
  initial begin
    forever begin
      @(negedge dut.uart_txd);                 // start bit
      repeat (DF + DF/2) @(posedge clk);       // to middle of bit0
      for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
        rxb[bit_i] = dut.uart_txd;
        repeat (DF) @(posedge clk);
      end
      if (rxb == 8'h0D) ; else if (rxb == 8'h0A) $write("\n");
      else $write("%c", rxb);
      $fflush;
    end
  end

  initial begin
    $dumpfile("qmtech_mem_test_tb.vcd"); $dumpvars(0, qmtech_mem_test_tb);
    repeat (30) @(negedge clk);
    key_n = 1'b1;                               // release reset
    wait (dut.state == 12);                     // S_DONE
    repeat (100) @(negedge clk);
    $display("\n--- DONE: fail flag = %b  (0 = all reads matched) ---", dut.fail);
    // LED encoding: done+pass -> led_n[1] off (high); done+fail -> both solid low
    if (dut.fail && led_n != 2'b00)
      $display("*** LED ENCODING WRONG for FAIL: led_n=%b (expected 00)", led_n);
    if (!dut.fail && led_n[1] != 1'b1)
      $display("*** LED ENCODING WRONG for PASS: led_n[1]=%b (expected 1/off)", led_n[1]);
    if (dut.fail) $display("=== RESULT: FAIL ==="); else $display("=== RESULT: PASS ===");
    // Machine-checkable verdict. The registry greps for this exact
    // string; the human-readable line above is kept as-is.
    if (dut.fail) $display("TB_RESULT: FAIL");
    else          $display("TB_RESULT: PASS");
    $finish;
  end

  initial begin #80000000; $display("\nTIMEOUT"); $finish; end

endmodule

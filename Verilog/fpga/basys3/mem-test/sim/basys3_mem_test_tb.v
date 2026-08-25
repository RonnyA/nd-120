/****************************************************************************
** Testbench for the Basys3 standalone memory test.                         **
** Drives clk directly (NO_MMCM), runs the FSM, and DECODES the uartTx line  **
** back into ASCII so we see the exact serial output (W/R/OK/ERR/PASS/FAIL)  **
** the board would emit -- plus checks the internal fail flag.               **
****************************************************************************/
`timescale 1ns / 1ps
`define NO_MMCM

module basys3_mem_test_tb;

  localparam integer DF = 8;   // small baud divisor for fast sim

  reg         clk = 1'b0;
  reg         btn1 = 1'b1;
  wire        uartTx;
  wire [15:0] led;

  basys3_mem_test_top #(.DF(DF)) dut (
      .sysclk(clk), .btn1(btn1), .uartTx(uartTx), .led(led)
  );

  always #5 clk = ~clk;   // 100 MHz-ish (period irrelevant in sim)

  // ---- internal monitor: print expected vs got at each read ----
  reg [3:0] pstate = 0;
  always @(posedge clk) begin
    pstate <= dut.state;
    if (dut.state == 7 && pstate != 7)   // S_RDMSG entered
      $display("  [check] addr=%05h  wrote=%02h  read=%02h  %s",
               dut.t_addr, dut.t_data, dut.rd_data,
               (dut.rd_data == dut.t_data) ? "OK" : "*** MISMATCH ***");
  end

  // ---- UART RX decoder on uartTx: reconstruct the serial bytes ----
  integer bit_i;
  reg [7:0] rxb;
  initial begin
    forever begin
      @(negedge uartTx);                       // start bit
      repeat (DF + DF/2) @(posedge clk);       // to middle of bit0
      for (bit_i = 0; bit_i < 8; bit_i = bit_i + 1) begin
        rxb[bit_i] = uartTx;
        repeat (DF) @(posedge clk);
      end
      if (rxb == 8'h0D) ; else if (rxb == 8'h0A) $write("\n");
      else $write("%c", rxb);
      $fflush;
    end
  end

  initial begin
    $dumpfile("basys3_mem_test_tb.vcd"); $dumpvars(0, basys3_mem_test_tb);
    repeat (30) @(negedge clk);
    btn1 = 1'b0;                                // release reset
    wait (dut.state == 12);                     // S_DONE
    repeat (100) @(negedge clk);
    $display("\n--- DONE: fail flag = %b  (0 = all reads matched) ---", dut.fail);
    if (dut.fail) $display("=== RESULT: FAIL ==="); else $display("=== RESULT: PASS ===");
    // Machine-checkable verdict. The registry greps for this exact
    // string; the human-readable line above is kept as-is.
    if (dut.fail) $display("TB_RESULT: FAIL");
    else          $display("TB_RESULT: PASS");
    $finish;
  end

  initial begin #80000000; $display("\nTIMEOUT"); $finish; end

endmodule

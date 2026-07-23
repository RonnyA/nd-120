/****************************************************************************
** Testbench for the Tang Nano 20K sdram18 test                            **
**                                                                         **
** Runs sdram18_test_top against the behavioral SDRAM model (reused from   **
** sdram-test/sim), decodes the UART output and echoes it to the console.  **
** Clock plays the 13.5 MHz slow-bring-up controller clock (SIM define     **
** bypasses the rPLL). Fast parameters: 16 clocks/bit UART, 64-word block. **
**                                                                         **
** Prints "TB_RESULT: PASS" when the design reports PASS.                  **
**                                                                         **
** Last reviewed: 9-JUL-2026                                               **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module sdram18_test_tb;

  localparam CLK_PERIOD = 74;  // ~13.5 MHz (the slow-bring-up frequency)
  localparam UART_DIV = 16;    // clocks per bit in this sim
  localparam BITP = UART_DIV * CLK_PERIOD;

  reg clk = 0;
  always #(CLK_PERIOD / 2.0) clk = ~clk;

  reg s1 = 0;
  reg rxd = 1;
  wire txd;

  wire sd_clk, sd_cke, sd_cs_n, sd_cas_n, sd_ras_n, sd_wen_n;
  wire [31:0] sd_dq;
  wire [10:0] sd_addr;
  wire [1:0] sd_ba;
  wire [3:0] sd_dqm;
  wire [5:0] led;

  sdram18_test_top #(
      .CLK_FREQ  (13_500_000),
      .BAUD      (13_500_000 / UART_DIV),
      .BLOCK_SIZE(22'd64),
      .DOT_STEP  (22'd16)
  ) dut (
      .sys_clk(clk),
      .s1(s1),
      .uart_rxp(rxd),
      .uart_txp(txd),
      .O_sdram_clk(sd_clk),
      .O_sdram_cke(sd_cke),
      .O_sdram_cs_n(sd_cs_n),
      .O_sdram_cas_n(sd_cas_n),
      .O_sdram_ras_n(sd_ras_n),
      .O_sdram_wen_n(sd_wen_n),
      .IO_sdram_dq(sd_dq),
      .O_sdram_addr(sd_addr),
      .O_sdram_ba(sd_ba),
      .O_sdram_dqm(sd_dqm),
      .led(led)
  );

  sdram_model u_model (
      .clk(sd_clk),
      .cke(sd_cke),
      .cs_n(sd_cs_n),
      .ras_n(sd_ras_n),
      .cas_n(sd_cas_n),
      .we_n(sd_wen_n),
      .a(sd_addr),
      .ba(sd_ba),
      .dqm(sd_dqm),
      .dq(sd_dq)
  );

  // ---- UART TX decoder: sample mid-bit, echo characters ----
  reg [7:0] ch;
  reg [31:0] last4 = 0;
  integer bi;
  initial begin
    forever begin
      @(negedge txd);  // start bit
      #(BITP * 1.5);
      ch = 0;
      for (bi = 0; bi < 8; bi = bi + 1) begin
        ch[bi] = txd;
        #(BITP);
      end
      $write("%c", ch);
      last4 = {last4[23:0], ch};
    end
  end

  // ---- send one UART character to the DUT (8N1, LSB first) ----
  task send_char(input [7:0] c);
    integer k;
    begin
      rxd = 0;
      #(BITP);
      for (k = 0; k < 8; k = k + 1) begin
        rxd = c[k];
        #(BITP);
      end
      rxd = 1;
      #(BITP * 2);
    end
  endtask

  // ---- stimulus: wait for the prompt ("...KEY\r\n"), then send a key ----
  initial begin
    wait (last4 === {"E", "Y", 8'h0D, 8'h0A});
    #(BITP * 4);
    $display("");
    $display("TB: prompt seen, sending start character over UART RX");
    send_char("G");
  end

  // ---- result detection ----
  initial begin
    fork
      begin
        wait (last4[31:0] === "PASS");
        #(BITP * 30);  // let the trailing CRLF drain
        $display("");
        $display("TB_RESULT: PASS");
        $finish;
      end
      begin
        wait (last4[31:0] === "FAIL");
        #(BITP * 30);
        $display("");
        $display("TB_RESULT: FAIL");
        $finish;
      end
    join
  end

  // ---- watchdog ----
  initial begin
    #100_000_000;  // 100 ms (13.5 MHz is 2x slower than the 27 MHz test)
    $display("");
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule

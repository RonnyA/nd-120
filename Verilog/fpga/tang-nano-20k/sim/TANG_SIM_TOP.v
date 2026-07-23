/****************************************************************************
** Simulation wrapper: ND120_TANG20K_TOP + behavioral SDRAM               **
**                                                                         **
** Verilator top for the full Tang Nano 20K ND-120 build. The SDRAM chip  **
** is the behavioral model from sdram-test; everything else is exactly    **
** what gowin_build synthesizes (SIM define bypasses only the rPLL).      **
**                                                                         **
** Last reviewed: 8-JUL-2026                                               **
** Ronny Hansen                                                            **
*****************************************************************************/

module TANG_SIM_TOP (
    input  wire clk2x,   // plays the 13.5 MHz PLL output (SIM bypass divides by 2)
    input  wire s1,
    input  wire uart_rxp,
    output wire uart_txp,
    output wire [5:0] led
);

  wire sd_clk, sd_cke, sd_cs_n, sd_cas_n, sd_ras_n, sd_wen_n;
  wire [31:0] sd_dq;
  wire [10:0] sd_addr;
  wire [1:0] sd_ba;
  wire [3:0] sd_dqm;

  ND120_TANG20K_TOP dut (
      .sys_clk(clk2x),
      .s1(s1),
      .s2(1'b0),
      .uart_rxp(uart_rxp),
      .uart_txp(uart_txp),
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

endmodule

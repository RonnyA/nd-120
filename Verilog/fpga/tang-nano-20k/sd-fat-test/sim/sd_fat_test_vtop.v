/****************************************************************************
** Verilator wrapper for sd_fat_test_top                                   **
**                                                                         **
** Verilator cannot drive the sd_cmd / sd_dat0 inouts from C++ directly,   **
** so this wrapper resolves both tristates: the C++ SD card model drives   **
** its _c_drive/_c_val pair, the DUT drives its own enables, and a tri1    **
** net (pullup, like the real card bus) resolves each line. The           **
** *_resolved outputs are what both sides see.                             **
**                                                                         **
** Simulation parameters are fixed here: fast baud (1 Mbaud), SIMULATE=1   **
** (short SD init), 1 s watchdog. The hardware build does NOT use this     **
** file.                                                                   **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/

module sd_fat_test_vtop (
    input sys_clk,
    input s1,
    input uart_rxp,
    output uart_txp,

    output sd_clk,
    input  sd_cmd_c_drive,   // C++ card model drives the CMD line
    input  sd_cmd_c_val,
    output sd_cmd_resolved,  // resolved CMD line (host + card + pullup)
    input  sd_dat0_c_drive,  // C++ card model drives DAT0
    input  sd_dat0_c_val,
    output sd_dat0_resolved, // resolved DAT0 line (host + card + pullup)
    output sd_dat1,
    output sd_dat2,
    output sd_dat3,

    output [5:0] led
);

  tri1 sd_cmd;   // pulled up, like the real card bus
  tri1 sd_dat0;

  assign sd_cmd = sd_cmd_c_drive ? sd_cmd_c_val : 1'bz;
  assign sd_cmd_resolved = sd_cmd;

  assign sd_dat0 = sd_dat0_c_drive ? sd_dat0_c_val : 1'bz;
  assign sd_dat0_resolved = sd_dat0;

  sd_fat_test_top #(
      .CLK_FREQ(27_000_000),
      .BAUD    (1_000_000),      // fast simulation baud
      .SIMULATE(1),
      .WD_MAX  (32'd27_000_000)  // 1 s watchdog
  ) u_top (
      .sys_clk (sys_clk),
      .s1      (s1),
      .uart_rxp(uart_rxp),
      .uart_txp(uart_txp),
      .sd_clk  (sd_clk),
      .sd_cmd  (sd_cmd),
      .sd_dat0 (sd_dat0),
      .sd_dat1 (sd_dat1),
      .sd_dat2 (sd_dat2),
      .sd_dat3 (sd_dat3),
      .led     (led)
  );

endmodule

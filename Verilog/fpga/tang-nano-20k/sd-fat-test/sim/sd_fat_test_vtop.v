/****************************************************************************
** Verilator wrapper for sd_fat_test_top                                   **
**                                                                         **
** Verilator cannot drive the sd_cmd / sd_dat0-3 inouts from C++ directly, **
** so this wrapper resolves the tristates: the C++ SD card model drives    **
** its _c_drive/_c_val pairs, the DUT drives its own enables, and a tri1   **
** net (pullup, like the real card bus) resolves each line. The           **
** *_resolved outputs are what both sides see. All four DAT lines are      **
** wrapped: the writer engine runs the 4-bit bus (ACMD6) by default.       **
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
    input  sd_dat1_c_drive,  // C++ card model drives DAT1 (4-bit reads)
    input  sd_dat1_c_val,
    output sd_dat1_resolved,
    input  sd_dat2_c_drive,
    input  sd_dat2_c_val,
    output sd_dat2_resolved,
    input  sd_dat3_c_drive,
    input  sd_dat3_c_val,
    output sd_dat3_resolved,

    // pad output-enable monitors for the C++ contention assertion: while
    // the card model transmits on a line, the DUT's pad driver for that
    // line must be OFF - both ends driving is the silicon failure mode
    // that z-resolution in simulation otherwise hides
    output [3:0] dat_oe_mon,  // {DAT3, DAT2, DAT1, DAT0} pad drivers
    output       cmd_oe_mon,  // CMD pad driver

    output [5:0] led
);

  assign dat_oe_mon = {u_top.s_dat3_pad_oe, u_top.s_dat2_pad_oe,
                       u_top.s_dat1_pad_oe, u_top.s_dat0_pad_oe};
  assign cmd_oe_mon = u_top.cmd_oe;

  tri1 sd_cmd;   // pulled up, like the real card bus
  tri1 sd_dat0;
  tri1 sd_dat1;
  tri1 sd_dat2;
  tri1 sd_dat3;

  assign sd_cmd = sd_cmd_c_drive ? sd_cmd_c_val : 1'bz;
  assign sd_cmd_resolved = sd_cmd;

  assign sd_dat0 = sd_dat0_c_drive ? sd_dat0_c_val : 1'bz;
  assign sd_dat0_resolved = sd_dat0;

  assign sd_dat1 = sd_dat1_c_drive ? sd_dat1_c_val : 1'bz;
  assign sd_dat1_resolved = sd_dat1;

  assign sd_dat2 = sd_dat2_c_drive ? sd_dat2_c_val : 1'bz;
  assign sd_dat2_resolved = sd_dat2;

  assign sd_dat3 = sd_dat3_c_drive ? sd_dat3_c_val : 1'bz;
  assign sd_dat3_resolved = sd_dat3;

  sd_fat_test_top #(
      .CLK_FREQ(27_000_000),
      .BAUD    (1_000_000),      // fast simulation baud
      .SIMULATE(1),
      .WD_MAX  (32'd27_000_000),  // 1 s watchdog
      .IO_BLOCKS(20)              // 40 KB speed-test file keeps the sim fast
  ) u_top (
      .sys_clk (sys_clk),
      .s1      (s1),
      .s2      (1'b0),
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

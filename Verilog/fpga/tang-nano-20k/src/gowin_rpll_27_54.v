/**************************************************************************
** ND120 - Tang Nano 20K clock generator                                 **
**                                                                       **
** One rPLL from the 27 MHz crystal:                                     **
**   clkout  = 54 MHz          - SDRAM controller clock (clk2x)          **
**   clkoutp = 54 MHz shifted  - SDRAM chip clock (same phase offset as  **
**                               the hardware-validated sdram-test PLL)  **
**   clkoutd = 27 MHz          - CPU / bus / OSC domain (clkout / 2,     **
**                               edge-aligned with clkout by the PLL)    **
**                                                                       **
** Derived from the nand2mario sdram-tang-nano-20k rPLL configuration    **
** (its commented-out 54 MHz option), Apache-2.0.                        **
**                                                                       **
** Last reviewed: 8-JUL-2026                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module Gowin_rPLL_ND120 (
    output clkout,   // 54 MHz
    output clkoutp,  // 54 MHz, phase shifted for the SDRAM chip
    output clkoutd,  // 27 MHz (clkout / 2)
    output lock,
    input  clkin     // 27 MHz crystal
);

  wire clkoutd3_o;
  wire gw_gnd;
  assign gw_gnd = 1'b0;

  rPLL rpll_inst (
      .CLKOUT(clkout),
      .LOCK(lock),
      .CLKOUTP(clkoutp),
      .CLKOUTD(clkoutd),
      .CLKOUTD3(clkoutd3_o),
      .RESET(gw_gnd),
      .RESET_P(gw_gnd),
      .CLKIN(clkin),
      .CLKFB(gw_gnd),
      .FBDSEL({gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd}),
      .IDSEL({gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd}),
      .ODSEL({gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd, gw_gnd}),
      .PSDA({gw_gnd, gw_gnd, gw_gnd, gw_gnd}),
      .DUTYDA({gw_gnd, gw_gnd, gw_gnd, gw_gnd}),
      .FDLY({gw_gnd, gw_gnd, gw_gnd, gw_gnd})
  );

`ifdef TANG_CRAWL_BRINGUP
  // Crawl bring-up (P0 timing-mechanism probe): CLKOUT = 27 * 1/4 = 6.75 MHz
  // (SDRAM pair), CLKOUTD = 3.375 MHz (CPU/bus). VCO = 6.75 * 128 = 864 MHz.
  defparam rpll_inst.FBDIV_SEL = 0;
  defparam rpll_inst.IDIV_SEL = 3;
  defparam rpll_inst.ODIV_SEL = 128;
`elsif TANG_SLOW_BRINGUP
  // Slow bring-up: CLKOUT = 27 * (FBDIV+1)/(IDIV+1) = 27 * 1/2 = 13.5 MHz
  // (SDRAM pair), CLKOUTD = 6.75 MHz (CPU/bus). VCO = 13.5 * 64 = 864 MHz.
  defparam rpll_inst.FBDIV_SEL = 0;
  defparam rpll_inst.IDIV_SEL = 1;
  defparam rpll_inst.ODIV_SEL = 64;
`else
  // 54 MHz from 27 MHz: CLKOUT = 27 * (FBDIV+1)/(IDIV+1) = 27 * 2; VCO = 54*16 = 864 MHz
  defparam rpll_inst.FBDIV_SEL = 1;
  defparam rpll_inst.IDIV_SEL = 0;
  defparam rpll_inst.ODIV_SEL = 16;
`endif

  defparam rpll_inst.FCLKIN = "27";
  defparam rpll_inst.DYN_IDIV_SEL = "false";
  defparam rpll_inst.DYN_FBDIV_SEL = "false";
  defparam rpll_inst.DYN_ODIV_SEL = "false";
  defparam rpll_inst.PSDA_SEL = "1010";  // same CLKOUTP phase as the validated sdram-test PLL
  defparam rpll_inst.DYN_DA_EN = "false";
  defparam rpll_inst.DUTYDA_SEL = "1000";
  defparam rpll_inst.CLKOUT_FT_DIR = 1'b1;
  defparam rpll_inst.CLKOUTP_FT_DIR = 1'b1;
  defparam rpll_inst.CLKOUT_DLY_STEP = 0;
  defparam rpll_inst.CLKOUTP_DLY_STEP = 0;
  defparam rpll_inst.CLKFB_SEL = "internal";
  defparam rpll_inst.CLKOUT_BYPASS = "false";
  defparam rpll_inst.CLKOUTP_BYPASS = "false";
  defparam rpll_inst.CLKOUTD_BYPASS = "false";
  defparam rpll_inst.DYN_SDIV_SEL = 2;  // CLKOUTD = CLKOUT / 2 = 27 MHz
  defparam rpll_inst.CLKOUTD_SRC = "CLKOUT";
  defparam rpll_inst.CLKOUTD3_SRC = "CLKOUT";
  defparam rpll_inst.DEVICE = "GW2AR-18C";

endmodule

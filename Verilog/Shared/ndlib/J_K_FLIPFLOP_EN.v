/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** J_K_FLIPFLOP_EN - J_K_FLIPFLOP with an optional clock-enable mode.    **
**                                                                       **
** USE_ENABLE=0 (default): wraps the original J_K_FLIPFLOP - clocked on  **
**   the original clock pin (InvertClockEnable passed through),          **
**   bit-for-bit the original behaviour.                                 **
** USE_ENABLE=1: clocked on posedge sysclk, updates when EN is high      **
**   (P2 clock-domain conversion mode - see SCAN_FF_EN.v / the plan      **
**   doc). The clock pin is unused in this mode. preset/reset stay       **
**   SYNCHRONOUS, exactly as in the original clocked block, with the     **
**   original priority: preset > reset > tick.                           **
**                                                                       **
** Last reviewed: 10-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module J_K_FLIPFLOP_EN #(
    parameter integer USE_ENABLE = 0,
    parameter integer InvertClockEnable = 1
) (
    input sysclk,  //! FPGA system clock (used only when USE_ENABLE=1)
    input EN,      //! Clock enable    (used only when USE_ENABLE=1)

    input clock,   //! Clock (used only when USE_ENABLE=0)
    input j,       //! J input
    input k,       //! K input
    input preset,  //! Synchronous active-high set (priority over reset)
    input reset,   //! Synchronous active-high clear
    input tick,    //! Update enable inside the clocked block

    output q,
    output qBar
);

  generate
    if (USE_ENABLE == 1) begin : gen_enable
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_clk = clock;
      /* verilator lint_on UNUSEDSIGNAL */
      reg q_r = 1'b0;
      always @(posedge sysclk) begin
        if (EN) begin
          if (preset) q_r <= 1'b1;
          else if (reset) q_r <= 1'b0;
          else if (tick) q_r <= (~q_r & j) | (q_r & ~k);
        end
      end
      assign q    = q_r;
      assign qBar = ~q_r;
    end else begin : gen_orig
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_sys = sysclk & EN;
      /* verilator lint_on UNUSEDSIGNAL */
      J_K_FLIPFLOP #(
          .InvertClockEnable(InvertClockEnable)
      ) FF (
          .clock (clock),
          .j     (j),
          .k     (k),
          .preset(preset),
          .reset (reset),
          .tick  (tick),
          .q     (q),
          .qBar  (qBar)
      );
    end
  endgenerate

endmodule

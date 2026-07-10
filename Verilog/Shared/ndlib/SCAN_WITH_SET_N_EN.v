/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** SCAN_WITH_SET_N_EN - SCAN_WITH_SET_N with an optional clock-enable    **
** mode.                                                                 **
**                                                                       **
** USE_ENABLE=0 (default): wraps the original SCAN_WITH_SET_N -          **
**   posedge CLK, original behaviour (async active-low set via S_n on    **
**   a D_FLIPFLOP with ACTIVE_ASYNC=1, d = TE ? TI : D).                 **
** USE_ENABLE=1: posedge sysclk, captures when EN is high (P2 clock-     **
**   domain conversion mode - see SCAN_FF_EN.v / the plan doc). The      **
**   CLK pin is unused in this mode. S_n stays an ASYNC active-low       **
**   set, exactly like the original's async preset (~S_n), and while     **
**   S_n is low it also overrides capture on the clock edge.             **
**                                                                       **
** Last reviewed: 10-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module SCAN_WITH_SET_N_EN #(
    parameter integer USE_ENABLE = 0
) (
    input sysclk,  //! FPGA system clock (used only when USE_ENABLE=1)
    input EN,      //! Clock enable    (used only when USE_ENABLE=1)

    input CLK,  //! Clock (used only when USE_ENABLE=0)
    input D,    //! D input
    input S_n,  //! Async active-low set
    input TE,   //! T enable
    input TI,   //! T input

    output Q,  //! Q output
    output QN  //! Q_n output
);

  generate
    if (USE_ENABLE == 1) begin : gen_enable
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_clk = CLK;
      /* verilator lint_on UNUSEDSIGNAL */
      reg q_r = 1'b0;
      // Active-high async set (posedge ~S_n), matching the original's
      // D_FLIPFLOP ACTIVE_ASYNC preset trigger: at time 0 with S_n low the
      // 0->1 preset transition fires the block, which a `negedge S_n`
      // sensitivity would miss (S_n starts low - no edge).
      wire s_preset = ~S_n;
      always @(posedge sysclk or posedge s_preset) begin
        if (s_preset) q_r <= 1'b1;
        else if (EN) q_r <= TE ? TI : D;
      end
      assign Q  = q_r;
      assign QN = ~q_r;
    end else begin : gen_orig
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_sys = sysclk & EN;
      /* verilator lint_on UNUSEDSIGNAL */
      SCAN_WITH_SET_N FF (
          .CLK(CLK),
          .D  (D),
          .S_n(S_n),
          .TE (TE),
          .TI (TI),
          .Q  (Q),
          .QN (QN)
      );
    end
  endgenerate

endmodule

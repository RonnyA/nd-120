/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** SCAN_WITH_RESET_N_EN - SCAN_WITH_RESET_N with an optional             **
** clock-enable mode.                                                    **
**                                                                       **
** USE_ENABLE=0 (default): wraps the original SCAN_WITH_RESET_N -        **
**   posedge CLK, original behaviour.                                    **
** USE_ENABLE=1: posedge sysclk, captures when EN is high (P2 clock-     **
**   domain conversion mode - see SCAN_FF_EN.v / the plan doc). The      **
**   CLK pin is unused in this mode.                                     **
**                                                                       **
** IMPORTANT - R_n finding (verified 10-JUL-2026 against the current     **
** sources):                                                             **
**   The original wires MEMORY_4 as a plain D_FLIPFLOP with the          **
**   default ACTIVE_ASYNC=0, and D_FLIPFLOP's gen_sync branch IGNORES    **
**   its preset/reset pins entirely (always @(posedge clk) q <= d;).     **
**   So in the original module, R_n has NO EFFECT on the flop today.     **
**   (Additionally the .reset pin is wired to R_n directly - not         **
**   inverted - so even the intended polarity would be active-HIGH on    **
**   an *_n-named input; the sibling SCAN_WITH_SET_N inverts S_n.)       **
**   Mode 1 replicates the ACTUAL current behaviour exactly: R_n is      **
**   ignored (lint-waived) and q simply captures TE ? TI : D under EN.   **
**                                                                       **
** Last reviewed: 10-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module SCAN_WITH_RESET_N_EN #(
    parameter integer USE_ENABLE = 0
) (
    input sysclk,  //! FPGA system clock (used only when USE_ENABLE=1)
    input EN,      //! Clock enable    (used only when USE_ENABLE=1)

    input CLK,  //! Clock (used only when USE_ENABLE=0)
    input D,    //! D input
    input R_n,  //! Reset input - see header: no effect in the original,
                //! so no effect here either (kept for port compatibility)
    input TE,   //! T enable
    input TI,   //! T input

    output Q,  //! Q output
    output QN  //! Q_n output
);

  generate
    if (USE_ENABLE == 1) begin : gen_enable
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_clk = CLK & R_n;
      /* verilator lint_on UNUSEDSIGNAL */
      reg q_r = 1'b0;
      always @(posedge sysclk) begin
        if (EN) q_r <= TE ? TI : D;
      end
      assign Q  = q_r;
      assign QN = ~q_r;
    end else begin : gen_orig
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_sys = sysclk & EN;
      /* verilator lint_on UNUSEDSIGNAL */
      SCAN_WITH_RESET_N FF (
          .CLK(CLK),
          .D  (D),
          .R_n(R_n),
          .TE (TE),
          .TI (TI),
          .Q  (Q),
          .QN (QN)
      );
    end
  endgenerate

endmodule

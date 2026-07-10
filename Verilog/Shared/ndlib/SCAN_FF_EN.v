/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** SCAN_FF_EN - SCAN_FF with an optional clock-enable mode.              **
**                                                                       **
** USE_ENABLE=0 (default): wraps the original SCAN_FF - clocked on       **
**   posedge CLK, bit-for-bit the original behaviour (latch mode).       **
** USE_ENABLE=1: clocked on posedge sysclk, captures when EN is high.    **
**   For the P2 clock-domain conversions (docs/                          **
**   plan-fix-unconstrained-clocks.md): EN is a CYC_36 *_EN pulse        **
**   aligned so the capture lands on the same edge the phase-accurate    **
**   clock rises - the CLK pin is unused in this mode and the flop       **
**   lives in the sysclk domain (constrained, retimable, no fabric-      **
**   routed clock).                                                      **
**                                                                       **
** Last reviewed: 9-JUL-2026                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module SCAN_FF_EN #(
    parameter integer USE_ENABLE = 0
) (
    input sysclk,  //! FPGA system clock (used only when USE_ENABLE=1)
    input EN,      //! Clock enable    (used only when USE_ENABLE=1)

    input CLK,  //! Clock (positive triggered; used only when USE_ENABLE=0)
    input D,    //! D input
    input TE,   //! T enable
    input TI,   //! T Input

    output Q,  //! Q output
    output QN  //! Q_n output
);

  generate
    if (USE_ENABLE == 1) begin : gen_enable
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_clk = CLK;
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
      SCAN_FF FF (
          .CLK(CLK),
          .D  (D),
          .TE (TE),
          .TI (TI),
          .Q  (Q),
          .QN (QN)
      );
    end
  endgenerate

endmodule

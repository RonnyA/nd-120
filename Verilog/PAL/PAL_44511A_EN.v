/**********************************************************************************************************
** ND120 PALASM CODE CONVERTED TO VERILOG                                                                **
**                                                                                                       **
** Component PAL 44511A (LEV0) - clock-enable wrapper                                                    **
**                                                                                                       **
** USE_ENABLE=0 (default): instantiates the original PAL_44511A untouched                                **
**   (posedge CK registered outputs).                                                                    **
** USE_ENABLE=1: structural copy of PAL_44511A with the registered                                       **
**   equations captured on `posedge sysclk + if (EN)` (P2 clock-domain                                   **
**   conversion, docs/plan-fix-unconstrained-clocks.md - EN is CYC_36's                                  **
**   CLK_EN pulse aligned with the CLK rise). Equations are line-for-line                                **
**   identical to PAL_44511A.v; only the flop trigger changes.                                           **
**                                                                                                       **
** The original PAL_44511A.v is generated from PALASM and is never                                       **
** modified - keep the equations here in sync with it.                                                   **
**                                                                                                       **
** Last reviewed: 10-JUL-2026                                                                            **
** Ronny Hansen                                                                                          **
***********************************************************************************************************/

module PAL_44511A_EN #(
    parameter integer USE_ENABLE = 0
) (
    input sysclk,  //! FPGA system clock (used only when USE_ENABLE=1)
    input EN,      //! Clock enable    (used only when USE_ENABLE=1)

    input CK,   //! Clock signal (used only when USE_ENABLE=0)
    input OE_n, //! OUTPUT ENABLE (active-low) for Q0-Q3

    input PIL0,    //! I0 - PIL0
    input PIL1,    //! I1 - PIL1
    input PIL2,    //! I2 - PIL2
    input PIL3,    //! I3 - PIL3
    input CLK,     //! I4 - CLK (same signal as CK)
    input MREQ_n,  //! I5 - MREQ_n
    input WCA_n,   //! I6 - WCA_n
    //input I7,       //! I7 - (not connected)

    output CUP,  //! Q0_n - (not connected)
    //output Q1_n,   //! Q1_n - (not connected)
    //output Q2_n,   //! Q2_n - (not connected)
    //output Q2_n,   //! Q3_n - (not connected)


    output CWR_n,  //! B0_n - CWR_n
    //output B1_n,   //! B1_n - (not connected)
    //output B2_n,   //! B2_n - (not connected)
    output LEV0    //! B3_n - LEV0

);

  generate
    if (USE_ENABLE == 1) begin : gen_enable
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_clk = CK;
      /* verilator lint_on UNUSEDSIGNAL */

      // Register declarations for state-holding variables
      reg  CWR_reg = 1'b0;
      reg  CUP_n_reg = 1'b0;


      // negated wires
      wire MREQ = ~MREQ_n;
      wire WCA = ~WCA_n;
      wire CLK_n = ~CLK;

      // LEVEL ZERO
      assign LEV0 = ~(PIL3 | PIL2 | PIL1 | PIL0);


      // Sequential logic - equations identical to PAL_44511A.v,
      // captured on the enable instead of posedge CK.
      always @(posedge sysclk) begin
        if (EN) begin

          // Logic for CWR (Cache Write Register)
          if ((MREQ & WCA) == 1)  // SET ON WRITE TO CACHE
            CWR_reg <= 1'b1;
          else if ((CLK_n) == 0)  // HOLD UNTIL START OF NEXT CYCLE
            CWR_reg <= 1'b0;

          // Logic for CUP  (ADDED CACHE UPDATE BIT)
          if ((CWR_n & MREQ_n) == 1)  // SET IN WRITE TO CACHE
            CUP_n_reg <= 1'b0;
          else if (MREQ_n == 0)  // HOLD UNTIL NEXT MREQ
            CUP_n_reg <= 1'b1;
        end
      end

      // outputs
      assign CWR_n = OE_n ? 1'b0 : ~CWR_reg;
      assign CUP   = OE_n ? 1'b0 : ~CUP_n_reg;
    end else begin : gen_orig
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_sys = sysclk & EN;
      /* verilator lint_on UNUSEDSIGNAL */
      PAL_44511A PAL (
          .CK(CK),
          .OE_n(OE_n),
          .PIL0(PIL0),
          .PIL1(PIL1),
          .PIL2(PIL2),
          .PIL3(PIL3),
          .CLK(CLK),
          .MREQ_n(MREQ_n),
          .WCA_n(WCA_n),
          .CUP(CUP),
          .CWR_n(CWR_n),
          .LEV0(LEV0)
      );
    end
  endgenerate

endmodule

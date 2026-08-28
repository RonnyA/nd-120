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
      reg  CWR_hold = 1'b0;
      reg  CUP_n_reg = 1'b0;


      // negated wires
      wire MREQ = ~MREQ_n;
      wire WCA = ~WCA_n;
      wire CLK_n = ~CLK;

      // CWR IS COMBINATIONAL, NOT REGISTERED. From the original PALASM,
      // DesignDocuments/PAL-Code/SRC/44511A.txt:
      //
      //   IF (VCC) CWR  = MREQ * WCA + CWR * /CLK    <-- '='  combinational
      //           /CUP := /CWR * MREQ + /CUP * /MREQ <-- ':=' registered
      //
      // In PALASM '=' is a combinational output and ':=' a registered one, and
      // on a PAL16R4 only Q0-Q3 have flip-flops - CWR is pin B0, which has
      // none. LEV0 (B3) in this same file was already modelled combinationally;
      // CWR was not, and that was the bug.
      //
      // WHY IT MATTERED. A registered CWR is not visible until the NEXT clock
      // edge, by which time MREQ has gone. The CUP term /CWR * MREQ needs both
      // in the SAME cycle, so CUP never asserted at all. Everything followed
      // from that: the used-bit PAL never wrote, CHIP_21F stayed zero, and
      // s_hit - which requires !s_used_n - could never assert. The machine's
      // own diagnostic (CACHE-120-A00 under TPE) reported exactly that chain:
      // "CUP does not work", "DATA is NOT COPIED to DATA CACHE", used bit
      // "Expected 1 Found 0", while the cache DATA memory test passed.
      //
      // HOW IT IS MODELLED HERE (FF mode, chosen 28-AUG-2026). The set term is
      // combinational, so CWR is visible in the very cycle MREQ * WCA happens -
      // that is what CUP needs. The hold term is a register qualified by /CLK,
      // matching "HOLD UNTIL START OF NEXT CYCLE": the hold dies at the CLK rise,
      // so CWR does not survive into the high phase.
      //
      // RESIDUAL DEVIATION, stated plainly. The real pin is a LEVEL-sensitive
      // feedback latch that sets the instant MREQ * WCA occurs during the low
      // phase. A flop clocked at the CLK rise cannot see inside that phase, so the
      // hold here is one CLK rise behind: an event captured at a rise can extend
      // CWR across the FOLLOWING low phase, which the PAL would not do. The set
      // term is unaffected, and it is the set term CUP samples. This is the
      // USE_LATCHES=0 path the FPGA builds; do not "fix" it by inferring a latch
      // without going through the repo's latch-vs-FF compare first.
      wire CWR = (MREQ & WCA) | (CWR_hold & CLK_n);

      // LEVEL ZERO
      assign LEV0 = ~(PIL3 | PIL2 | PIL1 | PIL0);


      // Sequential logic - equations identical to PAL_44511A.v,
      // captured on the enable instead of posedge CK.
      always @(posedge sysclk) begin
        if (EN) begin

          // Hold only - the SET path is combinational below.
          CWR_hold <= (MREQ & WCA);

          // Logic for CUP (ADDED CACHE UPDATE BIT). 44511A OCR/PNG (registered):
          //   /CUP := /CWR * MREQ + /CUP * /MREQ
          //   (intent: CUP := CWR*MREQ + CUP*/MREQ - SET on write-to-cache, hold until next MREQ).
          // Fix 26-JUL: the prior if/else had the MREQ polarity flipped (CWR_n & MREQ_n),
          // so CUP was never set on a cache write and spuriously set when idle -> the
          // CACHE-1X0 diagnostic reported "Cache updated bit: Not working".
          CUP_n_reg <= (~CWR & MREQ) | (CUP_n_reg & MREQ_n);
        end
      end

      // outputs
      assign CWR_n = OE_n ? 1'b0 : ~CWR;
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

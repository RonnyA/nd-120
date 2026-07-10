/**********************************************************************************************************
** ND120 PALASM CODE CONVERTED TO VERILOG                                                                **
**                                                                                                       **
** Component PAL 44402D - clock-enable variant                                                           **
**                                                                                                       **
** Equation copy of PAL_44402D.v (which stays untouched) with an optional                                **
** sysclk+enable capture mode for the four registered outputs.                                           **
**                                                                                                       **
** USE_ENABLE=0 (default): instantiates the original PAL_44402D - posedge                                **
**   CLK, original behaviour.                                                                            **
** USE_ENABLE=1: the registers capture on posedge sysclk when EN is high                                 **
**   (P3 UCLK-domain conversion mode, docs/plan-fix-unconstrained-clocks.md).                            **
**   EN must be the rise-aligned UCLK enable (CYC_36 UCLK_EN).                                           **
**                                                                                                       **
** Last reviewed: 10-JUL-2026                                                                            **
** Ronny Hansen                                                                                          **
***********************************************************************************************************/

module PAL_44402D_EN #(
    parameter integer USE_ENABLE = 0
) (
    input sysclk,  //! FPGA system clock (used only when USE_ENABLE=1)
    input EN,      //! Clock enable     (used only when USE_ENABLE=1)

    input CLK,  //! Clock signal (used only when USE_ENABLE=0)
    input OE_n, //! OUTPUT ENABLE (active-low) for Q0-Q3

    input DT_n,     //! I0
    input RT_n,     //! I1
    input LSHADOW,  //! I2
    input FMISS,    //! I3
    input CYD,      //! I4
    input HIT0_n,   //! I5
    input HIT1_n,   //! I6
    input EWC_n,    //! I7

    output USED_n,  //! B0_n
    output WCA_n,   //! B1_n (new input for 44404D)
    input  OUBI,    //! B2_n (Signal input from CHIP 21F)
    input  OUBD,    //! B3_n (Signal input from CHIP 21F)

    output NUBI_n,  //! Q0_n
    output NUBD_n,  //! Q1_n
                    //! Q2_n (not connected, no signal)
    output IHIT_n   //! Q3_n (not connected signal?)
);

  generate
    if (USE_ENABLE == 1) begin : gen_enable
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_clk = CLK;
      /* verilator lint_on UNUSEDSIGNAL */

      // Registers for CLOCKED signals
      reg NUBI_n_reg = 1'b0;
      reg NUBD_n_reg = 1'b0;
      reg IHIT_reg = 1'b0;

      // Creating non-negated wires for active-low inputs
      wire DT = ~DT_n;
      wire HIT0 = ~HIT0_n;
      wire HIT1 = ~HIT1_n;
      wire EWC = ~EWC_n;

      // Creating negated wires for active-high inputs
      wire OUBI_n = ~OUBI;
      wire OUBD_n = ~OUBD;
      wire RT = ~RT_n;
      wire FMISS_n = ~FMISS;
      wire LSHADOW_n = ~LSHADOW;

      // Registered equations - identical to PAL_44402D, trigger swapped to
      // posedge sysclk gated by the rise-aligned UCLK enable.
      always @(posedge sysclk) begin
        if (EN) begin
          // Logic for NUBI_n (Q0 - active-low)
          NUBI_n_reg <= (DT & OUBI_n) |  // READ OR WRITE KEEP OLD VALUE
          (RT_n & DT & HIT0 & HIT1);  // CLEAR IF WRITE WITH HIT

          // Logic for NUBD_n (Q1 - active-low)
          NUBD_n_reg <= (RT & DT_n & OUBD_n);  // IF FETCH KEEP OLD VALUE

          // Logic for IHIT (Q3)
          IHIT_reg <= (HIT1 & HIT0 & OUBI & RT & DT_n & WCA_n) |  // FETCH
          (HIT1 & HIT0 & OUBD & RT & DT & WCA_n);  // READ
        end
      end

      // Q0
      assign NUBI_n = OE_n ? 1'b0 : NUBI_n_reg;

      // Q1
      assign NUBD_n = OE_n ? 1'b0 : NUBD_n_reg;

      // Q3
      assign IHIT_n = OE_n ? 1'b0 : ~IHIT_reg;

      // Logic for USED_n (active-low)
      assign USED_n = ~((OUBI & RT & DT_n & WCA_n) |  // FETCH
          (OUBD & RT & DT & WCA_n)  // READ
          );

      // Logic for WCA_n (active-low)
      assign WCA_n = ~((RT_n & DT & EWC & CYD & FMISS_n & LSHADOW_n) |  // WRITE OUTSIDE SHADOW
          (RT & IHIT_n & EWC & CYD & FMISS_n & LSHADOW_n)  // FETCH/READ WITHOUT HIT OUTSIDE SHADOW
          );

    end else begin : gen_orig
      /* verilator lint_off UNUSEDSIGNAL */
      wire unused_sys = sysclk & EN;
      /* verilator lint_on UNUSEDSIGNAL */

      PAL_44402D PAL (
          .CLK (CLK),
          .OE_n(OE_n),

          .DT_n(DT_n),
          .RT_n(RT_n),
          .LSHADOW(LSHADOW),
          .FMISS(FMISS),
          .CYD(CYD),
          .HIT0_n(HIT0_n),
          .HIT1_n(HIT1_n),
          .EWC_n(EWC_n),

          .USED_n(USED_n),
          .WCA_n (WCA_n),
          .OUBI  (OUBI),
          .OUBD  (OUBD),

          .NUBI_n(NUBI_n),
          .NUBD_n(NUBD_n),
          .IHIT_n(IHIT_n)
      );
    end
  endgenerate

endmodule

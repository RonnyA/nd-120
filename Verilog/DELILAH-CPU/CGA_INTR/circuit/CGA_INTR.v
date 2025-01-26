/**************************************************************************
** CPU GATE ARRAY - CGA - DELILAH                                        **
**                                                                       **
** CGA/INTR                                                              **
**                                                                       **
** Sheet 1 of 1                                                          **
** PDF page 74                                                           **
**                                                                       **
** Last reviewed: 26-JAN-2025                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_INTR (
    input        BINT10N,          //! Bus Interrupt 10, active low
    input        BINT11N,          //! Bus Interrupt 11, active low
    input        BINT12N,          //! Bus Interrupt 12, active low
    input        BINT13N,          //! Bus Interrupt 13, active low
    input        BINT15N,          //! Bus Interrupt 15, active low
    input        CLIRQN,           //! Clear Interrupt Request, active low
    input        EMPIDN,           //! EMP Interrupt Disable, active low
    input        EPIC,             //! Enable PIC (Programmable Interrupt Controller) signal
    input [15:0] FIDBO_15_0,       //! FIDB , 16-bit
    input        IOXERRN,          //! IO Exception Error, active low
    input [ 3:0] LAA_3_0,          //! Latched Address A, 4-bit
    input        MCLK,             //! Master Clock
    input        MORN,             //! MOR signal, active low (Memory Error)
    input        PANN,             //! PAN signal, active low (Panel Interrupt)
    input        PARERRN,          //! Parity Error, active low
    input        POWFAILN,         //! Power Failure, active low
    input        Z,                //! Error flag from ALU

    output        EPICMASKN,       //! EPIC Mask, active low
    output        HIGSN,           //! High Speed signal, active low
    output        INTRQN,          //! Interrupt Request, active low
    output        IRQ,             //! Interrupt Request
    output        LOGSN,           //! Logical Segment Number, active low
    output        PD,              //! Power Down signal
    output [15:0] PICMASK_15_0,    //! PIC Mask, 16-bit
    output [ 2:0] PICS_2_0,        //! PIC Select, 3-bit
    output [ 2:0] PICV_2_0         //! PIC Vector, 3-bit
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_fidbo_15_0;
  wire [15:0] s_picmask_15_0_out;
  wire [ 2:0] s_picv_2_0_out;
  wire [ 2:0] s_pics_2_0_out;
  wire [ 3:0] s_laa_3_0;
  wire [15:0] s_ireq_15_0_n;
  wire        s_bint10_n;
  wire        s_bint11_n;
  wire        s_bint12_n;
  wire        s_bint13_n;
  wire        s_bint15_n;
  wire        s_clirq_n;
  wire        s_clirq;
  wire        s_empid_n;
  wire        s_epic;
  wire        s_epicmask_n_out;
  wire        s_gates1_out;
  wire        s_highs_n_out;
  wire        s_intrq_n;
  wire        s_ioxerr_n;
  wire        s_irq_n_out;
  wire        s_irq_out;
  wire        s_logs_n_out;
  wire        s_mclk;
  wire        s_nor_n;
  wire        s_pan_n;
  wire        s_parerr_n;
  wire        s_pd_out;
  wire        s_powfail_n;
  wire        s_z;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   reg [3:0] regLAA_3_0;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_bint10_n         = BINT10N;
  assign s_bint11_n         = BINT11N;
  assign s_bint12_n         = BINT12N;
  assign s_bint13_n         = BINT13N;
  assign s_bint15_n         = BINT15N;
  assign s_clirq_n          = CLIRQN;
  assign s_empid_n          = EMPIDN;
  assign s_epic             = EPIC;
  assign s_fidbo_15_0[15:0] = FIDBO_15_0;
  assign s_ioxerr_n         = IOXERRN;

  //assign s_laa_3_0[3:0]     = LAA_3_0;
  assign s_laa_3_0[3:0]     = regLAA_3_0;

  assign s_mclk             = MCLK;
  assign s_nor_n            = 1; //TODO: Fix MORN;
  assign s_pan_n            = PANN;
  assign s_parerr_n         = PARERRN;
  assign s_powfail_n        = POWFAILN;
  assign s_z                = Z;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign EPICMASKN          = s_epicmask_n_out;
  assign HIGSN              = s_highs_n_out;
  assign INTRQN             = s_intrq_n;
  assign IRQ                = s_irq_out;
  assign LOGSN              = s_logs_n_out;
  assign PD                 = s_pd_out;
  assign PICMASK_15_0       = s_picmask_15_0_out[15:0];
  assign PICS_2_0           = s_pics_2_0_out[2:0];
  assign PICV_2_0           = s_picv_2_0_out[2:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Need to add delay to changing of LAA_3_0 so that if it changes when MCLK changes we dont get the "new and wrong value"
  // TODO: Review if this can be solved with rising edge on sysclk
  always @(LAA_3_0)
  begin
    regLAA_3_0 <= LAA_3_0;
  end

  // NOT Gate
  assign s_irq_out          = ~s_irq_n_out;
  assign s_clirq            = ~s_clirq_n;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_1 (
      .input1(s_pan_n),
      .input2(s_irq_n_out),
      .result(s_gates1_out)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_2 (
      .clock(s_mclk),
      .d(s_gates1_out),
      .preset(1'b0),
      .q(),
      .qBar(s_intrq_n),
      .reset(s_clirq),
      .tick(1'b1)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  CGA_INTR_CNTLR CNTLR (
      .EPIC(s_epic),
      .EPICMASKN(s_epicmask_n_out),
      .FIDBO_15_0(s_fidbo_15_0[15:0]),
      .HIGSN(s_highs_n_out),
      .IREQ_15_0_N(s_ireq_15_0_n[15:0]),
      .IRQN(s_irq_n_out),
      .LAA_3_0(s_laa_3_0[3:0]),
      .LOGSN(s_logs_n_out),
      .MCLK(s_mclk),
      .PD(s_pd_out),
      .PICMASK_15_0(s_picmask_15_0_out[15:0]),
      .PICS_2_0(s_pics_2_0_out[2:0]),
      .PICV_2_0(s_picv_2_0_out[2:0])
  );

  CGA_INTR_IRSRC IRSRC (
      .BINT10N(s_bint10_n),
      .BINT11N(s_bint11_n),
      .BINT12N(s_bint12_n),
      .BINT13N(s_bint13_n),
      .BINT15N(s_bint15_n),
      .EMPIDN(s_empid_n),
      .FIDBO_15_0(s_fidbo_15_0[15:0]),
      .IOXERRN(s_ioxerr_n),
      .IREQ_15_0_N(s_ireq_15_0_n[15:0]),
      .NORN(s_nor_n),
      .PARERRN(s_parerr_n),
      .POWFAILN(s_powfail_n),
      .Z(s_z)
  );

endmodule

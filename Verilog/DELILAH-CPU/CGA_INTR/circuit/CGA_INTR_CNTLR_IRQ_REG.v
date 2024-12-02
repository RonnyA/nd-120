/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/IRQ/REG                                               **
** INTERRUPT CONTROLLER REGISTER                                         **
**                                                                       **
** Page 78                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 1-DEC-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_INTR_CNTLR_IRQ_REG (
    input [15:0] CLRQ_15_0,
    input        CPN,
    input [15:0] IRQ_15_0_N,
    input        MCLK,

    output [15:0] LREQ_15_0

);
  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_clrq_15_0;
  wire [15:0] s_irq_15_0_n;
  wire [15:0] s_lreq_15_0_out;
  wire        s_cp_n;
  wire        s_mclk;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_clrq_15_0[15:0]  = CLRQ_15_0;
  assign s_irq_15_0_n[15:0] = IRQ_15_0_N;
  assign s_mclk             = MCLK;
  assign s_cp_n             = CPN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign LREQ_15_0          = s_lreq_15_0_out[15:0];

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_0 (
      .CLR(s_clrq_15_0[0]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[0]),
      .PN (s_irq_15_0_n[0])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_1 (
      .CLR(s_clrq_15_0[1]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[1]),
      .PN (s_irq_15_0_n[1])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_2 (
      .CLR(s_clrq_15_0[2]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[2]),
      .PN (s_irq_15_0_n[2])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_3 (
      .CLR(s_clrq_15_0[3]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[3]),
      .PN (s_irq_15_0_n[3])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_4 (
      .CLR(s_clrq_15_0[4]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[4]),
      .PN (s_irq_15_0_n[4])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_5 (
      .CLR(s_clrq_15_0[5]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[5]),
      .PN (s_irq_15_0_n[5])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_6 (
      .CLR(s_clrq_15_0[6]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[6]),
      .PN (s_irq_15_0_n[6])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_7 (
      .CLR(s_clrq_15_0[7]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[7]),
      .PN (s_irq_15_0_n[7])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_8 (
      .CLR(s_clrq_15_0[8]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[8]),
      .PN (s_irq_15_0_n[8])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_9 (
      .CLR(s_clrq_15_0[9]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[9]),
      .PN (s_irq_15_0_n[9])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_10 (
      .CLR(s_clrq_15_0[10]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[10]),
      .PN (s_irq_15_0_n[10])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_11 (
      .CLR(s_clrq_15_0[11]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[11]),
      .PN (s_irq_15_0_n[11])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_12 (
      .CLR(s_clrq_15_0[12]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[12]),
      .PN (s_irq_15_0_n[12])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_13 (
      .CLR(s_clrq_15_0[13]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[13]),
      .PN (s_irq_15_0_n[13])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_14 (
      .CLR(s_clrq_15_0[14]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[14]),
      .PN (s_irq_15_0_n[14])
  );

  CGA_INTR_CNTLR_IRQ_REG_RQBIT RQBIT_15 (
      .CLR(s_clrq_15_0[15]),
      .CP (s_mclk),
      .CPN(s_cp_n),
      .INR(s_lreq_15_0_out[15]),
      .PN (s_irq_15_0_n[15])
  );


endmodule

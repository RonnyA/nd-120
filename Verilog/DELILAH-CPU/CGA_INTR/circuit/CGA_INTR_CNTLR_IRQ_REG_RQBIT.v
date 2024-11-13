/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/IRQ/REG/RQBIT                                         **
** INTERRUPT CONTROLLER REGISTER Q BIT                                   **
**                                                                       **
** Page 78                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_INTR_CNTLR_IRQ_REG_RQBIT (
    input CLR,
    input CP,
    input CPN,
    input PN,

    output INR
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_clr_n;
  wire s_clr;
  wire s_cp_n;
  wire s_cp;
  wire s_cpn_nand_clr;
  wire s_d;
  wire s_ff_nand_n_out;
  wire s_ff_nand_out;
  wire s_ff_or_out;
  wire s_inr_out;
  wire s_p_n;
  wire s_p;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_clr = CLR;
  assign s_cp = CP;
  assign s_p_n = PN;
  assign s_cp_n = CPN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign INR = s_inr_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_clr_n = ~s_clr;

  // NOT Gate
  assign s_p = ~s_p_n;

  // NOT Gate
  assign s_ff_nand_n_out = ~s_ff_nand_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  OR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_p),
      .input2(s_ff_nand_n_out),
      .result(s_ff_or_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_ff_or_out),
      .input2(s_cpn_nand_clr),
      .result(s_ff_nand_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_ff_or_out),
      .input2(s_clr_n),
      .result(s_d)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_4 (
      .input1(s_cp_n),
      .input2(s_clr),
      .result(s_cpn_nand_clr)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_5 (
      .clock(s_cp),
      .d(s_d),
      .preset(1'b0),
      .q(),
      .qBar(s_inr_out),
      .reset(1'b0),
      .tick(1'b1)
  );


endmodule

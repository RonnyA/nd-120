/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/IRGEL/VMUX                                            **
** VECTOR MUX                                                            **
**                                                                       **
** Page 95                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_INTR_CNTLR_IRGEL_VMUX (
    input [2:0] HIVEC_2_0, //! High vector
    input       HVE,       //! High vector Enable
    input [2:0] LOVEC_2_0, //! Lo vector
    input       LVE,       //! Lo vector Enable

    output [2:0] PICV_2_0  //! Prioritized Interrupt Vector
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [2:0] s_hivec_2_0;
  wire [2:0] s_lovec_2_0;
  wire [2:0] s_picv_2_0_out;
  wire       s_hivec0_nand_hve;
  wire       s_hivec1_nand_hve;
  wire       s_hivec2_nand_hve;
  wire       s_hve;
  wire       s_lovec0_nand_lve;
  wire       s_lovec1_nand_lve;
  wire       s_lovec2_nand_lve;
  wire       s_lve;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_hivec_2_0[2:0] = HIVEC_2_0;
  assign s_lovec_2_0[2:0] = LOVEC_2_0;
  assign s_lve            = LVE;
  assign s_hve            = HVE;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign PICV_2_0         = s_picv_2_0_out[2:0];

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_1 (
      .input1(s_hivec0_nand_hve),
      .input2(s_lovec0_nand_lve),
      .result(s_picv_2_0_out[0])
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_hivec_2_0[2]),
      .input2(s_hve),
      .result(s_hivec2_nand_hve)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_lovec_2_0[2]),
      .input2(s_lve),
      .result(s_lovec2_nand_lve)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_4 (
      .input1(s_hivec2_nand_hve),
      .input2(s_lovec2_nand_lve),
      .result(s_picv_2_0_out[2])
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_5 (
      .input1(s_hivec_2_0[1]),
      .input2(s_hve),
      .result(s_hivec1_nand_hve)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_6 (
      .input1(s_lovec_2_0[1]),
      .input2(s_lve),
      .result(s_lovec1_nand_lve)
  );

  OR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_7 (
      .input1(s_hivec1_nand_hve),
      .input2(s_lovec1_nand_lve),
      .result(s_picv_2_0_out[1])
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_8 (
      .input1(s_hivec_2_0[0]),
      .input2(s_hve),
      .result(s_hivec0_nand_hve)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_9 (
      .input1(s_lovec_2_0[0]),
      .input2(s_lve),
      .result(s_lovec0_nand_lve)
  );


endmodule

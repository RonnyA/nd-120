
/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/ALU/OUTMUX/SEL8                                                  **
** SEL8                                                                  **
**                                                                       **
** Page 56                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
**************************************************************************/

module CGA_ALU_OUTMUX_SEL8 (
    input [7:0] E_7_0,
    input [7:0] SI_7_0,

    output D
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [7:0] s_si_7_0;
  wire [7:0] s_e_7_0;
  wire       s_d_out;
  wire       s_nand_0;
  wire       s_nand_1;
  wire       s_nand_2;
  wire       s_nand_3;
  wire       s_nand_4;
  wire       s_nand_5;
  wire       s_nand_6;
  wire       s_nand_7;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_si_7_0[7:0] = SI_7_0;
  assign s_e_7_0[7:0] = E_7_0;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign D = s_d_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_si_7_0[7]),
      .input2(s_e_7_0[7]),
      .result(s_nand_7)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_si_7_0[6]),
      .input2(s_e_7_0[6]),
      .result(s_nand_6)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_si_7_0[5]),
      .input2(s_e_7_0[5]),
      .result(s_nand_5)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_4 (
      .input1(s_si_7_0[4]),
      .input2(s_e_7_0[4]),
      .result(s_nand_4)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_5 (
      .input1(s_si_7_0[3]),
      .input2(s_e_7_0[3]),
      .result(s_nand_3)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_6 (
      .input1(s_si_7_0[2]),
      .input2(s_e_7_0[2]),
      .result(s_nand_2)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_7 (
      .input1(s_si_7_0[1]),
      .input2(s_e_7_0[1]),
      .result(s_nand_1)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_8 (
      .input1(s_si_7_0[0]),
      .input2(s_e_7_0[0]),
      .result(s_nand_0)
  );

  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) GATES_9 (
      .input1(s_nand_7),
      .input2(s_nand_6),
      .input3(s_nand_5),
      .input4(s_nand_4),
      .input5(s_nand_3),
      .input6(s_nand_2),
      .input7(s_nand_1),
      .input8(s_nand_0),
      .result(s_d_out)
  );


endmodule

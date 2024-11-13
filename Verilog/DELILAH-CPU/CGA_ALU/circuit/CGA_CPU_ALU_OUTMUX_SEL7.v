/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/ALU/OUTMUX/SEL7                                                  **
** SEL7                                                                  **
**                                                                       **
** Page 57                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
**************************************************************************/

module CGA_CPU_ALU_OUTMUX_SEL7 (
    input [6:0] E_6_0,
    input [6:0] SI_6_0,

    output D
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [6:0] s_si_6_0;
  wire [6:0] s_e_6_0;
  wire       s_d_out;
  wire       s_nand0;
  wire       s_nand1;
  wire       s_nand2;
  wire       s_nand3;
  wire       s_nand4;
  wire       s_nand5;
  wire       s_nand6;
  
  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_si_6_0[6:0] = SI_6_0;
  assign s_e_6_0[6:0] = E_6_0;

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
      .input1(s_si_6_0[0]),
      .input2(s_e_6_0[0]),
      .result(s_nand0)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_si_6_0[1]),
      .input2(s_e_6_0[1]),
      .result(s_nand1)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_si_6_0[2]),
      .input2(s_e_6_0[2]),
      .result(s_nand2)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_4 (
      .input1(s_si_6_0[3]),
      .input2(s_e_6_0[3]),
      .result(s_nand3)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_5 (
      .input1(s_si_6_0[4]),
      .input2(s_e_6_0[4]),
      .result(s_nand4)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_6 (
      .input1(s_si_6_0[5]),
      .input2(s_e_6_0[5]),
      .result(s_nand5)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_7 (
      .input1(s_si_6_0[6]),
      .input2(s_e_6_0[6]),
      .result(s_nand6)
  );

  OR_GATE_7_INPUTS #(
      .BubblesMask({3'b111, 4'hF})
  ) GATES_8 (
      .input1(s_nand0),
      .input2(s_nand1),
      .input3(s_nand2),
      .input4(s_nand3),
      .input5(s_nand4),
      .input6(s_nand5),
      .input7(s_nand6),
      .result(s_d_out)
  );


endmodule

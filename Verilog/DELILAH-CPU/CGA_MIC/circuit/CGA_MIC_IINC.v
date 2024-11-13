/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MIC/IINC                                                         **
** INSTRUCTION INCREMENT                                                 **
**                                                                       **
** Page 16                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MIC_IINC (
    input        CIN,
    input [12:0] IW_12_0,

    output [12:0] NEXT_12_0
);
  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [12:0] s_iw_12_0;
  wire [12:0] s_next_12_0_out;
  wire        s_carryout_0;
  wire        s_carryout_1;
  wire        s_carryout_10;
  wire        s_carryout_11;
  wire        s_carryout_2;
  wire        s_carryout_3;
  wire        s_carryout_5;
  wire        s_carryout_6;
  wire        s_carryout_7;
  wire        s_carryout_8;
  wire        s_ci_n;
  wire        s_gates1_n;
  wire        s_gates1_out;
  wire        s_gates2_n;
  wire        s_gates2_out;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_iw_12_0[12:0] = IW_12_0;
  assign s_ci_n          = CIN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign NEXT_12_0       = s_next_12_0_out[12:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_gates1_n      = ~s_gates1_out;
  assign s_gates2_n      = ~s_gates2_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) GATES_1 (
      .input1(s_iw_12_0[4]),
      .input2(s_iw_12_0[3]),
      .input3(s_iw_12_0[2]),
      .input4(s_iw_12_0[1]),
      .input5(s_iw_12_0[0]),
      .input6(s_ci_n),
      .result(s_gates1_out)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) GATES_2 (
      .input1(s_iw_12_0[9]),
      .input2(s_iw_12_0[8]),
      .input3(s_iw_12_0[7]),
      .input4(s_iw_12_0[6]),
      .input5(s_iw_12_0[5]),
      .input6(s_gates1_n),
      .result(s_gates2_out)
  );
  FullAdder #(
      .extendedBits(2)
  ) ARITH_12 (
      .carryIn(1'b0),
      .carryOut(s_carryout_0),
      .dataA(s_iw_12_0[0]),
      .dataB(s_ci_n),
      .result(s_next_12_0_out[0])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_13 (
      .carryIn(1'b0),
      .carryOut(s_carryout_1),
      .dataA(s_iw_12_0[1]),
      .dataB(s_carryout_0),
      .result(s_next_12_0_out[1])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_14 (
      .carryIn(1'b0),
      .carryOut(s_carryout_2),
      .dataA(s_iw_12_0[2]),
      .dataB(s_carryout_1),
      .result(s_next_12_0_out[2])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_15 (
      .carryIn(1'b0),
      .carryOut(s_carryout_3),
      .dataA(s_iw_12_0[3]),
      .dataB(s_carryout_2),
      .result(s_next_12_0_out[3])
  );


  FullAdder #(
      .extendedBits(2)
  ) ARITH_3 (
      .carryIn(1'b0),
      .carryOut(),
      .dataA(s_iw_12_0[4]),
      .dataB(s_carryout_3),
      .result(s_next_12_0_out[4])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_4 (
      .carryIn(1'b0),
      .carryOut(s_carryout_5),
      .dataA(s_iw_12_0[5]),
      .dataB(s_gates1_n),
      .result(s_next_12_0_out[5])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_5 (
      .carryIn(1'b0),
      .carryOut(s_carryout_6),
      .dataA(s_iw_12_0[6]),
      .dataB(s_carryout_5),
      .result(s_next_12_0_out[6])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_6 (
      .carryIn(1'b0),
      .carryOut(s_carryout_7),
      .dataA(s_iw_12_0[7]),
      .dataB(s_carryout_6),
      .result(s_next_12_0_out[7])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_7 (
      .carryIn(1'b0),
      .carryOut(s_carryout_8),
      .dataA(s_iw_12_0[8]),
      .dataB(s_carryout_7),
      .result(s_next_12_0_out[8])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_8 (
      .carryIn(1'b0),
      .carryOut(),
      .dataA(s_iw_12_0[9]),
      .dataB(s_carryout_8),
      .result(s_next_12_0_out[9])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_9 (
      .carryIn(1'b0),
      .carryOut(s_carryout_10),
      .dataA(s_iw_12_0[10]),
      .dataB(s_gates2_n),
      .result(s_next_12_0_out[10])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_10 (
      .carryIn(1'b0),
      .carryOut(s_carryout_11),
      .dataA(s_iw_12_0[11]),
      .dataB(s_carryout_10),
      .result(s_next_12_0_out[11])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_11 (
      .carryIn(1'b0),
      .carryOut(),
      .dataA(s_iw_12_0[12]),
      .dataB(s_carryout_11),
      .result(s_next_12_0_out[12])
  );



endmodule

/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MAC/APOS/INC                                                     **
** INCREMENT                                                             **
**                                                                       **
** Page 33                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 01-FEB-2025                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_MAC_APOS_INC (
    input [15:0] LCA_15_0,

    output [15:0] NLCA_15_0
);

  // New implementation using Verilog arithmetic
assign NLCA_15_0 = LCA_15_0 + 16'd1;


`ifdef _OLD_WAY_
  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_lca_15_0;
  wire [15:0] s_nlca_15_0_out;
  wire        s_carryout_0;
  wire        s_carryout_1;
  wire        s_carryout_10;
  wire        s_carryout_11;
  wire        s_carryout_13;
  wire        s_carryout_14;
  wire        s_carryout_2;
  wire        s_carryout_3;
  wire        s_carryout_4;
  wire        s_carryout_5;
  wire        s_carryout_6;
  wire        s_carryout_8;
  wire        s_carryout_9;
  wire        s_gates1_n;
  wire        s_gates1_out;
  wire        s_gates2_n;
  wire        s_gates2_out;
  wire        s_power;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_lca_15_0[15:0] = LCA_15_0;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign NLCA_15_0 = s_nlca_15_0_out[15:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Power
  assign s_power = 1'b1;


  // NOT Gate
  assign s_gates1_n = ~s_gates1_out;
  assign s_gates2_n = ~s_gates2_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE_8_INPUTS #(
      .BubblesMask(8'h00)
  ) GATES_1 (
      .input1(s_lca_15_0[7]),
      .input2(s_lca_15_0[6]),
      .input3(s_lca_15_0[5]),
      .input4(s_lca_15_0[4]),
      .input5(s_lca_15_0[3]),
      .input6(s_lca_15_0[2]),
      .input7(s_lca_15_0[1]),
      .input8(s_lca_15_0[0]),
      .result(s_gates1_out)
  );

  NAND_GATE_6_INPUTS #(
      .BubblesMask({2'b00, 4'h0})
  ) GATES_2 (
      .input1(s_lca_15_0[12]),
      .input2(s_lca_15_0[11]),
      .input3(s_lca_15_0[10]),
      .input4(s_lca_15_0[9]),
      .input5(s_lca_15_0[8]),
      .input6(s_gates1_n),
      .result(s_gates2_out)
  );



  FullAdder #(
      .extendedBits(2)
  ) ARITH_14 (
      .carryIn(1'b0),
      .carryOut(s_carryout_0),
      .dataA(s_lca_15_0[0]),
      .dataB(s_power),
      .result(s_nlca_15_0_out[0])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_15 (
      .carryIn(1'b0),
      .carryOut(s_carryout_1),
      .dataA(s_lca_15_0[1]),
      .dataB(s_carryout_0),
      .result(s_nlca_15_0_out[1])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_16 (
      .carryIn(1'b0),
      .carryOut(s_carryout_2),
      .dataA(s_lca_15_0[2]),
      .dataB(s_carryout_1),
      .result(s_nlca_15_0_out[2])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_17 (
      .carryIn(1'b0),
      .carryOut(s_carryout_3),
      .dataA(s_lca_15_0[3]),
      .dataB(s_carryout_2),
      .result(s_nlca_15_0_out[3])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_18 (
      .carryIn(1'b0),
      .carryOut(s_carryout_4),
      .dataA(s_lca_15_0[4]),
      .dataB(s_carryout_3),
      .result(s_nlca_15_0_out[4])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_3 (
      .carryIn(1'b0),
      .carryOut(s_carryout_5),
      .dataA(s_lca_15_0[5]),
      .dataB(s_carryout_4),
      .result(s_nlca_15_0_out[5])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_4 (
      .carryIn(1'b0),
      .carryOut(s_carryout_6),
      .dataA(s_lca_15_0[6]),
      .dataB(s_carryout_5),
      .result(s_nlca_15_0_out[6])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_5 (
      .carryIn(1'b0),
      .carryOut(),
      .dataA(s_lca_15_0[7]),
      .dataB(s_carryout_6),
      .result(s_nlca_15_0_out[7])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_6 (
      .carryIn(1'b0),
      .carryOut(s_carryout_8),
      .dataA(s_lca_15_0[8]),
      .dataB(s_gates1_n),
      .result(s_nlca_15_0_out[8])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_7 (
      .carryIn(1'b0),
      .carryOut(s_carryout_9),
      .dataA(s_lca_15_0[9]),
      .dataB(s_carryout_8),
      .result(s_nlca_15_0_out[9])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_8 (
      .carryIn(1'b0),
      .carryOut(s_carryout_10),
      .dataA(s_lca_15_0[10]),
      .dataB(s_carryout_9),
      .result(s_nlca_15_0_out[10])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_9 (
      .carryIn(1'b0),
      .carryOut(s_carryout_11),
      .dataA(s_lca_15_0[11]),
      .dataB(s_carryout_10),
      .result(s_nlca_15_0_out[11])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_10 (
      .carryIn(1'b0),
      .carryOut(),
      .dataA(s_lca_15_0[12]),
      .dataB(s_carryout_11),
      .result(s_nlca_15_0_out[12])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_11 (
      .carryIn(1'b0),
      .carryOut(s_carryout_13),
      .dataA(s_lca_15_0[13]),
      .dataB(s_gates2_n),
      .result(s_nlca_15_0_out[13])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_12 (
      .carryIn(1'b0),
      .carryOut(s_carryout_14),
      .dataA(s_lca_15_0[14]),
      .dataB(s_carryout_13),
      .result(s_nlca_15_0_out[14])
  );

  FullAdder #(
      .extendedBits(2)
  ) ARITH_13 (
      .carryIn(1'b0),
      .carryOut(),
      .dataA(s_lca_15_0[15]),
      .dataB(s_carryout_14),
      .result(s_nlca_15_0_out[15])
  );

  `endif

endmodule

/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/VECGEN/PTY/PTYENC                                     **
** PRIORITY ENCODER                                                      **
**                                                                       **
** Page 83                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_INTR_CNTLR_VECGEN_PTY_PTYENC(
   input [7:0] RN,

   output       DET,
   output [2:0] V_2_0
);

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [2:0] s_v_2_0_out;
   wire [7:0] s_r_n;
   wire       s_det_out;
   wire       s_nd2_out;
   wire       s_nd3_out;
   wire       s_nd4_out;
   wire       s_nr2_out;
   wire       s_nr3_out;
   wire       s_or2_out;
   wire       s_r_1;
   wire       s_r_2;
   wire       s_r_3;
   wire       s_r_4;
   wire       s_r_5;
   wire       s_r_6;
   wire       s_r_7;
   wire       s_v_1_n_out;
   wire       s_v_2_0_out_n;
   wire       s_v_2_n_out;

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_r_n[7:0] = RN;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign DET   = s_det_out;
   assign V_2_0 = s_v_2_0_out[2:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate: V0
   assign s_v_2_0_out[0] = ~s_v_2_0_out_n;

   // NOT Gate
   assign s_r_6 = ~s_r_n[6];
   assign s_r_4 = ~s_r_n[4];
   assign s_r_2 = ~s_r_n[2];
   assign s_r_7 = ~s_r_n[7];
   assign s_r_5 = ~s_r_n[5];
   assign s_r_3 = ~s_r_n[3];
   assign s_r_1 = ~s_r_n[1];

   assign s_v_2_0_out[2] = ~s_v_2_n_out;
   assign s_v_2_0_out[1] = ~s_v_1_n_out;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   NOR_GATE #(.BubblesMask(2'b00))
      NR2 (.input1(s_r_3),
           .input2(s_r_2),
           .result(s_nr2_out));

   NOR_GATE_4_INPUTS #(.BubblesMask(4'hF))
      NRx (.input1(s_r_n[7]),
           .input2(s_nd2_out),
           .input3(s_nd3_out),
           .input4(s_nd4_out),
           .result(s_v_2_0_out_n));

   NAND_GATE #(.BubblesMask(2'b00))
      ND2 (.input1(s_r_n[6]),
           .input2(s_r_5),
           .result(s_nd2_out));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      ND3 (.input1(s_r_n[6]),
           .input2(s_r_n[4]),
           .input3(s_r_3),
           .result(s_nd3_out));

   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      ND4 (.input1(s_r_n[6]),
           .input2(s_r_n[4]),
           .input3(s_r_n[2]),
           .input4(s_r_1),
           .result(s_nd4_out));

   OR_GATE_8_INPUTS #(.BubblesMask(8'hFF))
      ND8P (.input1(s_r_n[0]),
            .input2(s_r_n[1]),
            .input3(s_r_n[2]),
            .input4(s_r_n[3]),
            .input5(s_r_n[4]),
            .input6(s_r_n[5]),
            .input7(s_r_n[6]),
            .input8(s_r_n[7]),
            .result(s_det_out));

   NOR_GATE_4_INPUTS #(.BubblesMask(4'h0))
      NR4 (.input1(s_r_4),
           .input2(s_r_5),
           .input3(s_r_6),
           .input4(s_r_7),
           .result(s_v_2_n_out));

   OR_GATE #(.BubblesMask(2'b00))
      OR2 (.input1(s_r_7),
           .input2(s_r_6),
           .result(s_or2_out));

   NOR_GATE #(.BubblesMask(2'b00))
      O1 (.input1(s_or2_out),
          .input2(s_nr3_out),
          .result(s_v_1_n_out));

   AND_GATE_3_INPUTS #(.BubblesMask(3'b111))
      NR3 (.input1(s_r_5),
           .input2(s_r_4),
           .input3(s_nr2_out),
           .result(s_nr3_out));


endmodule

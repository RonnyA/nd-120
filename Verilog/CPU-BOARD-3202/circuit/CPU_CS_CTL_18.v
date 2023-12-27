/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_CS_CTL_18                                                **
 **                                                                          **
 *****************************************************************************/

module CPU_CS_CTL_18( BRK,
                      CC_3_1_n,
                      ECSL_n,
                      ELOW_n,
                      EUPP_n,
                      EWCA_n,
                      EW_3_0_n,
                      FETCH,
                      FORM_n,
                      LCS_n,
                      LUA12,
                      RF_1_0,
                      RWCS_n,
                      TERM_n,
                      WCA_n,
                      WCS_n,
                      WU_3_0_n,
                      WW_3_0_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input       BRK;
   input [2:0] CC_3_1_n;
   input       FETCH;
   input       FORM_n;
   input       LCS_n;
   input       LUA12;
   input [1:0] RF_1_0;
   input       RWCS_n;
   input       TERM_n;
   input       WCA_n;
   input       WCS_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output       ECSL_n;
   output       ELOW_n;
   output       EUPP_n;
   output       EWCA_n;
   output [3:0] EW_3_0_n;
   output [3:0] WU_3_0_n;
   output [3:0] WW_3_0_n;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [3:0] s_logisimBus0;
   wire [3:0] s_logisimBus31;
   wire [1:0] s_logisimBus32;
   wire [3:0] s_logisimBus33;
   wire [2:0] s_logisimBus6;
   wire       s_logisimNet1;
   wire       s_logisimNet10;
   wire       s_logisimNet11;
   wire       s_logisimNet12;
   wire       s_logisimNet13;
   wire       s_logisimNet14;
   wire       s_logisimNet15;
   wire       s_logisimNet16;
   wire       s_logisimNet17;
   wire       s_logisimNet18;
   wire       s_logisimNet19;
   wire       s_logisimNet2;
   wire       s_logisimNet20;
   wire       s_logisimNet21;
   wire       s_logisimNet22;
   wire       s_logisimNet23;
   wire       s_logisimNet24;
   wire       s_logisimNet25;
   wire       s_logisimNet26;
   wire       s_logisimNet27;
   wire       s_logisimNet28;
   wire       s_logisimNet29;
   wire       s_logisimNet3;
   wire       s_logisimNet30;
   wire       s_logisimNet34;
   wire       s_logisimNet35;
   wire       s_logisimNet36;
   wire       s_logisimNet37;
   wire       s_logisimNet4;
   wire       s_logisimNet5;
   wire       s_logisimNet7;
   wire       s_logisimNet8;
   wire       s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus32[1:0] = RF_1_0;
   assign s_logisimBus6[2:0]  = CC_3_1_n;
   assign s_logisimNet1       = FETCH;
   assign s_logisimNet12      = WCS_n;
   assign s_logisimNet14      = BRK;
   assign s_logisimNet2       = LCS_n;
   assign s_logisimNet20      = LUA12;
   assign s_logisimNet21      = TERM_n;
   assign s_logisimNet25      = WCA_n;
   assign s_logisimNet30      = FORM_n;
   assign s_logisimNet7       = RWCS_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign ECSL_n   = s_logisimNet16;
   assign ELOW_n   = s_logisimNet26;
   assign EUPP_n   = s_logisimNet24;
   assign EWCA_n   = s_logisimNet9;
   assign EW_3_0_n = s_logisimBus0[3:0];
   assign WU_3_0_n = s_logisimBus31[3:0];
   assign WW_3_0_n = s_logisimBus33[3:0];

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   AND_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet2),
               .input2(s_logisimNet9),
               .result(s_logisimNet17));

   NOR_GATE #(.BubblesMask(2'b11))
      GATES_2 (.input1(s_logisimBus33[0]),
               .input2(s_logisimNet15),
               .result(s_logisimBus31[0]));

   NOR_GATE #(.BubblesMask(2'b11))
      GATES_3 (.input1(s_logisimBus33[1]),
               .input2(s_logisimNet15),
               .result(s_logisimBus31[1]));

   NOR_GATE #(.BubblesMask(2'b11))
      GATES_4 (.input1(s_logisimBus33[2]),
               .input2(s_logisimNet15),
               .result(s_logisimBus31[2]));

   NOR_GATE #(.BubblesMask(2'b11))
      GATES_5 (.input1(s_logisimBus33[3]),
               .input2(s_logisimNet15),
               .result(s_logisimBus31[3]));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74139   CHIP_30B (.A1(s_logisimBus32[0]),
                         .A2(s_logisimBus32[0]),
                         .B1(s_logisimBus32[1]),
                         .B2(s_logisimBus32[1]),
                         .G1_n(s_logisimNet17),
                         .G2_n(s_logisimNet11),
                         .Y1_0_n(s_logisimBus0[0]),
                         .Y1_1_n(s_logisimBus0[1]),
                         .Y1_2_n(s_logisimBus0[2]),
                         .Y1_3_n(s_logisimBus0[3]),
                         .Y2_0_n(s_logisimBus33[0]),
                         .Y2_1_n(s_logisimBus33[1]),
                         .Y2_2_n(s_logisimBus33[2]),
                         .Y2_3_n(s_logisimBus33[3]));

   PAL_16L8_12   PAL_44305_UCSCTL (.B0_n(s_logisimNet16),
                                   .B1_n(s_logisimNet9),
                                   .B2_n(s_logisimNet24),
                                   .B3_n(s_logisimNet26),
                                   .B4_n(),
                                   .B5_n(),
                                   .I0(s_logisimNet30),
                                   .I1(s_logisimBus6[0]),
                                   .I2(s_logisimBus6[1]),
                                   .I3(s_logisimBus6[2]),
                                   .I4(s_logisimNet2),
                                   .I5(s_logisimNet7),
                                   .I6(s_logisimNet12),
                                   .I7(s_logisimNet1),
                                   .I8(s_logisimNet14),
                                   .I9(s_logisimNet21),
                                   .Y0_n(s_logisimNet15),
                                   .Y1_n(s_logisimNet11));

endmodule

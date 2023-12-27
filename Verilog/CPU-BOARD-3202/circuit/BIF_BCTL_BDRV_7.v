/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : BIF_BCTL_BDRV_7                                              **
 **                                                                          **
 *****************************************************************************/

module BIF_BCTL_BDRV_7( APR_n,
                        BAPR_n,
                        BDAP_n,
                        BDRY25_n,
                        BDRY50_n,
                        BDRY_n,
                        BERROR_n,
                        BINACK_n,
                        BINPUT75_n,
                        BINPUT_n,
                        BIOXE_n,
                        BMEM_n,
                        BREF_n,
                        CACT_n,
                        CBWRITE_n,
                        DAP_n,
                        EIOD_n,
                        GNT50_n,
                        IBDRY_n,
                        IBREQ_n,
                        IOD_n,
                        IOXERR_n,
                        MEM_n,
                        MIS0,
                        MOR_n,
                        OUTGRANT_n,
                        OUTIDENT_n,
                        REF_n,
                        SEMRQ_n,
                        SEM_n,
                        SSEMA_n,
                        TOUT );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input APR_n;
   input BDRY25_n;
   input BDRY50_n;
   input BINPUT75_n;
   input CACT_n;
   input CBWRITE_n;
   input DAP_n;
   input EIOD_n;
   input GNT50_n;
   input IBDRY_n;
   input IBREQ_n;
   input IOD_n;
   input MEM_n;
   input MIS0;
   input REF_n;
   input SEM_n;
   input SSEMA_n;
   input TOUT;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output BAPR_n;
   output BDAP_n;
   output BDRY_n;
   output BERROR_n;
   output BINACK_n;
   output BINPUT_n;
   output BIOXE_n;
   output BMEM_n;
   output BREF_n;
   output IOXERR_n;
   output MOR_n;
   output OUTGRANT_n;
   output OUTIDENT_n;
   output SEMRQ_n;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire s_logisimNet0;
   wire s_logisimNet1;
   wire s_logisimNet10;
   wire s_logisimNet11;
   wire s_logisimNet12;
   wire s_logisimNet13;
   wire s_logisimNet14;
   wire s_logisimNet15;
   wire s_logisimNet16;
   wire s_logisimNet17;
   wire s_logisimNet18;
   wire s_logisimNet19;
   wire s_logisimNet2;
   wire s_logisimNet20;
   wire s_logisimNet21;
   wire s_logisimNet22;
   wire s_logisimNet23;
   wire s_logisimNet24;
   wire s_logisimNet25;
   wire s_logisimNet26;
   wire s_logisimNet27;
   wire s_logisimNet28;
   wire s_logisimNet29;
   wire s_logisimNet3;
   wire s_logisimNet30;
   wire s_logisimNet31;
   wire s_logisimNet32;
   wire s_logisimNet33;
   wire s_logisimNet34;
   wire s_logisimNet35;
   wire s_logisimNet36;
   wire s_logisimNet37;
   wire s_logisimNet38;
   wire s_logisimNet39;
   wire s_logisimNet4;
   wire s_logisimNet40;
   wire s_logisimNet41;
   wire s_logisimNet5;
   wire s_logisimNet6;
   wire s_logisimNet7;
   wire s_logisimNet8;
   wire s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet0  = IOD_n;
   assign s_logisimNet1  = EIOD_n;
   assign s_logisimNet16 = IBDRY_n;
   assign s_logisimNet17 = SEM_n;
   assign s_logisimNet24 = DAP_n;
   assign s_logisimNet25 = SSEMA_n;
   assign s_logisimNet26 = CACT_n;
   assign s_logisimNet28 = MEM_n;
   assign s_logisimNet30 = GNT50_n;
   assign s_logisimNet34 = REF_n;
   assign s_logisimNet35 = APR_n;
   assign s_logisimNet36 = IBREQ_n;
   assign s_logisimNet37 = BDRY25_n;
   assign s_logisimNet38 = BDRY50_n;
   assign s_logisimNet4  = BINPUT75_n;
   assign s_logisimNet41 = TOUT;
   assign s_logisimNet5  = CBWRITE_n;
   assign s_logisimNet8  = MIS0;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BAPR_n     = s_logisimNet20;
   assign BDAP_n     = s_logisimNet39;
   assign BDRY_n     = s_logisimNet15;
   assign BERROR_n   = s_logisimNet3;
   assign BINACK_n   = s_logisimNet12;
   assign BINPUT_n   = s_logisimNet18;
   assign BIOXE_n    = s_logisimNet11;
   assign BMEM_n     = s_logisimNet27;
   assign BREF_n     = s_logisimNet19;
   assign IOXERR_n   = s_logisimNet13;
   assign MOR_n      = s_logisimNet14;
   assign OUTGRANT_n = s_logisimNet31;
   assign OUTIDENT_n = s_logisimNet10;
   assign SEMRQ_n    = s_logisimNet29;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet22  =  1'b0;


   // NOT Gate
   assign s_logisimNet21 = ~s_logisimNet30;

   // NOT Gate
   assign s_logisimNet23 = ~s_logisimNet8;

   // NOT Gate
   assign s_logisimNet32 = ~s_logisimNet36;

   // NOT Gate
   assign s_logisimNet6 = ~s_logisimNet24;

   // Buffer
   assign s_logisimNet18 = s_logisimNet5;

   // Buffer
   assign s_logisimNet19 = s_logisimNet34;

   // Buffer
   assign s_logisimNet20 = s_logisimNet35;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   OR_GATE #(.BubblesMask(2'b11))
      GATES_1 (.input1(s_logisimNet40),
               .input2(s_logisimNet17),
               .result(s_logisimNet9));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_2 (.input1(s_logisimNet5),
               .input2(s_logisimNet7),
               .result(s_logisimNet29));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimNet9),
               .input2(s_logisimNet21),
               .result(s_logisimNet31));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimNet32),
               .input2(s_logisimNet0),
               .result(s_logisimNet33));

   OR_GATE #(.BubblesMask(2'b11))
      GATES_5 (.input1(s_logisimNet33),
               .input2(s_logisimNet28),
               .result(s_logisimNet2));

   AND_GATE #(.BubblesMask(2'b11))
      GATES_6 (.input1(s_logisimNet25),
               .input2(s_logisimNet26),
               .result(s_logisimNet7));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_7 (.input1(s_logisimNet6),
               .input2(s_logisimNet38),
               .result(s_logisimNet39));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_8 (.input1(s_logisimNet16),
               .input2(s_logisimNet2),
               .result(s_logisimNet27));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_9 (.input1(s_logisimNet37),
               .input2(s_logisimNet38),
               .result(s_logisimNet40));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74241   CHIP_3A (.I0_1A1(s_logisimNet8),
                        .I1_1A2(s_logisimNet23),
                        .I2_1A3(s_logisimNet4),
                        .I3_1A4(1'b0),
                        .I4_2A1(s_logisimNet0),
                        .I5_2A2(s_logisimNet28),
                        .I6_2A3(s_logisimNet22),
                        .I7_2A4(s_logisimNet3),
                        .O0_1Y1(s_logisimNet10),
                        .O1_1Y2(s_logisimNet11),
                        .O2_1Y3(s_logisimNet12),
                        .O3_1Y4(),
                        .O4_2Y1(s_logisimNet13),
                        .O5_2Y2(s_logisimNet14),
                        .O6_2Y3(s_logisimNet3),
                        .O7_2Y4(s_logisimNet15),
                        .OE1_1G_n(s_logisimNet1),
                        .OE2_2G(s_logisimNet41));

endmodule

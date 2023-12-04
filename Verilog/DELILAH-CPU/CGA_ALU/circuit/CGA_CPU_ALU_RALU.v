/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CGA_CPU_ALU_RALU                                             **
 **                                                                          **
 *****************************************************************************/

module CGA_CPU_ALU_RALU( ALUI4,
                         CI,
                         CRY,
                         FSEL,
                         F_15_0,
                         LOG,
                         OVF,
                         RN_15_0,
                         RSN,
                         SGR,
                         S_15_0,
                         ZF );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        ALUI4;
   input        CI;
   input        FSEL;
   input        LOG;
   input [15:0] RN_15_0;
   input        RSN;
   input [15:0] S_15_0;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output        CRY;
   output [15:0] F_15_0;
   output        OVF;
   output        SGR;
   output        ZF;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_logisimBus17;
   wire [15:0] s_logisimBus18;
   wire [15:0] s_logisimBus29;
   wire [15:0] s_logisimBus30;
   wire [15:0] s_logisimBus44;
   wire [15:0] s_logisimBus45;
   wire [15:0] s_logisimBus46;
   wire [15:0] s_logisimBus54;
   wire [15:0] s_logisimBus58;
   wire [15:0] s_logisimBus69;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
   wire        s_logisimNet23;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet3;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet35;
   wire        s_logisimNet36;
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet40;
   wire        s_logisimNet41;
   wire        s_logisimNet42;
   wire        s_logisimNet43;
   wire        s_logisimNet47;
   wire        s_logisimNet48;
   wire        s_logisimNet49;
   wire        s_logisimNet5;
   wire        s_logisimNet50;
   wire        s_logisimNet51;
   wire        s_logisimNet52;
   wire        s_logisimNet53;
   wire        s_logisimNet55;
   wire        s_logisimNet56;
   wire        s_logisimNet57;
   wire        s_logisimNet59;
   wire        s_logisimNet6;
   wire        s_logisimNet60;
   wire        s_logisimNet61;
   wire        s_logisimNet62;
   wire        s_logisimNet63;
   wire        s_logisimNet64;
   wire        s_logisimNet65;
   wire        s_logisimNet66;
   wire        s_logisimNet67;
   wire        s_logisimNet68;
   wire        s_logisimNet7;
   wire        s_logisimNet70;
   wire        s_logisimNet71;
   wire        s_logisimNet72;
   wire        s_logisimNet73;
   wire        s_logisimNet74;
   wire        s_logisimNet75;
   wire        s_logisimNet76;
   wire        s_logisimNet77;
   wire        s_logisimNet78;
   wire        s_logisimNet79;
   wire        s_logisimNet8;
   wire        s_logisimNet80;
   wire        s_logisimNet81;
   wire        s_logisimNet82;
   wire        s_logisimNet83;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus18[15:0] = S_15_0;
   assign s_logisimBus29[15:0] = RN_15_0;
   assign s_logisimNet10       = LOG;
   assign s_logisimNet15       = FSEL;
   assign s_logisimNet3        = ALUI4;
   assign s_logisimNet47       = RSN;
   assign s_logisimNet57       = CI;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign CRY    = s_logisimNet38;
   assign F_15_0 = s_logisimBus54[15:0];
   assign OVF    = s_logisimNet79;
   assign SGR    = s_logisimNet78;
   assign ZF     = s_logisimNet62;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimBus58 = ~s_logisimBus18;

   // NOT Gate
   assign s_logisimNet7 = ~s_logisimBus17[15];

   // NOT Gate
   assign s_logisimNet16 = ~s_logisimBus44[15];

   // NOT Gate
   assign s_logisimNet24 = ~s_logisimBus54[15];

   // NOT Gate
   assign s_logisimBus54[13] = ~s_logisimBus30[13];

   // NOT Gate
   assign s_logisimBus54[12] = ~s_logisimBus30[12];

   // NOT Gate
   assign s_logisimBus54[11] = ~s_logisimBus30[11];

   // NOT Gate
   assign s_logisimBus54[10] = ~s_logisimBus30[10];

   // NOT Gate
   assign s_logisimBus54[9] = ~s_logisimBus30[9];

   // NOT Gate
   assign s_logisimBus54[8] = ~s_logisimBus30[8];

   // NOT Gate
   assign s_logisimBus54[7] = ~s_logisimBus30[7];

   // NOT Gate
   assign s_logisimBus54[6] = ~s_logisimBus30[6];

   // NOT Gate
   assign s_logisimBus54[5] = ~s_logisimBus30[5];

   // NOT Gate
   assign s_logisimBus54[4] = ~s_logisimBus30[4];

   // NOT Gate
   assign s_logisimBus54[3] = ~s_logisimBus30[3];

   // NOT Gate
   assign s_logisimBus54[2] = ~s_logisimBus30[2];

   // NOT Gate
   assign s_logisimBus54[1] = ~s_logisimBus30[1];

   // NOT Gate
   assign s_logisimBus54[0] = ~s_logisimBus30[0];

   // NOT Gate
   assign s_logisimBus54[15] = ~s_logisimBus30[15];

   // NOT Gate
   assign s_logisimBus54[14] = ~s_logisimBus30[14];

   // NOT Gate
   assign s_logisimNet36 = ~s_logisimNet39;

   // NOT Gate
   assign s_logisimNet41 = ~s_logisimNet40;

   // NOT Gate
   assign s_logisimNet72 = ~s_logisimNet10;

   // NOT Gate
   assign s_logisimNet62 = ~s_logisimNet75;

   // NOT Gate
   assign s_logisimBus69 = ~s_logisimBus29;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   NAND_GATE_4_INPUTS #(.BubblesMask(4'h0))
      GATES_1 (.input1(s_logisimBus30[11]),
               .input2(s_logisimBus30[10]),
               .input3(s_logisimBus30[9]),
               .input4(s_logisimBus30[8]),
               .result(s_logisimNet39));

   NAND_GATE_8_INPUTS #(.BubblesMask(8'h00))
      GATES_2 (.input1(s_logisimBus30[7]),
               .input2(s_logisimBus30[6]),
               .input3(s_logisimBus30[5]),
               .input4(s_logisimBus30[4]),
               .input5(s_logisimBus30[3]),
               .input6(s_logisimBus30[2]),
               .input7(s_logisimBus30[1]),
               .input8(s_logisimBus30[0]),
               .result(s_logisimNet40));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_3 (.input1(s_logisimNet7),
               .input2(s_logisimNet24),
               .result(s_logisimNet32));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_4 (.input1(s_logisimNet7),
               .input2(s_logisimNet16),
               .result(s_logisimNet66));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_5 (.input1(s_logisimNet16),
               .input2(s_logisimNet24),
               .result(s_logisimNet63));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_6 (.input1(s_logisimBus17[15]),
               .input2(s_logisimBus44[15]),
               .input3(s_logisimNet24),
               .result(s_logisimNet2));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_7 (.input1(s_logisimNet7),
               .input2(s_logisimNet16),
               .input3(s_logisimBus54[15]),
               .result(s_logisimNet48));

   NAND_GATE_6_INPUTS #(.BubblesMask({2'b00, 4'h0}))
      GATES_8 (.input1(s_logisimBus30[15]),
               .input2(s_logisimBus30[14]),
               .input3(s_logisimBus30[13]),
               .input4(s_logisimBus30[12]),
               .input5(s_logisimNet36),
               .input6(s_logisimNet41),
               .result(s_logisimNet75));

   AND_GATE #(.BubblesMask(2'b00))
      GATES_9 (.input1(s_logisimNet72),
               .input2(s_logisimNet31),
               .result(s_logisimNet38));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_10 (.input1(s_logisimNet32),
                .input2(s_logisimNet66),
                .input3(s_logisimNet63),
                .result(s_logisimNet78));

   NAND_GATE #(.BubblesMask(2'b00))
      GATES_11 (.input1(s_logisimNet2),
                .input2(s_logisimNet48),
                .result(s_logisimNet79));

   Adder #(.extendedBits(17),
           .nrOfBits(16))
      ARITH_12 (.carryIn(s_logisimNet57),
                .carryOut(s_logisimNet31),
                .dataA(s_logisimBus17[15:0]),
                .dataB(s_logisimBus44[15:0]),
                .result(s_logisimBus46[15:0]));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   CGA_ALU_RALU_MUX216L   RN_R_MUX (.F_15_0(s_logisimBus69[15:0]),
                                    .O_15_0(s_logisimBus17[15:0]),
                                    .S(s_logisimNet47),
                                    .T_15_0(s_logisimBus29[15:0]));

   CGA_ALU_RALU_MUX216L   SN_S_MUX (.F_15_0(s_logisimBus18[15:0]),
                                    .O_15_0(s_logisimBus44[15:0]),
                                    .S(s_logisimNet3),
                                    .T_15_0(s_logisimBus58[15:0]));

   CGA_ALU_RALU_LOGOP   LOGOP (.ALU14(s_logisimNet3),
                               .A_15_0(s_logisimBus17[15:0]),
                               .FSEL(s_logisimNet15),
                               .LF_15_0(s_logisimBus45[15:0]),
                               .S_15_0(s_logisimBus18[15:0]));

   CGA_ALU_RALU_MUX216L   AF_LF_MUX (.F_15_0(s_logisimBus46[15:0]),
                                     .O_15_0(s_logisimBus30[15:0]),
                                     .S(s_logisimNet10),
                                     .T_15_0(s_logisimBus45[15:0]));

endmodule

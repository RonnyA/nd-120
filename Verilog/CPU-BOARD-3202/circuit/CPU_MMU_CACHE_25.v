/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_MMU_CACHE_25                                             **
 **                                                                          **
 *****************************************************************************/

module CPU_MMU_CACHE_25( BRK_n,
                         CA_10_0,
                         CCLR_n,
                         CD_15_0_io,
                         CON,
                         CON_n,
                         CPN_23_10_io,
                         CWR,
                         CYD,
                         DT_n,
                         ECD_n,
                         FMISS,
                         HIT,
                         HIT_1_0_n,
                         LSHADOW,
                         PD2,
                         RT_n,
                         SW1_CONSOLE,
                         UCLK,
                         WCA_n,
                         WCINH_n,
                         logisimOutputBubbles );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        BRK_n;
   input [10:0] CA_10_0;
   input        CCLR_n;
   input        CWR;
   input        CYD;
   input        DT_n;
   input        ECD_n;
   input        FMISS;
   input [1:0]  HIT_1_0_n;
   input        LSHADOW;
   input        PD2;
   input        RT_n;
   input        SW1_CONSOLE;
   input        UCLK;
   input        WCINH_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [15:0] CD_15_0_io;
   output        CON;
   output        CON_n;
   output [13:0] CPN_23_10_io;
   output        HIT;
   output        WCA_n;
   output [0:0]  logisimOutputBubbles;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [5:0]  s_logisimBus19;
   wire [3:0]  s_logisimBus2;
   wire [13:0] s_logisimBus27;
   wire [15:0] s_logisimBus3;
   wire [7:0]  s_logisimBus41;
   wire [3:0]  s_logisimBus42;
   wire [10:0] s_logisimBus7;
   wire [1:0]  s_logisimBus8;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
   wire        s_logisimNet20;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
   wire        s_logisimNet23;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet29;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet40;
   wire        s_logisimNet5;
   wire        s_logisimNet6;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
   assign s_logisimBus19[0]  = s_logisimBus41[2];
   assign s_logisimBus19[1]  = s_logisimBus41[3];
   assign s_logisimBus19[2]  = s_logisimBus41[4];
   assign s_logisimBus19[3]  = s_logisimBus41[5];
   assign s_logisimBus19[4]  = s_logisimBus41[6];
   assign s_logisimBus19[5]  = s_logisimBus41[7];
   assign s_logisimBus27[10] = s_logisimBus19[2];
   assign s_logisimBus27[11] = s_logisimBus19[3];
   assign s_logisimBus27[12] = s_logisimBus19[4];
   assign s_logisimBus27[13] = s_logisimBus19[5];
   assign s_logisimBus27[8]  = s_logisimBus19[0];
   assign s_logisimBus27[9]  = s_logisimBus19[1];

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus7[10:0] = CA_10_0;
   assign s_logisimBus8[1:0]  = HIT_1_0_n;
   assign s_logisimNet13      = SW1_CONSOLE;
   assign s_logisimNet17      = BRK_n;
   assign s_logisimNet18      = WCINH_n;
   assign s_logisimNet25      = CCLR_n;
   assign s_logisimNet30      = DT_n;
   assign s_logisimNet31      = LSHADOW;
   assign s_logisimNet32      = CYD;
   assign s_logisimNet33      = CWR;
   assign s_logisimNet38      = UCLK;
   assign s_logisimNet39      = RT_n;
   assign s_logisimNet4       = PD2;
   assign s_logisimNet40      = FMISS;
   assign s_logisimNet9       = ECD_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign CD_15_0_io   = s_logisimBus3[15:0];
   assign CON          = s_logisimNet13;
   assign CON_n        = s_logisimNet24;
   assign CPN_23_10_io = s_logisimBus27[13:0];
   assign HIT          = s_logisimNet29;
   assign WCA_n        = s_logisimNet10;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet21  =  1'b0;


   // Ground
   assign  s_logisimNet0  =  1'b0;


   // Ground
   assign  s_logisimNet23  =  1'b0;


   // Ground
   assign  s_logisimNet5  =  1'b0;


   // NOT Gate
   assign s_logisimNet24 = ~s_logisimNet13;

   // LED: LED_1
   assign logisimOutputBubbles[0] = s_logisimNet13;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_1 (.input1(s_logisimNet17),
               .input2(s_logisimNet13),
               .input3(s_logisimNet18),
               .result(s_logisimNet6));

   AND_GATE_5_INPUTS #(.BubblesMask({1'b1, 4'hF}))
      GATES_2 (.input1(s_logisimNet22),
               .input2(s_logisimBus8[1]),
               .input3(s_logisimBus8[0]),
               .input4(s_logisimNet33),
               .input5(s_logisimNet23),
               .result(s_logisimNet29));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TMM2018D_25   CHIP_23F (.A0_A10(s_logisimBus7[10:0]),
                           .CS_n(s_logisimNet9),
                           .D0_D7(s_logisimBus3[15:8]),
                           .OE_n(s_logisimNet21),
                           .W_n(s_logisimNet10));

   TMM2018D_25   CHIP_24F (.A0_A10(s_logisimBus7[10:0]),
                           .CS_n(s_logisimNet9),
                           .D0_D7(s_logisimBus3[7:0]),
                           .OE_n(s_logisimNet21),
                           .W_n(s_logisimNet10));

   PAL_16R4D   PAL_44402_UBITS (.B0_n(s_logisimNet22),
                                .B1_n(s_logisimNet10),
                                .B2_n(s_logisimNet26),
                                .B3_n(s_logisimNet37),
                                .CK(s_logisimNet38),
                                .I0(s_logisimNet30),
                                .I1(s_logisimNet39),
                                .I2(s_logisimNet31),
                                .I3(s_logisimNet40),
                                .I4(s_logisimNet32),
                                .I5(s_logisimBus8[0]),
                                .I6(s_logisimBus8[1]),
                                .I7(s_logisimNet6),
                                .OE_n(s_logisimNet4),
                                .Q0_n(s_logisimBus2[0]),
                                .Q1_n(s_logisimBus2[1]),
                                .Q2_n(),
                                .Q3_n(s_logisimNet20));

   AM9150_20   CHIP_21F (.A_9_0(s_logisimBus7[9:0]),
                         .D_4_1(s_logisimBus2[3:0]),
                         .G_n(s_logisimNet0),
                         .Q_4_1(s_logisimBus42[3:0]),
                         .R_n(s_logisimNet25),
                         .S_n(s_logisimNet0),
                         .W_n(s_logisimNet10));

   TMM2018D_25   CHIP_16F (.A0_A10(s_logisimBus7[10:0]),
                           .CS_n(s_logisimNet4),
                           .D0_D7(s_logisimBus41[7:0]),
                           .OE_n(s_logisimNet5),
                           .W_n(s_logisimNet10));

   TMM2018D_25   CHIP_20F (.A0_A10(s_logisimBus7[10:0]),
                           .CS_n(s_logisimNet4),
                           .D0_D7(s_logisimBus27[7:0]),
                           .OE_n(s_logisimNet5),
                           .W_n(s_logisimNet10));

endmodule

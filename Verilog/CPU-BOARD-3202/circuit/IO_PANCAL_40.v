/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : IO_PANCAL_40                                                 **
 **                                                                          **
 *****************************************************************************/

module IO_PANCAL_40( CLEAR_n,
                     DP_5_1_n,
                     EMP_n,
                     EPANS,
                     FUL_n,
                     IDB_15_0,
                     IONI,
                     LEV0,
                     LHIT,
                     PANOSC,
                     PA_7_0,
                     PCR_1_0,
                     PONI,
                     RMM_n,
                     STAT_4_3,
                     VAL );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input       CLEAR_n;
   input       EMP_n;
   input       EPANS;
   input       FUL_n;
   input       IONI;
   input       LEV0;
   input       LHIT;
   input       PANOSC;
   input [7:0] PA_7_0;
   input [1:0] PCR_1_0;
   input       PONI;
   input       VAL;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [4:0]  DP_5_1_n;
   output [15:0] IDB_15_0;
   output        RMM_n;
   output [1:0]  STAT_4_3;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [4:0]  s_logisimBus19;
   wire [4:0]  s_logisimBus2;
   wire [3:0]  s_logisimBus20;
   wire [1:0]  s_logisimBus3;
   wire [1:0]  s_logisimBus30;
   wire [15:0] s_logisimBus48;
   wire [7:0]  s_logisimBus50;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
   wire        s_logisimNet23;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
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
   wire        s_logisimNet44;
   wire        s_logisimNet45;
   wire        s_logisimNet46;
   wire        s_logisimNet49;
   wire        s_logisimNet5;
   wire        s_logisimNet6;
   wire        s_logisimNet7;
   wire        s_logisimNet8;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus30[1:0] = PCR_1_0;
   assign s_logisimBus50[7:0] = PA_7_0;
   assign s_logisimNet29      = FUL_n;
   assign s_logisimNet39      = CLEAR_n;
   assign s_logisimNet4       = PONI;
   assign s_logisimNet45      = VAL;
   assign s_logisimNet46      = EPANS;
   assign s_logisimNet5       = IONI;
   assign s_logisimNet6       = LHIT;
   assign s_logisimNet7       = LEV0;
   assign s_logisimNet8       = EMP_n;
   assign s_logisimNet9       = PANOSC;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign DP_5_1_n = s_logisimBus19[4:0];
   assign IDB_15_0 = s_logisimBus48[15:0];
   assign RMM_n    = s_logisimNet49;
   assign STAT_4_3 = s_logisimBus3[1:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimBus2[4:0]  =  {1'b0, 4'h0};


   // NOT Gate
   assign s_logisimBus19 = ~s_logisimBus2;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74244   CHIP_33B (.I0_1A1(s_logisimBus20[0]),
                         .I1_1A2(s_logisimBus20[1]),
                         .I2_1A3(s_logisimBus20[2]),
                         .I3_1A4(s_logisimBus20[3]),
                         .I4_2A1(s_logisimNet45),
                         .I5_2A2(s_logisimNet0),
                         .I6_2A3(s_logisimNet29),
                         .I7_2A4(s_logisimNet1),
                         .O0_1Y1(s_logisimBus48[8]),
                         .O1_1Y2(s_logisimBus48[9]),
                         .O2_1Y3(s_logisimBus48[10]),
                         .O3_1Y4(s_logisimBus48[11]),
                         .O4_2Y1(s_logisimBus48[12]),
                         .O5_2Y2(s_logisimBus48[13]),
                         .O6_2Y3(s_logisimBus48[14]),
                         .O7_2Y4(s_logisimBus48[15]),
                         .OE1_1G_n(s_logisimNet46),
                         .OE2_2G_n(s_logisimNet46));

   TTL_74374   CHIP_32B (.CK(s_logisimNet44),
                         .D1(s_logisimBus50[0]),
                         .D2(s_logisimBus50[1]),
                         .D3(s_logisimBus50[2]),
                         .D4(s_logisimBus50[3]),
                         .D5(s_logisimBus50[4]),
                         .D6(s_logisimBus50[5]),
                         .D7(s_logisimBus50[6]),
                         .D8(s_logisimBus50[7]),
                         .OE_n(s_logisimNet46),
                         .Q1(s_logisimBus48[0]),
                         .Q2(s_logisimBus48[1]),
                         .Q3(s_logisimBus48[2]),
                         .Q4(s_logisimBus48[3]),
                         .Q5(s_logisimBus48[4]),
                         .Q6(s_logisimBus48[5]),
                         .Q7(s_logisimBus48[6]),
                         .Q8(s_logisimBus48[7]));

endmodule

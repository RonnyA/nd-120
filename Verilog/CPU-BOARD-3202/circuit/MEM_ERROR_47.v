/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : MEM_ERROR_47                                                 **
 **                                                                          **
 *****************************************************************************/

module MEM_ERROR_47( BCGNT50,
                     BLOCKL25,
                     BLOCKL_n,
                     CGNT50_n,
                     CORR_n,
                     FETCH,
                     HIERR,
                     IDB_15_0,
                     LBD_23_0,
                     LERR_n,
                     LOERR,
                     MR_n,
                     PA_n,
                     PD4,
                     PS_n,
                     RDATA25,
                     RERR_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        BCGNT50;
   input        BLOCKL25;
   input        CGNT50_n;
   input        CORR_n;
   input        FETCH;
   input        HIERR;
   input [23:0] LBD_23_0;
   input        LERR_n;
   input        LOERR;
   input        MR_n;
   input        PA_n;
   input        PD4;
   input        PS_n;
   input        RDATA25;
   input        RERR_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output        BLOCKL_n;
   output [15:0] IDB_15_0;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [15:0] s_logisimBus16;
   wire [23:0] s_logisimBus17;
   wire [15:0] s_logisimBus31;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet18;
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
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet30;
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
   wire        s_logisimNet42;
   wire        s_logisimNet45;
   wire        s_logisimNet46;
   wire        s_logisimNet47;
   wire        s_logisimNet48;
   wire        s_logisimNet49;
   wire        s_logisimNet5;
   wire        s_logisimNet50;
   wire        s_logisimNet51;
   wire        s_logisimNet52;
   wire        s_logisimNet54;
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
   wire        s_logisimNet69;
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
   wire        s_logisimNet83;
   wire        s_logisimNet84;
   wire        s_logisimNet85;
   wire        s_logisimNet86;
   wire        s_logisimNet87;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus17[23:0] = LBD_23_0;
   assign s_logisimNet11       = BLOCKL25;
   assign s_logisimNet12       = PS_n;
   assign s_logisimNet13       = PA_n;
   assign s_logisimNet14       = LERR_n;
   assign s_logisimNet15       = MR_n;
   assign s_logisimNet24       = CGNT50_n;
   assign s_logisimNet25       = CORR_n;
   assign s_logisimNet26       = LOERR;
   assign s_logisimNet59       = RDATA25;
   assign s_logisimNet60       = BCGNT50;
   assign s_logisimNet61       = RERR_n;
   assign s_logisimNet62       = PD4;
   assign s_logisimNet68       = FETCH;
   assign s_logisimNet69       = HIERR;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BLOCKL_n = s_logisimNet67;
   assign IDB_15_0 = s_logisimBus16[15:0];

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Power
   assign  s_logisimNet42  =  1'b1;


   // Power
   assign  s_logisimNet83  =  1'b1;


   // Power
   assign  s_logisimNet32  =  1'b1;


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74374   CHIP_3C_PESL_LO (.CK(s_logisimNet18),
                                .D1(s_logisimBus17[23]),
                                .D2(s_logisimBus17[22]),
                                .D3(s_logisimBus17[21]),
                                .D4(s_logisimBus17[20]),
                                .D5(s_logisimBus17[19]),
                                .D6(s_logisimBus17[18]),
                                .D7(s_logisimBus17[17]),
                                .D8(s_logisimBus17[16]),
                                .OE_n(s_logisimNet23),
                                .Q1(s_logisimBus31[7]),
                                .Q2(s_logisimBus31[6]),
                                .Q3(s_logisimBus31[5]),
                                .Q4(s_logisimBus31[4]),
                                .Q5(s_logisimBus31[3]),
                                .Q6(s_logisimBus31[2]),
                                .Q7(s_logisimBus31[1]),
                                .Q8(s_logisimBus31[0]));

   PAL_16L8_12   PAL_45009_UERROR (.B0_n(s_logisimNet23),
                                   .B1_n(s_logisimNet5),
                                   .B2_n(s_logisimNet67),
                                   .B3_n(),
                                   .B4_n(),
                                   .B5_n(),
                                   .I0(s_logisimNet59),
                                   .I1(s_logisimNet11),
                                   .I2(s_logisimNet60),
                                   .I3(s_logisimNet12),
                                   .I4(s_logisimNet61),
                                   .I5(s_logisimNet13),
                                   .I6(s_logisimNet62),
                                   .I7(s_logisimNet14),
                                   .I8(1'b0),
                                   .I9(s_logisimNet15),
                                   .Y0_n(s_logisimNet10),
                                   .Y1_n(s_logisimNet18));

   TTL_74374   CHIP_4C_PEAL_HI (.CK(s_logisimNet18),
                                .D1(s_logisimBus17[15]),
                                .D2(s_logisimBus17[14]),
                                .D3(s_logisimBus17[13]),
                                .D4(s_logisimBus17[12]),
                                .D5(s_logisimBus17[11]),
                                .D6(s_logisimBus17[10]),
                                .D7(s_logisimBus17[9]),
                                .D8(s_logisimBus17[8]),
                                .OE_n(s_logisimNet5),
                                .Q1(s_logisimBus16[15]),
                                .Q2(s_logisimBus16[14]),
                                .Q3(s_logisimBus16[13]),
                                .Q4(s_logisimBus16[12]),
                                .Q5(s_logisimBus16[11]),
                                .Q6(s_logisimBus16[10]),
                                .Q7(s_logisimBus16[9]),
                                .Q8(s_logisimBus16[8]));

   TTL_74374   CHIP_6D_PEAL_LO (.CK(s_logisimNet18),
                                .D1(s_logisimBus17[7]),
                                .D2(s_logisimBus17[6]),
                                .D3(s_logisimBus17[5]),
                                .D4(s_logisimBus17[4]),
                                .D5(s_logisimBus17[3]),
                                .D6(s_logisimBus17[2]),
                                .D7(s_logisimBus17[1]),
                                .D8(s_logisimBus17[0]),
                                .OE_n(s_logisimNet5),
                                .Q1(s_logisimBus16[7]),
                                .Q2(s_logisimBus16[6]),
                                .Q3(s_logisimBus16[5]),
                                .Q4(s_logisimBus16[4]),
                                .Q5(s_logisimBus16[3]),
                                .Q6(s_logisimBus16[2]),
                                .Q7(s_logisimBus16[1]),
                                .Q8(s_logisimBus16[0]));

   TTL_74374   CHIP_7C_PESL_HI (.CK(s_logisimNet10),
                                .D1(s_logisimNet68),
                                .D2(s_logisimNet24),
                                .D3(s_logisimNet32),
                                .D4(s_logisimNet83),
                                .D5(s_logisimNet42),
                                .D6(s_logisimNet25),
                                .D7(s_logisimNet69),
                                .D8(s_logisimNet26),
                                .OE_n(s_logisimNet23),
                                .Q1(s_logisimBus31[15]),
                                .Q2(s_logisimBus31[14]),
                                .Q3(s_logisimBus31[13]),
                                .Q4(s_logisimBus31[12]),
                                .Q5(s_logisimBus31[11]),
                                .Q6(s_logisimBus31[10]),
                                .Q7(s_logisimBus31[9]),
                                .Q8(s_logisimBus31[8]));

endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : MEM_RAMC_50                                                  **
 **                                                                          **
 *****************************************************************************/

module MEM_RAMC_50( BDAP50_n,
                    BDRY50_n,
                    BGNT25,
                    BGNT25_n,
                    BGNT_n,
                    BLRQ50_n,
                    CAS,
                    CGNT25_n,
                    CGNT_n,
                    CLRQ_n,
                    HIEN_n,
                    LOEN_n,
                    MR_n,
                    OSC,
                    PD1,
                    PD3,
                    QD_n,
                    RAS,
                    RGNT_n,
                    RLRQ_n,
                    SEMRQ50_n,
                    SSEMA_n,
                    logisimOutputBubbles );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input BDAP50_n;
   input BDRY50_n;
   input BGNT25_n;
   input BLRQ50_n;
   input CGNT25_n;
   input CLRQ_n;
   input MR_n;
   input OSC;
   input PD1;
   input PD3;
   input RLRQ_n;
   input SEMRQ50_n;
   input SSEMA_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output       BGNT25;
   output       BGNT_n;
   output       CAS;
   output       CGNT_n;
   output       HIEN_n;
   output       LOEN_n;
   output       QD_n;
   output       RAS;
   output       RGNT_n;
   output [1:0] logisimOutputBubbles;

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
   wire s_logisimNet3;
   wire s_logisimNet4;
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
   assign s_logisimNet11 = MR_n;
   assign s_logisimNet17 = SSEMA_n;
   assign s_logisimNet18 = SEMRQ50_n;
   assign s_logisimNet19 = RLRQ_n;
   assign s_logisimNet2  = BDAP50_n;
   assign s_logisimNet20 = CLRQ_n;
   assign s_logisimNet21 = BLRQ50_n;
   assign s_logisimNet3  = PD1;
   assign s_logisimNet5  = OSC;
   assign s_logisimNet6  = CGNT25_n;
   assign s_logisimNet7  = BDRY50_n;
   assign s_logisimNet8  = PD3;
   assign s_logisimNet9  = BGNT25_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BGNT25 = s_logisimNet12;
   assign BGNT_n = s_logisimNet1;
   assign CAS    = s_logisimNet16;
   assign CGNT_n = s_logisimNet4;
   assign HIEN_n = s_logisimNet13;
   assign LOEN_n = s_logisimNet0;
   assign QD_n   = s_logisimNet14;
   assign RAS    = s_logisimNet15;
   assign RGNT_n = s_logisimNet10;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // LED: CPU_GRANT_INDICATOR
   assign logisimOutputBubbles[0] = s_logisimNet4;

   // LED: BUS_GRANT_INDICATOR
   assign logisimOutputBubbles[1] = s_logisimNet1;

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   PAL_16R8D   PAL_44803_URAMA (.CK(s_logisimNet5),
                                .I0(s_logisimNet0),
                                .I1(s_logisimNet19),
                                .I2(s_logisimNet11),
                                .I3(s_logisimNet20),
                                .I4(s_logisimNet21),
                                .I5(s_logisimNet17),
                                .I6(s_logisimNet18),
                                .I7(1'b0),
                                .OE_n(s_logisimNet3),
                                .Q0_n(s_logisimNet10),
                                .Q1_n(s_logisimNet4),
                                .Q2_n(s_logisimNet1),
                                .Q3_n(),
                                .Q4_n(),
                                .Q5_n(),
                                .Q6_n(),
                                .Q7_n(s_logisimNet12));

   PAL_16R8D   PAL_44902_URAMC (.CK(s_logisimNet5),
                                .I0(s_logisimNet10),
                                .I1(s_logisimNet4),
                                .I2(s_logisimNet1),
                                .I3(s_logisimNet2),
                                .I4(s_logisimNet11),
                                .I5(s_logisimNet9),
                                .I6(s_logisimNet6),
                                .I7(s_logisimNet7),
                                .OE_n(s_logisimNet8),
                                .Q0_n(),
                                .Q1_n(),
                                .Q2_n(),
                                .Q3_n(s_logisimNet14),
                                .Q4_n(s_logisimNet15),
                                .Q5_n(s_logisimNet16),
                                .Q6_n(s_logisimNet0),
                                .Q7_n(s_logisimNet13));

endmodule

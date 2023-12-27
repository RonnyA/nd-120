/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_PROC_CMDDEC_34                                           **
 **                                                                          **
 *****************************************************************************/

module CPU_PROC_CMDDEC_34( BRK_n,
                           CGABRK_n,
                           CLK,
                           CSCOMM_4_0,
                           CSIDBS_4_0,
                           CSMIS_1_0,
                           CUP,
                           CWR,
                           ERF_n,
                           IDB2,
                           LCS_n,
                           LEV0,
                           MREQ_n,
                           OPCLCS,
                           PD1,
                           PIL_3_0,
                           RRF_n,
                           RT_n,
                           RWCS_n,
                           VEX,
                           WCA_n,
                           WRTRF );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input       CGABRK_n;
   input       CLK;
   input [4:0] CSCOMM_4_0;
   input [4:0] CSIDBS_4_0;
   input [1:0] CSMIS_1_0;
   input       IDB2;
   input       LCS_n;
   input       MREQ_n;
   input       PD1;
   input [3:0] PIL_3_0;
   input       WCA_n;
   input       WRTRF;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output BRK_n;
   output CUP;
   output CWR;
   output ERF_n;
   output LEV0;
   output OPCLCS;
   output RRF_n;
   output RT_n;
   output RWCS_n;
   output VEX;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [4:0] s_logisimBus12;
   wire [4:0] s_logisimBus22;
   wire [1:0] s_logisimBus27;
   wire [3:0] s_logisimBus8;
   wire       s_logisimNet0;
   wire       s_logisimNet1;
   wire       s_logisimNet10;
   wire       s_logisimNet11;
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
   wire       s_logisimNet23;
   wire       s_logisimNet24;
   wire       s_logisimNet25;
   wire       s_logisimNet26;
   wire       s_logisimNet28;
   wire       s_logisimNet29;
   wire       s_logisimNet3;
   wire       s_logisimNet30;
   wire       s_logisimNet31;
   wire       s_logisimNet32;
   wire       s_logisimNet33;
   wire       s_logisimNet34;
   wire       s_logisimNet35;
   wire       s_logisimNet36;
   wire       s_logisimNet37;
   wire       s_logisimNet38;
   wire       s_logisimNet39;
   wire       s_logisimNet4;
   wire       s_logisimNet5;
   wire       s_logisimNet6;
   wire       s_logisimNet7;
   wire       s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus12[4:0] = CSCOMM_4_0;
   assign s_logisimBus22[4:0] = CSIDBS_4_0;
   assign s_logisimBus27[1:0] = CSMIS_1_0;
   assign s_logisimBus8[3:0]  = PIL_3_0;
   assign s_logisimNet0       = CLK;
   assign s_logisimNet10      = LCS_n;
   assign s_logisimNet23      = IDB2;
   assign s_logisimNet30      = CGABRK_n;
   assign s_logisimNet38      = MREQ_n;
   assign s_logisimNet39      = WCA_n;
   assign s_logisimNet7       = PD1;
   assign s_logisimNet9       = WRTRF;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BRK_n  = s_logisimNet11;
   assign CUP    = s_logisimNet19;
   assign CWR    = s_logisimNet20;
   assign ERF_n  = s_logisimNet33;
   assign LEV0   = s_logisimNet21;
   assign OPCLCS = s_logisimNet24;
   assign RRF_n  = s_logisimNet32;
   assign RT_n   = s_logisimNet26;
   assign RWCS_n = s_logisimNet25;
   assign VEX    = s_logisimNet18;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   NAND_GATE #(.BubblesMask(2'b11))
      GATES_1 (.input1(s_logisimNet30),
               .input2(s_logisimNet18),
               .result(s_logisimNet11));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   PAL_16R4D   PAL_44407_UERFIX (.B0_n(s_logisimNet33),
                                 .B1_n(),
                                 .B2_n(),
                                 .B3_n(),
                                 .CK(s_logisimNet0),
                                 .I0(s_logisimBus22[0]),
                                 .I1(s_logisimBus22[1]),
                                 .I2(s_logisimBus22[2]),
                                 .I3(s_logisimBus22[3]),
                                 .I4(s_logisimBus22[4]),
                                 .I5(s_logisimNet9),
                                 .I6(s_logisimNet10),
                                 .I7(1'b0),
                                 .OE_n(s_logisimNet7),
                                 .Q0_n(s_logisimNet32),
                                 .Q1_n(),
                                 .Q2_n(),
                                 .Q3_n());

   PAL_16R6D   PAL_444608_UVXFIX (.B0_n(),
                                  .B1_n(s_logisimNet6),
                                  .CK(s_logisimNet0),
                                  .I0(s_logisimBus12[4]),
                                  .I1(s_logisimBus12[3]),
                                  .I2(s_logisimBus12[2]),
                                  .I3(s_logisimBus12[1]),
                                  .I4(s_logisimBus12[0]),
                                  .I5(s_logisimBus27[1]),
                                  .I6(s_logisimBus27[0]),
                                  .I7(1'b0),
                                  .OE_n(s_logisimNet7),
                                  .Q0_n(),
                                  .Q1_n(s_logisimNet31),
                                  .Q2_n(s_logisimNet18),
                                  .Q3_n(s_logisimNet24),
                                  .Q4_n(s_logisimNet25),
                                  .Q5_n(s_logisimNet26));

   PAL_16R4D   PAL_44511_ULEV0 (.B0_n(s_logisimNet20),
                                .B1_n(),
                                .B2_n(),
                                .B3_n(s_logisimNet21),
                                .CK(s_logisimNet0),
                                .I0(s_logisimBus8[0]),
                                .I1(s_logisimBus8[1]),
                                .I2(s_logisimBus8[2]),
                                .I3(s_logisimBus8[3]),
                                .I4(s_logisimNet0),
                                .I5(s_logisimNet38),
                                .I6(s_logisimNet39),
                                .I7(1'b0),
                                .OE_n(s_logisimNet7),
                                .Q0_n(s_logisimNet19),
                                .Q1_n(),
                                .Q2_n(),
                                .Q3_n());

endmodule

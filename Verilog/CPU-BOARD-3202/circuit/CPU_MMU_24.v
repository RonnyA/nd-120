/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_MMU_24                                                   **
 **                                                                          **
 *****************************************************************************/

module CPU_MMU_24( BEDO_n,
                   BEMPID_n,
                   BLCS_n,
                   BRK_n,
                   BSTP,
                   CA_10_0,
                   CC2_n,
                   CCLR_n,
                   CD_15_0_io,
                   CUP,
                   CWR,
                   CYD,
                   DOUBLE,
                   DT_n,
                   DVACC_n,
                   ECSR_n,
                   EDO_n,
                   EMCL_n,
                   EMPID_n,
                   EORF_n,
                   ESTOF_n,
                   FMISS,
                   HIT,
                   IDB_15_0_io,
                   LAPA_n,
                   LA_20_10,
                   LCS_n,
                   LSHADOW,
                   PD2,
                   PPN_23_10_io,
                   PPN_25_10_io,
                   PT_15_0,
                   RT_n,
                   STP,
                   SW1_CONSOLE,
                   UCLK,
                   WCA_n,
                   WCHIM_n,
                   WRITE,
                   logisimOutputBubbles );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        BRK_n;
   input [10:0] CA_10_0;
   input        CC2_n;
   input        CCLR_n;
   input        CUP;
   input        CWR;
   input        CYD;
   input        DOUBLE;
   input        DT_n;
   input        DVACC_n;
   input        ECSR_n;
   input        EDO_n;
   input        EMCL_n;
   input        EMPID_n;
   input        EORF_n;
   input        ESTOF_n;
   input        FMISS;
   input [10:0] LA_20_10;
   input        LCS_n;
   input        LSHADOW;
   input        PD2;
   input        RT_n;
   input        STP;
   input        SW1_CONSOLE;
   input        UCLK;
   input        WCHIM_n;
   input        WRITE;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output        BEDO_n;
   output        BEMPID_n;
   output        BLCS_n;
   output        BSTP;
   output [15:0] CD_15_0_io;
   output        HIT;
   output [15:0] IDB_15_0_io;
   output        LAPA_n;
   output [13:0] PPN_23_10_io;
   output [15:0] PPN_25_10_io;
   output [15:0] PT_15_0;
   output        WCA_n;
   output [0:0]  logisimOutputBubbles;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [10:0] s_logisimBus17;
   wire [15:0] s_logisimBus2;
   wire [13:0] s_logisimBus21;
   wire [15:0] s_logisimBus24;
   wire [15:0] s_logisimBus29;
   wire [13:0] s_logisimBus33;
   wire [10:0] s_logisimBus34;
   wire [15:0] s_logisimBus45;
   wire [15:0] s_logisimBus5;
   wire [15:0] s_logisimBus7;
   wire [1:0]  s_logisimBus8;
   wire [15:0] s_logisimBus9;
   wire        s_logisimNet0;
   wire        s_logisimNet10;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet18;
   wire        s_logisimNet19;
   wire        s_logisimNet20;
   wire        s_logisimNet22;
   wire        s_logisimNet23;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet3;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
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
   wire        s_logisimNet46;
   wire        s_logisimNet47;
   wire        s_logisimNet48;
   wire        s_logisimNet49;
   wire        s_logisimNet50;
   wire        s_logisimNet51;
   wire        s_logisimNet52;
   wire        s_logisimNet53;
   wire        s_logisimNet54;
   wire        s_logisimNet55;
   wire        s_logisimNet56;
   wire        s_logisimNet57;
   wire        s_logisimNet58;
   wire        s_logisimNet59;
   wire        s_logisimNet6;
   wire        s_logisimNet60;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus17[10:0] = LA_20_10;
   assign s_logisimBus34[10:0] = CA_10_0;
   assign s_logisimNet14       = EMPID_n;
   assign s_logisimNet15       = LCS_n;
   assign s_logisimNet16       = ECSR_n;
   assign s_logisimNet22       = UCLK;
   assign s_logisimNet23       = CWR;
   assign s_logisimNet25       = WCHIM_n;
   assign s_logisimNet30       = CYD;
   assign s_logisimNet31       = PD2;
   assign s_logisimNet32       = SW1_CONSOLE;
   assign s_logisimNet37       = EORF_n;
   assign s_logisimNet4        = ESTOF_n;
   assign s_logisimNet40       = CUP;
   assign s_logisimNet41       = DVACC_n;
   assign s_logisimNet42       = EMCL_n;
   assign s_logisimNet48       = STP;
   assign s_logisimNet49       = EDO_n;
   assign s_logisimNet50       = DT_n;
   assign s_logisimNet51       = BRK_n;
   assign s_logisimNet53       = RT_n;
   assign s_logisimNet54       = CC2_n;
   assign s_logisimNet56       = CCLR_n;
   assign s_logisimNet57       = FMISS;
   assign s_logisimNet58       = DOUBLE;
   assign s_logisimNet59       = WRITE;
   assign s_logisimNet6        = LSHADOW;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign BEDO_n       = s_logisimNet11;
   assign BEMPID_n     = s_logisimNet46;
   assign BLCS_n       = s_logisimNet47;
   assign BSTP         = s_logisimNet10;
   assign CD_15_0_io   = s_logisimBus24[15:0];
   assign HIT          = s_logisimNet26;
   assign IDB_15_0_io  = s_logisimBus2[15:0];
   assign LAPA_n       = s_logisimNet18;
   assign PPN_23_10_io = s_logisimBus9[13:0];
   assign PPN_25_10_io = s_logisimBus9[15:0];
   assign PT_15_0      = s_logisimBus29[15:0];
   assign WCA_n        = s_logisimNet60;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   OR_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet25),
               .input2(s_logisimNet37),
               .result(s_logisimNet19));

   NAND_GATE_3_INPUTS #(.BubblesMask(3'b000))
      GATES_2 (.input1(s_logisimNet6),
               .input2(s_logisimNet59),
               .input3(s_logisimNet30),
               .result(s_logisimNet52));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   CPU_MMU_HIT_27   MMU_HIT (.CON_n(s_logisimNet3),
                             .CPN_23_10(s_logisimBus21[13:0]),
                             .FMISS(s_logisimNet57),
                             .HIT0_n(s_logisimBus8[0]),
                             .HIT1_n(s_logisimBus8[1]),
                             .LSHADOW(s_logisimNet6),
                             .PPN_23_10(s_logisimBus9[13:0]));

   CPU_MMU_PPNX_28   PPNX (.EIPL_n(s_logisimNet28),
                           .EIPUR_n(s_logisimNet27),
                           .EIPU_n(s_logisimNet36),
                           .ESTOF_n(s_logisimNet4),
                           .IDB_15_0_io(s_logisimBus2[15:0]),
                           .PPN_25_10_io(s_logisimBus7[15:0]));

   CPU_MMU_PTIDB_30   PTIDB (.EPTI_n(s_logisimNet43),
                             .IDB_15_0(s_logisimBus2[15:0]),
                             .PT_15_0(s_logisimBus5[15:0]),
                             .WRITE(s_logisimNet59));

   CPU_MMU_WCA_31   WCA (.CPN_23_10(s_logisimBus33[13:0]),
                         .PPN_23_10(s_logisimBus9[13:0]),
                         .WCA_n(s_logisimNet60));

   CPU_MMU_CSR_26   CSR (.BEDO_n(s_logisimNet11),
                         .BEMPID_n(s_logisimNet46),
                         .BLCS_n(s_logisimNet47),
                         .BSTP(s_logisimNet10),
                         .CON(s_logisimNet12),
                         .CUP(s_logisimNet40),
                         .ECSR_n(s_logisimNet16),
                         .EDO_n(s_logisimNet49),
                         .EMPID_n(s_logisimNet14),
                         .IDB_3_0(s_logisimBus45[3:0]),
                         .LCS_n(s_logisimNet15),
                         .PD2(s_logisimNet31),
                         .STP(s_logisimNet48));

   CPU_MMU_CACHE_25   CACHE (.BRK_n(s_logisimNet51),
                             .CA_10_0(s_logisimBus34[10:0]),
                             .CCLR_n(s_logisimNet56),
                             .CD_15_0_io(s_logisimBus24[15:0]),
                             .CON(s_logisimNet12),
                             .CON_n(s_logisimNet3),
                             .CPN_23_10_io(s_logisimBus21[13:0]),
                             .CWR(s_logisimNet23),
                             .CYD(s_logisimNet30),
                             .DT_n(s_logisimNet50),
                             .ECD_n(s_logisimNet0),
                             .FMISS(s_logisimNet57),
                             .HIT(s_logisimNet26),
                             .HIT_1_0_n(s_logisimBus8[1:0]),
                             .LSHADOW(s_logisimNet6),
                             .PD2(s_logisimNet31),
                             .RT_n(s_logisimNet53),
                             .SW1_CONSOLE(s_logisimNet32),
                             .UCLK(s_logisimNet22),
                             .WCA_n(s_logisimNet60),
                             .WCINH_n(s_logisimNet35),
                             .logisimOutputBubbles(logisimOutputBubbles[0 : 0]));

   PAL_16L8_12   PAL_44306_UNOCTL (.B0_n(s_logisimNet27),
                                   .B1_n(s_logisimNet36),
                                   .B2_n(s_logisimNet28),
                                   .B3_n(s_logisimNet43),
                                   .B4_n(s_logisimNet38),
                                   .B5_n(s_logisimNet13),
                                   .I0(s_logisimBus34[0]),
                                   .I1(s_logisimNet59),
                                   .I2(s_logisimNet41),
                                   .I3(s_logisimNet53),
                                   .I4(s_logisimNet25),
                                   .I5(s_logisimNet58),
                                   .I6(s_logisimNet42),
                                   .I7(s_logisimNet54),
                                   .I8(s_logisimNet60),
                                   .I9(s_logisimNet6),
                                   .Y0_n(s_logisimNet0),
                                   .Y1_n(s_logisimNet18));

   CPU_MMU_PT_29   PT (.EPMAP_n(s_logisimNet38),
                       .EPT_n(s_logisimNet13),
                       .LA_20_10(s_logisimBus17[10:0]),
                       .PPN_25_10_io(s_logisimBus9[15:0]),
                       .PT_15_0(s_logisimBus29[15:0]),
                       .WCINH_n(s_logisimNet35),
                       .WCLIM_n(s_logisimNet19),
                       .WMAP_n(s_logisimNet52));

endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_CS_16                                                    **
 **                                                                          **
 *****************************************************************************/

module CPU_CS_16( BLCS_n,
                  BRK_n,
                  CC_3_1_n,
                  CLK,
                  CSA_12_0,
                  CSBITS_io,
                  CSCA_9_0,
                  EWCA_n,
                  FETCH,
                  FORM_n,
                  IDB_15_0_io,
                  LCS_n,
                  LUA_12_0,
                  MACLK,
                  PD1,
                  RF_1_0,
                  RWCS_n,
                  TERM_n,
                  WCA_n,
                  WCS_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        BLCS_n;
   input        BRK_n;
   input [2:0]  CC_3_1_n;
   input        CLK;
   input [12:0] CSA_12_0;
   input [9:0]  CSCA_9_0;
   input        FETCH;
   input        FORM_n;
   input        LCS_n;
   input        MACLK;
   input        PD1;
   input [1:0]  RF_1_0;
   input        RWCS_n;
   input        TERM_n;
   input        WCA_n;
   input        WCS_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [63:0] CSBITS_io;
   output        EWCA_n;
   output [15:0] IDB_15_0_io;
   output [12:0] LUA_12_0;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [3:0]  s_logisimBus0;
   wire [15:0] s_logisimBus1;
   wire [63:0] s_logisimBus10;
   wire [1:0]  s_logisimBus19;
   wire [3:0]  s_logisimBus2;
   wire [15:0] s_logisimBus23;
   wire [3:0]  s_logisimBus26;
   wire [12:0] s_logisimBus34;
   wire [9:0]  s_logisimBus35;
   wire [2:0]  s_logisimBus36;
   wire [12:0] s_logisimBus7;
   wire [11:0] s_logisimBus9;
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
   wire        s_logisimNet24;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet30;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet37;
   wire        s_logisimNet4;
   wire        s_logisimNet5;
   wire        s_logisimNet6;
   wire        s_logisimNet8;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus19[1:0]  = RF_1_0;
   assign s_logisimBus34[12:0] = CSA_12_0;
   assign s_logisimBus35[9:0]  = CSCA_9_0;
   assign s_logisimBus36[2:0]  = CC_3_1_n;
   assign s_logisimNet11       = PD1;
   assign s_logisimNet17       = BLCS_n;
   assign s_logisimNet20       = MACLK;
   assign s_logisimNet22       = CLK;
   assign s_logisimNet27       = FORM_n;
   assign s_logisimNet28       = LCS_n;
   assign s_logisimNet29       = RWCS_n;
   assign s_logisimNet30       = FETCH;
   assign s_logisimNet31       = BRK_n;
   assign s_logisimNet32       = TERM_n;
   assign s_logisimNet33       = WCA_n;
   assign s_logisimNet8        = WCS_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign CSBITS_io   = s_logisimBus10[63:0];
   assign EWCA_n      = s_logisimNet37;
   assign IDB_15_0_io = s_logisimBus23[15:0];
   assign LUA_12_0    = s_logisimBus7[12:0];

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   CPU_CS_PROM_19   PROM (.BLCS_n(s_logisimNet17),
                          .IDB_15_0(s_logisimBus23[15:0]),
                          .LUA_12_0(s_logisimBus7[12:0]),
                          .RF_1_0(s_logisimBus19[1:0]));

   CPU_CS_WCS_21_22   WCS (.CSBITS_63_0_io(s_logisimBus10[63:0]),
                           .ELOW_n(s_logisimNet16),
                           .EUPP_n(s_logisimNet21),
                           .LUA_11_0(s_logisimBus7[11:0]),
                           .UUA_11_0(s_logisimBus9[11:0]),
                           .WU0_n(s_logisimBus26[0]),
                           .WU1_n(s_logisimBus26[1]),
                           .WU2_n(s_logisimBus26[2]),
                           .WU3_n(s_logisimBus26[3]),
                           .WW0_n(s_logisimBus2[0]),
                           .WW1_n(s_logisimBus2[1]),
                           .WW2_n(s_logisimBus2[2]),
                           .WW3_n(s_logisimBus2[3]));

   CPU_CS_TCV_20   TCV (.CSBITS_io(s_logisimBus10[63:0]),
                        .ECSL_n(s_logisimNet24),
                        .EW_3_0_n(s_logisimBus0[3:0]),
                        .IDB_15_0_io(s_logisimBus1[15:0]),
                        .WCS_n(s_logisimNet8));

   CPU_CS_CTL_18   CTL (.BRK(s_logisimNet31),
                        .CC_3_1_n(s_logisimBus36[2:0]),
                        .ECSL_n(s_logisimNet24),
                        .ELOW_n(s_logisimNet16),
                        .EUPP_n(s_logisimNet21),
                        .EWCA_n(s_logisimNet37),
                        .EW_3_0_n(s_logisimBus0[3:0]),
                        .FETCH(s_logisimNet30),
                        .FORM_n(s_logisimNet27),
                        .LCS_n(s_logisimNet28),
                        .LUA12(s_logisimBus7[12]),
                        .RF_1_0(s_logisimBus19[1:0]),
                        .RWCS_n(s_logisimNet29),
                        .TERM_n(s_logisimNet32),
                        .WCA_n(s_logisimNet33),
                        .WCS_n(s_logisimNet8),
                        .WU_3_0_n(s_logisimBus26[3:0]),
                        .WW_3_0_n(s_logisimBus2[3:0]));

   CPU_CS_ACAL_17   ACAL (.CLK(s_logisimNet22),
                          .CSA_12_0(s_logisimBus34[12:0]),
                          .CSCA_9_0(s_logisimBus35[9:0]),
                          .LUA_12_0(s_logisimBus7[12:0]),
                          .MACLK(s_logisimNet20),
                          .PD1(s_logisimNet11),
                          .UUA_11_0(s_logisimBus9[11:0]));

endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_MMU_HIT_27                                               **
 **                                                                          **
 *****************************************************************************/

module CPU_MMU_HIT_27( CON_n,
                       CPN_23_10,
                       FMISS,
                       HIT0_n,
                       HIT1_n,
                       LSHADOW,
                       PPN_23_10 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        CON_n;
   input [13:0] CPN_23_10;
   input        FMISS;
   input        LSHADOW;
   input [13:0] PPN_23_10;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output HIT0_n;
   output HIT1_n;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [7:0]  s_logisimBus3;
   wire [7:0]  s_logisimBus4;
   wire [13:0] s_logisimBus5;
   wire [13:0] s_logisimBus6;
   wire        s_logisimNet0;
   wire        s_logisimNet11;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet17;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet21;
   wire        s_logisimNet22;
   wire        s_logisimNet23;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet8;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all wiring is defined                                                 **
   *******************************************************************************/
   assign s_logisimBus3[0] = s_logisimNet0;
   assign s_logisimBus3[2] = s_logisimNet12;
   assign s_logisimBus3[3] = s_logisimNet13;
   assign s_logisimBus3[4] = s_logisimNet14;
   assign s_logisimBus3[5] = s_logisimNet15;
   assign s_logisimBus3[6] = s_logisimNet16;
   assign s_logisimBus3[7] = s_logisimNet17;
   assign s_logisimBus4[0] = s_logisimNet0;
   assign s_logisimBus4[1] = s_logisimNet0;
   assign s_logisimBus4[2] = s_logisimNet19;
   assign s_logisimBus4[3] = s_logisimNet20;
   assign s_logisimBus4[4] = s_logisimNet21;
   assign s_logisimBus4[5] = s_logisimNet22;
   assign s_logisimBus4[6] = s_logisimNet23;
   assign s_logisimBus4[7] = s_logisimNet24;
   assign s_logisimNet12   = s_logisimBus5[13];
   assign s_logisimNet13   = s_logisimBus5[12];
   assign s_logisimNet14   = s_logisimBus5[11];
   assign s_logisimNet15   = s_logisimBus5[10];
   assign s_logisimNet16   = s_logisimBus5[9];
   assign s_logisimNet17   = s_logisimBus5[8];
   assign s_logisimNet19   = s_logisimBus6[13];
   assign s_logisimNet20   = s_logisimBus6[12];
   assign s_logisimNet21   = s_logisimBus6[11];
   assign s_logisimNet22   = s_logisimBus6[10];
   assign s_logisimNet23   = s_logisimBus6[9];
   assign s_logisimNet24   = s_logisimBus6[8];

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus3[1]    = LSHADOW;
   assign s_logisimBus5[13:0] = PPN_23_10;
   assign s_logisimBus6[13:0] = CPN_23_10;
   assign s_logisimNet8       = FMISS;
   assign s_logisimNet9       = CON_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign HIT0_n = s_logisimNet25;
   assign HIT1_n = s_logisimNet11;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet0  =  1'b0;


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TTL_74521   CHIP_18G (.AB_n(s_logisimNet11),
                         .A_7_0(s_logisimBus3[7:0]),
                         .B_7_0(s_logisimBus4[7:0]),
                         .E_n(s_logisimNet8));

   TTL_74521   CHIP_19G (.AB_n(s_logisimNet25),
                         .A_7_0(s_logisimBus5[7:0]),
                         .B_7_0(s_logisimBus6[7:0]),
                         .E_n(s_logisimNet9));

endmodule

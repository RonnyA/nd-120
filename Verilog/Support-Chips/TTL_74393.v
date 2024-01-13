/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : TTL_74393                                                    **
 **                                                                          **
 *****************************************************************************/

module TTL_74393( A_n,
                  CLR,
                  QA,
                  QB,
                  QC,
                  QD );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input A_n;
   input CLR;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output QA;
   output QB;
   output QC;
   output QD;

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
   wire s_logisimNet2;
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
   assign s_logisimNet1  = CLR;
   assign s_logisimNet12 = A_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign QA = s_logisimNet15;
   assign QB = s_logisimNet11;
   assign QC = s_logisimNet16;
   assign QD = s_logisimNet17;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet15 = ~s_logisimNet9;

   // NOT Gate
   assign s_logisimNet11 = ~s_logisimNet14;

   // NOT Gate
   assign s_logisimNet16 = ~s_logisimNet10;

   // NOT Gate
   assign s_logisimNet17 = ~s_logisimNet8;

   // NOT Gate
   assign s_logisimNet4 = ~s_logisimNet7;

   // NOT Gate
   assign s_logisimNet13 = ~s_logisimNet2;

   // NOT Gate
   assign s_logisimNet5 = ~s_logisimNet3;

   // NOT Gate
   assign s_logisimNet6 = ~s_logisimNet0;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   D_FLIPFLOP #(.invertClockEnable(1))
      MEMORY_1 (.clock(s_logisimNet12),
                .d(s_logisimNet4),
                .preset(1'b0),
                .q(s_logisimNet7),
                .qBar(s_logisimNet9),
                .reset(s_logisimNet1),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_2 (.clock(s_logisimNet7),
                .d(s_logisimNet13),
                .preset(1'b0),
                .q(s_logisimNet2),
                .qBar(s_logisimNet14),
                .reset(s_logisimNet1),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_3 (.clock(s_logisimNet2),
                .d(s_logisimNet5),
                .preset(1'b0),
                .q(s_logisimNet3),
                .qBar(s_logisimNet10),
                .reset(s_logisimNet1),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_4 (.clock(s_logisimNet3),
                .d(s_logisimNet6),
                .preset(1'b0),
                .q(s_logisimNet0),
                .qBar(s_logisimNet8),
                .reset(s_logisimNet1),
                .tick(1'b1));


endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : TTL_74374                                                    **
 **                                                                          **
 *****************************************************************************/

module TTL_74374( CK,
                  D1,
                  D2,
                  D3,
                  D4,
                  D5,
                  D6,
                  D7,
                  D8,
                  OE_n,
                  Q1,
                  Q2,
                  Q3,
                  Q4,
                  Q5,
                  Q6,
                  Q7,
                  Q8 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input CK;
   input D1;
   input D2;
   input D3;
   input D4;
   input D5;
   input D6;
   input D7;
   input D8;
   input OE_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output Q1;
   output Q2;
   output Q3;
   output Q4;
   output Q5;
   output Q6;
   output Q7;
   output Q8;

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
   wire s_logisimNet22;
   wire s_logisimNet23;
   wire s_logisimNet24;
   wire s_logisimNet25;
   wire s_logisimNet26;
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
   assign s_logisimNet11 = D8;
   assign s_logisimNet12 = D1;
   assign s_logisimNet13 = D3;
   assign s_logisimNet14 = D6;
   assign s_logisimNet23 = D2;
   assign s_logisimNet24 = D4;
   assign s_logisimNet25 = D5;
   assign s_logisimNet26 = D7;
   assign s_logisimNet4  = CK;
   assign s_logisimNet6  = OE_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign Q1 = s_logisimNet2;
   assign Q2 = s_logisimNet16;
   assign Q3 = s_logisimNet0;
   assign Q4 = s_logisimNet15;
   assign Q5 = s_logisimNet17;
   assign Q6 = s_logisimNet3;
   assign Q7 = s_logisimNet18;
   assign Q8 = s_logisimNet1;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Controlled Buffer
   assign s_logisimNet1 = (s_logisimNet5) ? s_logisimNet19 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet2 = (s_logisimNet5) ? s_logisimNet20 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet16 = (s_logisimNet5) ? s_logisimNet7 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet0 = (s_logisimNet5) ? s_logisimNet21 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet15 = (s_logisimNet5) ? s_logisimNet8 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet17 = (s_logisimNet5) ? s_logisimNet9 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet3 = (s_logisimNet5) ? s_logisimNet22 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet18 = (s_logisimNet5) ? s_logisimNet10 : 1'bZ;

   // NOT Gate
   assign s_logisimNet5 = ~s_logisimNet6;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_1 (.clock(s_logisimNet4),
                .d(s_logisimNet11),
                .preset(1'b0),
                .q(s_logisimNet19),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_2 (.clock(s_logisimNet4),
                .d(s_logisimNet12),
                .preset(1'b0),
                .q(s_logisimNet20),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_3 (.clock(s_logisimNet4),
                .d(s_logisimNet23),
                .preset(1'b0),
                .q(s_logisimNet7),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_4 (.clock(s_logisimNet4),
                .d(s_logisimNet13),
                .preset(1'b0),
                .q(s_logisimNet21),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_5 (.clock(s_logisimNet4),
                .d(s_logisimNet24),
                .preset(1'b0),
                .q(s_logisimNet8),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_6 (.clock(s_logisimNet4),
                .d(s_logisimNet25),
                .preset(1'b0),
                .q(s_logisimNet9),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_7 (.clock(s_logisimNet4),
                .d(s_logisimNet14),
                .preset(1'b0),
                .q(s_logisimNet22),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_8 (.clock(s_logisimNet4),
                .d(s_logisimNet26),
                .preset(1'b0),
                .q(s_logisimNet10),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));


endmodule

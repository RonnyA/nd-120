/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : AM29C821                                                     **
 **                                                                          **
 *****************************************************************************/

module AM29C821( CK,
                 D0,
                 D1,
                 D2,
                 D3,
                 D4,
                 D5,
                 D6,
                 D7,
                 D8,
                 D9,
                 OE_n,
                 Y0,
                 Y1,
                 Y2,
                 Y3,
                 Y4,
                 Y5,
                 Y6,
                 Y7,
                 Y8,
                 Y9 );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input CK;
   input D0;
   input D1;
   input D2;
   input D3;
   input D4;
   input D5;
   input D6;
   input D7;
   input D8;
   input D9;
   input OE_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output Y0;
   output Y1;
   output Y2;
   output Y3;
   output Y4;
   output Y5;
   output Y6;
   output Y7;
   output Y8;
   output Y9;

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
   wire s_logisimNet27;
   wire s_logisimNet28;
   wire s_logisimNet29;
   wire s_logisimNet3;
   wire s_logisimNet30;
   wire s_logisimNet31;
   wire s_logisimNet32;
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
   assign s_logisimNet0  = CK;
   assign s_logisimNet10 = D5;
   assign s_logisimNet11 = D6;
   assign s_logisimNet12 = D7;
   assign s_logisimNet2  = OE_n;
   assign s_logisimNet3  = D3;
   assign s_logisimNet4  = D9;
   assign s_logisimNet5  = D8;
   assign s_logisimNet6  = D0;
   assign s_logisimNet7  = D1;
   assign s_logisimNet8  = D2;
   assign s_logisimNet9  = D4;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign Y0 = s_logisimNet23;
   assign Y1 = s_logisimNet24;
   assign Y2 = s_logisimNet25;
   assign Y3 = s_logisimNet27;
   assign Y4 = s_logisimNet28;
   assign Y5 = s_logisimNet29;
   assign Y6 = s_logisimNet30;
   assign Y7 = s_logisimNet31;
   assign Y8 = s_logisimNet32;
   assign Y9 = s_logisimNet26;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet1 = ~s_logisimNet2;

   // Controlled Buffer
   assign s_logisimNet26 = (s_logisimNet1) ? s_logisimNet14 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet23 = (s_logisimNet1) ? s_logisimNet16 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet24 = (s_logisimNet1) ? s_logisimNet17 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet25 = (s_logisimNet1) ? s_logisimNet18 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet27 = (s_logisimNet1) ? s_logisimNet13 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet28 = (s_logisimNet1) ? s_logisimNet19 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet29 = (s_logisimNet1) ? s_logisimNet20 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet30 = (s_logisimNet1) ? s_logisimNet21 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet31 = (s_logisimNet1) ? s_logisimNet22 : 1'bZ;

   // Controlled Buffer
   assign s_logisimNet32 = (s_logisimNet1) ? s_logisimNet15 : 1'bZ;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_1 (.clock(s_logisimNet0),
                .d(s_logisimNet4),
                .preset(1'b0),
                .q(s_logisimNet14),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_2 (.clock(s_logisimNet0),
                .d(s_logisimNet6),
                .preset(1'b0),
                .q(s_logisimNet16),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_3 (.clock(s_logisimNet0),
                .d(s_logisimNet7),
                .preset(1'b0),
                .q(s_logisimNet17),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_4 (.clock(s_logisimNet0),
                .d(s_logisimNet8),
                .preset(1'b0),
                .q(s_logisimNet18),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_5 (.clock(s_logisimNet0),
                .d(s_logisimNet3),
                .preset(1'b0),
                .q(s_logisimNet13),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_6 (.clock(s_logisimNet0),
                .d(s_logisimNet9),
                .preset(1'b0),
                .q(s_logisimNet19),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_7 (.clock(s_logisimNet0),
                .d(s_logisimNet10),
                .preset(1'b0),
                .q(s_logisimNet20),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_8 (.clock(s_logisimNet0),
                .d(s_logisimNet11),
                .preset(1'b0),
                .q(s_logisimNet21),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_9 (.clock(s_logisimNet0),
                .d(s_logisimNet12),
                .preset(1'b0),
                .q(s_logisimNet22),
                .qBar(),
                .reset(1'b0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_10 (.clock(s_logisimNet0),
                 .d(s_logisimNet5),
                 .preset(1'b0),
                 .q(s_logisimNet15),
                 .qBar(),
                 .reset(1'b0),
                 .tick(1'b1));


endmodule
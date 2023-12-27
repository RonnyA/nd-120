/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : TTL_74273                                                    **
 **                                                                          **
 *****************************************************************************/

module TTL_74273( CK,
                  CL_n,
                  D1,
                  D2,
                  D3,
                  D4,
                  D5,
                  D6,
                  D7,
                  D8,
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
   input CL_n;
   input D1;
   input D2;
   input D3;
   input D4;
   input D5;
   input D6;
   input D7;
   input D8;

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
   assign s_logisimNet1  = CK;
   assign s_logisimNet10 = CL_n;
   assign s_logisimNet15 = D2;
   assign s_logisimNet16 = D4;
   assign s_logisimNet17 = D5;
   assign s_logisimNet18 = D7;
   assign s_logisimNet6  = D8;
   assign s_logisimNet7  = D1;
   assign s_logisimNet8  = D3;
   assign s_logisimNet9  = D6;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign Q1 = s_logisimNet12;
   assign Q2 = s_logisimNet2;
   assign Q3 = s_logisimNet13;
   assign Q4 = s_logisimNet3;
   assign Q5 = s_logisimNet4;
   assign Q6 = s_logisimNet14;
   assign Q7 = s_logisimNet5;
   assign Q8 = s_logisimNet11;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // NOT Gate
   assign s_logisimNet0 = ~s_logisimNet10;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_1 (.clock(s_logisimNet1),
                .d(s_logisimNet6),
                .preset(1'b0),
                .q(s_logisimNet11),
                .qBar(),
                .reset(s_logisimNet0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_2 (.clock(s_logisimNet1),
                .d(s_logisimNet7),
                .preset(1'b0),
                .q(s_logisimNet12),
                .qBar(),
                .reset(s_logisimNet0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_3 (.clock(s_logisimNet1),
                .d(s_logisimNet15),
                .preset(1'b0),
                .q(s_logisimNet2),
                .qBar(),
                .reset(s_logisimNet0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_4 (.clock(s_logisimNet1),
                .d(s_logisimNet8),
                .preset(1'b0),
                .q(s_logisimNet13),
                .qBar(),
                .reset(s_logisimNet0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_5 (.clock(s_logisimNet1),
                .d(s_logisimNet16),
                .preset(1'b0),
                .q(s_logisimNet3),
                .qBar(),
                .reset(s_logisimNet0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_6 (.clock(s_logisimNet1),
                .d(s_logisimNet17),
                .preset(1'b0),
                .q(s_logisimNet4),
                .qBar(),
                .reset(s_logisimNet0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_7 (.clock(s_logisimNet1),
                .d(s_logisimNet9),
                .preset(1'b0),
                .q(s_logisimNet14),
                .qBar(),
                .reset(s_logisimNet0),
                .tick(1'b1));

   D_FLIPFLOP #(.invertClockEnable(0))
      MEMORY_8 (.clock(s_logisimNet1),
                .d(s_logisimNet18),
                .preset(1'b0),
                .q(s_logisimNet5),
                .qBar(),
                .reset(s_logisimNet0),
                .tick(1'b1));


endmodule

/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_CS_WCS_21_22                                             **
 **                                                                          **
 *****************************************************************************/

module CPU_CS_WCS_21_22( CSBITS_63_0_io,
                         ELOW_n,
                         EUPP_n,
                         LUA_11_0,
                         UUA_11_0,
                         WU0_n,
                         WU1_n,
                         WU2_n,
                         WU3_n,
                         WW0_n,
                         WW1_n,
                         WW2_n,
                         WW3_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        ELOW_n;
   input        EUPP_n;
   input [11:0] LUA_11_0;
   input [11:0] UUA_11_0;
   input        WU0_n;
   input        WU1_n;
   input        WU2_n;
   input        WU3_n;
   input        WW0_n;
   input        WW1_n;
   input        WW2_n;
   input        WW3_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [63:0] CSBITS_63_0_io;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [11:0] s_logisimBus1;
   wire [11:0] s_logisimBus11;
   wire [63:0] s_logisimBus45;
   wire [63:0] s_logisimBus6;
   wire        s_logisimNet0;
   wire        s_logisimNet12;
   wire        s_logisimNet15;
   wire        s_logisimNet18;
   wire        s_logisimNet2;
   wire        s_logisimNet25;
   wire        s_logisimNet29;
   wire        s_logisimNet3;
   wire        s_logisimNet4;
   wire        s_logisimNet8;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus11[11:0] = LUA_11_0;
   assign s_logisimBus1[11:0]  = UUA_11_0;
   assign s_logisimNet0        = WW2_n;
   assign s_logisimNet12       = WU3_n;
   assign s_logisimNet15       = WU2_n;
   assign s_logisimNet18       = WW3_n;
   assign s_logisimNet2        = ELOW_n;
   assign s_logisimNet25       = WU1_n;
   assign s_logisimNet29       = WW0_n;
   assign s_logisimNet3        = WU0_n;
   assign s_logisimNet4        = WW1_n;
   assign s_logisimNet8        = EUPP_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign CSBITS_63_0_io = s_logisimBus6[63:0];

   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   IDT6168A_20   CHIP_16C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[63:60]),
                           .WE_n(s_logisimNet18));

   IDT6168A_20   CHIP_17C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[59:56]),
                           .WE_n(s_logisimNet18));

   IDT6168A_20   CHIP_18C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[55:52]),
                           .WE_n(s_logisimNet18));

   IDT6168A_20   CHIP_19C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[51:48]),
                           .WE_n(s_logisimNet18));

   IDT6168A_20   CHIP_16D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[63:60]),
                           .WE_n(s_logisimNet12));

   IDT6168A_20   CHIP_17D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[59:56]),
                           .WE_n(s_logisimNet12));

   IDT6168A_20   CHIP_18D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[55:52]),
                           .WE_n(s_logisimNet12));

   IDT6168A_20   CHIP_19D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[51:48]),
                           .WE_n(s_logisimNet12));

   IDT6168A_20   CHIP_20C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[47:44]),
                           .WE_n(s_logisimNet0));

   IDT6168A_20   CHIP_21C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[43:40]),
                           .WE_n(s_logisimNet0));

   IDT6168A_20   CHIP_22C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[39:36]),
                           .WE_n(s_logisimNet0));

   IDT6168A_20   CHIP_23C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[35:32]),
                           .WE_n(s_logisimNet0));

   IDT6168A_20   CHIP_20D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[47:44]),
                           .WE_n(s_logisimNet15));

   IDT6168A_20   CHIP_21D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[43:40]),
                           .WE_n(s_logisimNet15));

   IDT6168A_20   CHIP_22D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[39:36]),
                           .WE_n(s_logisimNet15));

   IDT6168A_20   CHIP_23D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[35:32]),
                           .WE_n(s_logisimNet15));

   IDT6168A_20   CHIP_24C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[31:28]),
                           .WE_n(s_logisimNet4));

   IDT6168A_20   CHIP_25C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[27:24]),
                           .WE_n(s_logisimNet4));

   IDT6168A_20   CHIP_26C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[23:20]),
                           .WE_n(s_logisimNet4));

   IDT6168A_20   CHIP_27C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[19:16]),
                           .WE_n(s_logisimNet4));

   IDT6168A_20   CHIP_24D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[31:28]),
                           .WE_n(s_logisimNet25));

   IDT6168A_20   CHIP_25D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[27:24]),
                           .WE_n(s_logisimNet25));

   IDT6168A_20   CHIP_26D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[23:20]),
                           .WE_n(s_logisimNet25));

   IDT6168A_20   CHIP_27D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[19:16]),
                           .WE_n(s_logisimNet25));

   IDT6168A_20   CHIP_28C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[15:12]),
                           .WE_n(s_logisimNet29));

   IDT6168A_20   CHIP_29C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[11:8]),
                           .WE_n(s_logisimNet29));

   IDT6168A_20   CHIP_30C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[7:4]),
                           .WE_n(s_logisimNet29));

   IDT6168A_20   CHIP_31C (.A_11_0(s_logisimBus11[11:0]),
                           .CE_n(s_logisimNet2),
                           .D_3_0(s_logisimBus6[3:0]),
                           .WE_n(s_logisimNet29));

   IDT6168A_20   CHIP_28D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[15:12]),
                           .WE_n(s_logisimNet3));

   IDT6168A_20   CHIP_29D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[11:8]),
                           .WE_n(s_logisimNet3));

   IDT6168A_20   CHIP_30D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[7:4]),
                           .WE_n(s_logisimNet3));

   IDT6168A_20   CHIP_31D (.A_11_0(s_logisimBus1[11:0]),
                           .CE_n(s_logisimNet8),
                           .D_3_0(s_logisimBus45[3:0]),
                           .WE_n(s_logisimNet3));

endmodule

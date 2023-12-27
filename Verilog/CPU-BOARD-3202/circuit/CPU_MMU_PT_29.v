/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : CPU_MMU_PT_29                                                **
 **                                                                          **
 *****************************************************************************/

module CPU_MMU_PT_29( EPMAP_n,
                      EPT_n,
                      LA_20_10,
                      PPN_25_10_io,
                      PT_15_0,
                      WCINH_n,
                      WCLIM_n,
                      WMAP_n );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input        EPMAP_n;
   input        EPT_n;
   input [10:0] LA_20_10;
   input        WCLIM_n;
   input        WMAP_n;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output [15:0] PPN_25_10_io;
   output [15:0] PT_15_0;
   output        WCINH_n;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [10:0] s_logisimBus0;
   wire [15:0] s_logisimBus4;
   wire [15:0] s_logisimBus7;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet12;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet17;
   wire        s_logisimNet18;
   wire        s_logisimNet2;
   wire        s_logisimNet3;
   wire        s_logisimNet5;
   wire        s_logisimNet8;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus0[10:0] = LA_20_10;
   assign s_logisimNet10      = WCLIM_n;
   assign s_logisimNet18      = EPT_n;
   assign s_logisimNet3       = EPMAP_n;
   assign s_logisimNet8       = WMAP_n;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign PPN_25_10_io = s_logisimBus7[15:0];
   assign PT_15_0      = s_logisimBus4[15:0];
   assign WCINH_n      = s_logisimNet15;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet12  =  1'b0;


   // Ground
   assign  s_logisimNet1  =  1'b0;


   // Ground
   assign  s_logisimNet14  =  1'b0;


   // Ground
   assign  s_logisimNet2  =  1'b0;


   // Ground
   assign  s_logisimNet17  =  1'b0;


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   TMM2018D_25   CHIP_24G (.A0_A10(s_logisimBus0[10:0]),
                           .CS_n(s_logisimNet18),
                           .D0_D7(s_logisimBus4[15:8]),
                           .OE_n(s_logisimNet12),
                           .W_n(s_logisimNet8));

   TMM2018D_25   CHIP_25G (.A0_A10(s_logisimBus0[10:0]),
                           .CS_n(s_logisimNet18),
                           .D0_D7(s_logisimBus4[7:0]),
                           .OE_n(s_logisimNet1),
                           .W_n(s_logisimNet8));

   IMS1403_25   CHIP_20G (.A0_A13(s_logisimBus7[13:0]),
                          .CE_n(s_logisimNet14),
                          .D(s_logisimBus7[15]),
                          .Q(s_logisimNet15),
                          .W_n(s_logisimNet10));

   TMM2018D_25   CHIP_22G (.A0_A10(s_logisimBus0[10:0]),
                           .CS_n(s_logisimNet3),
                           .D0_D7(s_logisimBus7[15:8]),
                           .OE_n(s_logisimNet17),
                           .W_n(s_logisimNet8));

   TMM2018D_25   CHIP_23G (.A0_A10(s_logisimBus0[10:0]),
                           .CS_n(s_logisimNet3),
                           .D0_D7(s_logisimBus7[7:0]),
                           .OE_n(s_logisimNet2),
                           .W_n(s_logisimNet8));

endmodule

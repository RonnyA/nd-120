/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : IO_UART_42                                                   **
 **                                                                          **
 *****************************************************************************/

module IO_UART_42( CEUART_n,
                   CLK,
                   CONSOLE_n,
                   DA_n,
                   EAUTO_n,
                   EIOR_n,
                   I1P,
                   IDB_15_0_io,
                   LCS_n,
                   LOCK_n,
                   MIS_1_0,
                   O1P,
                   O2P,
                   PPOSC,
                   RUART_n,
                   RXD,
                   TBMT_n,
                   TXD,
                   XTR );

   /*******************************************************************************
   ** The inputs are defined here                                                **
   *******************************************************************************/
   input       CEUART_n;
   input       CLK;
   input       CONSOLE_n;
   input       EAUTO_n;
   input       EIOR_n;
   input       I1P;
   input       LCS_n;
   input       LOCK_n;
   input [1:0] MIS_1_0;
   input       PPOSC;
   input       RUART_n;
   input       RXD;
   input       XTR;

   /*******************************************************************************
   ** The outputs are defined here                                               **
   *******************************************************************************/
   output        DA_n;
   output [15:0] IDB_15_0_io;
   output        O1P;
   output        O2P;
   output        TBMT_n;
   output        TXD;

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire [4:0]  s_logisimBus11;
   wire [7:0]  s_logisimBus17;
   wire [1:0]  s_logisimBus18;
   wire [15:0] s_logisimBus21;
   wire        s_logisimNet0;
   wire        s_logisimNet1;
   wire        s_logisimNet10;
   wire        s_logisimNet12;
   wire        s_logisimNet13;
   wire        s_logisimNet14;
   wire        s_logisimNet15;
   wire        s_logisimNet16;
   wire        s_logisimNet19;
   wire        s_logisimNet2;
   wire        s_logisimNet20;
   wire        s_logisimNet22;
   wire        s_logisimNet23;
   wire        s_logisimNet24;
   wire        s_logisimNet25;
   wire        s_logisimNet26;
   wire        s_logisimNet27;
   wire        s_logisimNet28;
   wire        s_logisimNet3;
   wire        s_logisimNet31;
   wire        s_logisimNet32;
   wire        s_logisimNet33;
   wire        s_logisimNet34;
   wire        s_logisimNet35;
   wire        s_logisimNet36;
   wire        s_logisimNet37;
   wire        s_logisimNet38;
   wire        s_logisimNet39;
   wire        s_logisimNet4;
   wire        s_logisimNet40;
   wire        s_logisimNet5;
   wire        s_logisimNet6;
   wire        s_logisimNet7;
   wire        s_logisimNet8;
   wire        s_logisimNet9;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimBus18[1:0] = MIS_1_0;
   assign s_logisimNet0       = I1P;
   assign s_logisimNet1       = LOCK_n;
   assign s_logisimNet13      = CEUART_n;
   assign s_logisimNet14      = XTR;
   assign s_logisimNet15      = CONSOLE_n;
   assign s_logisimNet27      = RUART_n;
   assign s_logisimNet28      = PPOSC;
   assign s_logisimNet36      = EIOR_n;
   assign s_logisimNet37      = CLK;
   assign s_logisimNet38      = EAUTO_n;
   assign s_logisimNet39      = LCS_n;
   assign s_logisimNet40      = RXD;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign DA_n        = s_logisimNet4;
   assign IDB_15_0_io = s_logisimBus21[15:0];
   assign O1P         = s_logisimNet8;
   assign O2P         = s_logisimNet8;
   assign TBMT_n      = s_logisimNet20;
   assign TXD         = s_logisimNet8;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

   // Ground
   assign  s_logisimNet9  =  1'b0;


   // Constant
   assign  s_logisimBus11[4:0]  =  {1'b0, 4'h0};


   // NOT Gate
   assign s_logisimNet2 = ~s_logisimNet39;

   /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
   OR_GATE #(.BubblesMask(2'b00))
      GATES_1 (.input1(s_logisimNet0),
               .input2(s_logisimNet40),
               .result(s_logisimNet19));


   /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

   AM29C821   CHIP_33G (.CK(s_logisimNet37),
                        .D0(s_logisimNet20),
                        .D1(s_logisimNet4),
                        .D2(s_logisimNet38),
                        .D3(s_logisimNet1),
                        .D4(s_logisimNet15),
                        .D5(s_logisimBus11[4]),
                        .D6(s_logisimBus11[3]),
                        .D7(s_logisimBus11[2]),
                        .D8(s_logisimBus11[1]),
                        .D9(s_logisimBus11[0]),
                        .OE_n(s_logisimNet36),
                        .Y0(s_logisimBus21[15]),
                        .Y1(s_logisimBus21[14]),
                        .Y2(s_logisimBus21[13]),
                        .Y3(s_logisimBus21[12]),
                        .Y4(s_logisimBus21[11]),
                        .Y5(s_logisimBus21[4]),
                        .Y6(s_logisimBus21[3]),
                        .Y7(s_logisimBus21[2]),
                        .Y8(s_logisimBus21[1]),
                        .Y9(s_logisimBus21[0]));

   SC2661_UART   CHIP_32H (.A0(s_logisimBus18[0]),
                           .A1(s_logisimBus18[1]),
                           .BRCLK(s_logisimNet28),
                           .CE_n(s_logisimNet13),
                           .CTS_n(s_logisimNet9),
                           .DCD_n(s_logisimNet9),
                           .DSR_n(s_logisimNet9),
                           .DTR_n(),
                           .D_7_0(s_logisimBus17[7:0]),
                           .READ_n(s_logisimNet27),
                           .RESET(s_logisimNet2),
                           .RTS_n(),
                           .RXC_n(s_logisimNet14),
                           .RXD(s_logisimNet19),
                           .RXDRDY_n(s_logisimNet4),
                           .TXC_n(s_logisimNet14),
                           .TXD(s_logisimNet8),
                           .TXDRDY_n(s_logisimNet20),
                           .TXEMT_n());

endmodule

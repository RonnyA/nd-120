/**************************************************************************
** SC2661_UART                                                           **
**                                                                       ** 
** Last reviewed: 21-APRIL-2024                                          **
** Ronny Hansen                                                          **               
***************************************************************************/

module SC2661_UART( 
   input [1:0] ADDRESS,   
   input BRCLK,
   input CE_n,
   input CTS_n,
   input DCD_n,
   input DSR_n,
   input READ_n,
   input RESET,
   input RXC_n,
   input RXD,
   input TXC_n,

   input  [7:0] D,
   output [7:0] D_OUT,

   output       DTR_n,
   output       RTS_n,
   output       RXDRDY_n,
   output       TXD,
   output       TXDRDY_n,
   output       TXEMT_n
);


   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire       s_logisimNet0;
   wire       s_logisimNet1;
   wire       s_logisimNet10;
   wire       s_logisimNet12;
   wire       s_logisimNet13;
   wire       s_logisimNet14;
   wire       s_logisimNet15;
   wire       s_logisimNet16;
   wire       s_logisimNet17;
   wire       s_logisimNet18;
   wire       s_logisimNet2;
   wire       s_logisimNet3;
   wire       s_logisimNet4;
   wire       s_logisimNet5;
   wire       s_logisimNet6;
   wire       s_logisimNet7;
   wire       s_logisimNet8;
   wire       s_logisimNet9;

   wire [1:0] s_address;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_logisimNet0  = TXC_n;
   assign s_logisimNet1  = DCD_n;
   assign s_logisimNet12 = RESET;
   assign s_logisimNet13 = READ_n;
   assign s_address      = ADDRESS;
   assign s_logisimNet16 = CE_n;
   assign s_logisimNet17 = BRCLK;
   assign s_logisimNet18 = RXC_n;
   assign s_logisimNet2  = DSR_n;
   assign s_logisimNet3  = CTS_n;
   assign s_logisimNet4  = RXD;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   assign DTR_n    = s_logisimNet6;

   assign RTS_n    = s_logisimNet8;
   assign RXDRDY_n = s_logisimNet10;
   assign TXD      = s_logisimNet9;
   assign TXDRDY_n = s_logisimNet7;
   assign TXEMT_n  = s_logisimNet5;

   reg [7:0] data_out;

   assign D_OUT = (!CE_n & !READ_n) ? data_out :  8'bz;
endmodule

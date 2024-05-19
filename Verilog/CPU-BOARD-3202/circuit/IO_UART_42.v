/**************************************************************************
** ND120 CPU, MM&M                                                       **
** IO/UART                                                               **
** UART & IOR REG                                                        **
** SHEET 42 of 50                                                        **
**                                                                       ** 
** Last reviewed: 21-APRIL-2024                                          **
** Ronny Hansen                                                          **               
***************************************************************************/


module IO_UART_42(

   // Input signals
   input       CEUART_n,
   input       CLK,
   input       CONSOLE_n,
   input       EAUTO_n,
   input       EIOR_n,
   
   input       LCS_n,
   input       LOCK_n,
   input [1:0] MIS_1_0,
   input       PPOSC,
   input       RUART_n,

   input       XTR,

   // RS232 RX/TX signals
   input       RXD,
   output      TXD,          

   // Current loop signals
   input       I1P,
   output      O1P,
   output      O2P,

   // Baud rate settings
   input [3:0] BAUD_RATE_SWITCH,

   // Output and Input signals
   input  [7:0]  IDB_7_0_IN,
   output [15:0] IDB_15_0_OUT,

   // Output signals
   output        DA_n,
   output        TBMT_n
   
);

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/   
   wire [7:0]  s_idb_7_0_in;
   wire [1:0]  s_mis_1_0;
   
   wire [15:0] s_io_idb_15_0_out;
   wire [7:0]  s_uart_idb_7_0_out;



   wire        s_ceuart_n;
   wire        s_clk;
   wire        s_console_n;
   wire        s_da_n;
   wire        s_eauto_n;
   wire        s_eiorn_n;
   wire        s_gnd;
   wire        s_i1p;
   wire        s_lcs_n;   
   wire        s_lock_n;
   wire        s_pposc;
   wire        s_ruart_n;
   wire        s_rx;
   wire        s_rxd;
   wire        s_tbmt_n;
   wire        s_txd;
   wire        s_xtr;

   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
   assign s_mis_1_0[1:0]   = MIS_1_0;
   assign s_i1p            = I1P;
   assign s_lock_n         = LOCK_n;
   assign s_ceuart_n       = CEUART_n;
   assign s_xtr            = XTR;
   assign s_console_n      = CONSOLE_n;
   assign s_ruart_n        = RUART_n;
   assign s_pposc          = PPOSC;
   assign s_eiorn_n        = EIOR_n;
   assign s_clk            = CLK;
   assign s_eauto_n        = EAUTO_n;
   assign s_lcs_n          = LCS_n;
   assign s_rxd            = RXD;
   assign s_idb_7_0_in     = IDB_7_0_IN;

   /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
   
   assign IDB_15_0_OUT  = s_io_idb_15_0_out[15:0] | {8'b0, s_uart_idb_7_0_out[7:0]};
   
   assign  s_io_idb_15_0_out[10:5] = 6'b0;

   assign TXD           = s_txd;
   assign O1P           = s_txd;
   assign O2P           = s_txd;

   // Both DA and TBMT are pulled high 
   // DA_n (or /RXRDY from UART) signal is only valid when the receiver is enabled
   assign DA_n          = s_da_n;

   // TBMT_n (or /TXRDY from UART) signal is only valid when the transmitter is enabled
   assign TBMT_n        = s_tbmt_n;
   

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/   
   assign s_gnd         = 1'b0;
   assign s_rx          = s_i1p | s_rxd;

  
   AM29C821   CHIP_33G (.CK(s_clk),
                        .OE_n(s_eiorn_n),
                        .D({s_tbmt_n, s_da_n, s_eauto_n, s_lock_n, s_console_n, 1'b1, BAUD_RATE_SWITCH[3:0]}),
                        .Y({s_io_idb_15_0_out[15:11], s_io_idb_15_0_out[4:0]})
                        );

   SC2661_UART   CHIP_32H (.ADDRESS(s_mis_1_0[1:0]),                           

                           .BRCLK(s_pposc),                        
                           .RESET(!s_lcs_n),

                           .CE_n(s_ceuart_n),
                           .READ_n(s_ruart_n),

                           
                           .CTS_n(s_gnd), // always low
                           .DCD_n(s_gnd), // always low
                           .DSR_n(s_gnd), // always low

                           /* verilator lint_off PINCONNECTEMPTY */
                           .DTR_n(), // not connected
                           .RTS_n(), // not connected
                           /* verilator lint_on PINCONNECTEMPTY */


                           .D(s_idb_7_0_in[7:0]),
                           .D_OUT(s_uart_idb_7_0_out[7:0]),
                           
                           .RXC_n(s_xtr),
                           .RXD(s_rx),
                           .RXDRDY_n(s_da_n),

                           .TXC_n(s_xtr),
                           .TXD(s_txd),
                           .TXDRDY_n(s_tbmt_n),

                           /* verilator lint_off PINCONNECTEMPTY */
                           .TXEMT_n()
                           /* verilator lint_on PINCONNECTEMPTY */
                           );

endmodule


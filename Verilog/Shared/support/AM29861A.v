/**************************************************************************************************
** ND120 CPU                                                                                     **
**                                                                                               **
** AM29861A                                                                                      **
**                                                                                               **
** 10 Bit Bus Tranceivers                                                                        **
**                                                                                               **
** Documentation:                                                                                **
** https://datasheetspdf.com/datasheet/AM29861.html                                              **
**                                                                                               **
** Last reviewed: 11-NOV-2024                                                                    **
** Ronny Hansen                                                                                  **
***************************************************************************************************/

module AM29861A (
    input OER_n,  //! Output Enable Receiver, active low
    input OET_n,  //! Output Enable Transmitter, active low

    input [9:0] D_IN,  //! Receiver Data Bus - input (read left, write right)
    input [9:0] Y_IN,  //! Transmitter Data Bus - input (read right, write left)

    output [9:0] D_OUT,  //! Receiver Data Bus - output
    output [9:0] Y_OUT   //! Transmitter Data Bus - output
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_receive;
  wire s_transmit;

   /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  assign s_receive = !OER_n & OET_n;
  assign s_transmit = OER_n & !OET_n;

  // Logic to drive the internal bus signals
  assign Y_OUT = s_transmit ? D_IN : 10'b0;
  assign D_OUT = s_receive ? Y_IN : 10'b0;

endmodule

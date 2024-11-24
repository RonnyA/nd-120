
/**************************************************************************
** ND120 SHARED CODE                                                     **
** D FLIP-FLOP                                                           **
**                                                                       **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module D_FLIPFLOP #(
    parameter integer InvertClockEnable = 1
)(
    input clock,     //! Clock
    input d,         //! D input (DATA)
    input preset,    //! PRESET - Active-high, sets Q to 1 when asserted
    input reset,     //! RESET - Active-high, sets Q to 0 when asserted
    input tick,      //! Tick (not used, needs to be refactored out)

    output q,        //! Q out
    output qBar      //! QBar out
);

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire s_clock;
   wire s_nextState;

   /*******************************************************************************
   ** The registers are defined here                                             **
   *******************************************************************************/
   reg s_currentState;


   /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

   /*******************************************************************************
   ** Here the output signals are defined                                        **
   *******************************************************************************/
   assign q        = s_currentState;
   assign qBar     = ~(s_currentState);
   assign s_clock  = (InvertClockEnable == 0) ? clock : ~clock;

   /*******************************************************************************
   ** Here the initial register value is defined; for simulation only            **
   *******************************************************************************/
   initial
   begin
      s_currentState = 0;
   end


   /*******************************************************************************
   ** Here the actual state register is defined                                  **
   *******************************************************************************/
   /* ASYNC RESET NOT REALLY WORKING IN FPGA
   always @(posedge reset or posedge preset or posedge s_clock)
   begin
      if (reset)
         s_currentState <= 1'b0;
      else if (preset)
         s_currentState <= 1'b1;
      else if (tick)
         s_currentState <= s_nextState;
   end
   */

   always @(posedge s_clock or posedge preset or posedge reset)
   begin
      if (preset) begin
        s_currentState <= 1'b1; // Asynchronous preset (set q = 1)
      end else if (reset) begin
         s_currentState <= 1'b0; // Asynchronous reset (set q = 0)
      end else begin
         s_currentState <= d; // Synchronous D latch on clock edge
      end
   end

endmodule

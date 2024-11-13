
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
    input clock,
    input d,
    input preset,
    input reset,
    input tick,
    output q,
    output qBar
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
   ** Here the update logic is defined                                           **
   *******************************************************************************/
   assign s_nextState  =  d;

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

   always @(posedge s_clock)
   begin
      if (preset)
        s_currentState <= 1'b1; // priority to pre-set
      else if (reset)
         s_currentState <= 1'b0;
      else if (tick)
         s_currentState <= s_nextState;
   end

endmodule

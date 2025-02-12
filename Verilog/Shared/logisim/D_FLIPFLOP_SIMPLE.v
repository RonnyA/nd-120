
/**************************************************************************
** ND120 SHARED CODE                                                     **
** D FLIP-FLOP (Wihtout SET or RESET)                                    **
**                                                                       **
**                                                                       **
** Last reviewed: 9-FEB-2025                                             **
** Ronny Hansen                                                          **
***************************************************************************/


module D_FLIPFLOP_SIMPLE (
    input clock,     //! Clock
    input d,         //! D input (DATA)

    output q,        //! Q out
    output qBar      //! QBar out
);

   /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
   wire s_clock;

   /*******************************************************************************
   ** The registers are defined here                                             **
   *******************************************************************************/
   reg s_currentState;

   /*******************************************************************************
   ** Here the output signals are defined                                        **
   *******************************************************************************/
   assign q        = s_currentState;
   assign qBar     = ~(s_currentState);

   /*******************************************************************************
   ** Here the initial register value is defined; for simulation only            **
   *******************************************************************************/
   initial
   begin
      s_currentState = 0;
   end

   always @(posedge clock)
   begin
      s_currentState <= d;
   end

endmodule

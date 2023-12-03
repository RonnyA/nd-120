/******************************************************************************
 **                                                                          **
 ** Component : LATCH                                                        **
 **                                                                          **
 *****************************************************************************/

module LATCH(
      input D,
      input ENABLE,
      output reg Q,
      output reg QN );

 
   // Positive edge-triggered latch
   always @(posedge ENABLE or posedge D)
   begin
      if (ENABLE)
         Q <= D;
      // When ENABLE is low, Q retains its value
   end

   assign QN = ~Q; // Negate Q to get QN

endmodule


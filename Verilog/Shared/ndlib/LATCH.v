/******************************************************************************
 **                                                                          **
 ** Component : LATCH                                                        **
 **                                                                          **
 *****************************************************************************/

module LATCH(
      input wire D,
      input wire ENABLE,
      output reg Q,
      output reg QN );


  // Initialize Q and QN with opposite values
    initial begin
        Q = 1'b0;
        QN = 1'b1;
    end
 
   // LATCH
   always @* begin 
      if (ENABLE) begin
         Q = D;
      end        
      // When ENABLE is low, Q retains its value

      QN = ~Q; // Negate Q to get QN
   end

   

endmodule


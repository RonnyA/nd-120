/******************************************************************************
 **                                                                          **
 ** Component : F595                                                         **
 **                                                                          **
 ** R/S Latch with Gated input                                               **
 **                                                                          **
 *****************************************************************************/

module F595( 
   input H01_S, // Set
   input H02_R, // Reset
   input H03_G, // Gate Enable

   output N01_Q, // Q
   output N02_QB // Qn
);

   reg Q_int;

   wire s_signal_S;
   wire s_signal_R;

   
   // G needs to be HIGH to allow S and R to be set
   assign s_signal_S = H01_S & H03_G;
   assign s_signal_R = H02_R & H03_G;


   // Behavioral description of the R-S latch
   always @(*) begin
      if (s_signal_R && s_signal_S) begin
          // Invalid state, typically both Q and Qn should be undefined
          //Q_int = 1'bx;
          //Qn_int = 1'bx;

         // should be undefined.. but we need to define it 0
          Q_int = 1'b0;          

      end else if (s_signal_R) begin
          Q_int = 1'b0;          
      end else if (s_signal_S) begin
          Q_int = 1'b1;          
      end /*else begin
          Q_int = Q_int; // Explicitly maintaining previous state (to avoid warning/error "not all control paths of combinational always assign a value")
      end*/
  end
  
  assign N01_Q = Q_int;
  assign N02_QB = ~Q_int;

endmodule

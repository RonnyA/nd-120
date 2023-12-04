/******************************************************************************
 **                                                                          **
 ** Component : MUX21LP                                                      **
 **                                                                          **
 *****************************************************************************/

module MUX21LP(
    input A, 
    input B, 
    input S, 
    output Z
);

   // 2-to-1 Multiplexer
   Multiplexer_2 PLEXER (
      .muxIn_0(A),
      .muxIn_1(B),
      .muxOut(Z),
      .sel(S)
   );

endmodule


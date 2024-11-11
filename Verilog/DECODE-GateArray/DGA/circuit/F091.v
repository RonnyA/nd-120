/**************************************************************************
** ND120 DGA (Decode Gate Array)                                         **
** DECODE/DGA                                                            **
**                                                                       **
** NEC F091 -  H,L LEVEL GENERATOR                                       **
**                                                                       **
** Last reviewed: 20-MAY-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/
module F091 (
    output N01,
    output N02
);
  assign N01 = 1'b1;  // High
  assign N02 = 1'b0;  // Low

endmodule

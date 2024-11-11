/**************************************************************************
** ND120 DGA (Decode Gate Array)                                         **
** DECODE/DGA                                                            **
**                                                                       **
** NEC F103 - Inverter x3 signal drive                                   **
**                                                                       **
** Last reviewed: 20-MAY-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module F103 (
    input  F_IN,
    output F_OUT
);

  assign F_OUT = ~F_IN;

endmodule

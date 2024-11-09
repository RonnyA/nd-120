/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CGA A02 component                                                     **
** Used in CHG/ALU page 61                                               **
**                                                                       **
** Last reviewed: 09-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module A02 (
    input  A,
    input  B,
    input  C,
    input  D,
    output Z
);


  assign Z = ~((A & B) | (C & D));

endmodule


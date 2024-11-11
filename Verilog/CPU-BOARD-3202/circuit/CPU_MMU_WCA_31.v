/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU/MMU/WCA                                                           **
** PPN TO CPN                                                            **
** SHEET 31 of 50                                                        **
**                                                                       ** 
** Last reviewed: 10-FEB-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CPU_MMU_WCA_31 (
    input  [13:0] CPN_23_10,
    input         WCA_n,
    output [13:0] PPN_23_10
);

  // Refactored logic
  assign PPN_23_10 = WCA_n ? 14'b0 : CPN_23_10;


endmodule

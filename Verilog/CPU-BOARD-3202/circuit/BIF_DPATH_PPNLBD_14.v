/**************************************************************************
** ND120 CPU, MM&M                                                       **
** BIF/DPATH/PPNLBD                                                      **
** BIF PPN TO LBD                                                        **
** SHEET 14  of 50                                                       **
**                                                                       **
** Last reviewed: 09-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module BIF_DPATH_PPNLBD_14 (
    input [13:0] PPN_23_10,
    input [ 9:0] CA_9_0,

    input EADR_n,
    input ECREQ,

    output [23:0] LBD_23_0_OUT
);

  reg [23:0] Q_reg;  // Internal register

  // Latch data on rising edge of CK
  always @(posedge ECREQ) begin
    Q_reg <= {PPN_23_10[13:0], CA_9_0[9:0]};
  end

  assign LBD_23_0_OUT = EADR_n ? 24'b0 : Q_reg;
endmodule

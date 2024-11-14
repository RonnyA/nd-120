/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component L4 (4-bit latch)                                            **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module L4 (
    input L,

    input A,
    input B,
    input C,
    input D,

    output QA,
    output QAN,
    output QB,
    output QBN,
    output QC,
    output QCN,
    output QD,
    output QDN
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_a;
  wire s_b;
  wire s_qc_n_out;
  wire s_qd_out;
  wire s_qd_n_out;
  wire s_c;
  wire s_d;
  wire s_l;
  wire s_qa_out;
  wire s_qa_n_out;
  wire s_qb_out;
  wire s_qb_n_out;
  wire s_qc_out;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_a = A;
  assign s_b = B;
  assign s_c = C;
  assign s_d = D;
  assign s_l = L;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign QA  = s_qa_out;
  assign QAN = s_qa_n_out;
  assign QB  = s_qb_out;
  assign QBN = s_qb_n_out;
  assign QC  = s_qc_out;
  assign QCN = s_qc_n_out;
  assign QD  = s_qd_out;
  assign QDN = s_qd_n_out;

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  LATCH L0 (
      .D(s_a),
      .ENABLE(s_l),
      .Q(s_qa_out),
      .QN(s_qa_n_out)
  );

  LATCH L1 (
      .D(s_b),
      .ENABLE(s_l),
      .Q(s_qb_out),
      .QN(s_qb_n_out)
  );

  LATCH L2 (
      .D(s_c),
      .ENABLE(s_l),
      .Q(s_qc_out),
      .QN(s_qc_n_out)
  );

  LATCH L3 (
      .D(s_d),
      .ENABLE(s_l),
      .Q(s_qd_out),
      .QN(s_qd_n_out)
  );

endmodule

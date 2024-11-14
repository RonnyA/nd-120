/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component L8 (8-bit latch)                                            **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module L8 (
    input L,

    input A,
    input B,
    input C,
    input D,
    input E,
    input F,
    input G,
    input H,

    output QA,
    output QAN,
    output QB,
    output QBN,
    output QC,
    output QCN,
    output QD,
    output QDN,
    output QE,
    output QEN,
    output QF,
    output QFN,
    output QG,
    output QGN,
    output QH,
    output QHN
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_h;
  wire s_a;
  wire s_qh_out;
  wire s_qh_n_out;
  wire s_qg_out;
  wire s_qg_n_out;
  wire s_qf_out;
  wire s_qf_n_out;
  wire s_qe_out;
  wire s_qe_n_out;
  wire s_qd_out;
  wire s_qd_n_out;
  wire s_b;
  wire s_qc_out;
  wire s_qc_n_out;
  wire s_qb_out;
  wire s_qb_n_out;
  wire s_qa_out;
  wire s_c;
  wire s_d;
  wire s_e;
  wire s_f;
  wire s_g;
  wire s_qa_n_out;
  wire s_l;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_a = A;
  assign s_b = B;
  assign s_c = C;
  assign s_d = D;
  assign s_e = E;
  assign s_f = F;
  assign s_g = G;
  assign s_h = H;
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
  assign QE  = s_qe_out;
  assign QEN = s_qe_n_out;
  assign QF  = s_qf_out;
  assign QFN = s_qf_n_out;
  assign QG  = s_qg_out;
  assign QGN = s_qg_n_out;
  assign QH  = s_qh_out;
  assign QHN = s_qh_n_out;

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  LATCH L7 (
      .D(s_h),
      .ENABLE(s_l),
      .Q(s_qh_out),
      .QN(s_qh_n_out)
  );

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

  LATCH L4 (
      .D(s_e),
      .ENABLE(s_l),
      .Q(s_qe_out),
      .QN(s_qe_n_out)
  );

  LATCH L5 (
      .D(s_f),
      .ENABLE(s_l),
      .Q(s_qf_out),
      .QN(s_qf_n_out)
  );

  LATCH L6 (
      .D(s_g),
      .ENABLE(s_l),
      .Q(s_qg_out),
      .QN(s_qg_n_out)
  );

endmodule

/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component : R81                                                       **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module R81 (
    input CP,

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
  wire s_cp;
  wire s_qb_n_out;
  wire s_qe_n_out;
  wire s_qf_out;
  wire s_qf_n_out;
  wire s_qg_out;
  wire s_qg_n_out;
  wire s_qh_out;
  wire s_qh_n_out;
  wire s_a;
  wire s_b;
  wire s_c;
  wire s_qa_out;
  wire s_d;
  wire s_e;
  wire s_f;
  wire s_g;
  wire s_h;
  wire s_qa_n_out;
  wire s_qb_out;
  wire s_qc_out;
  wire s_qc_n_out;
  wire s_qd_out;
  wire s_qd_n_out;
  wire s_qe_out;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_cp = CP;
  assign s_a  = A;
  assign s_b  = B;
  assign s_c  = C;
  assign s_d  = D;
  assign s_e  = E;
  assign s_f  = F;
  assign s_g  = G;
  assign s_h  = H;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign QA   = s_qa_out;
  assign QAN  = s_qa_n_out;
  assign QB   = s_qb_out;
  assign QBN  = s_qb_n_out;
  assign QC   = s_qc_out;
  assign QCN  = s_qc_n_out;
  assign QD   = s_qd_out;
  assign QDN  = s_qd_n_out;
  assign QE   = s_qe_out;
  assign QEN  = s_qe_n_out;
  assign QF   = s_qf_out;
  assign QFN  = s_qf_n_out;
  assign QG   = s_qg_out;
  assign QGN  = s_qg_n_out;
  assign QH   = s_qh_out;
  assign QHN  = s_qh_n_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_1 (
      .clock(s_cp),
      .d(s_a),
      .preset(1'b0),
      .q(s_qa_out),
      .qBar(s_qa_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_2 (
      .clock(s_cp),
      .d(s_b),
      .preset(1'b0),
      .q(s_qb_out),
      .qBar(s_qb_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_3 (
      .clock(s_cp),
      .d(s_c),
      .preset(1'b0),
      .q(s_qc_out),
      .qBar(s_qc_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_4 (
      .clock(s_cp),
      .d(s_d),
      .preset(1'b0),
      .q(s_qd_out),
      .qBar(s_qd_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_5 (
      .clock(s_cp),
      .d(s_e),
      .preset(1'b0),
      .q(s_qe_out),
      .qBar(s_qe_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_6 (
      .clock(s_cp),
      .d(s_f),
      .preset(1'b0),
      .q(s_qf_out),
      .qBar(s_qf_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_7 (
      .clock(s_cp),
      .d(s_g),
      .preset(1'b0),
      .q(s_qg_out),
      .qBar(s_qg_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_8 (
      .clock(s_cp),
      .d(s_h),
      .preset(1'b0),
      .q(s_qh_out),
      .qBar(s_qh_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );


endmodule

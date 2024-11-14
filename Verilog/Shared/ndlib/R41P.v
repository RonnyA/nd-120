/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component : R41P                                                      **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module R41P (
    input CP,

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
  wire s_qd_out;
  wire s_qd_n_out;
  wire s_b;
  wire s_c;
  wire s_d;
  wire s_qa_out;
  wire s_qa_n_out;
  wire s_qb_out;
  wire s_qb_n_out;
  wire s_qc_out;
  wire s_qc_n_out;
  wire s_cp;
  wire s_a;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_a  = A;
  assign s_b  = B;
  assign s_c  = C;
  assign s_cp = CP;
  assign s_d  = D;

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


endmodule


/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component SR44                                                        **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module SR44 (
    input A,
    input B,
    input C,
    input CP,
    input D,
    input L,
    input SI,


    output QA,
    output QAN,
    output QB,
    output QBN,
    output QC,
    output QCN,
    output QD,
    output QDN
);

  wire s_qa_out;
  wire s_qc_out;
  wire s_qb_n_out;
  wire s_qd_out;
  wire s_qd_n_out;
  wire s_plex2_out;
  wire s_plex4_out;
  wire s_b;
  wire s_d;
  wire s_qa_n_out;
  wire s_qc_n_out;
  wire s_cp;
  wire s_qb_out;
  wire s_si;
  wire s_l;
  wire s_plex1_out;
  wire s_plex3_out;
  wire s_c;
  wire s_a;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_a  = A;
  assign s_b  = B;
  assign s_c  = C;
  assign s_cp = CP;
  assign s_d  = D;
  assign s_l  = L;
  assign s_si = SI;

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
  Multiplexer_2 PLEXERS_1 (
      .muxIn_0(s_si),
      .muxIn_1(s_a),
      .muxOut(s_plex1_out),
      .sel(s_l)
  );

  Multiplexer_2 PLEXERS_2 (
      .muxIn_0(s_qa_out),
      .muxIn_1(s_b),
      .muxOut(s_plex2_out),
      .sel(s_l)
  );

  Multiplexer_2 PLEXERS_3 (
      .muxIn_0(s_qb_out),
      .muxIn_1(s_c),
      .muxOut(s_plex3_out),
      .sel(s_l)
  );

  Multiplexer_2 PLEXERS_4 (
      .muxIn_0(s_qc_out),
      .muxIn_1(s_d),
      .muxOut(s_plex4_out),
      .sel(s_l)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_5 (
      .clock(s_cp),
      .d(s_plex1_out),
      .preset(1'b0),
      .q(s_qa_out),
      .qBar(s_qa_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_6 (
      .clock(s_cp),
      .d(s_plex2_out),
      .preset(1'b0),
      .q(s_qb_out),
      .qBar(s_qb_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_7 (
      .clock(s_cp),
      .d(s_plex3_out),
      .preset(1'b0),
      .q(s_qc_out),
      .qBar(s_qc_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_8 (
      .clock(s_cp),
      .d(s_plex4_out),
      .preset(1'b0),
      .q(s_qd_out),
      .qBar(s_qd_n_out),
      .reset(1'b0),
      .tick(1'b1)
  );


endmodule

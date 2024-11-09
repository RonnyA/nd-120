/**************************************************************************
** ND120 DGA (Decode Gate Array)                                         **
** DECODE/DGA                                                            **
**                                                                       **
** NEC F924 - 4-BIT D-TYPE FLIP-FLOP                                     **
**                                                                       **
** Last reviewed: 9-NOV-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module F924 (
    // Clock
    input C_H05,

    // Data inputs
    input D0_H01,
    input D1_H02,
    input D2_H03,
    input D3_H04,

    // Normal outputs
    output N01_Q0,
    output N02_Q1,
    output N03_Q2,
    output N04_Q3,

    // Negated outputs
    output N05_Q0B,
    output N06_Q1B,
    output N07_Q2B,
    output N08_Q3B

);

  wire s_clock;
  wire s_d0;
  wire s_d1;
  wire s_d2;
  wire s_d3;
  wire s_q0_n;
  wire s_q0;
  wire s_q1_n;
  wire s_q1;
  wire s_q2_n;
  wire s_q2;
  wire s_q3_n;
  wire s_q3;

  // Assign inputs
  assign s_clock = C_H05;

  assign s_d0 = D0_H01;
  assign s_d1 = D1_H02;
  assign s_d2 = D2_H03;
  assign s_d3 = D3_H04;

  // Assign outputs
  assign N01_Q0 = s_q0;
  assign N02_Q1 = s_q1;
  assign N03_Q2 = s_q2;
  assign N04_Q3 = s_q3;
  assign N05_Q0B = s_q0_n;
  assign N06_Q1B = s_q1_n;
  assign N07_Q2B = s_q2_n;
  assign N08_Q3B = s_q3_n;

  // Implementation
  D_FLIPFLOP #(
      .invertClockEnable(0)
  ) MEMORY_1 (
      .clock(s_clock),
      .d(s_d0),
      .preset(1'b0),
      .q(s_q0),
      .qBar(s_q0_n),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .invertClockEnable(0)
  ) MEMORY_2 (
      .clock(s_clock),
      .d(s_d1),
      .preset(1'b0),
      .q(s_q1),
      .qBar(s_q1_n),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .invertClockEnable(0)
  ) MEMORY_3 (
      .clock(s_clock),
      .d(s_d2),
      .preset(1'b0),
      .q(s_q2),
      .qBar(s_q2_n),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .invertClockEnable(0)
  ) MEMORY_4 (
      .clock(s_clock),
      .d(s_d3),
      .preset(1'b0),
      .q(s_q3),
      .qBar(s_q3_n),
      .reset(1'b0),
      .tick(1'b1)
  );


endmodule

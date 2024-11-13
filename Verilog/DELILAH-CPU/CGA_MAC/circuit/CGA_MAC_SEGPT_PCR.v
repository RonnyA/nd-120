/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/MAC/SEGPT/PCR                                                    **
** PCR REGISTER                                                          **
**                                                                       **
** Page 37                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_MAC_SEGPT_PCR (
    input [15:0] FIDBO_15_7_2_0,
    input        LLDPCR,
    input        MCLKN,


    output [15:0] PCR_14_13_10_9_N,
    output [15:0] PCR_15_7_2_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_pcr_14_12_10_9_n_out;
  wire [15:0] s_pcr_15_7_2_0_out;
  wire [15:0] s_fidbo_15_7_2_0;
  wire        s_gates1_out;
  wire        s_lldpcr; 
  wire        s_mclk_n;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_fidbo_15_7_2_0[15:0] = FIDBO_15_7_2_0;
  assign s_mclk_n               = MCLKN;
  assign s_lldpcr               = LLDPCR;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign PCR_14_13_10_9_N       = s_pcr_14_12_10_9_n_out[15:0];
  assign PCR_15_7_2_0           = s_pcr_15_7_2_0_out[15:0];

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_mclk_n),
      .input2(s_lldpcr),
      .result(s_gates1_out)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  L8 PCR_HI (
      .A  (s_fidbo_15_7_2_0[15]),
      .B  (s_fidbo_15_7_2_0[14]),
      .C  (s_fidbo_15_7_2_0[13]),
      .D  (s_fidbo_15_7_2_0[12]),
      .E  (s_fidbo_15_7_2_0[11]),
      .F  (s_fidbo_15_7_2_0[10]),
      .G  (s_fidbo_15_7_2_0[9]),
      .H  (s_fidbo_15_7_2_0[8]),
      .L  (s_gates1_out),
      .QA (s_pcr_15_7_2_0_out[15]),
      .QAN(),
      .QB (s_pcr_15_7_2_0_out[14]),
      .QBN(s_pcr_14_12_10_9_n_out[14]),
      .QC (s_pcr_15_7_2_0_out[13]),
      .QCN(s_pcr_14_12_10_9_n_out[13]),
      .QD (s_pcr_15_7_2_0_out[12]),
      .QDN(),
      .QE (s_pcr_15_7_2_0_out[11]),
      .QEN(),
      .QF (s_pcr_15_7_2_0_out[10]),
      .QFN(s_pcr_14_12_10_9_n_out[10]),
      .QG (s_pcr_15_7_2_0_out[9]),
      .QGN(s_pcr_14_12_10_9_n_out[9]),
      .QH (s_pcr_15_7_2_0_out[8]),
      .QHN()
  );

  L4 PCR_LO (
      .A  (s_fidbo_15_7_2_0[7]),
      .B  (s_fidbo_15_7_2_0[2]),
      .C  (s_fidbo_15_7_2_0[1]),
      .D  (s_fidbo_15_7_2_0[0]),
      .L  (s_gates1_out),
      .QA (s_pcr_15_7_2_0_out[7]),
      .QAN(),
      .QB (s_pcr_15_7_2_0_out[2]),
      .QBN(),
      .QC (s_pcr_15_7_2_0_out[1]),
      .QCN(),
      .QD (s_pcr_15_7_2_0_out[0]),
      .QDN()
  );

endmodule

/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/VECGEN/PTY                                            **
** VECTOR GENERATOR                                                      **
**                                                                       **
** Page 83                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_INTR_CNTLR_VECGEN_PTY (
    input [15:0] MIREQ_15_0_N,

    output       HIDET,
    output [2:0] HIVEC,
    output       LODET,
    output [2:0] LOVEC
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_mireq_15_0_n;
  wire [ 2:0] s_hivec_out;
  wire [ 2:0] s_lovec_out;
  wire        s_hidet_out;
  wire        s_lodet_out;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_mireq_15_0_n[15:0] = MIREQ_15_0_N;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign HIDET = s_hidet_out;
  assign HIVEC = s_hivec_out[2:0];
  assign LODET = s_lodet_out;
  assign LOVEC = s_lovec_out[2:0];

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  CGA_INTR_CNTLR_VECGEN_PTY_PTYENC PTYENC_HI (
      .DET(s_hidet_out),
      .RN(s_mireq_15_0_n[15:8]),
      .V_2_0(s_hivec_out[2:0])
  );

  CGA_INTR_CNTLR_VECGEN_PTY_PTYENC PTYENC_LO (
      .DET(s_lodet_out),
      .RN(s_mireq_15_0_n[7:0]),
      .V_2_0(s_lovec_out[2:0])
  );

endmodule

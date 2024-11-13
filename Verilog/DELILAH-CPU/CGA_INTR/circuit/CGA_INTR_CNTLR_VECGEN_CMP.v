/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/VECGEN/CMP                                            **
** CMP                                                                   **
**                                                                       **
** Page 88                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_INTR_CNTLR_VECGEN_CMP (
    input [2:0] HISTAT_2_0,
    input [2:0] HIVEC_2_0,
    input [2:0] LOSTAT_2_0,
    input [2:0] LOVEC_2_0,

    output HIVGES,
    output LOVGES
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [2:0] s_lovec_2_0;
  wire [2:0] s_hivec_2_0;
  wire [2:0] s_lostat_2_0;
  wire [2:0] s_histat_2_0;
  wire       s_hivges_out;
  wire       s_lovges_out;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_histat_2_0[2:0] = HISTAT_2_0;
  assign s_hivec_2_0[2:0] = HIVEC_2_0;
  assign s_lostat_2_0[2:0] = LOSTAT_2_0;
  assign s_lovec_2_0[2:0] = LOVEC_2_0;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign HIVGES = s_hivges_out;
  assign LOVGES = s_lovges_out;

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  CGA_INTR_CNTLR_VECGEN_CMP_MAGCMP HICMP (
      .S_2_0(s_histat_2_0[2:0]),
      .VGES (s_hivges_out),
      .V_2_0(s_hivec_2_0[2:0])
  );

  CGA_INTR_CNTLR_VECGEN_CMP_MAGCMP LOCMP (
      .S_2_0(s_lostat_2_0[2:0]),
      .VGES (s_lovges_out),
      .V_2_0(s_lovec_2_0[2:0])
  );

endmodule

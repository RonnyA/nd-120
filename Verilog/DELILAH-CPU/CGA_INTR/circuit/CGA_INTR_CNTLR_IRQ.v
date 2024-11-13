/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/IRQ                                                   **
** IRQ                                                                   **
**                                                                       **
** Page 79                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_INTR_CNTLR_IRQ (
    input        A,
    input        B,
    input        C,
    input [15:0] CLRQ_15_0,
    input        CPN,
    input [15:0] DIN_15_0,
    input [15:0] IREQ_15_0_N,
    input        MCLK,

    output [15:0] MIREQ_15_0_N,
    output [15:0] PICMASK_15_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_clrq_15_0;
  wire [15:0] s_din_15_0;
  wire [15:0] s_ireq_15_0_n;
  wire [15:0] s_lreq_15_0;
  wire [15:0] s_mireq_15_0_n_out;
  wire [15:0] s_picmask_15_0_n_out;
  wire [15:0] s_picmask_15_0_out;
  wire        a_b;
  wire        s_a;
  wire        s_c;
  wire        s_cp_n;
  wire        s_mclk;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign a_b                 = B;
  assign s_a                 = A;
  assign s_c                 = C;
  assign s_clrq_15_0[15:0]   = CLRQ_15_0;
  assign s_cp_n              = CPN;
  assign s_din_15_0[15:0]    = DIN_15_0;
  assign s_ireq_15_0_n[15:0] = IREQ_15_0_N;
  assign s_mclk              = MCLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign MIREQ_15_0_N        = s_mireq_15_0_n_out[15:0];
  assign PICMASK_15_0        = s_picmask_15_0_out[15:0];

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  CGA_INTR_CNTLR_IRQ_REG IRQ_REG (
      .CLRQ_15_0(s_clrq_15_0[15:0]),
      .CPN(s_cp_n),
      .IRQ_15_0_N(s_ireq_15_0_n[15:0]),
      .LREQ_15_0(s_lreq_15_0[15:0]),
      .MCLK(s_mclk)
  );

  CGA_INTR_CNTLR_IRQ_MASK IRQ_MASK (
      .A(s_a),
      .B(a_b),
      .C(s_c),
      .DIN_15_0(s_din_15_0[15:0]),
      .MCLK(s_mclk),
      .PICMASK_15_0(s_picmask_15_0_out[15:0]),
      .PICMASK_15_0_N(s_picmask_15_0_n_out[15:0])
  );

  CGA_INTR_CNTLR_IRQ_MREQ IRQ_MREQ (
      .LREQ_15_0(s_lreq_15_0[15:0]),
      .MIREQ_15_0_N(s_mireq_15_0_n_out[15:0]),
      .PICMASK_15_0_N(s_picmask_15_0_n_out[15:0])
  );

endmodule

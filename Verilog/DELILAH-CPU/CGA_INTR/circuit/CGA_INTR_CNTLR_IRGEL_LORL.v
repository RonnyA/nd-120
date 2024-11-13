

/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/IRGEL/LORL                                            **
** LO RL                                                                 **
**                                                                       **
** Page 92                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_INTR_CNTLR_IRGEL_LORL (
    input       D,
    input       E,
    input       LODET,
    input [2:0] LOVEC_2_0,
    input       LOVGES,
    input       MCLK,
    input       RDN,
    input       S,

    output LIENABN,
    output LIRQ,
    output LOGAS,
    output LOGASN,
    output LOPASSALL,
    output LVE
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [2:0] s_lovec_2_0;
  wire       s_d;
  wire       s_e;
  wire       s_int_req_enable_q_n;
  wire       s_int_req_enable_q;
  wire       s_lienab_n_out;
  wire       s_lirq_out;
  wire       s_lodet;
  wire       s_logas_n_out;
  wire       s_logas_out;
  wire       s_lopassall_n;
  wire       s_lopassall_out;
  wire       s_lovges;
  wire       s_lve_out;
  wire       s_mclk;
  wire       s_rd_n;
  wire       s_s;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_lovec_2_0[2:0] = LOVEC_2_0;
  assign s_d              = D;
  assign s_rd_n           = RDN;
  assign s_e              = E;
  assign s_mclk           = MCLK;
  assign s_lodet          = LODET;
  assign s_s              = S;
  assign s_lovges         = LOVGES;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign LIENABN          = s_lienab_n_out;
  assign LIRQ             = s_lirq_out;
  assign LOGAS            = s_logas_out;
  assign LOGASN           = s_logas_n_out;
  assign LOPASSALL        = s_lopassall_out;
  assign LVE              = s_lve_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_logas_out      = ~s_logas_n_out;

  // NOT Gate
  assign s_lienab_n_out   = ~s_rd_n;

  // NOT Gate
  assign s_lopassall_out  = ~s_lopassall_n;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) GATES_1 (
      .input1(s_lve_out),
      .input2(s_lovec_2_0[2]),
      .input3(s_lovec_2_0[1]),
      .input4(s_lovec_2_0[0]),
      .result(s_logas_n_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_2 (
      .input1(s_rd_n),
      .input2(s_lodet),
      .input3(s_lovges),
      .result(s_lopassall_n)
  );

  AND_GATE #(
      .BubblesMask(2'b11)
  ) GATES_3 (
      .input1(s_lopassall_n),
      .input2(s_int_req_enable_q_n),
      .result(s_lirq_out)
  );

  AND_GATE #(
      .BubblesMask(2'b11)
  ) GATES_4 (
      .input1(s_lopassall_n),
      .input2(s_s),
      .result(s_lve_out)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  SCAN_FF INT_REQ_ENABLE_FF (
      .CLK(s_mclk),
      .D  (s_e),
      .Q  (s_int_req_enable_q),
      .QN (s_int_req_enable_q_n),
      .TE (s_d),
      .TI (s_int_req_enable_q)
  );

endmodule

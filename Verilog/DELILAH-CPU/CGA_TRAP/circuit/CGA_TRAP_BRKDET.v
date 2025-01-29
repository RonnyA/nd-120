/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/TRAP/BRKDET                                                      **
** BREAK DETECTION (?)                                                   **
**                                                                       **
** Page 103                                                              **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 19-JAN-2025                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_TRAP_BRKDET (
    input       CBRKN,
    input       ETRAPN,
    input       FTRAPN,
    input       IFETCH,
    input       IFETCHN,
    input       IINDN,
    input       INTRQ,
    input [1:0] IPCR_1_0,
    input [1:0] IPCR_1_0_N,
    input [6:0] IPT_15_9,
    input [6:0] IPT_15_9_N,
    input       IWRITE,
    input       IWRITEN,
    input       VACC,
    input       VTRAPN,


    output BRKN,
    output TRAPN
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [1:0] s_ipcr_1_0;
  wire [6:0] s_ipt_15_9;
  wire [1:0] s_ipcr_1_0_n;
  wire [6:0] s_ipt_15_9_n;
  wire       s_a02_1_z_out;
  wire       s_a02_2_z_out;
  wire       s_a02_3_z_out;
  wire       s_a02_4_z_out;
  wire       s_an2_1_out;
  wire       s_brk_n_out;
  wire       s_cbrk_n;
  wire       s_cbrk;
  wire       s_etrap_n;
  wire       s_ftrap_n;
  wire       s_gates10_out;
  wire       s_gates12_out;
  wire       s_gates14_out;
  wire       s_gates15_out;
  wire       s_gates18_out;
  wire       s_gates19_out;
  wire       s_gates2_out;
  wire       s_gates20_out;
  wire       s_gates21_out;
  wire       s_gates22_out;
  wire       s_gates23_out;
  wire       s_gates24_out;
  wire       s_gates4_out;
  wire       s_gates5_out;
  wire       s_gates7_out;
  wire       s_ifetch_n;
  wire       s_ifetch;
  wire       s_iind_n;
  wire       s_intr_out;
  wire       s_intrq;
  wire       s_ipv_out;
  wire       s_iwrite_n;
  wire       s_iwrite;
  wire       s_pgf_out;
  wire       s_rd2_out;
  wire       s_rv3_out;
  wire       s_trap_n_out;
  wire       s_vacc;
  wire       s_vtrap_n;
  wire       s_vtrap;
  wire       s_wip_out;


  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_cbrk_n          = CBRKN;
  assign s_etrap_n         = ETRAPN;
  assign s_ftrap_n         = FTRAPN;
  assign s_ifetch          = IFETCH;
  assign s_ifetch_n        = IFETCHN;
  assign s_iind_n          = IINDN;
  assign s_intrq           = INTRQ;
  assign s_ipcr_1_0_n[1:0] = IPCR_1_0_N[1:0];
  assign s_ipcr_1_0[1:0]   = IPCR_1_0[1:0];
  assign s_ipt_15_9_n[6:0] = IPT_15_9_N[6:0];
  assign s_ipt_15_9[6:0]   = IPT_15_9[6:0];
  assign s_iwrite          = IWRITE;
  assign s_iwrite_n        = IWRITEN;
  assign s_vacc            = VACC;
  assign s_vtrap_n         = VTRAPN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign BRKN              = s_brk_n_out;
  assign TRAPN             = s_trap_n_out;

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_vtrap           = ~s_vtrap_n;
  assign s_cbrk            = ~s_cbrk_n;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) IPV (
      .input1(s_vacc),
      .input2(s_ipt_15_9_n[5]),
      .input3(s_ipt_15_9_n[4]),
      .result(s_ipv_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_vacc),
      .input2(s_iwrite),
      .result(s_gates2_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) WIP (
      .input1(s_gates2_out),
      .input2(s_ipt_15_9[6]),  // IPT 15 3
      .input3(s_ipt_15_9_n[3]),  // IPT 12n
      .result(s_wip_out)
  );

  AND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_4 (
      .input1(s_vacc),
      .input2(s_ifetch),
      .input3(s_ipcr_1_0[0]),
      .result(s_gates4_out)
  );

  OR_GATE_4_INPUTS #(
      .BubblesMask(4'hF)
  ) GATES_5 (
      .input1(s_ipv_out),
      .input2(s_wip_out),
      .input3(s_rd2_out),
      .input4(s_rv3_out),
      .result(s_gates5_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) RD2 (
      .input1(s_gates4_out),
      .input2(s_ipt_15_9_n[1]), //IPT 10n
      .input3(s_ipt_15_9_n[0]), //IPT 9n
      .result(s_rd2_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_7 (
      .input1(s_vacc),
      .input2(s_ipcr_1_0_n[0]),
      .result(s_gates7_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) RV3 (
      .input1(s_gates7_out),
      .input2(s_ipt_15_9[1]),
      .input3(s_ipt_15_9[0]),
      .result(s_rv3_out)
  );

  NAND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) PGF (
      .input1(s_vacc),
      .input2(s_ipt_15_9_n[6]),
      .input3(s_ipt_15_9_n[5]),
      .input4(s_ipt_15_9_n[4]),
      .result(s_pgf_out)
  );

  OR_GATE_4_INPUTS #(
      .BubblesMask(4'hF)
  ) GATES_10 (
      .input1(s_pgf_out),
      .input2(s_intr_out),
      .input3(s_gates14_out),
      .input4(s_gates15_out),
      .result(s_gates10_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) INTR (
      .input1(s_ifetch),
      .input2(s_intrq),
      .result(s_intr_out)
  );

  NOR_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_12 (
      .input1(s_gates10_out),
      .input2(s_gates5_out),
      .input3(s_gates20_out),
      .result(s_gates12_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b11)
  ) GATES_13 (
      .input1(s_gates12_out),
      .input2(s_cbrk_n),
      .result(s_brk_n_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_14 (
      .input1(s_vtrap),
      .input2(s_vacc),
      .result(s_gates14_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b11)
  ) GATES_15 (
      .input1(s_ftrap_n),
      .input2(s_ifetch_n),
      .result(s_gates15_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b111)
  ) GATES_16 (
      .input1(s_brk_n_out),
      .input2(s_cbrk),
      .input3(s_etrap_n),
      .result(s_trap_n_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) AN2_1 (
      .input1(s_vacc),
      .input2(s_iwrite),
      .result(s_an2_1_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_18 (
      .input1(s_vacc),
      .input2(s_ifetch),
      .result(s_gates18_out)
  );

  AND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) GATES_19 (
      .input1(s_vacc),
      .input2(s_iwrite_n),
      .input3(s_iind_n),
      .input4(s_ifetch_n),
      .result(s_gates19_out)
  );

  OR_GATE_4_INPUTS #(
      .BubblesMask(4'hF)
  ) GATES_20 (
      .input1(s_a02_1_z_out),
      .input2(s_a02_2_z_out),
      .input3(s_a02_3_z_out),
      .input4(s_a02_4_z_out),
      .result(s_gates20_out)
  );

  AND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_21 (
      .input1(s_vacc),
      .input2(s_ifetch),
      .input3(s_ipcr_1_0[1]),
      .result(s_gates21_out)
  );

  AND_GATE_4_INPUTS #(
      .BubblesMask(4'h0)
  ) GATES_22 (
      .input1(s_vacc),
      .input2(s_ifetch),
      .input3(s_ipcr_1_0[1]),
      .input4(s_ipcr_1_0[0]),
      .result(s_gates22_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_23 (
      .input1(s_vacc),
      .input2(s_ipcr_1_0_n[1]),
      .result(s_gates23_out)
  );

  AND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_24 (
      .input1(s_vacc),
      .input2(s_ipcr_1_0_n[1]),
      .input3(s_ipcr_1_0_n[0]),
      .result(s_gates24_out)
  );


  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  A02 A02_1 (
      .A(s_ipt_15_9_n[4]),
      .B(s_gates18_out),
      .C(s_ipt_15_9_n[6]),
      .D(s_an2_1_out),
      .Z(s_a02_1_z_out)
  );

  A02 A02_2 (
      .A(s_ipt_15_9_n[2]),
      .B(s_vacc),
      .C(s_ipt_15_9_n[5]),
      .D(s_gates19_out),
      .Z(s_a02_2_z_out)
  );

  A02 A02_3 (
      .A(s_ipt_15_9_n[0]),
      .B(s_gates22_out),
      .C(s_ipt_15_9_n[1]),
      .D(s_gates21_out),
      .Z(s_a02_3_z_out)
  );

  A02 A02_4 (
      .A(s_ipt_15_9[0]),
      .B(s_gates24_out),
      .C(s_ipt_15_9[1]),
      .D(s_gates23_out),
      .Z(s_a02_4_z_out)
  );

endmodule

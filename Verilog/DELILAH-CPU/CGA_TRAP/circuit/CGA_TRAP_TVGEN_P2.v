/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/TRAP/TVGEN/P2                                                    **
** P2                                                                    **
**                                                                       **
** Page 104                                                              **
** SHEET 2 of 2                                                          **
**                                                                       **
** Last reviewed: 19-JAN-2025                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_TRAP_TVGEN_P2 (
    input DSTOPN,
    input FTRAPN,
    input IFETCH,
    input INTRQ,
    input LEV1,
    input LEV2,
    input PAN,
    input PGF,
    input PGU,
    input PGUN,
    input PVIOL,
    input RD,
    input RV,
    input TCLK,  //! TRAP CLOCK
    input VACC,
    input VTRAPN,
    input WIP,
    input WIPN,


    output [3:0] TVEC_3_0 //! TRAP VECTOR (4 bits)
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [1:0] s_mux_selector;
  wire [3:0] s_tvec_3_0_out;
  wire       s_dstop_n;
  wire       s_ftrap_n;
  wire       s_ftrap;
  wire       s_gates10_out;
  wire       s_gates11_out;
  wire       s_gates5_out;
  wire       s_gates6_out;
  wire       s_gates7_out;
  wire       s_gates8_out;
  wire       s_gates9_out;
  wire       s_gnd;
  wire       s_ifetch;
  wire       s_intrq;
  wire       s_l1v0_n;
  wire       s_l1v1_n;
  wire       s_l2v0_n;
  wire       s_l2v1_n;
  wire       s_l2v2_n;
  wire       s_l3v0_n;
  wire       s_l3v1_n;
  wire       s_mux_sel0_n;
  wire       s_mux_sel1_n;
  wire       s_nand_vacc_ftrap_ifetch;
  wire       s_nand_vtrap_vacc;
  wire       s_nor_pviol_rv_n;
  wire       s_nor_pviol_rv;
  wire       s_pan;
  wire       s_pgf_n;
  wire       s_pgf;
  wire       s_pgu_n;
  wire       s_pgu;
  wire       s_power;
  wire       s_pviol;
  wire       s_rd;
  wire       s_rv;
  wire       s_tclk;
  wire       s_tvec0_n;
  wire       s_tvec1_n;
  wire       s_tvec2_n;
  wire       s_vacc;
  wire       s_vtrap_n;
  wire       s_vtrap;
  wire       s_wip_n;
  wire       s_wip;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_mux_selector[0] = LEV2;
  assign s_mux_selector[1] = LEV1;
  assign s_dstop_n         = DSTOPN;
  assign s_ftrap_n         = FTRAPN;
  assign s_ifetch          = IFETCH;
  assign s_intrq           = INTRQ;
  assign s_pan             = PAN;
  assign s_pgf             = PGF;
  assign s_pgu             = PGU;
  assign s_pgu_n           = PGUN;
  assign s_pviol           = PVIOL;
  assign s_rd              = RD;
  assign s_rv              = RV;
  assign s_tclk            = TCLK;
  assign s_vacc            = VACC;
  assign s_vtrap_n         = VTRAPN;
  assign s_wip             = WIP;
  assign s_wip_n           = WIPN;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign TVEC_3_0          = s_tvec_3_0_out[3:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // Power
  assign s_power           = 1'b1;

  // Ground
  assign s_gnd             = 1'b0;


  // NOT Gate
  assign s_ftrap           = ~s_ftrap_n;
  assign s_nor_pviol_rv_n    = ~s_nor_pviol_rv;
  assign s_mux_sel0_n      = ~s_mux_selector[0];
  assign s_mux_sel1_n      = ~s_mux_selector[1];
  assign s_pgf_n           = ~s_pgf;
  assign s_tvec_3_0_out[2] = ~s_tvec2_n;
  assign s_tvec_3_0_out[1] = ~s_tvec1_n;
  assign s_tvec_3_0_out[0] = ~s_tvec0_n;
  assign s_vtrap           = ~s_vtrap_n;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_mux_sel0_n),
      .input2(s_mux_sel1_n),
      .result(s_tvec_3_0_out[3])
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_2 (
      .input1(s_vacc),
      .input2(s_ftrap),
      .input3(s_ifetch),
      .result(s_nand_vacc_ftrap_ifetch)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_3 (
      .input1(s_vtrap),
      .input2(s_vacc),
      .result(s_nand_vtrap_vacc)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_4 (
      .input1(s_pviol),
      .input2(s_rv),
      .result(s_nor_pviol_rv)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_5 (
      .input1(s_nand_vtrap_vacc),
      .input2(s_nand_vacc_ftrap_ifetch),
      .result(s_gates5_out)
  );

  NAND_GATE_5_INPUTS #(
      .BubblesMask({1'b0, 4'h0})
  ) GATES_6 (
      .input1(s_nand_vtrap_vacc),
      .input2(s_ifetch),
      .input3(s_intrq),
      .input4(s_pan),
      .input5(s_dstop_n),
      .result(s_gates6_out)
  );

  NOR_GATE #(
      .BubblesMask(2'b00)
  ) GATES_7 (
      .input1(s_wip),
      .input2(s_pgu),
      .result(s_gates7_out)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_8 (
      .input1(s_rd),
      .input2(s_wip_n),
      .input3(s_pgu_n),
      .result(s_gates8_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_9 (
      .input1(s_pgf_n),
      .input2(s_nor_pviol_rv_n),
      .result(s_gates9_out)
  );

  AND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_10 (
      .input1(s_nand_vacc_ftrap_ifetch),
      .input2(s_gates6_out),
      .result(s_gates10_out)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_11 (
      .input1(s_wip_n),
      .input2(s_pgu),
      .result(s_gates11_out)
  );


  // TVEC 2
  Multiplexer_4 TVEC2_MUX (
      .muxIn_0(s_gnd),
      .muxIn_1(s_l2v2_n),
      .muxIn_2(s_power),
      .muxIn_3(1'b0),
      .muxOut(s_tvec2_n),
      .sel(s_mux_selector[1:0])
  );

  // TVEC 1
  Multiplexer_4 TVEC1_MUX (
      .muxIn_0(s_l3v1_n),
      .muxIn_1(s_l2v1_n),
      .muxIn_2(s_l1v1_n),
      .muxIn_3(1'b0),
      .muxOut(s_tvec1_n),
      .sel(s_mux_selector[1:0])
  );

  //TVEC 0
  Multiplexer_4 TVEC0_MUX (
      .muxIn_0(s_l3v0_n),
      .muxIn_1(s_l2v0_n),
      .muxIn_2(s_l1v0_n),
      .muxIn_3(1'b0),
      .muxOut(s_tvec0_n),
      .sel(s_mux_selector[1:0])
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) L1V0_FF (
      .clock(s_tclk),
      .d(s_gates9_out),
      .preset(1'b0),
      .q(s_l1v0_n),
      .qBar(),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) L2V2_FF (
      .clock(s_tclk),
      .d(s_gates8_out),
      .preset(1'b0),
      .q(),
      .qBar(s_l2v2_n),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) L3V1_FF (
      .clock(s_tclk),
      .d(s_gates5_out),
      .preset(1'b0),
      .q(),
      .qBar(s_l3v1_n),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) L2V1_FF (
      .clock(s_tclk),
      .d(s_gates7_out),
      .preset(1'b0),
      .q(),
      .qBar(s_l2v1_n),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) L1V1_FF (
      .clock(s_tclk),
      .d(s_pgf),
      .preset(1'b0),
      .q(s_l1v1_n),
      .qBar(),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) L3V0_FF (
      .clock(s_tclk),
      .d(s_gates10_out),
      .preset(1'b0),
      .q(),
      .qBar(s_l3v0_n),
      .reset(1'b0),
      .tick(1'b1)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) L2V0_FF (
      .clock(s_tclk),
      .d(s_gates11_out),
      .preset(1'b0),
      .q(),
      .qBar(s_l2v0_n),
      .reset(1'b0),
      .tick(1'b1)
  );


endmodule

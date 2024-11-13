/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/IRQ/MASK/MASKBIT                                      **
** IRQ MASK BIT                                                          **
**                                                                       **
** Page 80                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_INTR_CNTLR_IRQ_MASK_MASKBIT (
    input CLOCK,
    input DATAIN,
    input DCDA,
    input DCDB,
    input DCDCN,

    output MSK,
    output MSKN
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire s_dcdc_n;
  wire s_msk_n_out;
  wire s_datain;
  wire s_datain_nand_dcdb;
  wire s_or_3signals;
  wire s_msk_nand_dcda;
  wire s_clock;
  wire s_dcdb_nand_mskn_nand_dcdcn;
  wire s_msk_out;
  wire s_dcdb;
  wire s_d_input;
  wire s_dcda;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_dcdc_n = DCDCN;
  assign s_datain = DATAIN;
  assign s_clock = CLOCK;
  assign s_dcdb = DCDB;
  assign s_dcda = DCDA;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign MSK = s_msk_out;
  assign MSKN = s_msk_n_out;

  /*******************************************************************************
   ** Here all normal components are defined                                     **
   *******************************************************************************/
  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_1 (
      .input1(s_msk_out),
      .input2(s_dcda),
      .result(s_msk_nand_dcda)
  );

  NAND_GATE #(
      .BubblesMask(2'b00)
  ) GATES_2 (
      .input1(s_datain),
      .input2(s_dcdb),
      .result(s_datain_nand_dcdb)
  );

  NAND_GATE_3_INPUTS #(
      .BubblesMask(3'b000)
  ) GATES_3 (
      .input1(s_dcdb),
      .input2(s_msk_n_out),
      .input3(s_dcdc_n),
      .result(s_dcdb_nand_mskn_nand_dcdcn)
  );

  OR_GATE_3_INPUTS #(
      .BubblesMask(3'b111)
  ) GATES_4 (
      .input1(s_msk_nand_dcda),
      .input2(s_datain_nand_dcdb),
      .input3(s_dcdb_nand_mskn_nand_dcdcn),
      .result(s_or_3signals)
  );

  XNOR_GATE_ONEHOT #(
      .BubblesMask(2'b00)
  ) GATES_5 (
      .input1(s_or_3signals),
      .input2(s_dcdc_n),
      .result(s_d_input)
  );

  D_FLIPFLOP #(
      .InvertClockEnable(0)
  ) MEMORY_6 (
      .clock(s_clock),
      .d(s_d_input),
      .preset(1'b0),
      .q(s_msk_n_out),
      .qBar(s_msk_out),
      .reset(1'b0),
      .tick(1'b1)
  );


endmodule

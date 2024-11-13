/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** /CGA/INTR/CNTLR/IRQ/MASK                                              **
** IRQ MASK                                                              **
**                                                                       **
** Page 80                                                               **
** SHEET 1 of 1                                                          **
**                                                                       **
** Last reviewed: 10-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module CGA_INTR_CNTLR_IRQ_MASK (
    input        A,
    input        B,
    input        C,
    input [15:0] DIN_15_0,
    input        MCLK,

    output [15:0] PICMASK_15_0,
    output [15:0] PICMASK_15_0_N
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire [15:0] s_picmask_15_0_out;
  wire [15:0] s_din_15_0;
  wire [15:0] s_picmask_15_0_n_out;
  wire        s_a;
  wire        s_b;
  wire        s_c;
  wire        s_dcdc_n;
  wire        s_mclk;

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_din_15_0[15:0] = DIN_15_0;
  assign s_a              = A;
  assign s_c              = C;
  assign s_b              = B;
  assign s_mclk           = MCLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign PICMASK_15_0     = s_picmask_15_0_out[15:0];
  assign PICMASK_15_0_N   = s_picmask_15_0_n_out[15:0];

  /*******************************************************************************
   ** Here all in-lined components are defined                                   **
   *******************************************************************************/

  // NOT Gate
  assign s_dcdc_n         = ~s_c;

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/
  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT15 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[15]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[15]),
      .MSKN(s_picmask_15_0_n_out[15])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT14 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[14]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[14]),
      .MSKN(s_picmask_15_0_n_out[14])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT13 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[13]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[13]),
      .MSKN(s_picmask_15_0_n_out[13])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT12 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[12]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[12]),
      .MSKN(s_picmask_15_0_n_out[12])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT11 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[11]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[11]),
      .MSKN(s_picmask_15_0_n_out[11])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT10 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[10]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[10]),
      .MSKN(s_picmask_15_0_n_out[10])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT9 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[9]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[9]),
      .MSKN(s_picmask_15_0_n_out[9])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT8 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[8]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[8]),
      .MSKN(s_picmask_15_0_n_out[8])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT7 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[7]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[7]),
      .MSKN(s_picmask_15_0_n_out[7])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT6 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[6]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[6]),
      .MSKN(s_picmask_15_0_n_out[6])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT5 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[5]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[5]),
      .MSKN(s_picmask_15_0_n_out[5])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT4 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[4]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[4]),
      .MSKN(s_picmask_15_0_n_out[4])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT3 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[3]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[3]),
      .MSKN(s_picmask_15_0_n_out[3])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT2 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[2]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[2]),
      .MSKN(s_picmask_15_0_n_out[2])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT1 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[1]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[1]),
      .MSKN(s_picmask_15_0_n_out[1])
  );

  CGA_INTR_CNTLR_IRQ_MASK_MASKBIT MASKBIT0 (
      .CLOCK(s_mclk),
      .DATAIN(s_din_15_0[0]),
      .DCDA(s_a),
      .DCDB(s_b),
      .DCDCN(s_dcdc_n),
      .MSK(s_picmask_15_0_out[0]),
      .MSKN(s_picmask_15_0_n_out[0])
  );



endmodule

/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CGA/WRF/RBLOCK/DR16                                                   **
** WRF: Register File                                                    **
** (PDF page 64)                                                         **
**                                                                       **
** Last reviewed: 1-DEC-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/


module CGA_WRF_RBLOCK_DR16 (
    // System input signals
    input sysclk,    // System clock in FPGA
    input sys_rst_n, // System reset in FPGA

    // Input signals
    input        ALUCLK,
    input [15:0] RB_15_0,
    input        WR,

    // Output signals
    output [15:0] REG_15_0
);

  /*******************************************************************************
   ** The wires are defined here                                                 **
   *******************************************************************************/
  wire        s_aluclk;
  wire        s_wr;
  wire [15:0] s_rb_15_0;
  wire [15:0] s_reg_15_0_out;

  /*******************************************************************************
   ** The module functionality is described here                                 **
   *******************************************************************************/

  /*******************************************************************************
   ** Here all input connections are defined                                     **
   *******************************************************************************/
  assign s_rb_15_0[15:0] = RB_15_0;
  assign s_wr            = WR;
  assign s_aluclk        = ALUCLK;

  /*******************************************************************************
   ** Here all output connections are defined                                    **
   *******************************************************************************/
  assign REG_15_0        = s_reg_15_0_out[15:0];

  /*******************************************************************************
   ** Here all sub-circuits are defined                                          **
   *******************************************************************************/

  reg [15:0] regFF;
  always @(posedge s_aluclk) begin
    if (s_wr) begin
        regFF <= s_rb_15_0[15:0];
    end
  end

  assign s_reg_15_0_out = regFF;

  /*
  // verilator lint_off UNUSED
  // verilator lint_off UNDRIVEN
  // verilator lint_off PINCONNECTEMPTY

  SCAN_FF R15 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[15]),
      .Q  (s_reg_15_0_out[15]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[15])
  );

  SCAN_FF R14 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[14]),
      .Q  (s_reg_15_0_out[14]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[14])
  );

  SCAN_FF R13 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[13]),
      .Q  (s_reg_15_0_out[13]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[13])
  );

  SCAN_FF R12 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[12]),
      .Q  (s_reg_15_0_out[12]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[12])
  );

  SCAN_FF R11 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[11]),
      .Q  (s_reg_15_0_out[11]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[11])
  );

  SCAN_FF R10 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[10]),
      .Q  (s_reg_15_0_out[10]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[10])
  );

  SCAN_FF R9 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[9]),
      .Q  (s_reg_15_0_out[9]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[9])
  );

  SCAN_FF R8 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[8]),
      .Q  (s_reg_15_0_out[8]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[8])
  );

  SCAN_FF R7 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[7]),
      .Q  (s_reg_15_0_out[7]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[7])
  );

  SCAN_FF R6 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[6]),
      .Q  (s_reg_15_0_out[6]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[6])
  );

  SCAN_FF R5 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[5]),
      .Q  (s_reg_15_0_out[5]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[5])
  );

  SCAN_FF R4 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[4]),
      .Q  (s_reg_15_0_out[4]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[4])
  );

  SCAN_FF R3 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[3]),
      .Q  (s_reg_15_0_out[3]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[3])
  );

  SCAN_FF R2 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[2]),
      .Q  (s_reg_15_0_out[2]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[2])
  );

  SCAN_FF R1 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[1]),
      .Q  (s_reg_15_0_out[1]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[1])
  );

  SCAN_FF R0 (
      .CLK(s_aluclk),
      .D  (s_reg_15_0_out[0]),
      .Q  (s_reg_15_0_out[0]),
      .QN (),
      .TE (s_wr),
      .TI (s_rb_15_0[0])
  );
*/
endmodule

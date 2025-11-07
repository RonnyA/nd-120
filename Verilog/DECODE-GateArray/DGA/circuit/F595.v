/**************************************************************************
** ND120 DGA (Decode Gate Array)                                         **
** DECODE/DGA                                                            **
**                                                                       **
** NEC F595 - R/S Latch with Gated input                                 **
**                                                                       **
** Truth table from REN_A12213XJ5V1UM00_OTH_19980801.pdf                 **
** Page 6-214. Function RS-LATCH                                         **
**                                                                       **
** Last reviewed: 20-MAY-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module F595 (
    input H01_S,  // Set
    input H02_R,  // Reset
    input H03_G,  // Gate Enable

    output N01_Q,  // Q
    output N02_QB  // Qn
);

  /* verilator lint_off UNOPTFLAT */

  reg regQ;
  reg regQn;

  // Behavioral description of the R-S latch
  // Converted from gated latch to edge-triggered flip-flop for FPGA synthesis
  // Captures state on rising edge of gate signal (when latch would become transparent)

  /* verilator lint_off LATCH */

  always @(posedge H03_G) begin
    if (H01_S & H02_R) begin
      regQ  <= 1'b1;
      regQn <= 1'b1;
    end else if (H02_R & !H01_S) begin
      regQ  <= 1'b0;
      regQn <= 1'b1;
    end else if (!H02_R & H01_S) begin
      regQ  <= 1'b1;
      regQn <= 1'b0;
    end
    // else: hold previous value (implicit in edge-triggered flip-flop)
  end

  assign N01_Q  = regQ;
  assign N02_QB = regQn;

endmodule

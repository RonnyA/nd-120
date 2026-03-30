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
  // FPGA: edge-triggered flip-flop captures on rising edge of gate
  // Simulation: transparent gated latch (original behavior)

  /* verilator lint_off LATCH */

`ifdef USE_TRANSPARENT_LATCHES
  // Transparent gated latch (original behavior)
  always @* begin
    if (H03_G) begin
      if (H01_S & H02_R) begin
        regQ  = 1'b1;
        regQn = 1'b1;
      end else if (H02_R & !H01_S) begin
        regQ  = 1'b0;
        regQn = 1'b1;
      end else if (!H02_R & H01_S) begin
        regQ  = 1'b1;
        regQn = 1'b0;
      end
    end
  end
`else
  // Edge-triggered flip-flop (FPGA synthesis)
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
`endif

  assign N01_Q  = regQ;
  assign N02_QB = regQn;

endmodule

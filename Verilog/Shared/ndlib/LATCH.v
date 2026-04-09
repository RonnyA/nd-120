/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component LATCH                                                       **
**                                                                       **
** Last reviewed: 24-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module LATCH (
    input  wire sysclk,    //! FPGA system clock — same code path for sim and FPGA
    input  wire D,
    input  wire ENABLE,
    output wire Q,
    output wire QN
);

  // Edge-detect on rising ENABLE, sampled by sysclk.
  //
  // Replaces the previous `always @(posedge ENABLE)` pattern which routed
  // ENABLE through fabric as a clock signal — unsafe on FPGA (no clock
  // network, glitch-prone, hold-time analysis incomplete).
  //
  // Semantics: captures D on the first sysclk edge AFTER ENABLE has gone
  // from 0 to 1 (≤1 sysclk lag). Equivalent to the original posedge-ENABLE
  // semantics whenever D is stable across that 1-cycle window.

  reg regD   = 1'b0;
  reg en_prev = 1'b0;

  always @(posedge sysclk) begin
    en_prev <= ENABLE;
    if (ENABLE & ~en_prev) regD <= D;
  end

  assign Q  = regD;
  assign QN = ~regD;

endmodule

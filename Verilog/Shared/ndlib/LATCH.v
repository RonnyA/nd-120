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

  // Level-sensitive sysclk capture (matches L4.v / L8.v).
  //
  // Replaces the previous `always @(posedge ENABLE)` pattern which routed
  // ENABLE through fabric as a clock signal — unsafe on FPGA (no clock
  // network, glitch-prone, hold-time analysis incomplete).
  //
  // Semantics: while ENABLE is high, regD tracks D on every sysclk edge
  // (effectively transparent on a 1-sysclk grain). When ENABLE is low,
  // regD holds. This is the closest synchronous approximation to the
  // original 74xx transparent-latch behaviour.
  //
  // Edge-detect was tried first and broke LCS loading, because during
  // LCS load `s_aluclk_n` is held high constantly — no rising edge ever
  // appears, so an edge-detect FF never fires and CSEL_Q stayed at its
  // init value. Level-sensitive capture has no such failure mode: it
  // tracks D throughout the high window.

  reg regD = 1'b0;

`ifdef USE_TRANSPARENT_LATCHES
  // TRUE transparent latch (the original 74xx behaviour): while ENABLE high, Q
  // follows D combinationally; when ENABLE falls, Q holds. This is the correct
  // reference model with no sysclk-sampling race. FPGA path below keeps the
  // synchronous approximation.
  always @(*) begin
    if (ENABLE) regD = D;
  end
`else
  always @(posedge sysclk) begin
    if (ENABLE) regD <= D;
  end
`endif

`ifdef USE_TRANSPARENT_LATCHES
  assign Q  = regD;
  assign QN = ~regD;
`else
  // FPGA: synthesizable transparent latch = mux + FF (Q follows D while ENABLE high)
  wire q = ENABLE ? D : regD;
  assign Q  = q;
  assign QN = ~q;
`endif

endmodule

/**************************************************************************
** ND120 SHARED CODE                                                     **
** J-K FLIP-FLOP                                                         **
**                                                                       **
**                                                                       **
** Last reviewed: 11-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module J_K_FLIPFLOP #(
    parameter integer InvertClockEnable = 1
) (
    input  clock,
    input  j,
    input  k,
    input  preset,
    input  reset,
    input  tick,
    output q,
    output qBar
);

  reg s_currentState;

  // Output logic
  assign q = s_currentState;
  assign qBar = ~s_currentState;

  // Clock inversion based on parameter
  wire s_clock = (InvertClockEnable == 0) ? clock : ~clock;

  // State transition logic
  wire s_nextState = (~s_currentState & j) | (s_currentState & ~k);

  // State update logic
  //always @(posedge reset or posedge preset or posedge s_clock) begin (Vivado doesnt like ASYNC RESET )
  always @(posedge s_clock) begin
    if (preset)  // priority to pre-set
      s_currentState <= 1'b1;
    else if (reset) s_currentState <= 1'b0;
    else if (tick) s_currentState <= s_nextState;
  end

  // Initial state for simulation
  initial s_currentState = 0;

endmodule

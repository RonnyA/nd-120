/******************************************************************************
 ** Logisim-evolution goes FPGA automatic generated Verilog code             **
 ** https://github.com/logisim-evolution/                                    **
 **                                                                          **
 ** Component : J_K_FLIPFLOP                                                 **
 **                                                                          **
 *****************************************************************************/

module J_K_FLIPFLOP(
    input  clock,
    input  j,
    input  k,
    input  preset,
    input  reset,
    input  tick,
    output q,
    output qBar
);

    parameter invertClockEnable = 1;
    reg s_currentState;

    // Output logic
    assign q = s_currentState;
    assign qBar = ~s_currentState;

    // Clock inversion based on parameter
    wire s_clock = (invertClockEnable == 0) ? clock : ~clock;

    // State transition logic
    wire s_nextState = (~s_currentState & j) | (s_currentState & ~k);

    // State update logic
    always @(posedge reset or posedge preset or posedge s_clock) begin
        if (reset)
            s_currentState <= 1'b0;
        else if (preset)
            s_currentState <= 1'b1;
        else if (tick)
            s_currentState <= s_nextState;
    end

    // Initial state for simulation
    initial s_currentState = 0;

endmodule

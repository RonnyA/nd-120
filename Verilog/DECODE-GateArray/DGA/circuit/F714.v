/**************************************************************************
** ND120 DGA (Decode Gate Array)                                         **
** DECODE/DGA                                                            **
**                                                                       **
** NEC F714 - T Flip-Flop with R, S                                      **
**                                                                       **
** Last reviewed: 2-FEB-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module F714 (
    input H01_T,  // Toggle
    input H02_R,  // Reset
    input H03_S,  // Set

    output N01_Q,
    output N02_QB
);


  reg  regQ;
  reg  reqQ_n;

  // Wires
  wire s_t;
  wire s_reset;
  wire s_set;


  // Assign inputs
  assign s_t    = H01_T;
  assign s_reset    = H02_R;
  assign s_set    = H03_S;


  // Assign outputs
  assign N01_Q  = regQ;
  assign N02_QB = reqQ_n;


  always @(posedge s_t or posedge s_reset or posedge s_set) begin
    // Prioritized: RESET has priority over SET to avoid synthesis warning
    if (s_reset) begin
      // Reset has highest priority
      regQ   <= 1'b0;
      reqQ_n <= 1'b1;
    end else if (s_set) begin
      // Set has second priority
      regQ   <= 1'b1;
      reqQ_n <= 1'b0;
    end else begin
      // Toggle on posedge s_t (s_t is guaranteed high here)
      reqQ_n <= regQ;
      regQ   <= ~regQ;
    end
  end

endmodule


/*

TRUTH TABLE
===========

| T       | R | S | Q | QB |
|---------|---|---|---|----|
| posedge | 0 | 0 | Invert |
| negedge | 0 | 0 |  Hold  |
|   X     | 1 | 0 | 0 | 1  |
|   X     | 0 | 1 | 1 | 0  |
|   X     | 1 | 1 | 1 | 1  |  <= prohibition

X=irrelevant

*/

/**************************************************************************
** ND120 DGA (Decode Gate Array)                                         **
** DECODE/DGA                                                            **
**                                                                       **
** NEC F617 - D Flip-Flop with RB, SB                                    **
**                                                                       **
** Truth table from REN_A12213XJ5V1UM00_OTH_19980801.pdf                 **
** Page 6-238. Function D-F/F WITH RB, SB                                **
**                                                                       **
** Last reviewed: 2-FEB-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/

module F617 (
    input H01_D,   // Data
    input H02_C,   // Clock
    input H03_RB,  // Reset (negated)
    input H04_SB,  // Set (negated)

    output reg N01_Q,
    output reg N02_QB
);

  // Wires
  wire s_d;
  wire s_set;
  wire s_reset;


  // Assign inputs
  assign s_d      = H01_D;
  assign s_set    = ~H04_SB;
  assign s_reset  = ~H03_RB;

  always @(posedge H02_C or posedge s_set or posedge s_reset)
  begin
    // Prioritized: RESET has priority over SET to avoid synthesis warning
    if (s_reset)
    begin
      // Reset has highest priority
      N01_Q   <= 1'b0;
      N02_QB  <= 1'b1;
    end
    else if (s_set)
    begin
      // Set has second priority
      N01_Q   <= 1'b1;
      N02_QB  <= 1'b0;
    end
    else
    begin
      // Normal D flip-flop operation on clock edge
      N01_Q   <= s_d;
      N02_QB  <= ~s_d;
    end

  end

endmodule

/* 

TRUTH TABLE
===========

| D | C       |RB | SB| Q | QB |
|---|---------|---|---|---|----|
| 0 | posedge | 1 | 1 | 0 | 1  |
| 1 | posedge | 1 | 1 | 1 | 0  |
| X | negedge | 1 | 1 |  Hold  |
| X |   X     | 0 | 1 | 0 | 1  |
| X |   X     | 1 | 0 | 1 | 0  |
| X |   X     | 0 | 0 | 0 | 0  |  <= prohibition

X=irrelevant

*/

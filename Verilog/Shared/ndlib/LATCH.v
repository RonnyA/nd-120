/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Component LATCH                                                       **
**                                                                       **
** Last reviewed: 24-NOV-2024                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module LATCH (
    input  wire D,
    input  wire ENABLE,
    output wire Q,
    output wire QN
);

  reg regD;
  assign Q = regD;  //Assign Q
  assign QN = ~regD;  // Assign Q_n

  // Initialize register to 0
  initial begin
    regD = 1'b0;
  end


  // LATCH
  always @(D or ENABLE) begin
    if (ENABLE) begin
      regD <= D;  // When ENABLE is high, Q takes the value of the input
    end
    // When ENABLE is low, Q retains its value
  end

endmodule


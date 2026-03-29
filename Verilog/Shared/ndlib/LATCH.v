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

  // FPGA_MODE: Set to 1 for edge-triggered operation (FPGA synthesis)
  //            Set to 0 for transparent latch operation (original behavior)
`ifdef USE_TRANSPARENT_LATCHES
  parameter FPGA_MODE = 0;  // Simulation: use transparent latch (original behavior)
`else
  parameter FPGA_MODE = 1;  // FPGA: use edge-triggered FF for synthesis
`endif

  reg regD;
  assign Q = regD;   // Assign Q
  assign QN = ~regD; // Assign Q_n

  // Initialize register to 0
  initial begin
    regD = 1'b0;
  end


  generate
    if (FPGA_MODE == 1) begin : gen_flipflop
      // Edge-triggered flip-flop mode (FPGA-friendly)
      // Captures data on rising edge of ENABLE
      always @(posedge ENABLE) begin
        regD <= D;
      end
    end else begin : gen_latch
      // Transparent latch mode (original behavior)
      /* verilator lint_off LATCH */
      always @(D or ENABLE) begin
        if (ENABLE) begin
          regD <= D;  // When ENABLE is high, Q takes the value of the input
        end
        // When ENABLE is low, Q retains its value
      end
      /* verilator lint_on LATCH */
    end
  endgenerate

endmodule


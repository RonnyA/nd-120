/**********************************************************************************************************
** ND120 Shared                                                                                          **
**                                                                                                       **
** Component AM29841                                                                                     **
**                                                                                                       **
** Bus Driver 10 bit (D-Latch) with 3-state output                                                       **
** Documentation: https://www.alldatasheet.com/datasheet-pdf/pdf/107079/AMD/AM29841.html                 **
**                                                                                                       **
** Last reviewed: 1-DEC-2024                                                                             **
** Ronny Hansen                                                                                          **
***********************************************************************************************************/

module AM29841 (
    input wire [9:0] D,   // 10 Bit Data inputs
    input wire LE,        // Latch Enable (when high in latch mode, rising edge in FF mode)
    input wire OE_n,      // Output Enable
    output wire [9:0] Y   // Outputs
);

    // FPGA_MODE: Set to 1 for edge-triggered operation (FPGA synthesis)
    //            Set to 0 for transparent latch operation (original behavior)
`ifdef USE_TRANSPARENT_LATCHES
    parameter FPGA_MODE = 0;  // Simulation: use transparent latch (original behavior)
`else
    parameter FPGA_MODE = 1;  // FPGA: use edge-triggered FF for synthesis
`endif

    reg [9:0] Q_reg = 10'b0;  // Internal register/latch with initial value for FPGA

    generate
        if (FPGA_MODE == 1) begin : gen_flipflop
            // Edge-triggered flip-flop mode (FPGA-friendly)
            always @(posedge LE) begin
                Q_reg <= D;  // Capture on rising edge
            end
        end else begin : gen_latch
            // Transparent latch mode (original behavior)
            /* verilator lint_off LATCH */
            always @(*) begin
                if (LE)
                    Q_reg = D; // Transparent mode: follows input when LE high
                else
                    Q_reg = Q_reg; // Hold previous value
            end
            /* verilator lint_on LATCH */
        end
    endgenerate

    // Output control
    // When OE_n is low (active), outputs reflect the registered data
    // When OE_n is high, outputs are in high-impedance state (zero for simulation)
    assign Y = OE_n ? 10'b0 : Q_reg;

endmodule

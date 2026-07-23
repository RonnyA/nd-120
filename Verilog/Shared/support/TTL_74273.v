/**************************************************************************
** 74273                                                                 **
** OCTAL D-TYPE FLIP-FLOP WITH COMMON CLOCK AND ASYNCHRONOUS CLEAR       **
** (NONE NEGATING)                                                       **
**                                                                       **
** Documentation:  https://www.ti.com/lit/ds/symlink/sn54ls273-sp.pdf    **
**                                                                       **
** Last reviewed: 26-JAN-2025                                            **
** Ronny Hansen                                                          **
***************************************************************************/


module TTL_74273 (
    input wire sysclk,     // FPGA system clock (used only when USE_SYSCLK=2)
    input wire CLK,        // Clock input
    input wire CLR_n,      // Active low clear input
    input wire [7:0] D,    // 8-bit data input
    output reg [7:0] Q     // 8-bit output
);

    // USE_SYSCLK:
    //   0 (default): original posedge CLK - matches the real chip.
    //   2: sysclk-sampled RISING-EDGE capture (AM29C821 USE_SYSCLK=2
    //      pattern) - the FPGA-safe mode when CLK is driven by a control
    //      strobe (SIOC_n ...), not a clock. Clear stays synchronous,
    //      matching the original block below.
    parameter USE_SYSCLK = 0;

    generate
        if (USE_SYSCLK == 2) begin : gen_edge
            reg clk_d = 1'b0;
            always @(posedge sysclk)
            begin
                clk_d <= CLK;
                if (!CLR_n) begin
                    Q <= 8'b0;
                end else if (CLK && !clk_d) begin
                    Q <= D;
                end
            end
        end else begin : gen_posedge
            // Flip-flop logic
            always @(posedge CLK ) //or negedge CLR_n)
            begin
                if (!CLR_n) begin
                    Q <= 8'b0;     // Reset output to 0 when clr_n is low
                end else begin
                    Q <= D;        // Load data into flip-flops on rising edge of clk
                end
            end
        end
    endgenerate

endmodule

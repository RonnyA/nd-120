/**************************************************************************
** ND120 Shared                                                          **
**                                                                       **
** Module 74PCT373                                                       **
**                                                                       **
** Octal D-TYPE Transparent Latch with 3-state outputs                   **
** Documentation: https://www.ti.com/lit/ds/symlink/sn54ls373-sp.pdf     **
**                                                                       **
** Last reviewed: 1-DEC-2024                                             **
** Ronny Hansen                                                          **
***************************************************************************/


module TTL_74373 (
    input wire [7:0] D,   // Data inputs
    input wire C,         // Control input (active high)
    input wire OC_n,      // Output Control (active low)
    output wire [7:0] Q   // Outputs
);

    reg [7:0] Q_Latch;  // Internal latch


    // Latch operation: latch data whenever C is high
    //always @(posedge C or negedge C or posedge D or negedge D) begin
    always @(*) begin 
    //always_latch begin
        if (C) begin
            Q_Latch = D;  // Transparent mode: Internal latch follows input
        end else begin
            Q_Latch = Q_Latch; // Explicit latch in hope of synth keeping silent (nope.. no change.. dont know how to make Vivado happy)
        end
    end

    // Output control
    // When OC_n is low (active), outputs reflect the latched data
    // When OC_n is high, outputs are in high-impedance state
    assign Q = OC_n ? 8'b0 : Q_Latch;

endmodule

// 74PCT373
// Octal Transparent Latch with 3-state outputs
// Documentation: https://www.ti.com/lit/ds/symlink/sn54ls373-sp.pdf

module TTL_74373 (
    input wire [7:0] D,   // Data inputs
    input wire C,         // Control input (active high)
    input wire OC_n,      // Output Control (active low)
    output wire [7:0] Q   // Outputs
);

    reg [7:0] Q_Latch;  // Internal latch

    // Latch operation
    always @(*) begin
        if (C) begin
            Q_Latch <= D;  // Transparent mode: Internal latch follows input
        end
    end

    // Output control
    // When OC_n is low (active), outputs reflect the latched data
    // When OC_n is high, outputs are in high-impedance state
    assign Q = OC_n : 8'bz ? Q_Latch;

endmodule

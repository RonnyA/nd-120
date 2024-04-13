// AM29841
// Bus Driver 10 bit (D-Latch) with 3-state output
// Documentation: https://www.alldatasheet.com/datasheet-pdf/pdf/107079/AMD/AM29841.html

module AM29841 (
    input wire [9:0] D,   // 10 Bit Data inputs
    input wire C,         // Control input (active high)
    input wire OC_n,      // Output Control (active low)
    output wire [9:0] Q   // Outputs
);

    reg [9:0] Q_Latch;  // Internal latch

    // Latch operation
    always @(*) begin
        if (C) begin
            Q_Latch = D;  // Transparent mode: Internal latch follows input
        end
    end

    // Output control
    // When OC_n is low (active), outputs reflect the latched data
    // When OC_n is high, outputs are in high-impedance state
    assign Q = (OC_n == 1'b0) ? Q_Latch : 10'bz;

endmodule

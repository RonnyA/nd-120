module TTL_74374 (
    input wire [7:0] D,   // Data inputs
    input wire CK,        // Clock input (Latching on rising edge of CK)
    input wire OE_n,      // Output Enable (active low)
    output wire [7:0] Q   // Outputs
);

    reg [7:0] Q_Latch;  // Internal latch

   
    // Latch operation on rising edge of CK
    always @(posedge CK) begin
        Q_Latch <= D;  // Latch data on rising edge of CK
    end

    // Output control
    // When OC_n is low (active), outputs reflect the latched data
    // When OC_n is high, outputs are in high-impedance state
    assign Q = (OC_n == 1'b0) ? Q_Latch : 8'bz;

endmodule

// AM29841
// Bus Driver 10 bit (D-Latch) with 3-state output
// Documentation: https://www.alldatasheet.com/datasheet-pdf/pdf/107079/AMD/AM29841.html

module AM29841 (
    input wire [9:0] D,   // 10 Bit Data inputs
    input wire LE,         // Latch Enable
    input wire OE_n,      // Output Enable
    output wire [9:0] Y   // Outputs
);

    reg [9:0] Q_Latch;  // Internal latch

    // Latch operation
    //always @(posedge LE or negedge LE or posedge D or negedge D) begin 
    always @(*) begin
    //always_latch begin
        if (LE) begin
            Q_Latch = D;  // Transparent mode: Internal latch follows input
        end
    end

    // Output control
    // When OC_n is low (active), outputs reflect the latched data
    // When OC_n is high, outputs are in high-impedance state
    assign Y = OE_n ?  10'b0 : Q_Latch;

endmodule

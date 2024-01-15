/******************************************************************************
 **                                                                          **
 ** Component : TTL_74245                                                    **
 **                                                                          **
 ** Ronny Hansen 14.01.2024
 *****************************************************************************/

module TTL_74245( 
    input [7:0] A,       // A-side 8-bit port
    inout [7:0] B,       // B-side 8-bit bidirectional port/bus
    input DIR,           // Direction control
    input OE_n           // Output enable
);

reg [7:0] internalBus;

// Control the direction of data flow
always @(*) begin
    if (DIR) begin
        internalBus = A; // Data flows from A to B
    end else begin
        internalBus = B; // Data flows from B to A
    end
end

// Assign the bidirectional bus with respect to OE
assign B = (OE_n == 0 && DIR == 1) ? internalBus : 8'bz;

// Output to A when receiving from B with respect to OE (OE_n==1 means "isolated". Don't write to A or B)
assign A = (OE_n == 0 && DIR == 0) ? internalBus : 8'bz;

endmodule



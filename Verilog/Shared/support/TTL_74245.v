/******************************************************************************
 **                                                                          **
 ** Component : TTL_74245                                                    **
 **                                                                          **
 ** Ronny Hansen 14.01.2024
 *****************************************************************************/

module TTL_74245( 
    input  [7:0] A,        // A-side 8-bit port
    output [7:0] A_OUT,    // A-side 8-bit port

    input  [7:0] B,        // B-side 8-bit bidirectional port/bus
    output [7:0] B_OUT,    // B-side 8-bit bidirectional port/bus

    input DIR,           // Direction control
    input OE_n           // Output enable
);

    wire [7:0] internalBus;

    assign internalBus = DIR ? A : B; // DIR = 1 =>Data flows from A to B, else Data flows from B to A


    // Assign the bidirectional bus with respect to OE
    assign B_OUT = (OE_n == 0 && DIR == 1) ? internalBus : 8'b0;

    // Output to A when receiving from B with respect to OE (OE_n==1 means "isolated". Don't write to A or B)
    assign A_OUT = (OE_n == 0 && DIR == 0) ? internalBus : 8'b0;

endmodule



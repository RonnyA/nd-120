// PAL16L8
// JLB/CITC 15AUG86
// 44303B,2C,LBC2 - LOCAL DATA BUS CONTROL PAL

module PAL_44303B(
    input CACT_n,
    input CGNT_n,
    input EADR_n,           // Address from CPU to Bus
    input BINPUT50_n,
    input MIS0,
    input IOD_n,
    input WRITE,
    input TEST,
    input BACT_n,
    
    output reg WBD_n,       // Write Bus Direction
    output reg CBWRITE_n,   // CPU Write cycle to Bus
    output reg WLBD_n,      // Write Local Bus Direction
    output reg CMWRITE_n    // CPU Write to Local Memory
);

// Inverted input signals
wire CACT = ~CACT_n;
wire CGNT = ~CGNT_n;
wire EADR = ~EADR_n;
wire IOD = ~IOD_n;
wire BACT = ~BACT_n;

wire CBWRITE = ~CBWRITE_n;
wire CMWRITE = ~CMWRITE_n;


always @(*) begin
    if (!TEST) begin // Active-high TEST signal

        // WBD - DIRECTION FROM LBD TO BD
        assign WBD_n = ~(
                            (EADR)                    |   // Address from CPU to Bus
                            (CBWRITE)                 |   // CPU Write cycle to Bus
                            (IOD & MIS0 & BINPUT50_n) |   // Output part of IOX
                            (BACT)                      // DMA Output cycle
        );
                        

        // CBWRITE - CPU TO BUS WRITE. STARTS ONLY WHEN THE BUS IS GRANTED.
        //           LASTS UNTIL THE END OF THE BUS CYCLE.

        if (WRITE & CACT) 
            CBWRITE_n = 1'b0;
        else if (CACT==0)
            CBWRITE_n = 1'b1;
        

        // WLBD - DIRECTION FROM CD TO LBD
        assign WLBD_n = ~(
                             CBWRITE |                  // CPU Write cycle to Bus
                             CMWRITE |                  // CPU Write cycle to Local Memory
                            (IOD & MIS0 & BINPUT50_n)   // Output part of IOX
        );

        // CMWRITE - CPU WRITE TO LOCAL MEMORY.
        if (WRITE & CGNT)
            CMWRITE_n = 1'b0;
        else if (CGNT==0)
            CMWRITE_n = 1'b1;


    end else begin
        // Default values when TEST is active
        assign WBD_n = 1'b1;
        assign CBWRITE_n = 1'b1;
        assign WLBD_n = 1'b1;
        assign CMWRITE_n = 1'b1;
    end
end


endmodule


/*
DESCRIPTION

; 180587 - 3202B
; 070887 JLB: 3202c ONLY ! (TEST MODE).

*/


/* IMPLEMENTATION NOTES


Recursive Definitions Caution: The recursive definitions for CBWRITE and CMWRITE need careful handling
 to ensure they align with the design requirements and behave correctly in hardware.

Testing and Verification: Extensive testing with appropriate testbenches is crucial to validate the module's behavior under all conditions, 
including different states of the TEST signal.

*/
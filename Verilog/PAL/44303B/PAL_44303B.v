module PAL_44303B(
    input CACT_n,
    input CGNT_n,
    input EADR_n,           // Address from CPU to Bus
    input BINPUT50_n,
    input MISO,
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
wire BINPUT50 = ~BINPUT50_n;
wire IOD = ~IOD_n;
wire BACT = ~BACT_n;

// Output signal logic (active-high)
reg WBD, CBWRITE, WLBD, CMWRITE;

always @(*) begin
    if (!TEST) begin // Active-high TEST signal

        // WBD - DIRECTION FROM LBD TO BD
        WBD = EADR |                      // Address from CPU to Bus
              CBWRITE |                   // CPU Write cycle to Bus
              (IOD & MISO & BINPUT50) |   // Output part of IOX
              BACT;                       // DMA Output cycle

        // CBWRITE - CPU TO BUS WRITE. STARTS ONLY WHEN THE BUS IS GRANTED.
        //           LASTS UNTIL THE END OF THE BUS CYCLE.
        CBWRITE = (WRITE & CACT) |
                  (CBWRITE & CACT);

        // WLBD - DIRECTION FROM CD TO LBD
        WLBD = CBWRITE |                  // CPU Write cycle to Bus
               CMWRITE |                  // CPU Write cycle to Local Memory
               (IOD & MISO & BINPUT50);   // Output part of IOX

        // CMWRITE - CPU WRITE TO LOCAL MEMORY.
        CMWRITE = (WRITE & CGNT) |
                  (CMWRITE & CGNT);
    end else begin
        // Default values when TEST is active
        WBD = 1'b0;
        CBWRITE = 1'b0;
        WLBD = 1'b0;
        CMWRITE = 1'b0;
    end
end

// Assign negated outputs
assign WBD_n = ~WBD;
assign CBWRITE_n = ~CBWRITE;
assign WLBD_n = ~WLBD;
assign CMWRITE_n = ~CMWRITE;

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
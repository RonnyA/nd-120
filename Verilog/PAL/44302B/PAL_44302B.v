module PAL_44302B(
    input Q0_n, Q2_n, CC2_n, BDRY25_n, BDRY50_n, CGNT_n, CGNT50_n, CACT_n, TERM_n, BGNT_n, RT_n, IORQ_n, TEST, 
    output reg EMD_n, DSTB_n, BGNTCACT_n, CGNTCACT_n
);

// Inverted input signals
wire Q0 = ~Q0_n;
wire Q2 = ~Q2_n;
wire CC2 = ~CC2_n;
wire BDRY25 = ~BDRY25_n;
wire BDRY50 = ~BDRY50_n;
wire CGNT = ~CGNT_n;
wire CGNT50 = ~CGNT50_n;
wire CACT = ~CACT_n;
wire TERM = ~TERM_n;
wire IORQ = ~IORQ_n;
wire RT = ~RT_n;
wire BGNT = ~BGNT_n;


// Output signal logic (self reference)
reg EMD_logic;
reg EMD;

// Output signal logic (active-high)
reg CGNTCACT, BGNTCACT, DSTB;

always @(*) begin

    if (!TEST) begin // Active-high TEST signal
        // Logic for EMD
        EMD_logic = (Q2 & Q0 & CACT) |          // CPU CYCLE TO BUS SET 
                (EMD & CACT) |                  //       "          HOLD
                (CGNT & CGNT50) |               // CPU CYCLE TO MEM SET 
                (EMD & RT & CC2 & TERM) |       // ) HOLD TERMS FOR 
                (EMD & IORQ & CC2 & TERM);      // ) CPU READ, FETCH AND
                                                // ) MAP CYCLES

        // Logic for CGNTCACT
        CGNTCACT = CGNT | CACT;

        // Logic for BGNTCACT
        BGNTCACT = BGNT | CACT;

        // Logic for DSTB
        DSTB = (CGNT & CACT & BDRY50 & BDRY25 & IORQ) | 
               (CACT & IORQ & CC2);
    end else begin
        // Set default values when TEST is active ( to prevent latch inference )
        EMD = 1'b0;
        CGNTCACT = 1'b0;
        BGNTCACT = 1'b0;
        DSTB = 1'b0;
    end   

    EMD = EMD_logic;
end



// Assign negated outputs
assign EMD_n = ~EMD;
assign CGNTCACT_n = ~CGNTCACT;
assign BGNTCACT_n = ~BGNTCACT;
assign DSTB_n = ~DSTB;

endmodule


/*
  DESCRIPTION

; 060387 JLB: EMD WAS HOLDING IN ADDRESS PART OF IOX CYCLES AFTER
; BUFFERED WRITE CYCLES.
; EMD - ENABLE DATA PATH BETWEEN CD AND LBD
; 270387 CJTC: NEW SIGNAL DSTB TO SAMPLE DATA AT LBD/CD BUFFERS ON
; CPU FROM BUS READ, AT BDRY.
; 040487 JLB: DSTB MUST NOT CLOCK DATA BEFORE CACT GOES OFF IN IOXES.
;  (NEGATIVE SETUP OF DATA IN BUS SPECS.)
;
; 180587 CJTC: 3202B
; 070887 JLB: 3202C ONLY! (TEST MODE).

*/

/* IMPLEMENTATION NOTES


Recursive Definitions Caution: The recursive definitions for EMD need careful handling
 to ensure they align with the design requirements and behave correctly in hardware.

Testing and Verification: Extensive testing with appropriate testbenches is crucial to validate the module's behavior under all conditions, 
including different states of the TEST signal.

*/
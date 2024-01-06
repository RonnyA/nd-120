/*
; TO FIX VIRTUAL EXAMINE BUG IN CGA 
; + MISC. OTHER BUGS. 

Replaces 44608 that has a pin RT_n (Assume this signal is now comming from somewhere else)
*/

module PAL_44408B(
    input CLK, input C4, input C3, input C2, input C1, input C0, input M1, input M0, input LCS_n, input IDB2, input OE_n,
    output RWCS_n, output OPCLCS_n, output VEX, output LDEXM_n
);

// Inverted input signals
wire LCS = ~LCS_n;

// Internal signals for outputs
reg RWCS_int, OPCLCS_n_int, VEX_n_int, LDEXM_int;

// Sequential logic triggered on the rising edge of CLK
always @(posedge CLK) begin
    // Logic for LDEXM
    LDEXM_int <= C4 & ~C3 & ~C2 & ~C1 & C0 & M1 & M0 & LCS_n; // COMMAND 21.3 (validated RH)

    // Logic for VEX
    VEX_n_int <= LDEXM_int & ~IDB2 |       // CLEAR
                 ~LDEXM_int & VEX_n_int |  // HOLD CLEAR
                 LCS;                      // LCS

    // Logic for OPCLCS
    OPCLCS_n_int <= ~C4 | ~C3 | ~C2 | ~C1 | C0 | ~M1 | M0 | LCS; // COMMAND 36.2 (validated RH)

    // Logic for RWCS
    RWCS_int <= C4 & C3 & C2 & C1 & ~C0 & ~M1 & M0 & LCS_n; // COMMAND 36.1 (validated RH)

end

// Tri-state control for outputs
// High-impedance state when OE_n is high (active-low)

assign RWCS_n = OE_n ? 1'bz : ~RWCS_int;
assign OPCLCS_n = OE_n ? 1'bz : OPCLCS_n_int;
assign VEX = OE_n ? 1'bz : ~VEX_n_int;
assign LDEXM_n = OE_n ? 1'bz : ~LDEXM_int;
        

endmodule



/*
DESCRIPTION 

; 180587 M3202B
; 150687 RWCS SIGNAL TOO SLOW FROM NEC G.A. MUST BE DONE IN A PAL.
; 010787 REGISTRATION NUMBER CHANGED FROM 44501B 

*/
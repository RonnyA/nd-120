// 44307C,13D,CYCLK

module PAL_44307C(
    input TERM_n, CC0_n, CC1_n, CC2_n, CC3_n, FORM_n, BRK_n, RWCS_n, TRAP_n, VEX_n,
    output MCLK, WRFSTB_n, CYD_n, EORF, UCLK_n, MAP, MACLK, ETRAP_n
);


// Creating non-negated wires for active-low inputs
wire TERM = ~TERM_n;
wire CC0 = ~CC0_n;
wire CC1 = ~CC1_n;
wire CC2 = ~CC2_n;
wire CC3 = ~CC3_n;
wire FORM = ~FORM_n;
wire RWCS = ~RWCS_n;
wire TRAP = ~TRAP_n;



// Logic for MCLK
assign MCLK = (RWCS & CC3_n) |  // BECAUSE THE CONTROL STORE ADDRESS TO B
              (RWCS & CC2);     // IN PRESENTED ONTO MA. THEN THE ADDRESS
                                // STORE LOCATION TO BE EXECUTED IS PRESE

// Logic for WRFSTB_n (active-low)
assign WRFSTB_n = ~(CC3 | CC2 | CC1 | CC0_n | TERM); // b ON 75NS CYCLES TO PROVIDE A WRITE PU

// Logic for CYD_n (active-low)
assign CYD_n = ~( 
                  (CC3)         | // d + e + f WRITE PULSE USED IN WMAP AND WCA
                  (CC1_n)       | 
                  (CC2_n & CC0) |
                  (TERM)
                ); 

// Logic for EORF
assign EORF = (CC3_n & CC2_n & CC1 & CC0_n & TERM_n); // d MISC WRITE PULSE.

// Logic for UCLK_n (active-low)
assign UCLK_n = ~(
                   (CC3)   | // ON c ON ALL MEMORY REQUESTS.
                   (CC2)   | // USED TO UPDATE USED BITS AND CLOCK TRA
                   (CC1_n) |
                   (CC0_n) |
                   (TERM)
                  ); 

// Logic for MAP
assign MAP = (FORM & BRK_n & CC2 & TERM_n); // MUST NOT COME BEFORE ALL SHORT CYCLES

// Logic for MACLK
assign MACLK = (MAP & CC3_n & CC2 & CC1)    |   // e+f CAPTURE CD FROM MEMORY THROUGH M
               (TRAP & CC3_n & CC1 & CC0_n) |   // d+e CAPTURE TRAP VECTOR
               (RWCS & CC3_n)               |   //     CAPTURE MICROADDRESS AFTER EWCA
               (RWCS & CC2 & CC1_n);            //     TURNED OFF

// Logic for ETRAP_n (active-low)
assign ETRAP_n = ~(
                    (TERM_n & VEX_n & CC3)  |   // ENABLE TRAPS ONLY OUTSIDE t OR a
                    (TERM_n & VEX_n & CC2)  |   // UNSTABLE TRAP IN THIS PERIOD
                    (TERM_n & VEX_n & CC1)  |   // CAN DESTROY MA !
                    (TERM_n & VEX_n & CC0)      // DISABLE TRAPS DURING VEX
                  );

endmodule

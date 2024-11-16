// PAL16L8
// JLB 26NOV86
// PAL 44305D,15F,CSCTL (CONTROL STORE CONTROL)

module PAL_44305D (
    input FORM_n,  //! I0
    input CC1_n,   //! I1 - Cycle Control 1 (b+c+d+e+j+k+l+m)
    input CC2_n,   //! I2 - Cycle control 2 (e+f+g+h+i+j+k)
    input CC3_n,   //! I3 - Cycle Control 3 (h+i+j+k+l+m+n+o)
    input LCS_n,   //! I4 - Load Control Store (negated)
    input RWCS_n,  //! I5 - Read/Write Control Store (low=write)
    input WCS_n,   //! I6 - Write Control Store (negated)
    input FETCH,   //! I7 - Fetch
    input BRK_n,   //! I8 -
    input TERM_n,  //! I9 -

    output WICA_n,  //! Y0_n - WRITE PULSE TO MICROINSTRUCTION CACHE
    output WCSTB_n, //! Y1_n - (e+f) WRITE PULSE TO WRITEABLE | (m+n) WRITE PULSE DURING LOAD CONTROL

    output ECSL_n,  //! Enable Control Stroe (CSL negated)  B0_n - READ CONTROL STORE HOLD | HOLD OVERLAP WITH EWCA_n
    output EWCA_n,  //! Enable WCA reg in mic ont MA        B1_n - ENABLE WCA REG. IN MIC ONTO MA |  AVOID BLIP ON NEXT CYCLE
    output EUPP_n,  //! Enable Upper                        B2_n - NORMAL ADDRESSING | WRITE INTO MICROINSTRUCTION CACHE | ENABLE IN THE FIRST 50NS 
    output ELOW_n,  //! Enable Low                          B3_n - NORMAL ADDRESSING. ON FETCH EITHER MI |  ENABLE ACCORDING TO LUA12 BEFORE FETCH | OR A MAP IS USED. |  DO A MAP | ON BRK: USE BANK SELECTED BY LUA12.

    input WCA_n,  //! B4_n - WRITE INTO MICROINSTRUCTION CACHE (negated)
    input LUA12   //! B5_n
);

  // Inverted input signals for active-high usage
  wire FORM = ~FORM_n;
  wire CC1 = ~CC1_n;
  wire CC2 = ~CC2_n;
  wire CC3 = ~CC3_n;
  wire LCS = ~LCS_n;
  wire RWCS = ~RWCS_n;
  wire WCS = ~WCS_n;
  wire BRK = ~BRK_n;
  wire WCA = ~WCA_n;
  wire TERM = ~TERM_n;

  wire FETCH_n = ~FETCH;
  wire LUA12_n = ~LUA12;

  // Logic for WICA_n (active-low)
  assign WICA_n = ~(WCA & FETCH & TERM_n);  // WRITE PULSE TO MICROINSTRUCTION CACHE

  // Logic for WCSTB_n (active-low)
  assign WCSTB_n = ~((CC3_n & CC2 & CC1 & WCS & RWCS) |     // e+f WRITE PULSE TO WRITEABLE
      (CC3 & CC2_n & CC1 & LCS));                           // m+n WRITE PULSE DURING LOAD CONTROL

  // Logic for ECSL_n (active-low)
  assign ECSL_n = ~((RWCS & WCS_n & CC3 & TERM_n) |     // READ CONTROL STORE HOLD
      (RWCS & WCS_n & CC1_n & CC2 & TERM_n));           // HOLD OVERLAP WITH EWCA_n

  // Logic for EWCA_n (active-low)
  assign EWCA_n = ~((RWCS & CC3_n & CC2 & TERM_n) |     // ENABLE WCA REG. IN MIC ONTO MA
      (RWCS & CC3_n & CC1 & TERM_n));                  // AVOID BLIP ON NEXT CYCLE

  // Logic for EUPP_n (active-low)
  assign EUPP_n = ~(LUA12 |                     // NORMAL ADDRESSING
      (WCA & FETCH) |                           // WRITE INTO MICROINSTRUCTION CACHE
      (FETCH & CC1_n & CC2_n & CC3_n & TERM_n)  // ENABLE IN THE FIRST 50NS
      );  // + HOLD TIME = 75NS

  // Logic for ELOW_n (active-low)
  assign ELOW_n = ~((LUA12_n & FETCH_n) |   // NORMAL ADDRESSING. ON FETCH EITHER MI
      (LUA12_n & TERM) |                    // ENABLE ACCORDING TO LUA12 BEFORE FETCH
      (FORM & BRK_n & CC2 & TERM_n) |       // OR A MAP IS USED.
      (FORM & BRK_n & CC3 & TERM_n) |       // DO A MAP
      (LUA12_n & BRK & CC2 & TERM_n) |      // ON BRK: USE BANK SELECTED BY LUA12.
      (LUA12_n & BRK & CC3 & TERM_n));      //

endmodule

/*
DESCRIPTION

; 130387 JLB: ELOW ALWAYS ENABLED ON TERM IF LUA12 IS LOW.
; MAY SPEED UP NON FETCH CYCLES.

; 180587 3202B
; 090687 JLB: EWCA MUST NOT BE ENABLED DURING a AND b. WILL CREATE BLIP ON
; NEXT CYCLE.
; 090687 JLB: ECSL HOLD IN g AND h.
; 030987 JLB: WRITE IN CONTROL STORE DOES NOT WORK. WRITE PULSE STARTS TOO
; SOON. WCSTB CHANGED TO e+f IN THIS CASE, AND TO m+n DURING LCS
; TO BE ABLE TO USE 250ns PROMS.


*/

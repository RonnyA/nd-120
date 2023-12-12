// 44304E - LOCAL DATA BUS CONTROL PAL

module PAL_44304E(
    input CGNT_n, BGNT_n, BGNT50_n, MWRITE_n, BDAP50_n, EBUS_n, IBAPR_n, GNT_n, TEST,
    output reg EBD_n, 
    output reg CLKBD,
    output reg SAPR,
    output reg FAPR,
    output reg EBADR,
    output reg BACT_n, 
    output reg DBAPR
);


// TODO: Should there be some "CLEAR" signal to reset all registers? ?
// TODO: FIX SELF REFERENDE!!! EBDADR_n and BACT
// TODO: WHAT IF TEST IS ACTIVE? (set default values to prevent latch inference)?

// Inverted input signals
wire BGNT = ~BGNT_n;
wire BGNT50 = ~BGNT50_n;
wire BDAP50 = ~BDAP50_n;
wire EBUS = ~EBUS_n;	

// Output signal logic (self reference)
reg BACT_logic; // Register to handle self-reference   
reg BACT;

reg EBADR_n_logic; // Register to handle self-reference
reg EBADR_n;

always @(*) begin

    if (!TEST) begin // Active-high TEST signal


        // BACT - BUS ACTIVITY
        BACT_logic =  (BGNT50 & MWRITE_n) |       // Enable for data only after address
                       (BACT & BDAP50);           // Hold after BDAP finished

        // EBD - ENABLE BUS DATA
        EBD_n =~( 
                (EBUS & CGNT_n & GNT_n) |
                (EBUS & BGNT) |
                (EBUS & BACT)
        );

        // EBADR - ENABLE ADDRESS FROM BUS TO LOCAL MEMORY
        EBADR_n_logic = (GNT_n & BGNT_n) |
                (IBAPR_n & EBADR_n) |
                (GNT_n & EBADR_n);


        FAPR  = ~IBAPR_n;
        SAPR = FAPR; 
        DBAPR  = SAPR;

        // CLKBD - CLOCK PULSE TO 648's
        CLKBD = ~(
                (~SAPR & BGNT50_n) |    // Clock addresses on delayed BAPR
                (~SAPR & BDAP50_n) |    // Clock data 50ns after start of
                (~SAPR & MWRITE_n)     // BGNT * BDAP on memory writes from DMA
        );
    end 

    BACT = BACT_logic;
    EBADR_n = EBADR_n_logic;
end

// Assign negated outputs
assign BACT_n = ~BACT;
assign EBADR = ~EBADR_n;


endmodule

/*

DESCRIPTION

; 200387 CJTC:      NEED TO SLOW DOWN APR TO AS648 BUS TCVRS. PUT IT
;                   THROUGH THIS PAL INSTEAD OF F04
; 200387 JLB:       EBADR COMES ON AT BAPR TO AVOID SPIKE ON LBD.
; NEW INPUT CGNT
; 230387 JLB:       APR DELAYED 3XPAL DELAY
; 240387 JLB:       EBD MUST NOT CHANGE WHEN DATA IS CLOCKED IN.
;
; 180587 - 3202B
; 310787 JLB:       BUFFERED DMA WRITE: CLOCK DATA IN 648'S ALSO.

; 040887 JLB:       BUFFERED DMA WRITE: NEED TO ENABLE THE REGISTER IN THE
;                   648'S FOR THE PERIOD OF BGNT.
; 060887 D JLB:     EBADR CHANGED TO MAKE BUFFERED DMA WRITE WORK.
; 090887 E JLB:     TEST MODE FOR C-PRINT.
*/
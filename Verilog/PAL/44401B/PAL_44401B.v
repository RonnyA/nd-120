// 44401B,5D,BTIM
// PAL16R4D (https://rocelec.widen.net/view/pdf/c6dwcslffz/VANTS00080-1.pdf)

// I/O 1,2,7, and 8 is not controlled by OE_n

// Four D flip-flops controleed by CLK signal (and reads input to O3,O4,O5 and O6) when transision from LOW to HIGH.
// O3-O6 output is controlled by OE_n (HIGH signal means output is three-state)

module PAL_44401B(
    input OSC, CC2_n, CACT_n, CACT25_n, BDRY50_n, CGNT_n, CGNT50_n, TERM_n, IORQ_n, OE_n,
    output EADR_n, EIOD_n, Q2_n, Q1_n, Q0_n, DAP_n, APR_n
);

// PCB 3202D sheet 6:
//
// PAL input signal PD1 is connected to PAL OE_n
//     input signal OSC is connectec to PAL CK pin

// Creating non-negated wires for active-low inputs
wire CC2 = ~CC2_n;
wire CACT = ~CACT_n;
wire CACT25 = ~CACT25_n;
wire CGNT = ~CGNT_n;
wire IORQ = ~IORQ_n;


// Temporary removed because of "unused" warning. 
// Which is related to " Feedback to public clock or circular logic: 'DAP_n'"
//wire DAP = ~DAP_n;	


// Logic for Q0, Q1, Q2
reg Q0, Q1, Q2;


// Flip-flop logic for Q0, Q1, Q2
always @(posedge OSC) begin
    Q0 <=
                    (CACT & Q2_n & Q1_n & Q0_n & CACT25_n) |
                    (Q2_n & Q1_n & Q0)                     |
                    (Q2 & Q1 & Q0)                         |
                    (Q2 & Q1 & Q0_n);
            

    Q1 <=
                    (Q2_n & Q0 & Q1)   |
                    (Q2_n & Q0 & Q1_n) |
                    (Q1 & Q0_n & Q2)   |
                    (Q1 & Q0_n & Q2_n);
              

    Q2 <= 
                    (Q1 & Q0_n & Q2)   |
                    (Q1 & Q0_n & Q2_n) |
                    (Q2 & Q0 & Q1)     |
                    (Q2 & Q0 & Q1_n);            
end


// Output logic for Q0_n, Q1_n, Q2_n
assign Q0_n = OE_n ? 1'bz : ~Q0;
assign Q1_n = OE_n ? 1'bz : ~Q1;
assign Q2_n = OE_n ? 1'bz : ~Q2;


// Logic for APR
assign APR_n = ~(Q2_n & Q1 & CACT);

// Logic for EADR_n (active-low)
assign EADR_n = ~(
                  (Q2_n & Q0 & CACT)                     |   // t + u
                  (Q2_n & Q1 & CACT)                     |   // u + v
                  (Q1 & Q0_n & CACT)                     |   // v + w
                  (Q2_n & Q1_n & Q0_n & CACT & CACT25_n) |   // s
                  (CGNT & CGNT50_n));                        // address part for CPU cycle

// Logic for DAP
assign DAP_n = ~(
                  (Q2_n & Q1_n & Q0_n & CACT & CACT25) |

// TODO:  Feedback to public clock or circular logic: 'DAP_n'                
// When DAP_n is included in the logic, the above error is shown.
//                  (DAP & TERM_n & IORQ & CC2)
                  (TERM_n & IORQ & CC2)
                );

// Logic for EIOD_n (active-low)
assign EIOD_n = ~(IORQ & Q2_n & Q1_n & Q0_n & CACT & CACT25 & BDRY50_n & CC2);
// STARTS WHEN THE s STATE HAS BEEN REACHED AFTER COMPLETING THE LOOP.

endmodule

/*
DESCRIPTION


;                        |<----------------------------------------------------|
;                                                                              |
;                ------<(s)000                                                 |
;               |     /                                                        |
; /CACT+CACT25  |    /   |                                                     |
;               |   /    |                                                     |
;                --/     |                                                     |
;                        |                                                     |
;                                                                              |
;                        (t)001                                                |
;                                                                              |
;                        |-----(u)-----(v)-----(w)-----(x)-----(y)-----(z)---->| 
;                             O11     010     110     111     101     100
                 
; 010387 JLB: EIOD TOO SOON, ONLY 15NS SETUP FOR BD BEFORE BIOXE.
; WOULD NOT LOAD FROM FLOPPY. EIOD FRONT FLANK DELAYED 25NS.

: SAME WITH DAP. DAP HELD FOR THE REST OF THE CYCLE UNTIL TERM
; ON IORQ.
; 060387 JLB: DAP HELD INTO ADDRESS PART OF IOX CYCLES AFTER A
; BUFFERED WRITE CYCLE. SWAPPED IOD FOR IORQ IN EIOD.
; USING CC2 (NEW INPUT) TO QUALIFY DAP AND EIOD
; STATE MACHINE
;
; 180587 M3202B
; 090887 B JLB: MAXIMIZED EQUATIONS TO MATCH CLOCK SKEW.

*/
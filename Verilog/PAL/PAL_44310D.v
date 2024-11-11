//PAL16L8
//ADGD 13/8/86
//44310D,3F,LBDIF

module PAL_44310D (
    input  HIEN_n,    //! I0
    input  BGNT_n,    //! I1
    input  CGNT_n,    //! I2
    input  LOEN_n,    //! I3
    input  CGNT50_n,  //! I4
    input  ECCR,      //! I5
    input  BGNT50_n,  //! I6
    input  BGNT75_n,  //! I7
    input  BDAP50_n,  //! I8
    input  MR_n,      //! I9

    output BDRY_n,     //! B0
    output BIOXL_n,    //! B1
    input  RAS,        //! B2
    input  REF100_n,   //! B3
    input  BIOXE_n,    //! B4
    input  MWRITE50_n, //! B5

    output BCGNT50R_n, //! Y0
    output RDATA       //! Y1
);


  // Creating non-negated wires for active-low inputs
  wire HIEN = ~HIEN_n;
  wire BGNT = ~BGNT_n;
  wire CGNT = ~CGNT_n;
  wire LOEN = ~LOEN_n;
  wire BGNT50 = ~BGNT50_n;
  wire BGNT75 = ~BGNT75_n;
  wire BDAP50 = ~BDAP50_n;
  wire MWRITE50 = ~MWRITE50_n;
  wire BIOXE = ~BIOXE_n;

  wire BIOXL = ~BIOXL_n;
  wire CGNT50 = ~CGNT50_n;
  wire REF100 = ~REF100_n;

  wire RAS_n = ~RAS;


  // Logic for BCGNT50R_n (active-low)
  assign BCGNT50R_n = ~((MWRITE50_n & BGNT & BGNT50) |  // FROM 50NS AFTER GNT ON READ C
      (MWRITE50_n & CGNT & CGNT50)  // LASTS FOR THE REST OF THE CYCLE
      );

  // Logic for BDRY_n (active-low)
  reg BDRY;
  always @(*) begin
    if ((MWRITE50_n & BDAP50 & BGNT & LOEN_n & HIEN_n & RAS_n) |  // BUS READ FROM LOCAL MEM
        (MWRITE50 & BDAP50 & BGNT50 & BGNT) |  // BUS WRITE TO LOCAL MEM
        (BIOXL & ECCR) |  // IOX=ECCR
        (REF100) | (MWRITE50_n & BDAP50 & BGNT50_n & BGNT75)  // LATE BDRY FOR 10MHZ DISK
        )
      BDRY = 1'b1;
    else if (((MR_n & BDAP50) == 0) |  // HOLD TERM FOR MEMORY
        ((MR_n & BIOXE) == 0)  // HOLD TERM FOR IOX CYCLE
        )
      BDRY = 1'b0;
  end

  assign BDRY_n = ~BDRY;

  // Logic for BIOXL_n (active-low)
  assign BIOXL_n = ~(BIOXE & BGNT_n & CGNT_n);

  // Logic for RDATA
  assign RDATA = ~((MWRITE50) |  // INDICATES DATA READY ON
      (LOEN) | (HIEN) | (BGNT_n & CGNT_n) | (RAS));

endmodule

/*

DESCRIPTION

:280287 JLB: ECCR WRONG POLARITY, RESPONDS WITH BDRY TO
;EXISTING IOX-ES.
;280287 JLB: NEW INPUT REF~ , TO GENERATE A REF PULSE OF 175-200NS
;DURATION BY GENERATING BDRY.
;
;180587 M3202B
;090787 B JLB: RAS USED IN RDATA TO AVOID SPIKE ON TRANSITION FROM
;              LOEN TO HIEN.
;290787 C JLB: BD HAD A TYPICAL SETUP TIME OF 140NS BEFORE BDRY ON DMA READ
;              CHANGED TO 65NS (25NS REQUIRED). DMA BUFFERED WRITE: BDRY START
;              50NS AFTER BGNT GOES ACTIVE ON DMA WRITE, AND LASTS UNTIL BGNT
;              OR BDAP50 GOES OFF (105NS MIN.}. THIS IS TO GIVE TIME FROM
;              GRANT OFF TO BMEM ON IN THE FOLLOWING CYCLE.
;110887 D JLB: BDRY GAN BE LOST IF BDRY50 IS NOT PRESENT AT THE TIME STATE
;              7 IN THE RAM CONTROL IS REACHED. HAPPENS WITH 1OMHZ DISK CONTR.
;              SINTRAN STOPS ON LEVEL 14 DURING STARTUP.

*/

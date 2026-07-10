
%*****************************************
%*****************************************
%* M I C R O P R O G R A M N D - 1 9 0 J / C X
%*****************************************
%*****************************************
%*****************************************

%*****************************************
%*****************************************
% HARDWARE TRAP VECTOR
%*****************************************

 0/
% MASTER CLEAR / POWER CLEAR

        AB,MACL                                 ALUD,NONE
        IDBS,ARG            COMM,EWRF           T,JMP       T,HOLD
        MACL;

 1/
% PAGE FAULT

        A,6                                     ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,JMP       T,HOLD
        PVPF;

 2/
% PROTECT VIOLATION

        A,5                                     ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,JMP       T,HOLD
        PVPF;

 3/
% RING-DOWN TRAP

        B,R7                ALUF,PASSD          ALUD,B
        IDBS,PGS                                T,JMP       T,HOLD
        RNGDW;

 4/
% PGU TRAP SINTRAN III

        B,R7                ALUF,PASSD          ALUD,B
        IDBS,PGS                                T,JMP       T,HOLD
        PGU3;

 5/
% WIP TRAP SINTRAN III

        B,R7                ALUF,PASSD          ALUD,B
        IDBS,PGS                                T,JMP       T,HOLD
        WIP3;

 6/
% ALT-TRAP SINTRAN 4

        6                   COMM,SLOW;          T,JMP

 7/
% WIP-TRAP SINTRAN 4

        7                   COMM,SLOW;          T,JMP

 10/
% MISMATCH TRAP SINTRAN 4

        10                  COMM,SLOW;          T,JMP

 11/
% PGU-TRAP SINTRAN 4

        11                  COMM,SLOW;          T,JMP


 12/
% DOUBLE PREFIX IS NOT ALLOWED (20-BIT LOG.ADDRESSING MUST BE ACTIVE)

                                                ALUD,NONE
        IDBS,ALU            COMM,SLOW           T,JMP       T,HOLD
        ILLIN;

 13/
% SPARE VECTOR LOCATIONS

        13                  COMM,SLOW;          T,JMP
        14                  COMM,SLOW;          T,JMP
        15                  COMM,SLOW;          T,JMP

 16/
% PANEL INTERRUPT

                                                ALUD,NONE
        IDBS,PANEL          COMM,LDLC           T,JMP       T,HOLD
        PANEL;

 17/
% MACRO INTERRUPT

        PIC,RVECT B,R1      ALUF,PASSD          ALUD,B
        IDBS,PICVC          COMM,EPIC           T,JMP       T,HOLD
        MACRI;

 20/
% READ VERSION INSTRUCTION

VERSN:  B,T                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        100014;  % L-VERSION
% CC K: ELEAV: LEAVE INSTRUCTION PROBLEM AT PAGE BOUNDARY TRAPS.


                            ALUF,PASSD          ALUD,Q
        IDBS,STS                                T,NEXT      T,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDPIL          T,NEXT      T,HOLD;

% L-ONLY WORD: inserted in version L (not present in the K print)
                                                ALUD,NONE
                            COMM,SLOW           T,NEXT      T,HOLD;

        B,D                 ALUF,PASSD          ALUD,B
        IDBS,INR                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDPIL          T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        40377;

%CC INVERT BIT 0-3 (ALD), BIT 4-6 (PRINT RELEASE), BIT 7 (CX); BIT14 (PRINT NO)
%CC BIT7=1 => HIGH SPEED, BIT 15-13=101 => 3202

        B,A                 ALUF,XORDQ          ALUD,B
        IDBS,ALD                                T,JMP       T,HOLD
        CONT;

%********************************************************
%********************************************************

% SPECIAL TREATMENT OF PAGE FAULT AND PROTECT VIOLATION

%********************************************************

PVPF:   AB,PGS                                  ALUD,NONE
        IDBS,PGS            COMM,EWRF           T,NEXT      T,HOLD
 COND,FETCH                                     F,NEXT      F,HOLD;

        IDBS,ALU                                ALUD,NONE
        FTCH CONDENABL;                         T,JMP       T,HOLD


%********************************************************
% INCREMENT P IF NOT FETCH
%********************************************************

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

FTCH:                                           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU            COMM,CLIRQ          T,NEXT      T,HOLD
 COND,IRQ                                       F,JMP       F,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD
        NOINT CONDENABL;


%***********************************************
% INTERRUPT IS PENDING

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,STP                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        FTCH2 CONDENABL;


%***********************************************
% CPU IS IN STOP MODE, MULTIPLE SINGLE OR BREAKPOINT MUST BE THE CASE

        AB,BPFLG            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        AB,SINGL            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
        BRKZZ CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        BRKZZ CONDENABL;



%***********************************************
% NO INTERRUPT IS PENDING, IT CAN BE IOF-PAGEFAULT

NOINT:                                          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,FETCH                                     F,NEXT      F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        FTCH2 CONDENABL;


%***********************************************
% DECREMENT P, IT HAS BEEN INCREMENTED

        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        FTCH2;




%***********************************************
% EXECUTE LEVEL CHANGE OR TRY SAME INSTRUCTION AGAIN.

FTCH2:  B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


%***********************************************
%***********************************************
PANEL:

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,LC                                    ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,LC                                    ALUD,NONE
        IDBS,ALU                                T,JMPAOPR   T,HOLD
        PANVC;

MACRI:  A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,LC                                    ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,LC                                    ALUD,NONE
        IDBS,ALU                                T,JMPAOPR   T,HOLD
        ITSRV;

%********************************************************
% RING-DOWN TRAP

RNGDW:  B,R5                ALUF,PASSD          ALUD,B
        IDBS,STS                                T,JMP       T,PUSH
        PTC;

                                                ALUD,NONE
        IDBS,DBR                                T,NEXT      T,HOLD;

        B,R1                ALUF,PASSD          ALUD,SRB
        IDBS,SWAP                               T,NEXT      T,HOLD;

        A,PIL B,0           ALUF,PASSD          ALUD,Q      XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        B,R2                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        177774;

        A,R1 B,3            ALUF,ANDDA          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

        A,R2                ALUF,ORAQ           ALUD,Q
        IDBS,ALU            COMM,LDPCR          T,NEXT      T,HOLD;

        A,PIL B,0           ALUF,PASSQ          ALUD,NONE   XRF
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        PXTST;

%********************************************************
% PGU-TRAP FOR SINTRAN III

PGU3:   A,13 B,R1           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        WIPGU;

%********************************************************
% WIP-TRAP FOR SINTRAN III

WIP3:   B,R1                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        54000;

%CC SET READ PERMIT ALSO.

WIPGU:  B,R5                ALUF,PASSD          ALUD,B
        IDBS,STS                                T,JMP       T,PUSH
        PTC;

        A,R1 B,R1           ALUF,ORDA           ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,R7                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD;

PXTST:  B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;

%***********************************************
%***********************************************


 101/
% INDIRECT MEMORY REFERENCES. MUST BE IN-LINE WITH PREFIXED COUNTERPARTS

STR1I:  A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,I       T,JMP       T,HOLD
        CONT;
STR1IX: A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,XI      T,JMP       T,HOLD
        CONT;
STDI:   A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,I       T,JMP       T,HOLD
        STD1;
STDIX:  A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,XI      T,JMP       T,HOLD
        STD1;
LDDI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        LDD1;
LDDIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        LDD1;
STFI:   A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,I       T,JMP       T,HOLD
        STF1;
STFIX:  A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,XI      T,JMP       T,HOLD
        STF1;
LDFI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        LDF1;
LDFIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        LDF1;
MINI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        MIN1;
MINIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        MIN1;
LDAI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        LDA1;
LDAIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        LDA1;
LDTI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        LDT1;
LDTIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        LDT1;
LDXI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        LDX1;
LDXIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        LDX1;
ADDI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        ADD1;
ADDIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        ADD1;
SUBI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        SUB1;
SUBIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        SUB1;
ANDI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        AND1;
ANDIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        AND1;
ORAI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        ORA1;
ORAIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        ORA1;
FADI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        FAD1;
FADIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        FAD1;
FMUI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        FMU4;
FMUIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        FMU4;
FDVI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        FDV4;
FDVIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        FDV4;
MPYI:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,I        T,JMP       T,HOLD
        MPY5;
MPYIX:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XI       T,JMP       T,HOLD
        MPY5;
JMPI:                                           ALUD,NONE
        IDBS,LA             COMM,JMP,I          T,JMP       T,HOLD;
JMPIX:                                          ALUD,NONE
        IDBS,LA             COMM,JMP,XI         T,JMP       T,HOLD;



% NORMAL CONTINUE EXECUTION

CONT:   B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


% CONTINUATION OF MOST COMMON INSTRUCTIONS:

STZXB:  A,Z                 ALUF,PASSA          ALUD,NONE
                            COMM,AWRITE,XB      T,JMP       T,HOLD
        CONT;
STAXB:  A,A                 ALUF,PASSA          ALUD,NONE
                            COMM,AWRITE,XB      T,JMP       T,HOLD
        CONT;
STTXB:  A,T                 ALUF,PASSA          ALUD,NONE
                            COMM,AWRITE,XB      T,JMP       T,HOLD
        CONT;
STXXB:  A,X                 ALUF,PASSA          ALUD,NONE
                            COMM,AWRITE,XB      T,JMP       T,HOLD
        CONT;
STD1:   A,D                 ALUF,PASSA          ALUD,NONE
                            COMM,AWRITE,NEXT    T,JMP       T,HOLD
        CONT;
STDXB:  A,A                 ALUF,PASSA          ALUD,NONE
                            COMM,AWRITE,XB      T,JMP       T,HOLD
        STD1;
LDD1:   B,A                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,AREAD,NEXT     T,NEXT      T,HOLD;
        B,D                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;
LDDXB:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XB       T,JMP       T,HOLD
        LDD1;
STF1:   A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,NEXT    T,JMP       T,HOLD
        STD1;
STFXB:  A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,XB      T,JMP       T,HOLD
        STF1;
LDF1:   B,T                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,AREAD,NEXT     T,JMP       T,HOLD
        LDD1;
LDFXB:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XB       T,JMP       T,HOLD
        LDF1;
MIN1:   B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;
        B,R1                ALUF,B+1            ALUD,B
        IDBS,ALU            COMM,AWRITE,HOLD    T,NEXT      T,HOLD;
        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,CNEXT,NF=0     T,NEXT      T,HOLD;
        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,CNEXT,F=0      T,NEXT      T,HOLD;
MINXB:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XB       T,JMP       T,HOLD
        MIN1;
LDA1:   B,A                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;
LDAXB:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XB       T,JMP       T,HOLD
        LDA1;
LDT1:   B,T                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;
LDTXB:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XB       T,JMP       T,HOLD
        LDT1;
LDX1:   B,X                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;
LDXXB:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XB       T,JMP       T,HOLD
        LDX1;
ADD1:   A,A B,A             ALUF,D+A            ALUD,B      STS,EA
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;
ADDXB:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XB       T,JMP       T,HOLD
        ADD1;
SUB1:   A,A B,A             ALUF,A-D            ALUD,B      STS,EA
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;
SUBXB:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XB       T,JMP       T,HOLD
        SUB1;
AND1:   A,A B,A             ALUF,ANDDA          ALUD,B
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;
ANDXB:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XB       T,JMP       T,HOLD
        AND1;
ORA1:   A,A B,A             ALUF,ORDA           ALUD,B
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;
ORAXB:                                          ALUD,NONE
        IDBS,ALU            COMM,AREAD,XB       T,JMP       T,HOLD
        ORA1;
FADXB:                      ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,XB       T,JMP       T,HOLD
        FAD1;
FSBXB:  A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,XB       T,JMP       T,HOLD
        FAD1;
FMUXB:  A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,XB       T,JMP       T,HOLD
        FMU4;
FDVXB:  A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,XB       T,JMP       T,HOLD
        FDV4;
MPYXB:                      ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,XB       T,JMP       T,HOLD
        MPY5;
JMPXB:                                          ALUD,NONE
        IDBS,LA             COMM,JMP,XB         T,JMP       T,HOLD;
CJP1:                                           ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;
SKIP1:                      ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,CNEXT,F=0      T,JMP       T,HOLD;
ILLIN:  A,7                                     ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,JMP       T,HOLD
        ILLI2;
PRIVI:  A,11                                    ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,JMP       T,HOLD
        ILLI2;
ILLI2:                                          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;  % PAUSE
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;
SWO:    A,SRCE B,DEST       ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        SWO0;
SWO0:   B,SRCE              ALUF,PASSQ          ALUD,B
        IDBS,ALU            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
SW2:    A,SRCE B,DEST       ALUF,INVA           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        SWO0;
REX02:  A,R1 B,DEST         ALUF,ORAB           ALUD,B
        IDBS,ALU            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;










%**********************************************************
%**********************************************************
% SHIFT INSTRUCTIONS
%**********************************************************

SHA1:                                           ALUD,NONE

        IDBS,GPR            COMM,LDLC           T,JMP       T,LOAD
        IDBS,GPR            COMM,LDLC           T,JMP       T,LOAD
        DUMMY;

        B,A                 ALUF,PASSB          ALUD,SRB    ALUM,IR
        IDBS,ALU                                T,JMP       T,POP
                                                            LCOUNT
        CONT;


%**********************************************************
% SUBROUTINE TO REMOVE ONE SHIFT COUNT

DUMMY:
        IDBS,ALU                                ALUD,NONE
 COND,LC=0;                                     T,NEXT      T,HOLD


        IDBS,ALU                                ALUD,NONE
                                                T,RETURN    LCOUNT; T,HOLD

SHT1:                                           ALUD,NONE
        IDBS,GPR            COMM,LDLC           T,JMP       T,LOAD
        DUMMY;

        B,T                 ALUF,PASSB          ALUD,SRB    ALUM,IR
        IDBS,ALU                                T,JMP       T,POP
                                                            LCOUNT
        CONT;

SHD1:                                           ALUD,NONE
        IDBS,GPR            COMM,LDLC           T,JMP       T,LOAD
        DUMMY;

        B,D                 ALUF,PASSB          ALUD,SRB    ALUM,IR
        IDBS,ALU                                T,JMP       T,POP
                                                            LCOUNT
        CONT;

SAD1:   A,D                 ALUF,PASSA          ALUD,Q
        IDBS,GPR            COMM,LDLC           T,JMP       T,LOAD
        DUMMY;

        B,A                 ALUF,PASSB          ALUD,SRD    ALUM,IR
        IDBS,ALU                                T,NEXT      T,POP
LCOUNT;

        B,D                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;








%********************************************************
%********************************************************

% BIT INSTRUCTIONS

%********************************************************
% BSET BAC

BSETK:  B,4                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,PUSH
        GETK;
                                                ALUD,NONE

        IDBS,ALU                                T,NEXT      T,HOLD
        BSET1 CONDENABL;


%********************************************************
% BSET ZRO

BSETO:  A,REG B,R1          ALUF,INVD           ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        STSTZ;

        A,R1 B,DEST         ALUF,ANDAB          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        ZTSTS;


%********************************************************
% SUBROUTINE TO ISOLATE K-FLIP-FLOP

GETK:                       ALUF,ANDDQ          ALUD,Q
        IDBS,STS                                T,RETURN    T,POP
 COND,F=0                                       F,JMP       F,HOLD;


%***********************************************
% SUBROUTINE TO TRANSFER STS TO Z-REGISTER

STSTZ:  B,Z                 ALUF,PASSD          ALUD,B
        IDBS,STS                                T,RETURN    T,POP;


%***********************************************
% SUBROUTINE TO TRANSFER Z-REGISTER TO STS

ZTSTS:  A,Z                 ALUF,PASSA          ALUD,Q      STS,LO
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;


%***********************************************
% BSET ONE

BSET1:  A,REG B,R1          ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        STSTZ;

        A,R1 B,DEST         ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        ZTSTS;


%***********************************************
% BSET BCM

BSETC:  A,REG B,R1          ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        STSTZ;

        A,R1 B,DEST         ALUF,XORAB          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        ZTSTS;


%********************************
% BSKP BCM

BSKPC:  B,4                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,LOAD
        GETK;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        BSKP0 CONDENABL;


%********************************
% BSKP ONE

BSKP1:  B,Z                 ALUF,PASSD          ALUD,B
        IDBS,STS                                T,NEXT      T,HOLD;

        B,DEST              ALUF,INVB           ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        BSKP9;


%********************************
% BSKP BAC

BSKPK:  B,4                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,LOAD
        GETK;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        BSKP1 CONDENABL;

%*******************************
%********************************


BSKP0:  B,Z                 ALUF,PASSD          ALUD,B
        IDBS,STS                                T,NEXT      T,HOLD;

        B,DEST              ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

BSKP9:  A,REG               ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;


        IDBS,ALU                                ALUD,NONE
        SKIP CONDENABL;                         T,JMP       T,HOLD

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


%*******************************
% BSTA

BSTA:   A,2 B,R2            ALUF,INVD           ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        BSEK1;

        A,Z B,R2            ALUF,ANDAB          ALUD,NONE   STS,LO
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;


%*******************************
% BSTC

BSTC:   A,2 B,R2            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R2                ALUF,XORDA          ALUD,Q
        IDBS,STS                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE   STS,LO
        IDBS,ALU                                T,JMP       T,PUSH
        BSEK1;

        A,Z B,R2            ALUF,ORAB           ALUD,NONE   STS,LO
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;

BSEK1:  B,4                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,PUSH
        GETK;


        IDBS,ALU                                ALUD,NONE
        BSE11 CONDENABL;                        T,NEXT      T,HOLD

        A,REG B,R1          ALUF,INVD           ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        STSTZ;

        A,R1 B,DEST         ALUF,ANDAB          ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;

BSE11:  A,REG B,R1          ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        STSTZ;

        A,R1 B,DEST         ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;


%****************************
% BANC

BANC:   B,4                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,LOAD
        GETK;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        BLDC CONDENABL;                         T,NEXT      T,HOLD

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


%******************************
% BORC

BORC:   B,4                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,LOAD
        GETK;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        CONT CONDENABL;


%******************************
% BLDC

BLDC:   A,REG B,R1          ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        STSTZ;

        A,R1 B,DEST         ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,2 B,R2            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        SETK0 CONDENABL;

SETK1:  A,R2 B,Z            ALUF,ORAB           ALUD,NONE   STS,LO
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;


%********************************
% BAND

BAND:   B,4                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,LOAD
        GETK;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        BLDA CONDENABL;

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


%********************************
% BORA

BORA:   B,4                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,LOAD
        GETK;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        CONT CONDENABL;


%********************************
% BLDA


BLDA:   A,REG B,R1          ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        STSTZ;

        A,R1 B,DEST         ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,2 B,R2            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        SETK1 CONDENABL;

SETK0:  A,R2 B,Z            ALUF,MASKAB         ALUD,NONE   STS,LO
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;


SKIP:   B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;



%***********************************************
%************************************************

% SUBROUTINE TO CHECK PROTECT VIOLATION FOR RESTRICTED INSTRUCTIONS

%***********************************************

PVCHK:                                          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,RESTR                                     F,RETURN    F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        PRIVI CONDENABL;






%***********************************************
% SUBROUTINE TO CHECK FOR OWN LEVEL IN SRB, LRB, IRW, IRR
%***********************************************
RBLOK:                      ALUF,PASSD          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;


%***********************************************
% ENTRY USED BY MOPC IN REGISTER DEPOSIT

OPCRB:                                          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;


%***********************************************
% ENTRY USED BY IRR AND IRW

IRWRD:  A,PIL               ALUF,XORDQ          ALUD,Q
        IDBS,AARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        170;







%***********************************************
%***********************************************

% STORE REGISTER BLOCK

%***********************************************

SRB2:   B,7                                     ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,JMP       T,PUSH
        PVCHK;

        B,Z                 ALUF,PASSD          ALUD,B
        IDBS,STS                                T,JMP       T,PUSH
        RBLOK;

        A,10                ALUF,D-1            ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD
        SRB1 CONDENABL;


%***********************************************
% OWN LEVEL, SAVE REGISTER BLOCK IN REGISTER FILE

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,LC=0;

        A,PIL B,LC          ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,POP
                                                            LCOUNT;

SRB1:   A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,REG B,P                               ALUD,NONE
        IDBS,REG            COMM,WRRQ,APT       T,NEXT      T,HOLD;
        A,REG B,X                               ALUD,NONE
        IDBS,REG            COMM,AWRITE,NEXT    T,NEXT      T,HOLD;
        A,REG B,T                               ALUD,NONE
        IDBS,REG            COMM,AWRITE,NEXT    T,NEXT      T,HOLD;
        A,REG B,A                               ALUD,NONE
        IDBS,REG            COMM,AWRITE,NEXT    T,NEXT      T,HOLD;
        A,REG B,D                               ALUD,NONE
        IDBS,REG            COMM,AWRITE,NEXT    T,NEXT      T,HOLD;
        A,REG B,L                               ALUD,NONE
        IDBS,REG            COMM,AWRITE,NEXT    T,NEXT      T,HOLD;
        A,REG B,Z           ALUF,ANDDQ          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;
                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,NEXT    T,NEXT      T,HOLD;
        A,REG B,B                               ALUD,NONE
        IDBS,REG            COMM,AWRITE,NEXT    T,JMP       T,HOLD
        CONT;




%***********************************************
%***********************************************

% LOAD REGISTER BLOCK

%***********************************************

LRB2:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PVCHK;

        B,7                                     ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,JMP       T,PUSH
        RBLOK;

        A,P B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;
        A,REG B,P                               ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,JMP       T,PUSH
        LRB3;
        A,REG B,X                               ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,JMP       T,PUSH
        LRB3;
        A,REG B,T                               ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,JMP       T,PUSH
        LRB3;
        A,REG B,A                               ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,JMP       T,PUSH
        LRB3;
        A,REG B,D                               ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,JMP       T,PUSH
        LRB3;
        A,REG B,L                               ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,JMP       T,PUSH
        LRB3;
        A,REG B,Z                               ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,JMP       T,PUSH
        LRB3;

        A,REG B,B           ALUF,PASSQ          ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,POP;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        CONT CONDENABL;


%****************************************
% OWN LEVEL. UNSAVE REGISTER BLOCK

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,LC=0;

        A,PIL B,LC          ALUF,PASSD          ALUD,B
        IDBS,REG                                T,NEXT      T,POP
                                                            LCOUNT;

        A,R2 B,P            ALUF,PASSA          ALUD,B  % P IS UNCHANGED
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,Z                 ALUF,PASSA          ALUD,NONE   STS,LO  % CHANGE STS
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;


LRB3:                                           ALUD,NONE
        IDBS,ALU            COMM,AREAD,NEXT     T,RETURN    T,POP;








%******************************************
%******************************************

% INTER-REGISTER READ

%******************************************


IRR3:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PVCHK;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        IRR;

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;



IRR:    B,Z                 ALUF,PASSD          ALUD,B
        IDBS,STS                                T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,GPR                                T,JMP       T,PUSH
        IRWRD;

        A,REG B,Z           ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        IRR1 CONDENABL;

%*******************************
% OWN LEVEL


        A,Z B,Z             ALUF,ANDDA          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

        B,DEST              ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        IRR2;


%*******************************
% OTHER LEVEL

IRR1:                       ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

        A,REG B,Z           ALUF,PASSQ          ALUD,NONE
                            COMM,EWRF           T,NEXT      T,HOLD;

        A,REG B,DEST        ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

IRR2:   B,A                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,RETURN    T,HOLD;













%************************************
%************************************

% INTER REGISTER WRITE

%************************************
IRW3:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PVCHK;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        IRW;

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


IRW:    A,P B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,GPR                                T,JMP       T,PUSH
        IRWRD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        IRW1 CONDENABL;


%************************************
% OWN LEVEL

        A,A B,DEST          ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        IRW2;

        A,R2 B,P            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        CONDENABL;


%********************************
% STS MUST BE LOADED

        A,Z                 ALUF,PASSA          ALUD,NONE   STS,LO
        IDBS,ALU                                T,RETURN    T,HOLD;



%********************************
% OTHER LEVEL

IRW1:   A,A                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,REG B,DEST        ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,PUSH
        IRW2;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        377 CONDENABL;


%********************************
% STS MUST BE LOADED

        A,REG B,Z           ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,RETURN    T,HOLD;


%********************************
% SUBROUTINE TO CHECK FOR STS AS DESTINATION

IRW2:   B,DEST              ALUF,PASSD          ALUD,NONE
        IDBS,BARG                               T,RETURN    T,POP
 COND,F=0                                       F,RETURN    F,HOLD;







%****************************************
%****************************************

% REGISTER DIVIDE

%****************************************

RDIV6:  A,SRCE B,R1         ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;
        A,A B,R5            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        RDIV1 CONDENABL;


        B,R1                ALUF,-B             ALUD,B  % NEGATIVE DIVISOR
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,COND                                      F,JMP       F,HOLD;

RDIV1:  A,SRCE B,A          ALUF,XORAB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
        RDIV2 CONDENABL;

        B,D                 ALUF,-B             ALUD,B      STS,EA  % NEGATIVE
        IDBS,ALU                                T,NEXT      T,HOLD;  % DIVIDEND

        B,A                 ALUF,-B-1           ALUD,B      CRY,C
        IDBS,ALU                                T,NEXT      T,HOLD;

RDIV2:  A,R1 B,A            ALUF,B-A            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,CRY                                       F,NEXT      F,HOLD;

        B,R7                ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        RDIVZ CONDENABL;

        B,D                 ALUF,PASSB          ALUD,Q
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        16;
                            ALUF,PASSD          ALUD,B
        B,STS                                   T,NEXT      T,HOLD
        IDBS,STS;
                            ALUF,PASSD          ALUD,NONE   STS,LO
        A,7                 COMM,LDGPR          T,NEXT      T,HOLD
        IDBS,BMG;

        A,0 B,A             ALUF,PASSB          ALUD,SLD    MIS,ZIN STS,ES
        IDBS,AARG           COMM,LDGPR          T,NEXT      T,PUSH
 COND,LC=0;


%************************
% DIVIDE LOOP

        A,R1 B,A            ALUF,B-A-1          ALUD,SLD    MIS,ZIN ALUM,FDV STS,ES CRY,GPR
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

                            ALUF,PASSD          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,A B,D             ALUF,PASSA          ALUD,SRB    MIS,LIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,1                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,STS               ALUF,PASSA          ALUD,NONE   STS,LO
        IDBS,ALU                                T,NEXT      T,HOLD
        RDIV3 CONDENABL;

        A,R1 B,D            ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSA          ALUD,NONE
RDIV3:  A,R7                                    T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;
                            ALUF,PASSA          ALUD,NONE
        A,R5                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        RDIV4 CONDENABL;


%*******************************
% CHANGE QUOTIENT SIGN


        IDBS,ALU            ALUF,-Q             ALUD,Q
 COND,COND                                      T,NEXT      T,HOLD;

RDIV4:  B,A                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        RDIV5 CONDENABL;


%*******************************
% CHANGE REMAINDER SIGN

        B,D                 ALUF,-B             ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

RDIV5:  A,A B,R7            ALUF,XORAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,POP;

        IDBS,ALU                                ALUD,NONE
        CONT CONDENABL;                         T,NEXT      T,HOLD




%*******************************
% OVERFLOW (OR ERROR IN EXR, DNZ ETC.)

RDIVZ:  B,10                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

        B,STS               ALUF,ORDQ           ALUD,B
        IDBS,STS                                T,NEXT      T,HOLD;
        A,STS               ALUF,PASSA          ALUD,NONE   STS,LO
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;










%****************************************
%****************************************

% EXECUTE REGISTER

%****************************************

EXR1:   A,SRCE              ALUF,XORDA          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                            ALUF,ANDDQ          ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        177700;

        A,SRCE              ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,CLIRQ          T,JMP       T,HOLD
        RDIVZ CONDENABL;


%****************************************
% OK, NOT EXR(EXR)

        A,SRCE              ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,MAP            T,JMP       T,HOLD;











%******************************************
%******************************************

% MIXJ-INSTRUCTION

%******************************************

MIX4:   A,X B,X             ALUF,D+A            ALUD,B
        IDBS,GPR            COMM,CONTINUE       T,JMP       T,HOLD;













%******************************************
%******************************************


% IOX-INSTRUCTION

%******************************************


IOX1:   B,R1                ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,JMP       T,PUSH
        PVCHK;

                                                ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,JMP       T,PUSH
        IOXG;

                                                ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;







%***********************************************
%***********************************************

% IOXT - INSTRUCION

%***********************************************

IOXT2:  A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,LDIRV          T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        IOXX1;

                                                ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;








%***********************************************
%***********************************************

% SUBROUTINE USED BY IOX OR MICROPROGRAMMED LOADERS
% TO ISSUE IOXINSTRUCTIONS ON SYSTEM BUS

%***********************************************
% IOX-ROUTINE FOR 11-BIT IOX-ADDRESS

IOXG:                       ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        3777;

        A,R1 B,R1           ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;


%***********************************************
% IOX-ROUTINE FOR 16-BIT IOX ADDRESS

IOXX1:  A,R1 B,7            ALUF,MASKDA         ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

%***********************************************
% CHECK IF DEVICE NUMBERS 30X IS ON THE CPU-BOARD

                            ALUF,XORDQ          ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        300;

        A,R1 B,3            ALUF,MASKDA         ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        TERMX CONDENABL;


%***********************************************
% CHECK IF DEVICE IS IN THE RANGE 10-13

        B,10                ALUF,XORDQ          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        CLKX CONDENABL;


%****************************************
% DEVICE IS NOT ON CPU-BOARD. ISSUE GENERAL IOX

        A,R1                ALUF,PASSA          ALUD,NONE  % ADDRESS -> IOX
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE  % OUTPUT DATA
        IDBS,ALU            COMM,IOX            T,NEXT      T,HOLD;

        B,A                 ALUF,PASSD          ALUD,B  % INPUT DATA
        IDBS,DBR            COMM,SLOW           T,RETURN    T,POP;

%CC SLOW CYCLE TO LET MEGALINK GET TIME TO TURN OFF DATA OUT ENABLE
%CC BEFORE THE NEXT CPU FETCH.


%****************************************
% DEV.NO. 30X IS ON CPU BOARD, JUMP TO VECTOR

TERMX:  AB,STATUS           ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP0-3    T,HOLD
        TRMVC;



%****************************************
% DEV.NO. IS 10-13, JUMP TO VECTOR

CLKX:   AB,STATUS           ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP0-3    T,HOLD
        CLKVC;





%***********************************************
% SUBROUTINE TO WRITE STATUS-SCRATCH WORD. AND TO WRITE SIOC-REGISTER

WSIOC:  AB,STATUS           ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

WSIO2:                      ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,SIOC           T,RETURN    T,POP;







%***********************************************
% ROUTINES FOR CPU-TERMINAL, ENTERED FROM VECTOR


%***********************************************
% IOX 300 READ CONSOLE DATA


TRM0:                                           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F11                                       F,RETURN    F,POP;

        IDBS,ALU                                ALUD,NONE
        CONDENABL                               T,NEXT      T,HOLD;

%CC RETURN IF IN OPCOM

                            ALUF,PASSD          ALUD,Q
        IDBS,UART           COMM,UART,DATA      T,NEXT      T,HOLD;

%CC READ UART DATA

        B,A                 ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,RETURN    T,POP
        377;

%CC MASK OFF THE CRAP AND PUT CHARACTER IN A-REGISTER

%***************************************
% IOX 302 READ CONSOLE INPUT STATUS
%CC UART STATUS REG IN (P-REG). FE=BIT5,PE=BIT3,OR=BIT4.
%CC MACRO STATUS WORD UPON EXIT:
%CC PIN=BIT0,DA=BIT3,ERR=BIT4,FE=BIT5,PE=BIT6,OR=BIT7.
%CC OTHER BITS 0.

TRM2:   A,7                 ALUF,ANDDQ          ALUD,Q
        IDBS,AARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

%CC MASK OFF EVERYTHING BUT BIT3-5. JUMP IF NO ERRORS.

        A,3 B,R4            ALUF,ANDDQ          ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        TRM20 CONDENABL;

%CC PE,OR -> R4.

        A,2                 ALUF,ORDQ           ALUD,Q
        IDBS,AARG                               T,NEXT      T,HOLD;

%CC SET INCLUSIVE OR OF ERRORS (ERR=BIT4).

        B,1                                     ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD
 COND,LC=0;

%CC SET UP FOR LOOP 3 TIMES

        A,6                 ALUF,ANDDQ          ALUD,Q
        IDBS,AARG                               T,NEXT      T,PUSH;

%CC MASK EVERYTHING BUT FE AND ERR.

        B,R4                ALUF,PASSB          ALUD,SLB    MIS,ZIN ALUM,MIC
                                                            LCOUNT
        IDBS,ALU                                T,NEXT      T,POP;

%CC PE=BIT3 -> 6 OR=BIT4 -> 7

TRM20:  A,R4 B,A            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

%CC BIT 4-7 OK

                            ALUF,PASSD          ALUD,Q
        IDBS,IOR                                T,NEXT      T,HOLD;

%CC SAME AS RASK FROM HERE, EXCEPT DA INVERTED.

        A,16                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,13                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
        TRM21 CONDENABL;

        AB,STATUS           ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        TRM20B CONDENABL;

        IDBS,ALU            ALUF,PASSQ          ALUD,NONE
                                                T,JMP       T,HOLD
        TRM21;

TRM20B: A,3 B,R6            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R6 B,A            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

TRM21:  A,1                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,0 B,R6            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,RETURN    T,POP
        CONDENABL;

TRM22:  A,R6 B,A            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;



%***********************************************
%IOX 303 WRITE CONSOLE INPUT CONTROL
%CC MACRO STATUS WORD UPON ENTRY:
%CC PIN=BIT0,WORD LENGTH =BIT12,11,STOP BITS=BIT13,CHECK PARITY=BIT14
%CC WORD LENGTH 5 => 1 1 0=>1.5 STOP BITS
%CC WORD LENGTH 6 => 1 0 0=>2 STOP BITS
%CC WORD LENGTH 7 => 0 1 0=>2 STOP BITS
%CC WORD LENGTH 8 => 0 0 0=>2 STOP BITS
%CC PARITY IS EVEN
%CC OTHER BITS 0.
%CC UART MODE REG 1: CHECK PARITY=BIT4,WORD LENGTH=BIT2,3 INVERTED
%CC STOP BITS=BIT7,6. 01=1 STOP BIT,10=1.5 STOP BITS, 11=2 STOP BITS.
%CC BIT0=0,BIT1=1,BIT5=1 ALWAYS. (EVEN PARITY,ASYNC. 16XBAUD RATE FACT.)

TRM3:   IDBS,ALU                                ALUD,NONE
 COND,F=0                                       F,NEXT      F,HOLD
                                                T,NEXT      T,HOLD;

                            ALUF,ANDDQ          ALUD,NONE
        IDBS,ARG 074000                         T,NEXT      T,HOLD;

%CC JUMP IF NO UART CONTROL BITS CHANGED

        A,A B,R2            ALUF,INVA           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        TRM34 CONDENABL;

        B,R7                ALUF,PASSD          ALUD,SRB    MIS,ZIN
        IDBS,SWAP                               T,NEXT      T,HOLD;
%
%CC R7=XXPSWWXX

        B,R6                ALUF,INVD           ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        14;

        IDBS,ALU                                ALUD,NONE
 COND,F=0                                       F,JMP       F,HOLD
                                                T,NEXT      T,HOLD;

%CC R6=11110011

        A,R6 B,R7           ALUF,ORAB           ALUD,B
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

%CC R7=1111WW11, 0100000000000000 -> GPR

        B,R7                ALUF,ANDDA          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        177776;

%CC R7=1111WW10 (TOP 4 BITS OF ARG WILL MAKE A-OP = R7)

        A,A                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR            COMM,UART,COM       T,NEXT      T,HOLD;

%CC TEST CHECK PARITY BIT. DISABLE RECEIVE AND TRANSMIT.

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        TRM31 CONDENABL;

%CC JUMP IF PARITY CHECK ENABLED

        B,R7                ALUF,ANDDA          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        177757;

%CC R7=111PWW10 (TOP 4 BITS OF ARG WILL MAKE A-OP = R7)

TRM31:  A,15                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG            COMM,XSLOW          T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

%CC 425NS DELAY. TEST STOP BITS.

        AB,OLD303           ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        TRM32 CONDENABL;

%CC A-REG -> OLD303. JUMP IF 2 OR 1.5 STOP BITS.

        B,R7                ALUF,ANDDA          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        177577;

%CC R7=S11PWW10 (TOP 4 BITS OF ARG WILL MAKE A-OP = R7)

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        TRM33;

TRM32:  A,R6 B,R7           ALUF,MASKAB         ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

%CC TEST FOR 5 DATA BITS

        IDBS,ALU                                ALUD,NONE
        TRM33 CONDENABL                         T,NEXT      T,HOLD;

%CC JUMP IF 2 STOP BITS

        B,R7                ALUF,ANDDA          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        177677;

%CC R7=SS1PWH10 (TOP 4 BITS OF ARG WILL MAKE A-OP = R7)


TRM33:  A,R7                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,UART,MODE      T,JMP       T,PUSH
        BAUDS;

%CC R7 -> UART MODE 1 REGISTER
%CC SAME AS RASK FROM HERE

TRM34:  AB,STATUS           ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,R2 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R2 B,R2           ALUF,ORDA           ALUD,B
        IDBS,BARG                               T,JMP       T,HOLD
        TRM35 CONDENABL;

        A,R2 B,R2           ALUF,MASKDA         ALUD,B
        IDBS,BARG                               T,NEXT      T,HOLD;

TRM35:  B,R3                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        74002;

        A,R3 B,R2           ALUF,ANDAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;


        IDBS,ARG            ALUF,ANDDQ          ALUD,Q
        175;                                    T,NEXT      T,HOLD

        A,R2                ALUF,ORAQ           ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        WSIOC;


%*******************************
% IOX 306 READ CONSOLE OUTPUT STATUS
%CC SIOC BIT 2 -> BIT0= INTERRUPT AT READY FOR TRANSFER
%CC TBMT -> BIT3= TRANSMIT BUFFER EMPTY

TRM6:                       ALUF,PASSD          ALUD,NONE
        IDBS,IOR                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

%CC TBMT INVERSE POLARITY. NO OTHER CHANGES.

        AB,STATUS           ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        TRM61 CONDENABL;

        A,3 B,A             ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

TRM61:  A,2                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;


        A,0 B,R6            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,RETURN    T,POP
        TRM22 CONDENABL;


%****************************************
% I0X J07 WRITE CONSOLE OUTPUT CONTROL
%CC BIT0- INTERRUPT AT READY FOR TRANSFER -> SIOC BIT 2
%CC SAME AS RASK

TRM7:   A,A B,1             ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,2                 ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD
        WSIOC CONDENABL;

        B,4                 ALUF,MASKDQ         ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        WSIOC;








%********************************************
% ROUTINES FOR DEVICE NUMBERS 10-13, ENTERED FROM VECTOR
%********************************************


% IOX 11

CLK1:                       ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,SIOC           T,NEXT      T,HOLD;

        A,7                 ALUF,MASKDQ         ALUD,Q
        IDBS,BMG            COMM,CLRTC          T,JMP       T,HOLD
        WSIO2;


%********************************************
% IOX 13

CLK3:   A,A B,1             ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,15 B,R2           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        CLK31 CONDENABL;

        B,1                 ALUF,MASKDQ         ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

CLK31:  A,A B,R2            ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        WSIOC CONDENABL;

        B,10                ALUF,MASKDQ         ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        WSIOC;














%****************************************
%****************************************

% MASKED CLEAR INSTRUCTION

%****************************************


MCL1:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PVCHK;
                            ALUF,PASSD          ALUD,Q

        IDBS,GPR                                T,JMP       T,PUSH
        MCMS1;

        B,6                 ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        MCSTS CONDENABL;

        B,7                 ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        MCPID CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MCPIE CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;

% MASKED SET INSTRUCTION

MST1:                                           ALUD,NONE
                                                T,JMP       T,PUSH
        PVCHK;

                            ALUF,PASSD          ALUD,Q
        IDBS,GPR                                T,JMP       T,PUSH
        620                                     F,NEXT      F,POP;
        B,T                 ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        MPID CONDENABL                          F,RETURN    F,POP;
        B,7                 ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        MPID CONDENABL                          F,RETURN    F,PUSH;
                            ALUF,A+Q            ALUD,NONE
                                                T,JMP       T,HOLD
        MPID CONDENABL                          F,NEXT      F,POP;
                            ALUF,A+Q            ALUD,NONE
                                                T,JMP       T,HOLD
        SUB1                                    F,NEXT F,RETURN F,LOAD;



%***********************************************
% SUBROUTINE FOR MCL & MST INSTRUCTIONS

MCMS1:  B,17                ALUF,ANDDQ          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,1                 ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,RETURN    T,POP;



%***********************************************
% SUBROUTINE FOR MCL

MCLEA:  A,A                 ALUF,MASKAQ         ALUD,Q
        IDBS,ALU                                T,RETURN    T,POP;




%***********************************************
% SUBROUTINE FOR MST

MSET:   A,A                 ALUF,ORAQ           ALUD,Q
        IDBS,ALU                                T,RETURN    T,POP;



%***********************************************
% MCL STS

MCSTS:                      ALUF,PASSD          ALUD,Q
        IDBS,STS                                T,NEXT      T,HOLD;

        A,A                 ALUF,MASKAQ         ALUD,NONE   STS,LO
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;


%***********************************************
% MCL PID

MCPID:  AB,PID              ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,PUSH
        MCLEA;

MPID:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        TRPID;

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;



%***********************************************
% MCL PIE

MCPIE:  AB,PIE              ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,PUSH
        MCLEA;

MPIE:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        TRPIE;

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


%***********************************************
% MST STS

MSSTS:  A,A                 ALUF,ORDA           ALUD,Q
        IDBS,STS                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE   STS,LO
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;


%***********************************************
% MST PID

MSPID:  AB,PID              ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,PUSH
        MSET;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MPID;


%***********************************************
% MST PIE

MSPIE:  AB,PIE              ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,PUSH
        MSET;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MPIE;








%***********************************************
%***********************************************

% MONITOR CALL INSTRUCTION

%***********************************************

MON1:   A,16 B,T                                ALUD,NONE
        IDBS,GPR,SEXT       COMM,EWRF           T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;






%***********************************************
%***********************************************

% IOT - INSTRUCTION IS PRIVILEGED WHEN RING = 0 OR 1
% AND ILLEGAL WHEN RING = 2 OR 3

IOT1:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PVCHK;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;




%***********************************************
%***********************************************

% PIONF (1504XX) - GROUP OF INSTRUCTIONS

%***********************************************

PINF1:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PVCHK;

                            ALUF,PASSD          ALUD,Q
        IDBS,STS                                T,JMP0-3    T,HOLD
        VECT1;  % VECTORIZED JUMP



%***********************************************

% DIFFERENT PIONF-ROUTINES, ENTERED FROM VECTOR

%***********************************************
% IOF

IOF2:   PIC,IOF                                 ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,NEXT      T,HOLD;


%***********************************************
% POF

POF2:                       ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDPIL          T,JMP       T,HOLD
        TRAX;

%***********************************************
% ION

ION2:                       ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDPIL          T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        PIC,ION                                 ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,JMP       T,PUSH
        CHKIT;

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


%***********************************************
% EXAM - INSTRUCTION

EXAM2:  A,D                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        B,T                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;



%***********************************************
% DEPO - INSTRUCTION

DEPO2:  A,D                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;


%***********************************************
% SUBROUTINE USED BY PHYSICAL MEMORY HANDLING INSTRUCTIONS TO OUTPUT
% SEGMENT NUMBER.

EXPHY:  A,R7                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,RETURN    T,POP;








%***********************************************
%***********************************************

% TRA-INSTRUCTION (1500XX)

%***********************************************

TRA1:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PVCHK;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        TRA;

TRAX:                                           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

%CC DUMMY INSTRUCTION TO MAKE DVACC GO OFF IN TIME

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;

TRA:                                            ALUD,NONE
        IDBS,ALU                                T,JMP0-3    T,HOLD
        VECT2;  % VECTORIZED JUMP



%***********************************************

% TRA-ROUTINES, ENTERED FROM VECTOR

%***********************************************
% TRA PID


APID1:  PIC,RSTS B,R5       ALUF,PASSD          ALUD,B
        IDBS,PIC            COMM,EPIC           T,NEXT      T,HOLD
 COND,IRQ                                       F,JMP       F,HOLD;

        PIC,LOSTS B,10      ALUF,ZERO           ALUD,Q
        IDBS,BARG           COMM,EPIC           T,NEXT      T,HOLD;

        PIC,ION B,R6        ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,EPIC           T,NEXT      T,HOLD;

        PIC,LMSK B,R6       ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,NEXT      T,HOLD;

        AB,IIE              ALUF,PASSD          ALUD,B
        IDBS,REG            COMM,CLIRQ          T,NEXT      T,HOLD;

        A,17                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD
        APID2 CONDENABL;

        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

APID2:  B,5                                     ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD;

        A,4 B,R3            ALUF,INVD           ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        PIC,LMSK B,R2       ALUF,INVB           ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,JMP       T,PUSH
        APID3;



        PIC,LMSK B,R3       ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,NEXT      T,HOLD
        APID3 CONDENABL;

                            ALUF,ORDQ           ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

APID3:  PIC,LOSTS B,10                          ALUD,NONE
        IDBS,BARG           COMM,EPIC           T,NEXT      T,HOLD
 COND,LC=0;

        B,R3                ALUF,PASSB          ALUD,SRB    ALUM,FMU
        IDBS,ALU            COMM,CLIRQ          T,NEXT      T,POP
                                                            LCOUNT
                                                F,JMP       F,HOLD COND,IRQ;


        AB,PID              ALUF,ORDQ           ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        PIC,LOSTS B,R5      ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,NONE
        IDBS,STS                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        PIC,LMSK B,R1       ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,JMP       T,HOLD
        APIE1 CONDENABL;

APID4:  PIC,IOF                                 ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,JMP       T,HOLD
        APIE1;




%***********************************************
% TRA IIC

AIIC1:  PIC,RMSK B,R6       ALUF,PASSD          ALUD,B
        IDBS,DSABL          COMM,EPIC           T,NEXT      T,HOLD;

        AB,IIE              ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        37760;

        PIC,LMSK            ALUF,INVQ           ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        25;

        PIC,ION B,13        ALUF,PASSD          ALUD,B
        IDBS,BARG           COMM,EPIC           T,NEXT      T,PUSH
 COND,F=0                                       F,NEXT      F,HOLD;



        PIC,LOSTS           ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,JMP       T,POP
        AIIC3 CONDENABL;

        A,R3                ALUF,A-Q            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,HOLD;

                            ALUF,Q-1            ALUD,Q
        IDBS,ALU            COMM,CLIRQ          T,NEXT      T,POP
        CONDENABL COND,IRQ                      F,NEXT      F,HOLD;




                            ALUF,ZERO           ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        AIIC2;

AIIC3:                      ALUF,Q-D            ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        12;

        A,16                                    ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

AIIC2:  PIC,LOSTS B,R5      ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,JMP       T,PUSH
        CLR14;

                            ALUF,PASSD          ALUD,NONE
        IDBS,STS                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        PIC,LMSK B,R6       ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,NEXT      T,HOLD
        APID4 CONDENABL;




%***********************************************
% TRA PIE

APIE1:  B,A                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,RETURN    T,HOLD;

%***********************************************
% TRA CS

ACS:    A,X                 ALUF,ANDAQ          ALUD,NONE
        IDBS,ALU            COMM,ADCS           T,NEXT      T,HOLD;

        B,A                 ALUF,PASSD          ALUD,B
        IDBS,RCS            COMM,RWCS           T,RETURN    T,HOLD;


%***********************************************
% TRA PVL

APVL1:  B,A                 ALUF,ORDQ           ALUD,B
        IDBS,ARG                                T,RETURN    T,HOLD
        153602;


%***********************************************
% TRA ALD

AALD1:                                          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,LC                                    ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;
        A,LC                                    ALUD,NONE
        IDBS,ALU                                T,JMPAOPR   T,PUSH
        ALDVC;
        B,A                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,RETURN    T,HOLD;


%***********************************************
%CCR TRA PES. NEED TO CLEAR DOWN PARERR INTERUPT FROM
%CC THE ON-BOARD MEMORY.

APES1:  PIC,MCLPID IDBS,ARG COMM,EPIC
        4000                                    T,RETURN    T,HOLD;

%***************************************
% TRA PGC (PAGING CONTROL REG.)

APGC1:  B,R6                ALUF,PASSD          ALUD,B
        IDBS,STS                                T,JMP       T,PUSH
        PLPCR;

        A,PIL B,0           ALUF,PASSD          ALUD,Q      XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        B,A                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;



%***************************************
% SUBROUTINE FOR TRA PGC AND TRR PCR

PLPC2:  A,R6                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDPIL          T,RETURN    T,HOLD;


%***************************************
% TRR PCR

RPCR1:
        B,R6                ALUF,PASSD          ALUD,B
        IDBS,STS                                T,JMP       T,PUSH
        PLPCR;

        A,PIL B,0           ALUF,PASSQ          ALUD,B      XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;


        A,R6 B,R5           ALUF,XORAB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                            ALUF,ANDDQ          ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        7400;


        IDBS,ALU                                ALUD,NONE
        PLPC2 CONDENABL;                        T,NEXT      T,HOLD

% TRR PCR IS EXECUTED ON OWN LEVEL. UPDATE HARDWARE PCR

        A,0                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDPCR          T,JMP       T,HOLD
        PLPC2;



%***********************************************
% SUBROUTINE FOR TRR PCR AND TRA PGC

PLPCR:  B,2                                     ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD;

        A,A B,R5            ALUF,PASSA          ALUD,SLB
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,LC=0;

        B,R5                ALUF,PASSB          ALUD,SLB
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        A,R5                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDPIL          T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP;  % PAUSE FOR PIL TO BE VALID


%***********************************************
% TRA PGS


APGS1:  B,A                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,2                 ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,PIL B,Z           ALUF,ANDDQ          ALUD,NONE   XRF  % TEST BIT 2
        IDBS,REG                                T,NEXT      T,HOLD  % IN PCR
 COND,F=0                                       F,NEXT      F,HOLD;

        A,A                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,RETURN    T,HOLD
        CONDENABL;

        B,A                 ALUF,XORDQ          ALUD,B  % 16 PT MODUS
        IDBS,ARG                                T,RETURN    T,HOLD  % INVERT 2 BITS
        1400;




%****************************************
%****************************************

% TRR INSTRUCTIONS (1501XX)

%****************************************
TRR1:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PVCHK;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        TRR;

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;

TRR:    B,A                 ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,JMP0-3    T,HOLD
        VECT3;  % VECTORIZED JUMP




%********************************************

% TRR ROUTINES, ENTERED FROM VECTOR

%********************************************
% TRR IIE

RIIE1:                      ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        7774;

        B,R1                ALUF,ORDQ           ALUD,SLB
        IDBS,ARG                                T,NEXT      T,HOLD
        10000;

        PIC,RMSK B,R2       ALUF,INVD           ALUD,B
        IDBS,DSABL          COMM,EPIC           T,NEXT      T,HOLD;

        AB,PIE              ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,16                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R1 B,R1           ALUF,A+B            ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        NOTI2 CONDENABL;

        B,R6                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        100017;

        A,R6 B,R2           ALUF,ANDAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R2 B,R2           ALUF,ORAQ           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;
        PIC,LMSK B,R2       ALUF,INVB           ALUD,NONE
        PIC,LMSK B,R2       ALUF,INVB           ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,NEXT      T,HOLD;


NOTI2:  AB,IIE              ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,RETURN    T,HOLD;




%*******************************
% TRR PIE

RPIE1:                      ALUF,PASSD          ALUD,Q
        IDBS,SWAP                               T,JMP       T,PUSH
        PICFM;

        A,Z B,STS           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R1                ALUF,ANDDA          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        100017;

        A,STS               ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,IIE              ALUF,ANDDQ          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,R1 B,R1           ALUF,ORAQ           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        PIC,LMSK B,R1       ALUF,INVB           ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,JMP       T,HOLD
        CHKIT;





%*******************************
% TRR PID

RPID1:                      ALUF,PASSD          ALUD,Q
        IDBS,SWAP                               T,JMP       T,PUSH
        PICFM;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        140017;

        A,Z B,R1            ALUF,MASKAQ         ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        CLRXX;

        A,Z                 ALUF,ANDAQ          ALUD,NONE
        IDBS,ALU            COMM,SMPID          T,JMP       T,HOLD
        CHKIT;



%*******************************
% TRR LMP

RLMP1:  AB,LMP              ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,RETURN    T,HOLD;





%*******************************
% TRR CCLR (CACHE CLEAR)

RCCL1:                      ALUF,ANDDQ          ALUD,NONE
        IDBS,CSR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        RCCL1 CONDENABL;

                                                ALUD,NONE
        IDBS,ALU            COMM,CCLR           T,RETURN    T,HOLD;

%****************************************
% TRR CS

RCS:    A,X                 ALUF,ORAQ           ALUD,NONE
        IDBS,ALU            COMM,ADCS           T,NEXT      T,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,RWCS           T,RETURN    T,HOLD;




%****************************************
% TRR ECCR, USES IOX - NUMBER 100115

RECC1:  B,R1                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        100115;

                                                ALUD,NONE
        IDBS,DBR            COMM,LDGPR          T,JMP       T,PUSH
        IOXX1;

                                                ALUD,NONE
        IDBS,ALU                                T,RETURN    T,HOLD;



%****************************************
% TRR PANC


RPANC:                                          ALUD,NONE
        IDBS,SWAP           COMM,LDPANC         T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,SWAP           COMM,LDPANC         T,RETURN    T,HOLD;


%***********************************************
% TRR CILU (CACHE INHIBIT LIMIT UPPER)

RCIU1:                      ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        37777;

        AB,UCIL             ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,LCIL             ALUF,PASSD          ALUD,B  % R3
        IDBS,REG                                T,JMP       T,HOLD
        CILI1;

%***********************************************
% TRR CILL (CACHE INHIBIT LIMIT LOWER)

RCIL1:                      ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        37777;

        AB,LCIL             ALUF,PASSQ          ALUD,B  % R3
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,UCIL             ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        CILI1;

CILI1:  A,R3                ALUF,Q-A            ALUD,NONE  % UPPER-LOWER
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,CRY                                       F,NEXT      F,HOLD;

        A,17 B,R1           ALUF,ZERO           ALUD,B
        IDBS,BMG            COMM,LDGPR          T,JMP       T,HOLD
        CILI3 CONDENABL;

CILI4:  A,16 B,R2           ALUF,D-1            ALUD,B  % 37777
        IDBS,BMG                                T,JMP       T,PUSH
        CILIL;  % NORMAL R1 -> 37777

                                                ALUD,NONE
        IDBS,ALU                                T,RETURN    T,HOLD;

CILI3:  A,R3 B,R2           ALUF,PASSA          ALUD,B  % CILL
        IDBS,ALU                                T,JMP       T,PUSH
        CILIL;  % NORMAL 0 -> CILL

        B,R2                ALUF,PASSQ          ALUD,B  % CILU
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,R3 B,R1           ALUF,PASSA          ALUD,B  % CILL
        IDBS,ALU                                T,JMP       T,PUSH
        CILIL;  % INHIBIT CILL -> CILU

                            ALUF,XORDQ          ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        37777;  % COND,F=0 F,JMP F,HOLD

        A,17 B,R1           ALUF,Q+1            ALUD,B  % CILU+1
        IDBS,BMG            COMM,LDGPR          T,RETURN    T,HOLD  % FINISHED
        CILI4 CONDENABL;

% SUBROUTINE TO FILL MAP AREA FROM R1 TO R2 WITH GPR-CONTENT.

CILIL:  A,R1 B,R6           ALUF,ORDA           ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R2 B,R7           ALUF,ORDA           ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

CILI2:  A,R6 B,R7           ALUF,XORAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,R6 B,R6           ALUF,B+1            ALUD,B,YA
        IDBS,ALU            COMM,WCIHM          T,RETURN    T,POP
        CILI2 CONDENABL;




%****************************************
%*****************************************

% WAIT INSTRUCTION

%****************************************

WAIT1:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PVCHK;

                            ALUF,PASSD          ALUD,NONE
        IDBS,STS                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,SWAP                               T,NEXT      T,HOLD
        STOPW CONDENABL;


%****************************************
% INTERRUPT IS ON

        B,17                ALUF,ANDDQ          ALUD,Q
        IDBS,BARG                               T,JMP       T,PUSH
        WAIT2;

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;

%****************************************
% REMOVE CURRENT PID-BIT

WAIT2:  B,R1                ALUF,PASSQ          ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        AB,PID              ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,LC                ALUF,MASKDQ         ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R1 B,16           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        AB,PID              ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        WT14 CONDENABL;


%****************************************
% NOT ON LEVEL 14
%****************************************
        A,R1 B,12           ALUF,A-D            ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,JMP       T,HOLD
        CHKIT CONDENABL;


%****************************************
% ON LEVEL 10-15 (EXCEPT 14)
%****************************************
        B,4                 ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,LC                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        W1013 CONDENABL;


%****************************************
% ON LEVEL 15
%****************************************
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

W1013:  PIC,MCLPID          ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,NEXT      T,HOLD;





%***********************************************
%***********************************************
% ROUTINE TO CHECK WHICH INTERRUPT LEVEL SHOULD BE ENTERED

%***********************************************
%***********************************************

CHKIT:                                          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        PIC,LOSTS B,10                          ALUD,NONE
        IDBS,BARG           COMM,EPIC           T,NEXT      T,HOLD
 COND,IRQ                                       F,NEXT      F,HOLD;

        AB,PID              ALUF,PASSD          ALUD,Q
        IDBS,REG            COMM,CLIRQ          T,NEXT      T,HOLD;


        IDBS,STS            ALUF,PASSD          ALUD,NONE
        CONDENABL COND,F15                      T,RETURN    T,HOLD  F,RETURN    F,HOLD;


%***********************************************
% NO HARDWARE INTERRUPT REQUEST IS PENDING

        AB,PIE              ALUF,ANDDQ          ALUD,SLB
        IDBS,REG                                T,NEXT      T,HOLD
        CONDENABL COND,F11;


%***********************************************
% CPU IS IN ION


        IDBS,ARG            ALUF,PASSD          ALUD,Q
        100013;             COMM,LDLC           T,NEXT      T,PUSH


%************************************
% LOOP TO FIND HIGHEST ENABLED LEVEL

        B,R3                ALUF,PASSB          ALUD,SLD    ALUM,MIC
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        B,LC                ALUF,PASSD          ALUD,Q  % NEW LEVEL -> Q
        IDBS,BARG                               T,JMP       T,HOLD
        PLINT;



%************************************
% THE WAIT-INSTRUCTION WAS ON LEVEL 14

WT14:                       ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        40000;

        PIC,MCLPID          ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,JMP       T,HOLD
        CHKIT;
















%************************************************************
% HARDWARE INTERRUPT HANDLING (EXT. OR INT. INTERRUPTS)
% ENTERED FROM INTERRUPT VECTOR (37+40-3757)
%************************************************************
% INTERNAL INTERRUPTS

%************************************************************


EXT14:  B,P                 ALUF,B-1            ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        27;

        A,16                                    ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,NEXT      T,HOLD;


%************************************************************
% ONLY LEVEL 15 IS HIGHER THAN STATUS 27

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        PIC,LOSTS                               ALUD,NONE
        IDBS,GPR            COMM,EPIC           T,JMP       T,PUSH
        PLINT;

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;



%************************************************************
% HARDWARE INTERRUPT EXCEPT LEVEL 14

XINT:   B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        PLINT;
        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


%****************************************
% LEVEL IN Q SHOULD BE ENTERED

PLINT:                      ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R6                ALUF,PASSD          ALUD,B
        IDBS,SWAP                               T,JMP       T,HOLD
        PLVO CONDENABL;


%****************************************
% NEW LEVEL IS NOT LEVEL 0, UPDATE PID

        A,LC                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

        AB,PID              ALUF,ORDQ           ALUD,B
        IDBS,REG                                T,NEXT      T,HOLD;

        AB,PID              ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

PLVO:   A,PIL               ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,LC                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,HOLD;

                            ALUF,ANDDQ          ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        140000 CONDENABL;


%****************************************
% NEW LEVEL IS UNEQUAL TO OLD LEVEL

        A,LC                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,COND                                      F,JMP       F,HOLD;

        A,PIL B,R5          ALUF,PASSD          ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD
        LVSWP CONDENABL;


%****************************************
% OLD LEVEL IS NOT 14 OR 15

        AB,PVL              ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;




%****************************************
% CHANGE LEVEL ROUTINE. Q = NEW LEVEL

LVSWP:  AB,ACTLV            ALUF,ORDQ           ALUD,B
        IDBS,REG                                T,NEXT      T,HOLD;



        IDBS,ARG                                ALUD,NONE
        7;                  COMM,LDLC           T,NEXT      T,HOLD

        B,Z                 ALUF,PASSD          ALUD,B
        IDBS,STS                                T,NEXT      T,PUSH
 COND,LC=0;

        A,PIL B,LC          ALUF,PASSB          ALUD,Q  % SAVE LOOP
        IDBS,ALU            COMM,EWRF           T,NEXT      T,POP
                                                            LCOUNT;


        B,Z                 ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        170000;

        A,Z B,R6            ALUF,ORAB           ALUD,NONE
        IDBS,ALU            COMM,LDPIL          T,NEXT      T,HOLD;
                                                ALUD,NONE
                                                ALUD,NONE
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        7;

        AB,ACTLV            ALUF,PASSB          ALUD,NONE
                            COMM,EWRF           T,NEXT      T,PUSH;

        A,PIL B,LC          ALUF,PASSD          ALUD,B  % UNSAVE LOOP
        IDBS,REG                                T,NEXT      T,POP
                                                            LCOUNT;

        A,PIL B,0                               ALUD,NONE   XRF
        IDBS,REG            COMM,LDPCR          T,NEXT      T,HOLD;

        A,Z                 ALUF,PASSA          ALUD,NONE   STS,LO
        IDBS,ALU                                T,RETURN    T,POP;









%********************************************
% SUBROUTINE TO CLEAR INTERNAL INTERUPTS

CLR14:  B,R1                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        37760;

CLRXX:  PIC,MCLPID B,R1     ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,RETURN    T,POP;










%********************************************************
% SUBROUTINE USED BY TRR PID AND TRR PIE TO TRANSLATE TO PIC-FORMAT

PICFM:  B,Z                 ALUF,ANDDQ          ALUD,SRB
        IDBS,ARG                                T,NEXT      T,HOLD
        74;
        A,7                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,6                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,JMP       T,HOLD
        PICF2 CONDENABL;

        A,0 B,Z             ALUF,ORDA           ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,COND                                      F,NEXT      F,HOLD;


PICF2:  B,Z                 ALUF,PASSB          ALUD,SRB    MIS,ROT
        IDBS,ALU                                T,RETURN    T,POP
        CONDENABL;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        77760;

        A,Z B,Z             ALUF,ORAQ           ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;










%************************************************************
% SUBROUTINE USED BY E-COMMAND & MACL TO SET OUT EXAMINE MODE
%
EXM02:
        AB,EXMOD            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,15                                    ALUD,NONE
        IDBS,BARG           COMM,LDPANC         T,RETURN    T,POP;







%************************************************************
%************************************************************
%
% PLANC ENTER- AND LEAVE- ROUTINES
%
%************************************************************
%
% 5INIT IN PLANC
%
5INIT:  A,P B,R1            ALUF,A+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R6                ALUF,PASSD          ALUD,B
        IDBS,ARG            COMM,RDRQ,PT        T,NEXT      T,HOLD
        176;

        A,B B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,DBR                                T,JMP       T,PUSH
        ENTRC;

        B,R1                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R5                ALUF,PASSD          ALUD,B
        IDBS,ARG            COMM,RDRQ,PT        T,NEXT      T,HOLD
        172;

        B,R7                ALUF,D+Q            ALUD,B
        IDBS,DBR                                T,JMP       T,PUSH
        ENTRB;

                            ALUF,PASSD          ALUD,Q
        IDBS,STS                                T,NEXT      T,HOLD;

        B,R1                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        IDBS,ALU                                ALUD,NONE ALUD,NONE
                            COMM,RDRQ,PT        T,NEXT      T,HOLD;

                            ALUF,XORDQ          ALUD,Q
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,0                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R1 B,P            ALUF,A+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        TSTAC CONDENABL;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,POP
        BCHNG;



%***********************************************

% 5ENTR IN PLANC


ENTR:   B,R6                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        176;

        A,B B,R6            ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,B B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,DBR                                T,JMP       T,PUSH
        ENTRC;

        A,R2 B,R4           ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R5                ALUF,PASSD          ALUD,B
        IDBS,ARG            COMM,RDRQ,APT       T,NEXT      T,HOLD
        172;

        B,R7                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,PUSH
        ENTRB;

TSTAC:  A,R7 B,R3           ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,CRY                                       F,JMP       F,POP;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        BCHNG CONDENABL;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,POP
        BCHNG;

ENTRC:                      ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,L                 ALUF,B+1            ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;

        A,7 B,STS           ALUF,D+Q            ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R6 B,R3           ALUF,A+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,P                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,PT        T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,DBR            COMM,LDGPR          T,NEXT      T,HOLD;

        A,STS B,R3          ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R2                ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;

        A,R6 B,R4           ALUF,A-1            ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;

ENTRB:  A,STS B,R4          ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R7                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;

        A,R5                ALUF,D-A            ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,STS B,R6          ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,STS B,R3          ALUF,A+Q            ALUD,B
        IDBS,ALU            COMM,WRRQ,APT       T,RETURN    T,POP;

%***********************************************

% 5LEAV AND ELEAV IN PLANC

ELEAV:                      ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        173;

        A,B                 ALUF,A-Q            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;

        A,7                 ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,B                 ALUF,A-Q            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;

        B,STS               ALUF,D-1            ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,STS               ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;

LEAV:   B,R1                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        177;

        A,B B,R1            ALUF,A-B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;

        B,STS               ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,R1                ALUF,A-1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;

        B,P                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,LDGPR          T,JMP       T,POP
        BCHNG;

BCHNG:  A,STS B,B           ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;








%***********************************************
%***********************************************
%
% SUBROUTINES FOR COMMERCIAL INSTRUCTIONS
%
%***********************************************
% SUBROUTINE TO REMEMBER IN R4 THE NUMBER OF WORDS TO FILL OR MOVE

LSET1:  A,R1 B,R4           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,RETURN    T,POP
 COND,F=0                                       F,JMP       F,PUSH;



%********************************************
% SUBROUTINE TO ADD TO X,T THE CONTENT OF R6, WHICH IS BYTE COUNT SHIFTED ROT 1

MBXS1:  A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R6 B,R4           ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,13                ALUF,D-1            ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R6 B,R6           ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R4 B,T            ALUF,A+B            ALUD,B      STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R6 B,X            ALUF,A+B            ALUD,B      CRY,C
        IDBS,ALU                                T,RETURN    T,POP;





%********************************************
% SUBROUTINE TO WRITE R10 INTO LOCATION [R3]

WRDST:  A,R7 B,T            ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;
        A,R3                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        WRDS2 CONDENABL;
        A,STS               ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;

WRDS3:                                          ALUD,NONE
        IDBS,ALU            COMM,CLIRQ          T,RETURN    T,POP
 COND,IRQ                                       F,NEXT      F,HOLD;

WRDS2:  A,STS               ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,PT        T,JMP       T,HOLD
        WRDS3;






%*******************************
% SUBROUTINE TO READ LOCATION [R3] INTO R10

RDDST:  A,R7 B,T            ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R3                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        RDDS2 CONDENABL;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;

RDDS3:  B,STS               ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,RETURN    T,POP;

RDDS2:                                          ALUD,NONE
        IDBS,ALU            COMM,RDRQ,PT        T,JMP       T,HOLD
        RDDS3;



%*******************************
% SUBROUTINES TO CHECK THAT LAST PAGE NEEDED BY MOVE IS IN MEMORY

PFSRC:  A,R5 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;
        A,D                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
        RDSRC CONDENABL;


        A,17                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD;


        IDBS,ALU                                ALUD,NONE
        RDSRC CONDENABL;                        T,NEXT      T,HOLD

        B,R2                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        RDSRC;


PFDST:  A,R5 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;
        A,T                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
        RDDST CONDENABL;

        A,17                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD;


        IDBS,ALU                                ALUD,NONE
        RDDST CONDENABL;                        T,NEXT      T,HOLD

        B,R3                ALUF,B-1            ALUD,B

        IDBS,ALU                                T,JMP       T,HOLD
        RDDST;





%********************************
% SUBROUTINE TO FILL LEFT BYTE OF (R3] WITH LEFT BYTE OF Q

BTL:    B,R2                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        RDDST;

        A,Z B,STS           ALUF,ANDAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,STS B,STS         ALUF,ORAQ           ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        WRDST;

        B,R3                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;


%********************************
% ADJUST R5 AND R6 FOR BTL AND BTR

BTX:    B,R5                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;




%********************************
% SUBROUTINE TO FILL RIGHT BYTE OF (R3] WITH RIGHT BYTE OF Q

BTR:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        RDDST;                                  T,JMP       T,PUSH
        A,Z B,STS           ALUF,MASKAB         ALUD,B
        A,Z B,STS           ALUF,MASKAB         ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,STS B,STS         ALUF,ORAQ           ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        WRDST;

        A,17 B,R3           ALUF,B+1            ALUD,B
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,T B,T             ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        B,X                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        BTX;














%************************************
%************************************
% BYTE FILL INSTRUCTION BFILL (140130)
%************************************



BFILL:  A,16 B,R7           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        7777;

        A,T B,R5            ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;

        A,X B,R3            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        BFIL2 CONDENABL;


%****************************************
% FINISHED, OR 0 BYTES TO MOVE

        A,R5 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;

        A,Z B,STS           ALUF,MASKAB         ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
        BTL CONDENABL;  % LAST BYTE NOT ON WORD BOUNDARY -> BTL

        AB,SSAVE                                ALUD,NONE
        IDBS,STS            COMM,EWRF           T,NEXT      T,HOLD;

        A,R5 B,R6           ALUF,PASSA          ALUD,SRB    MIS,ROT
        IDBS,ALU                                T,JMP       T,PUSH
        MBXS1;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        170000;

        A,T B,T             ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,SSAVE                                ALUD,NONE   STS,LO
        IDBS,REG                                T,NEXT      T,HOLD;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;






BFIL2:  B,Z                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

        A,Z B,A             ALUF,ANDAB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R2                ALUF,ORDQ           ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD
 COND,F15                                       F,RETURN    F,POP;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        BFIL3;

        A,R5 B,R1           ALUF,PASSA          ALUD,SRB    ALUM,MIC
        IDBS,ALU                                T,JMP       T,PUSH
        LSET1;


%****************************************

% LOOP TO STORE WORDS OF TWO BYTES EACH

BFLOO:  A,R2 B,STS          ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,RETURN    T,POP
        WRDST CONDENABL;

        B,R3                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        BFILQ CONDENABL;
        B,R1                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;

        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD

        BFLOO;




%*******************************
% INTERRUPT IS SENSED WHILE INSIDE LOOP

BFILQ:  A,R4 B,R1           ALUF,A-B            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,X B,X             ALUF,A+Q+1          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R1                ALUF,Q+1            ALUD,SLB
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        170000;

        A,T B,T             ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R5 B,R1           ALUF,A-B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R1 B,T            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;

















%************************************
% SUBROUTINE TO MOVE RIGHT BYTE OF (R2) TO LEFT BYTE OF (R3)

RBTL:
        IDBS,ALU                                ALUD,NONE
        RDSRC;                                  T,JMP       T,PUSH
        A,Z B,R4            ALUF,ANDDA          ALUD,B
                            COMM,LDGPR          T,NEXT      T,HOLD
        IDBS,SWAP;
                            ALUF,PASSD          ALUD,Q
                                                T,NEXT      T,HOLD
        IDBS,GPR;

        A,Z                 ALUF,MASKAQ         ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        BTL;




%************************************
% SUBROUTINE TO MOVE LEFT BYTE OF (R2) TO LEFT BYTE OF (R3)

LBTL1:  B,D                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

LBTL:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        RDSRC;

        A,Z B,STS           ALUF,MASKAB         ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        BTL;



%***********************************************
% SUBROUTINE TO MOVE LEFT BYTE OF [R2] TO RIGHT BYTE OF [R3]

LBTR:   B,D                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        RDSRC;

        A,Z                 ALUF,ANDDA          ALUD,Q
        IDBS,SWAP           COMM,LDGPR          T,NEXT      T,HOLD;

        B,R4                ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,Z B,R4            ALUF,MASKAB         ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        BTR;


%***********************************************
% SUBROUTINE TO MOVE RIGHT BYTE OF [R2] TO RIGHT BYTE OF [R3]


RBTR:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        RDSRC;

        A,Z B,STS           ALUF,ANDAB          ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        BTR;





%****************************************
%****************************************
%****************************************
% ZERO BYTES TO BE MOVED

%****************************************

MOVB9:  A,14                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,D                 ALUF,ANDAQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;


        IDBS,ALU                                ALUD,NONE
        MB52 CONDENABL;                         T,NEXT      T,HOLD

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MB21;










%****************************************
%****************************************

% MOVE BYTES INSTRUCTIONS

%********************************************

MOVB:   A,T                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,14 B,T            ALUF,MASKDQ         ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        MOVB3;





%********************************************
%********************************************

% MOVE BYTES FORWARDS INSTRUCTION

%********************************************


MOVBF:                      ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        10000;

        A,T B,T             ALUF,ORAQ           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;




%********************************************
% COMMON PARTS OF MOVB AND MOVBF
% SET UP INITIAL REGISTERS

MOVB3:                      ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        7777;

        A,D B,R5            ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,15 B,R1           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,T B,R1            ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,T B,R6            ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        MINTD CONDENABL;

        A,14 B,R2           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,T B,R2            ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;


        IDBS,ALU                                ALUD,NONE
        MOVB2 CONDENABL;                        T,JMP       T,HOLD

MINTD:  A,R5 B,R6           ALUF,B-A            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,14 B,R4           ALUF,INVQ           ALUD,B
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD
        MOVB5 CONDENABL;

        A,R6 B,R5           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;


MOVB5:  A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,R1 B,T            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        MOVB2 CONDENABL;

        A,R4 B,T            ALUF,ANDAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R5 B,T            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;


        A,R4 B,D            ALUF,ANDAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R5 B,D            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

MOVB2:  A,10 B,Z            ALUF,D-1            ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R5                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,16 B,R7           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        MOVB9 CONDENABL;  % ZERO BYTES TO MOVE


%****************************************
% ENSURE THAT NECESSARY PAGES ARE IN MEMORY
%****************************************
        B,R2                ALUF,ZERO           ALUD,SRB    ALUM,FMU
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A B,R2            ALUF,D+A            ALUD,B
        IDBS,GPR                                T,JMP       T,PUSH
        PFSRC;

        A,X B,R3            ALUF,D+A            ALUD,B
        IDBS,GPR                                T,JMP       T,PUSH
        PFDST;

        B,R2                ALUF,ZERO           ALUD,SRB    ALUM,FMU
        IDBS,ALU                                T,JMP       T,PUSH
        WRDST;

        A,A B,R2            ALUF,D+A            ALUD,B
        IDBS,GPR                                T,JMP       T,PUSH
        RDSRC;

        A,X B,R3            ALUF,D+A            ALUD,B
        IDBS,GPR                                T,JMP       T,PUSH
        RDDST;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        WRDST;

        A,A B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        RDSRC;

        A,X B,R3            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        RDDST;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        WRDST;


%*******************************
% SELECT WAY THROUGH MOVE

        A,D                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        MB1T4 CONDENABL;

MB5T8:  A,R5 B,R4           ALUF,A-1            ALUD,SRB    ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD
        MB5T6 CONDENABL;

        A,A B,X             ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,CRY                                       F,JMP       F,PUSH;

        A,17 B,R1           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        MB7T CONDENABL;


%*******************************
% FORWARD ALIGNED, FIRST BYTE RIGHT

MB8:    A,17 B,R1           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        RBTR;

        B,R2                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,A                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,D                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        TTDCR;

        A,R1 B,D            ALUF,MASKAB         ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        FWLOO;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MB21;


MB7T:   A,D B,T             ALUF,XORAB          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        TOLAP;

        A,R5 B,STS          ALUF,PASSA          ALUD,SRB
        IDBS,ALU                                T,NEXT      T,POP
        CONDENABL;


%*******************************
% BACKWARD ALIGNED, FIRST BYTE RIGHT

MB7:    A,STS B,R2          ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R5 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD;

        A,STS B,R3          ALUF,A+B            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LBTL1 CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        BWLOO;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        MBXBW;

        A,T B,R4            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        RBTR;

MB71:   B,X                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R4 B,T            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;

MB5T6:  A,A B,X             ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,CRY                                       F,JMP       F,PUSH;

        A,17 B,R1           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        MB5T CONDENABL;


%***************************************
% FORWARDS SWAP. FIRST BYTE RIGHT

MB6:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        FWEXL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MB41;


MB5T:   A,D B,T             ALUF,XORAB          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        TOLAP;

        A,R5 B,STS          ALUF,PASSA          ALUD,SRB
        IDBS,ALU                                T,NEXT      T,POP
        CONDENABL;


%***************************************
% BACKWARD SWAP. FIRST BYTE RIGHT

MB5:    A,STS B,R2          ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R5 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD;

        A,R4 B,R3           ALUF,A+B            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        MB51 CONDENABL;

        B,D                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        RBTL;

        A,R4                ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        BWEXQ;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MB52;

MB51:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        BWEXL;

MB52:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        MBXBW;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;


MB1T4:  A,R5 B,R4           ALUF,A-1            ALUD,SRB    ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD
        MB1T2 CONDENABL;

        A,A B,X             ALUF,B-A            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,CRY                                       F,NEXT      F,HOLD;

        A,17 B,R1           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        MB3T CONDENABL;


%*******************************
% FORWARD SWAP, FIRST BYTE LEFT

MB4:    A,R1 B,T            ALUF,MASKAB         ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LBTR;

        A,R1 B,D            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        TTDCR;

        A,R4                ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        FWEXQ;

MB41:   B,R1                ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        MBXFW;

        A,R5 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;

        A,R1                ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
        BTL CONDENABL;

        CONT B,P            ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD;


MB3T:   A,D B,T             ALUF,XORAB          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        TOLAP;

        A,R5 B,STS          ALUF,PASSA          ALUD,SRB
        IDBS,ALU                                T,NEXT      T,POP
        CONDENABL;


%*******************************
% BACKWARD SWAP, FIRST BYTE LEFT

MB3:    A,R4 B,R2           ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R5 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD;

        A,STS B,R3          ALUF,A+B            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        MB31 CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        BWEXL;

MB32:   B,R1                ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        MBXBW;

        A,T B,R4            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R1                ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        BTR;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        MB71;

MB31:   B,D                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        RBTL;

        A,R4                ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        BWEXQ;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MB32;

MB1T2:  A,A B,X             ALUF,B-A            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,CRY                                       F,NEXT      F,HOLD;

        A,17 B,R1           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        MB1T CONDENABL;


%*******************************
% FORWARD ALIGNED, FIRST BYTE LEFT

MB2:
        IDBS,ALU                                ALUD,NONE
        FWLOO;                                  T,JMP       T,PUSH

MB21:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        MBXFW;

        A,R5 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;


        IDBS,ALU                                ALUD,NONE
        LBTL CONDENABL;                         T,NEXT      T,HOLD

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;

MB1T:   A,D B,T             ALUF,XORAB          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        TOLAP;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,POP
        CONDENABL;                              T,NEXT      T,POP


%********************************
% BACKWARD ALIGNED. FIRST BYTE LEFT

MB1:    A,R4 B,R2           ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;

        A,R5 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD;

        A,R4 B,R3           ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        LBTL1 CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        BWLOO;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        MBXBW;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;








%********************************
% SUBROUTINE TO TEST ILLEGAL OVERLAP OF SOURCE AND DESTINATION

TOLAP:  A,16                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,POP;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        10000 CONDENABL;

        A,D                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD;

        AB,SSAVE            ALUF,ZERO           ALUD,Q
        IDBS,STS            COMM,EWRF           T,NEXT      T,HOLD
        CONDENABL;

        A,17 B,R5           ALUF,PASSB          ALUD,SRB    MIS,ROT
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,D                 ALUF,ANDDA          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R5                ALUF,A+Q            ALUD,Q      STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        3777;

        A,R5 B,R6           ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,A B,R6            ALUF,A+B            ALUD,B      CRY,C
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,SSAVE                                ALUD,NONE   STS,LO
        IDBS,REG                                T,JMP       T,PUSH
        OLAP1;


%**********************************************
% RETURN HERE MEANS NO OVERLAP

        B,R5                ALUF,PASSB          ALUD,SLB    MIS,ROT
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,1                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,RETURN    T,POP
 COND,F=0                                       F,RETURN    F,POP;




OLAP1:  A,X B,R6            ALUF,B-A            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,CRY                                       F,RETURN    F,POP;

        A,14 B,R6           ALUF,PASSB          ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD
        CONDENABL COND,F=0                      F,NEXT      F,HOLD;

        A,17                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,JMP       T,HOLD
        0XEQ6
        CONDENABL;




%****************************************
% OVERLAP EXISTS, ILLEGAL IF 'MOVBF'

OVLAP:  A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,POP
 COND,F=0                                       F,JMP       F,HOLD;

        A,14 B,R5           ALUF,PASSB          ALUD,SLB    MIS,ROT
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD
        MBERR CONDENABL;

        A,D B,D             ALUF,ORDA           ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

                            ALUF,ZERO           ALUD,Q
        IDBS,ALU                                T,RETURN    T,POP
 COND,F=0                                       F,RETURN    F,POP;





0XEQ6:  A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP
        CONDENABL COND,F15                      F,JMP       F,HOLD;


        IDBS,ALU                                ALUD,NONE
        OVLAP CONDENABL;                        T,RETURN    T,POP





%*******************************
% FORWARDS MOVE LOOP IS INTERRUPTED

IRQFW:  A,R4 B,R1           ALUF,A-B            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A B,A             ALUF,A+Q+1          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,14 B,R1           ALUF,Q+1            ALUD,SLB
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,X B,X             ALUF,A+Q+1          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        MOVB4 CONDENABL;

        A,R1 B,T            ALUF,B-A            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        MOVB4;




%****************************************
% BACKWARDS MOVE LOOP IS INTERRUPTED

IRQBW:  A,R4 B,R1           ALUF,A-B            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R1                ALUF,Q+1            ALUD,SLB
        IDBS,ALU                                T,NEXT      T,HOLD;

MOVB4:  A,R1 B,D            ALUF,B-A            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;





%****************************************
% ILLEGAL OVERLAP IN MOVBF-INSTRUCTION

MBERR:                                          ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        30000;

        A,T B,T             ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,JMP       T,HOLD
        CONT;








%**********************************************
% SUBROUTINE TO ADJUST BYTE POINTERS WHEN FORWARDS MOVE IS FINISHED

MBXFW:  A,R5 B,R6           ALUF,PASSA          ALUD,SRB    MIS,ROT
        IDBS,ALU                                T,JMP       T,PUSH
        MBXSR;
MOVBO:  A,T                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,14                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD;

        IDBS,ALU                                ALUD,NONE
        MBX1 CONDENABL;                         T,JMP       T,HOLD

MOVBX:                      ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        147777;

        A,T B,T             ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R5 B,T            ALUF,B-A            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R5 B,D            ALUF,B-A            ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;









%**********************************************
% SUBROUTINE TO ADJUST BYTE POINTERS WHEN BACKWARDS MOVE IS FINISHED

MBXBW:  B,R6
        IDBS,ARG            ALUF,PASSD          ALUD,B
        7777;                                   T,NEXT      T,HOLD

        A,T B,R6            ALUF,ANDAB          ALUD,SRB    MIS,ROT
        IDBS,ALU                                T,JMP       T,PUSH
        MBXSR;

MBX1:
        IDBS,ARG            ALUF,PASSD          ALUD,Q
        147777;                                 T,NEXT      T,HOLD

        A,T B,T             ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        170000;

        A,D B,D             ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;



%******************************************
% SUBROUTINE USED BY MBXFW AND MBXBW

MBXSR:  AB,SSAVE                                ALUD,NONE
        IDBS,STS            COMM,EWRF           T,JMP       T,PUSH
        MBXS1;

MBX1:
        A,R4 B,D            ALUF,A+B            ALUD,B      STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R6 B,A            ALUF,A+B            ALUD,B      CRY,C
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        167777;

        A,D B,D             ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,SSAVE                                ALUD,NONE   STS,LO
        IDBS,REG                                T,RETURN    T,POP;






%***************************************
% SUBROUTINE TO READ WORD [R2] INTO R10

RDSRC:  A,R7 B,D            ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R2                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        RDSR2 CONDENABL;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;

RDSR3:  B,STS               ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,RETURN    T,POP;

RDSR2:                                          ALUD,NONE
        IDBS,ALU            COMM,RDRQ,PT        T,JMP       T,HOLD
        RDSR3;




%****************************************
% SUBROUTINE TO INCREMENT R3

R3INC:  B,R3                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,RETURN    T,POP
 COND,F=0                                       F,JMP       F,PUSH;




%****************************************
% SUBROUTINE TO DECREMENT R3

R3DCR:  B,R3                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,RETURN    T,POP
 COND,F=0                                       F,JMP       F,PUSH;










%****************************************
% SUBROUTINE TO MOVE WORDS FORWARDS. BYTES ALIGNED

FWLOO:  A,R5 B,R1           ALUF,PASSA          ALUD,SRB    ALUM,MIC
        IDBS,ALU                                T,JMP       T,PUSH
        FWFST;

FWLO1:                                          ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP
        RDSRC CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        WRDST;

        B,R2                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        IRQFW CONDENABL;

        B,R3                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;

        B,R1                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        FWLO1;





%***********************************************
% SUBROUTINE TO MOVE WORDS BACKWARDS, BYTES ALIGNED

BWLOO:  A,R5 B,R1           ALUF,PASSA          ALUD,SRB    ALUM,MIC
        IDBS,ALU                                T,JMP       T,PUSH
        LSET1;

BWLO1:                                          ALUD,NONE
        IDBS,ALU
        RDSRC CONDENABL;                        T,RETURN    T,POP

                                                ALUD,NONE
        IDBS,ALU
        WRDST;                                  T,JMP       T,PUSH

        B,R2                ALUF,B-1            ALUD,B
        IDBS,ALU
        IRQBW CONDENABL;                        T,JMP       T,HOLD

        B,R3                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;

        B,R1                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        BWLO1;





%***********************************************
% SUBROUTINE TO MOVE WORDS FORWARDS. BYTES SWAPPED

FWEXL:
        IDBS,ALU                                ALUD,NONE
        RDSRC;                                  T,JMP       T,PUSH

        A,Z B,STS           ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,SWAP                               T,NEXT      T,HOLD;


%***********************************************
% ALTERNATIVE ENTRY IF FIRST BYTE ALREADY PRESENT IN Q


FWEXQ:  B,R2                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R5 B,R1           ALUF,PASSA          ALUD,SRB    ALUM,MIC
        IDBS,ALU                                T,JMP       T,PUSH
        LSET1;

FWEX1:                                          ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP
        RDSRC CONDENABL;

        A,Z B,STS           ALUF,ANDDA          ALUD,B
        IDBS,SWAP           COMM,LDGPR          T,NEXT      T,HOLD;

        B,R6                ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,STS B,STS         ALUF,ORAQ           ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        WRDST;

        A,Z B,R6            ALUF,MASKAB         ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        IRQFW CONDENABL;

        B,R2                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        R3INC;

        B,R1                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        FWEX1;






%***********************************************
% SUBROUTINE TO MOVE BYTES BACKWARDS, BYTES SWAPPED

BWEXL:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        RDSRC;

        A,STS B,R2          ALUF,B-1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,Z                 ALUF,ANDDA          ALUD,Q
        IDBS,SWAP                               T,NEXT      T,HOLD;


%***********************************************
% ALTERNATIVE ENTRY IF FIRST BYTE ALREADY PRESENT IN Q

BWEXQ:  A,R5 B,R1           ALUF,PASSA          ALUD,SRB    ALUM,MIC
        IDBS,ALU                                T,JMP       T,PUSH
        LSET1;

BWEX1:                                          ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP
        RDSRC CONDENABL;

        A,Z B,R6            ALUF,ANDDA          ALUD,B
        IDBS,SWAP           COMM,LDGPR          T,NEXT      T,HOLD;

        B,STS               ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,Z B,STS           ALUF,MASKAB         ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,STS B,STS         ALUF,ORAQ           ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        WRDST;

        A,R6                ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        IRQBW CONDENABL;

        B,R2                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        R3DCR;

        B,R1                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        BWEX1;



%***********************************************
% SUBROUTINE TO MOVE WORDS ALIGNED FORWARDS AS LONG AS >10 ARE LEFT
% OPTIMIZED AGAINST SPEED


FWFST:  A,R1 B,7            ALUF,PASSA          ALUD,Q
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;
                            ALUF,Q-D            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        IDBS,ARG
        40;
        A,R1 B,R4           ALUF,PASSA          ALUD,B
                                                T,RETURN    T,POP
        IDBS,ALU                                F,JMP       F,PUSH
        CONDENABL COND,F=0;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,LC=0;

        A,PIL B,LC          ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,LOAD
                                                            LCOUNT
        FWLO2;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,LC=0;

        A,PIL B,LC          ALUF,PASSD          ALUD,B
        IDBS,REG                                T,NEXT      T,POP
                                                            LCOUNT;

        A,R4                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP
 COND,F=0                                       F,JMP       F,PUSH;

FWLO2:  A,R1 B,11           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,R7 B,7            ALUF,PASSA          ALUD,Q
        IDBS,BARG           COMM,LDLC           T,RETURN    T,POP
        CONDENABL COND,F=0                      F,NEXT      F,HOLD;

        A,PIL B,D           ALUF,ANDDQ          ALUD,NONE
        IDBS,REG                                T,JMP       T,PUSH
        FWLO3;

        B,LC                ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,AREAD,NEXT     T,NEXT      T,POP
                                                            LCOUNT;

        B,LC                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

        B,6                                     ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,PIL B,T           ALUF,ANDDQ          ALUD,NONE
        IDBS,REG                                T,JMP       T,PUSH
        FWLO4;

        A,LC B,R1           ALUF,B-1            ALUD,B,YA
        IDBS,ALU            COMM,AWRITE,NEXT    T,NEXT      T,POP
                                                            LCOUNT;

        B,Z                 ALUF,D+1            ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        7;

        A,Z B,R2            ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,IRQ                                       F,JMP       F,HOLD;

        A,Z B,R3            ALUF,A+B            ALUD,B
        IDBS,ALU            COMM,CLIRQ          T,RETURN    T,POP
        FWLO2 CONDENABL;


FWLO3:  A,R2                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        FWLO5 CONDENABL;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,RETURN    T,HOLD
                                                            LCOUNT
        400 COND,LC=0;  % STOPS WHEN LC = 1

FWLO5:                                          ALUD,NONE
        IDBS,ALU            COMM,RDRQ,PT        T,RETURN    T,HOLD
                                                            LCOUNT
        400 COND,LC=0;  % STOPS WHEN LC = 1


FWLO4:  A,R3                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        FWLO6 CONDENABL;

        A,7 B,R1            ALUF,B-1            ALUD,B,YA
        IDBS,ALU            COMM,WRRQ,APT       T,RETURN    T,HOLD
                                                            LCOUNT
        COND,LC=0;

FWLO6:  A,7 B,R1            ALUF,B-1            ALUD,B,YA
        IDBS,ALU            COMM,WRRQ,PT        T,RETURN    T,HOLD
                                                            LCOUNT
        COND,LC=0;




%******************************************
% TEST IF T-REG SHOULD BE DECREMENTED AFTER SINGLE BYTE MOVED BEFORE
% LOOPS ARE ENTERED.

TTDCR:  A,T                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,14                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        IDBS,ALU                                ALUD,NONE
                                                T,RETURN    T,POP
        CONDENABL;

        B,T                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;











%************************************************************
%************************************************************

% INSTRUCTIONS FOR BIG CORE-MAP HANDLING IN SINTRAN III

%************************************************************

SINT1:  A,X B,SRCE          ALUF,D+A            ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,RESTR                                     F,NEXT      F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        PRIVI CONDENABL;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,JMP0-3    T,HOLD
        VCS13;


LDA8:   B,A                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;

LDX8:   B,X                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;

LDAD8:  B,A                 ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

                            ALUF,Q+1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;
                                                ALUD,NONE

        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        B,D                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;

LDB8:   B,R7                ALUF,PASSD          ALUD,SLB    MIS,ZIN
        IDBS,DBR                                T,NEXT      T,HOLD;

        7000 A,R7 B,B       ALUF,ORDA           ALUD,B  % 177000 .OR. B
        IDBS,ARG            COMM,CONTINUE       T,JMP       T,HOLD;

STAD8:                      ALUF,Q+1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,D                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;





%********************************************************
%********************************************************
%********************************************************
% MASTER CLEAR ROUTINE
%********************************************************
%********************************************************

MACL4:
        IDBS,ALU            ALUF,Q+1            ALUD,Q
        MACL4 CONDENABL;                        T,NEXT      T,HOLD

        B,R1                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        MACL3;

MACL:
        IDBS,ARG            ALUF,PASSD          ALUD,Q
        30120;              COMM,SIOC           T,NEXT      T,HOLD

        A,6 B,R1            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

MACL3:  B,1                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD
        MACL4 CONDENABL;  % WAITING LOOP 0.5 - 1 SECOND

                            ALUF,PASSD          ALUD,Q  % STOP
        IDBS,STS            COMM,SSTOP          T,NEXT      T,HOLD;

                            ALUF,MASKDQ         ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        160000;

        PIC,IOF                                 ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,NEXT      T,HOLD;

                            ALUF,PASSQ
        IDBS,ALU            COMM,LDPIL          T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ARG            COMM,UART,MODE      T,NEXT      T,HOLD
        372;

%CC ASYNC, 7BITS, EVEN PARITY, 2 STOP BITS. 16X BAUD RATE -> MODE 1 REG.

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        44000;

%CC ASYNC, 7BITS, EVEN PARITY, 2 STOP BITS -> Q-REG.

        AB,OLD303           ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

%CC ASYNC, 7BITS. EVEN PARITY, 2 STOP BITS -> REG FILE.

                            ALUF,PASSD          ALUD,Q
        IDBS,IOR            COMM,XSLOW          T,NEXT      T,HOLD;

%CC IOR -> Q

        B,17                ALUF,ANDDQ          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

%CC BAUD RATE THUMBWHEEL POSITION IN Q

        AB,BAUD             ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

%CC SAVE IN REG FILE

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDIRV          T,NEXT      T,HOLD;

%CC SET UP FOR VECTOR JUMP

        IDBS,ALU                                ALUD,NONE
                                                T,JMP0-3    T,PUSH
        BAUDV;

%CC VECTOR JUMP

        IDBS,ALU                                ALUD,NONE
                            COMM,XSLOW          T,NEXT      T,HOLD;

        IDBS,ALU                                ALUD,NONE
                            COMM,SLOW           T,NEXT      T,HOLD;

%CC WAIT 625 NS

                                                ALUD,NONE
        IDBS,ARG            COMM,UART,COM       T,NEXT      T,HOLD
        60;

%CC DISABLE TRANSMIT AND RECEIVE, RESET ERROR, FORCE RTS.

                                                ALUD,NONE
        IDBS,ALU            COMM,XSLOW          T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,SLOW           T,NEXT      T,HOLD;

%CC WAIT 625 NS

                                                ALUD,NONE
        IDBS,ARG            COMM,UART,COM       T,NEXT      T,HOLD
        45;

%CC ENABLE TRANSMIT AND RECEIVE

                            ALUF,ZERO           ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        RIIE1;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        PIC,LOSTS B,10      ALUF,ZERO           ALUD,Q  % 0 -> PIE
        IDBS,BARG           COMM,EPIC           T,JMP       T,PUSH
        TRPIE;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        177777;


% INITIALIZE MOPC VARIABLES

        AB,RONLY            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;
        AB,CDIGI            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;
        AB,PRCHR                                ALUD,NONE
        IDBS,ARG            COMM,EWRF           T,NEXT      T,HOLD
        443;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        PIC,LMSK            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EPIC           T,NEXT      T,HOLD;


        AB,DISPL            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,OCTAD            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,OCTA2            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,PUSH

        SPAC2;

        AB,BPFLG            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,R1                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;
                            ALUF,PASSD          ALUD,Q
                            COMM,LDEXM          T,NEXT      T,PUSH
        IDBS,ARG
        37777;

        A,R1                ALUF,A-Q            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,HOLD;

        A,R1 B,R1           ALUF,A+1            ALUD,B,YA
        IDBS,ALU            COMM,WCIHM          T,NEXT      T,POP
        CONDENABL;  % JUMPS TO 0-1

        AB,UCIL             ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,PUSH
        TRCCL;

        AB,LCIL             ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,PUSH
        TRCCL;


        IDBS,ALU            ALUF,ZERO           ALUD,Q
        EXM02;              COMM,LDEXM          T,JMP       T,PUSH


        IDBS,ALU            ALUF,PASSQ          ALUD,NONE
        SELF1;              COMM,LDPANC         T,JMP       T,HOLD



%****************************************
% SELF-TEST PROGRAM FOR CPU

SELF1:  B,R2                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,PUSH
        400;



%****************************************
% TEST 1 : 0-1+1=0

ST1:    B,R1                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R1                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R1                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;


%*******************************
% STERR IF NOT 0  (;400)


        IDBS,ALU                                ALUD,NONE
        STERR CONDENABL;                        T,NEXT      T,PUSH



%*******************************
% TEST 2 : 0 + 1*5 = 5

ST2:    B,R2                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        1000;


        IDBS,ARG            ALUF,ZERO           ALUD,Q
        3;                  COMM,LDLC           T,NEXT      T,HOLD


        IDBS,ALU                                ALUD,NONE
 COND,LC=0;                                     T,NEXT      T,PUSH

                            ALUF,Q+1            ALUD,Q  % LOOP 5 TIMES
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        B,5                 ALUF,D-Q            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;


%****************************************
% STERR IF NOT 5 (1000)

        IDBS,ALU                                ALUD,NONE
        STERR CONDENABL;                        T,NEXT      T,PUSH




%****************************************
% TEST 3 : SHIFT DOUBLE LEFT

ST3:    B,R2                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        1400;

        B,3                                     ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD
 COND,LC=0;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        70707;

        B,R3                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,PUSH
        30303;

        B,R3                ALUF,PASSB          ALUD,SLD    MIS,ROT  % LOOP 5 TIMES
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

                            ALUF,Q-D            ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        34346;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

%****************************************
% STERR IF Q ERRONEOUS (1400)

        B,R3                ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
        STERR CONDENABL;

                            ALUF,Q-D            ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        14156;



%****************************************
% STER1 IF R3 ERRONEOUS (2000)


        IDBS,ALU                                ALUD,NONE
        STER1 CONDENABL;                        T,NEXT      T,PUSH



%****************************************
% TEST 4 : -1 -> R5, 0 -> Q

ST4:    B,R2                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        2400;

        B,R5                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        177777;

        B,0                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;
                            ALUF,PASSQ          ALUD,NONE
                                                T,NEXT      T,HOLD
        IDBS,ALU
 COND,F=0;
                                                F,JMP       F,HOLD

%*******************************
% STERR IF Q NOT 0 (2400)

        B,R5                ALUF,B+1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        STERR CONDENABL;


%*******************************
% STERR1 IF R5+1 NOT 0 (3000)

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,PUSH
        STER1 CONDENABL;




%*******************************
% TEST 5 : 170(AARG) -> SWAP = 74000

ST5:    B,R2                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        3400;

        A,17                                    ALUD,NONE
        IDBS,AARG                               T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,SWAP                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                            ALUF,Q-D            ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        74000;

%****************************************
%*******************************
% STERR IF NOT 74000 (3400)


        IDBS,ALU                                ALUD,NONE
        STERR CONDENABL;                        T,NEXT      T,PUSH



%****************************************
% TEST 6 : LC USED TO GENERATE 1 AMONG 0'S.
% SHIFT RIGHT DOUBLE WITH SHIFT GPR.

ST6:    B,R2                ALUF,B+1            ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        4000;

        B,R1                ALUF,ZERO           ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        17;


        IDBS,ARG            ALUF,PASSD          ALUD,Q
        100000;             COMM,LDGPR          T,NEXT      T,PUSH

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,LC                ALUF,Q-D            ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,POP;


%****************************************
% STERR IF BMG(LC) NOT CORRECT (4000)


        IDBS,GPR            ALUF,Q-D            ALUD,NONE

                                                T,NEXT      T,HOLD
        STERR CONDENABL;


% ***********************************************
% STER1 IF GPR NOT SHIFTED CORRECT (+400)
%***********************************************
        B,R1                ALUF,PASSB          ALUD,SRD    ALUM,FMU
        IDBS,ALU                                T,NEXT      T,HOLD
        STER1 CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,LC=0;

                                                ALUD,NONE  % LOOP BACK
        IDBS,PEA                                T,NEXT      T,HOLD
                                                            LCOUNT;

        B,R7                ALUF,PASSD          ALUD,B
        IDBS,STS                                T,NEXT      T,LOAD;



% ***********************************************
% TEST 7 : TEST STS AND REGISTER FILE
%***********************************************
ST7:    B,R2                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        5000;

        B,STS                                   ALUD,NONE  % -1 -> REG.FILE
        IDBS,ARG            COMM,EWRF           T,NEXT      T,HOLD
        177777;

                            ALUF,ZERO           ALUD,NONE   STS,LO  % 0 -> STS
        IDBS,ALU            COMM,LDPIL          T,JMP       T,PUSH
        ST77;

                            ALUF,PASSD          ALUD,Q  % STS -> Q
        IDBS,STS                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;
                            ALUF,PASSQ          ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        IDBS,ARG                                T,NEXT      T,HOLD;


%****************************************
% STERR IF STS NOT 10000 (5000)

        A,17 B,STS          ALUF,D+1            ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
        STERR CONDENABL;


%****************************************
% STER1 IF REG.FILE NOT -1 (5400)

        A,17 B,STS          ALUF,ZERO           ALUD,NONE  % 0 -> REG.FILE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD
        STER1 CONDENABL;

        A,17 B,STS          ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD;



%****************************************
% STER2 IF REG.FILE NOT 0 (6000)

        A,14                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD
        STER2 CONDENABL;

        A,R7                ALUF,ORAQ           ALUD,NONE   STS,LO
        IDBS,ALU            COMM,LDPIL          T,NEXT      T,HOLD;

        A,A B,R7            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,PUSH;



%*******************************
% TEST 8 : TEST OF PIC

ST8:    B,R2                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        6400;

                                                ALUD,NONE  % PID -> REG.FILE
        IDBS,ALU                                T,JMP       T,PUSH
        TAPID;

        A,17 B,STS          ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

                            ALUF,ZERO           ALUD,Q  % 0 -> PID
        IDBS,ALU                                T,JMP       T,LOAD
        TRPID;

                                                ALUD,NONE  % 176000 -> PID
        IDBS,ARG            COMM,SMPID          T,NEXT      T,HOLD
        140017;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        TAPID;

                            ALUF,D-Q            ALUD,Q  % CHECK PID
        IDBS,ARG                                T,NEXT      T,POP
        176000;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;


%***********************************************
% STERR IF PID NOT 176000 (6400)

        A,17 B,STS          ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        STERR CONDENABL;

        B,R6                ALUF,ZERO           ALUD,B  % REG.FILE -> PID
        IDBS,ALU                                T,JMP       T,PUSH
        TRPID;

        A,R7 B,A            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        MACL2;






%****************************************
% SUBROUTINE TO PLACE IDB HIGH

ST77:                                           ALUD,NONE
        IDBS,ARG                                T,RETURN    T,POP
        177777;





%****************************************
% DISPLAY ERROR NO. R2+2

STER2:  400 A,R2 B,R2       ALUF,A+B            ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD;







%****************************************
% DISPLAY ERROR NO. R2+1

STER1:  400 A,R2 B,R2       ALUF,A+B            ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD;






%*******************************
% DISPLAY ERROR NO. R2

STERR:  B,R2                ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        DYTP2;

                            ALUF,PASSQ          ALUD,NONE  % LOOP ON ERROR
        IDBS,ALU            COMM,LDPIL          T,RETURN    T,HOLD;






%
%************************************
% LAST PART OF MASTER CLEAR ROUTINE

MACL2:                      ALUF,PASSD          ALUD,Q
        IDBS,ARG            COMM,SIOC           T,NEXT      T,HOLD
        30140;

        AB,STATUS           ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,MANIR            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        IDBS,ARG            ALUF,PASSD          ALUD,Q
        17777                                   T,NEXT      T,HOLD;

        AB,NOISE            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

%CC WRITE A VALUE <> 0 TO THE NOISE FLIP FLOP. DISABLES LOAD IMMEDIATELY
%CC AFTER MACL.

        AB,TXT1             ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,TXT2             ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,SINGL            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,EWRF           T,JMP       T,PUSH
        LVSWP;

                            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,LDPCR          T,NEXT      T,HOLD;

        A,PIL B,0           ALUF,ZERO           ALUD,NONE   XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;  % PCR LEVEL 0

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;








%********************************************************
%********************************************************

% SUBROUTINE USED BY MOPC AND MACL TO CLEAR SEVERAL MOPC VARIABLES

%********************************************************

SPAC2:  AB,DUMPF            ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;  %0->R6
        AB,SCRAM            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;
        AB,OCTNR            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;
        AB,CURNR            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;
        AB,UPPNR            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;
        AB,OCTN2            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;
        AB,DEPOS            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,RETURN    T,POP;










%***********************************************
%***********************************************

% STOP CPU. ENTERED FROM WAIT-INSTRUCTION. PRINT #

%***********************************************

STOPW:  443 AB,PRCHR                            ALUD,NONE
        IDBS,ARG            COMM,EWRF           T,NEXT      T,HOLD;





%***********************************************
%***********************************************

% FROM INTERRUPT VECTOR IF THE CPU IS IN STOP (3760 OR 3770)

%***********************************************

STOP:   AB,NOISE            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

%CC RESET THE NOISE FLIP-FLOP. WILL NOW ENABLE THE LOAD BUTTON.

        AB,MACL             ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,IOR                                T,JMP       T,HOLD
        STOP2 CONDENABL;

%***********************************************
% STOP FOLLOWS DIRECTLY AFTER MASTER CLEAR. STAND-BY IS NOT OK

        A,15                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        AB,MACL             ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD
        STOP2 CONDENABL;




%***********************************************
% PANEL IS LOCKED WHEN POWER-UP, OR LOAD IS PRESSED

ALDLO:                                          ALUD,NONE  % USE ALD-SWITCH
        IDBS,ALD            COMM,LDLC           T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,LC                                    ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,LC                                    ALUD,NONE
        IDBS,ALU                                T,JMPAOPR   T,PUSH
        ALDVC;



%***********************************************
% LOAD, $ OR &, LOAD CODE IN Q

LOAD1:  A,17                ALUF,MASKDQ         ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,15                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,JMP       T,HOLD
        CONT CONDENABL;


%******************************
% Q IS NOT 0

        A,7 B,STS           ALUF,D-1            ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        ETLO1 CONDENABL;











%****************************************
%****************************************

% MASS STORAGE LOAD, BECAUSE BIT 13 IS 1


%****************************************
MASS:   A,1 B,D             ALUF,D+Q            ALUD,B  % DEV.:NO. +2 -> D
        IDBS,BMG                                T,NEXT      T,HOLD;

MAS1:   B,A                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;


%****************************************
% IOX N+1 (0) CORE ADDRESS

        A,D B,R1            ALUF,A-1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        IOXG;


%*******************************
% IOX N+1 (0) CORE ADDRESS

        A,D B,R1            ALUF,A-1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        IOXG;


%*******************************
% IOX N+3 (0) BLOCK ADDRESS

        A,D B,R1            ALUF,A+1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        IOXG;


%*******************************
% IOX N+7 (2000) WORD COUNTER

        5 A,D B,R1          ALUF,D+A            ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD;

        A,12 B,A            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        IOXG;


%*******************************
% IOX N+5 (4) ACTIVATE DEVICE

        A,D B,R1            ALUF,D+A+1          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,2 B,A             ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        IOXG;




%********************************
% IOX N+4 READ STATUS

MAS2:   A,D B,R1            ALUF,D+A            ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        IOXG;

        A,A B,4             ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,2 B,R7            ALUF,PASSD          ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD
        MAS2 CONDENABL;


%********************************
% DEVICE FINISHED

        A,A B,R7            ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        IDBS,ALU                                ALUD,NONE
                                                T,NEXT      T,HOLD
        MAS1 CONDENABL;


%********************************
% NO ERRORS, START IN 0. AND LEAVE MOPC

        B,P                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,START          T,JMP       T,HOLD
        ESCAP;










%****************************************
%****************************************

% RESTART, ENTERED FROM INTERRUPT VECTOR (3766)
% ONLY IF STAND-BY POWER IS OK

%****************************************

RSTRT:                      ALUF,PASSD          ALUD,Q
        IDBS,IOR            COMM,CLRTC          T,NEXT      T,HOLD
 COND,STP                                       F,RETURN    F,POP;

        A,15                ALUF,ANDDQ          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD
        CONDENABL COND,F=0                      F,JMP       F,HOLD;

%****************************************
% ONLY IF IN STOP MODE


        AB,MACL             ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
        RSTR1 CONDENABL;


%****************************************
% IF LOCKED

                                                ALUD,NONE
        IDBS,ALD            COMM,LDLC           T,NEXT      T,HOLD;

        AB,MACL             ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,LC                                    ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,LC                                    ALUD,NONE
        IDBS,ALU                                T,JMPAOPR   T,PUSH
        ALDVC;  % USE ALD SWITCHES

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;


%***********************************************
% LOAD IF BIT 15=1. START IN ADDRESS 20 IF BIT 15=0


        IDBS,ALU                                ALUD,NONE
        LOAD1 CONDENABL;                        T,JMP       T,HOLD




%***********************************************
% START CPU IN ADDRESS 20

RSTR2:  A,2 B,P             ALUF,PASSD          ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        CONTI;




%***********************************************
% IF UNLOCKED, DO NOTHING JUST AFTER MASTER CLEAR, ELSE START IN 20
RSTR1:  AB,MACL             ALUF,ZERO           ALUD,NONE
RSTR1:  AB,MACL             ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD
        CONT CONDENABL;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        RSTR2;








%***********************************************
%***********************************************

% LOAD BUTTON IS PRESSED. ENTERED FROM INTERRUPT VECTOR (3764 OR 3774)

%***********************************************

LOAD:   AB,NOISE            ALUF,PASSD          ALUD,NONE
        IDBS,REG            COMM,CLRTC          T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        CONT CONDENABL                          T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,STP                                       F,NEXT      F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ALDLO CONDENABL;



%***********************************************
%***********************************************

% CPU IS NOT IN STOP WHEN LOAD IS PRESSED, OR
% CONTINUE BUTTON IS PRESSED. ENTERED FROM INTERRUPT VECTOR (3765 OR 3775)

%****************************************

CONTI:
        IDBS,ALU                                ALUD,NONE
        ESCAP;              COMM,START          T,JMP       T,HOLD








%****************************************
%****************************************

% $ OR & IS TYPED TO NOPC

%****************************************

DOLOA:
ETLOA:  AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;


%****************************************
% USE ALD-SWITCH IF NO OCTAL NUMBER GIVEN


        IDBS,ALU                                ALUD,NONE
        ALDLO CONDENABL;                        T,JMP       T,HOLD


        IDBS,ALU                                ALUD,NONE
        LOAD1;                                  T,JMP       T,HOLD













%****************************************
%****************************************
% BINARY LOADER. LOAD CODE BIT 13 IS 0.

%****************************************


ETLO1:  B,D                 ALUF,PASSQ          ALUD,B  % DEV.NO. -> D
        IDBS,ALU                                T,JMP       T,PUSH
        DVACT;

SEEK:   A,R5 B,P            ALUF,PASSA          ALUD,B  % POSSIBLE S.A.
        IDBS,ALU                                T,NEXT      T,HOLD;

SIKI:   A,5 B,L             ALUF,D+1            ALUD,B  % READ OCTAL NO.
        IDBS,BMG                                T,JMP       T,PUSH
        ASS8;
        A,R2 B,15           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;
        A,R2 B,L            ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SEEK CONDENABL;


%****************************************
% LAST CHAR. IS NOT CR



                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        EXFOU CONDENABL;


%****************************************
% LAST CHAR. IS NOT !

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SIKI;




%****************************************
% EXCLAMATION MARK (!) FOUND

EXFOU:  A,10 B,STS          ALUF,D-1            ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        B,L                 ALUF,ZERO           ALUD,B  % READ CORE ADDR.
        IDBS,ALU                                T,JMP       T,PUSH
        BIN;

        A,Z B,X             ALUF,PASSA          ALUD,B  % READ WORD COUNT
        IDBS,ALU                                T,JMP       T,PUSH
        BIN;

        A,Z B,T             ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;



%****************************************
%LOOP TO STORE PROGRAM IN MEMORY

STLP:                                           ALUD,NONE  % READ ONE WORD
        IDBS,ALU                                T,JMP       T,PUSH
        BIN;

        B,T                 ALUF,B-1            ALUD,B  % DECR. WORD COUNT
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,X B,X             ALUF,B+1            ALUD,B,YA  % INCR. CORE ADDR.
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,COND                                      F,JMP       F,HOLD;

        A,Z B,L             ALUF,A+B            ALUD,B,YA  % ACCUMULATE CH.SM.
        IDBS,ALU            COMM,WRRQ,PT        T,NEXT      T,HOLD
        STLP CONDENABL;





%***********************************************
% ALL WORDS ARE PLACED IN MEMORY

                                                ALUD,NONE  % READ CHECKSUM
        IDBS,ALU                                T,JMP       T,PUSH
        BIN;

        A,Z B,L             ALUF,XORAB          ALUD,NONE  % TEST CH.SM.
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        ILLEG CONDENABL;


%***********************************************
% CHECKSUM OK. READ ACTION CODE

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        ASS8;

        A,R2                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        ESCAP CONDENABL;


%*******************************
% ACTION CODE =0, START PROGRAM

                                                ALUD,NONE
        IDBS,ALU            COMM,START          T,JMP       T,HOLD
        ESCAP;





%*******************************
% SUBROUTINE FOR BINARY LOADER TO READ ONE CHARACTER

INCH:   A,D B,R1            ALUF,D+A            ALUD,B  % I0X N+2
        IDBS,BMG                                T,JMP       T,PUSH
        IOXG;

        A,A B,10            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        INCH CONDENABL;


%*******************************
% READY FOR TRANSFER

        A,D B,R1            ALUF,PASSA          ALUD,B  % I0X N
        IDBS,ALU                                T,JMP       T,PUSH
        IOXG;

        A,A B,STS           ALUF,ANDAB          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,JMP       T,HOLD
        DVACT;



%****************************************
% ACTIVATE DEVICE

DVACT:  B,A                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        4005;

        A,D B,R1            ALUF,D+A+1          ALUD,B  % IOX N+3 (+4005)
        IDBS,BMG                                T,JMP       T,HOLD
        IOXG;










%****************************************
% SUBROUTINE FOR BINARY LOADER TO READ OCTAL NUMBER, RETURNS ON NON-OCTAL CHAR

ASS8:   AB,OCTNR            ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        ASS81;



% OCTAL DIGIT FOUND

                                                ALUD,NONE
        ASS82:
        IDBS,ALU                                T,JMP       T,PUSH
        OCDIG;
ASS81:  AB,OCTNR            ALUF,PASSD          ALUD,B  % READ CHARACTER
        IDBS,REG                                T,JMP       T,PUSH
        INCH;

        A,STS B,R2          ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        60;

        A,R2 B,R3           ALUF,A-Q            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,10           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,RETURN    T,POP
        CONDENABL COND,F15                      F,RETURN    F,POP;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ASS82 CONDENABL;










%********************************************************
% SUBROUTINE USED BY BINARY LOADER TO READ TWO BYTES AS ONE 16-BIT WORD
BIN:                                            ALUD,NONE  % READ BYTE 1
        IDBS,ALU                                T,JMP       T,PUSH
        IDBS,ALU                                T,JMP       T,PUSH
        INCH;
                                                ALUD,NONE  % SWAP BYTES
        IDBS,GPR                                T,NEXT      T,HOLD;

        B,Z                 ALUF,PASSD          ALUD,B
                                                T,JMP       T,PUSH
        IDBS,SWAP
        INCH;  % READ BYTE 2

        A,Z B,Z             ALUF,ORDA           ALUD,B  % MAKE WORD
        IDBS,GPR                                T,RETURN    T,POP;










%***********************************************
%***********************************************

% ENTERED FROM INTERRUPT VECTOR EVERY 20 MS

%***********************************************

MS20:   B,10                ALUF,PASSD          ALUD,Q
        IDBS,BARG           COMM,CLRTC          T,NEXT      T,HOLD;

        AB,STATUS           ALUF,ORDQ           ALUD,Q
        IDBS,REG                                T,JMP       T,PUSH
        WSIOC;





%***********************************************
% TEST IF 20 MS CLOCK SHOULD ACTIVATE NOPC

                            ALUF,PASSD          ALUD,NONE
        IDBS,MIPANS                             T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        MOPC CONDENABL;



%****************************************
% MOPC SHOULD BE DRIVEN BY PANEL REQUEST FROM MEMORY MANAGEMENT MODULE

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;














%****************************************
%****************************************

% PANEL REQUEST, ENTERED FROM INTERRUPT VECTOR :3762)

%****************************************

PRQ:                                            ALUD,NONE
        IDBS,MIPANS                             T,NEXT      T,HOLD;










%********************************************
%********************************************

% MAIN ENTRY POINT OF MOPC

%********************************************

MOPC:
MRET1:  AB,PRCHR            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;


        IDBS,IOR            ALUF,PASSD          ALUD,Q
        NOUTP CONDENABL;                        T,JMP       T,HOLD


%********************************************
% CHARACTER IS WAITING TO BE OUTPUTTED

        A,16                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

%CC TBMT INVERSE POLARITY

        A,17                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
        OUTPT CONDENABL;

%CC DA INVERSE POLARITY

%********************************************
% OUTPUT STOPPED BY INPUT
                                                ALUD,NONE
        IDBS,UART           COMM,UART,DATA      T,JMP       T,HOLD
        RONLY;

%CC READ DATA, RESET DA, DISCARD CHARACTER

OUTPT:                                          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        CONT CONDENABL;


%****************************************
% UART READY FOR OUTPUT

        AB,PRCHR            ALUF,PASSD          ALUD,Q
        IDBS,REG            COMM,UART,DATA      T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

%CC PRCHR -> UART DATA

                            ALUF,D-Q            ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        43;


%****************************************
% JUMP TO CR IF OUTPUTTED CHAR. WAS #

        B,12                ALUF,D-Q            ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        CR CONDENABL;


%****************************************
% JUMP TO LFEED IF OUTPUTTED CHAR. WAS LF

        AB,PRCHR            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        LFEED CONDENABL;

        AB,CDIGI            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;


        IDBS,ALU                                ALUD,NONE
        OUTP1 CONDENABL;                        T,JMP       T,HOLD


%**********************************************************
% THERE ARE MORE CHARACTERS LEFT TO BE PRINTED IN ONE OCTAL NUMBER

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        AB,CDIGI            ALUF,Q-1            ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        SPAC3 CONDENABL;


%**********************************************************
% GET NEXT DIGIT

        AB,NUMBR            ALUF,PASSD          ALUD,SLB    MIS,ROT ALUM,MIC
        IDBS,REG                                T,NEXT      T,HOLD;

        AB,NUMBR            ALUF,PASSB          ALUD,SLB    MIS,ROT ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,NUMBR            ALUF,PASSB          ALUD,SLB    MIS,ROT ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,NUMBR            ALUF,PASSB          ALUD,Q
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        7;

                            ALUF,D+Q            ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        60;


%***********************************************
% PLACE IT IN PRCHR

PRICH:  AB,PRCHR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        MRET1;


%***********************************************
% GET SPACE, WHICH IS THE LAST CHAR. IN AN OCTAL NUMBER

SPAC3:  A,5                 ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        PRICH;






%***********************************************
% ONE OCTAL NUMBER IS FINISHED

OUTP1:  AB,DUMPF            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        AB,CNT10            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        MRET1 CONDENABL;


%***********************************************
% WE ARE PRESENTLY INSIDE A DUMP COMMAND

        B,2                 ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        B,12                ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        DUMP2 CONDENABL;

        AB,CURNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        DMP10 CONDENABL;


%***********************************************
% SOMETHING ELSE THAN MEMORY CONTENT SHOULD BE PRINTED IN THE DUMP NOW

DUMP2:  AB,CNT10            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        DUMP3;


%***********************************************
% CNT10 = 0 , PRINT ADDRESS

DUMP4:  AB,CURNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,PUSH
        PROCT;

        AB,CNT10            ALUF,D+1            ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        MRET3;



%***********************************************
% NEXT OCTAL NUMBER SHOULD POSSIBLY BE PRINTED

DMP10:  AB,UPPNR            ALUF,Q-D            ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        AB,PRCHR            ALUF,ZERO           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SPACE CONDENABL;  % JUMP TO SPACE IF FINISHED WITH DUMP


%*******************************
% NOT FINISHED

        AB,SCRAM                                ALUD,NONE
        IDBS,REG            COMM,LDLC           T,NEXT      T,HOLD;


%*******************************
% GET VALUE


        IDBS,ALU                                ALUD,NONE
        DSPLY;                                  T,JMP       T,PUSH

        AB,CURNR            ALUF,D+1            ALUD,B
        IDBS,REG                                T,NEXT      T,HOLD;


%*******************************
% PRINT IT WITH PROCT

        AB,CURNR            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,PUSH
        PROCT;



%*******************************
% INCREMENT CNT10, CONTROLLING THE NUMBER OF ADDRESSES PER LINE

MRET2:  AB,CNT10            ALUF,D+1            ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

MRET3:  AB,CNT10            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        MRET1;


DUMP3:  B,1                 ALUF,D-Q            ALUD,NONE
        IDBS,BARG                               T,RETURN    T,POP
        DUMP5 CONDENABL;


%****************************************
% CNT10 = 1, PRINT /

DUMP6:                      ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        57;

DMP61:  AB,PRCHR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,CNT10            ALUF,D+1            ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        MRET3;

DUMP5:  B,12                ALUF,D-Q            ALUD,NONE
        IDBS,BARG                               T,RETURN    T,POP
        DUMP7 CONDENABL;


%****************************************
% CNT10 = 12, PRINT CR

DUMP8:  B,15                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        DMP61;

DUMP7:                                          ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP
        DUMP9 CONDENABL;


%****************************************
% CNT10 = 13. PRINT LF

DUMP9:                      ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        412;

        AB,PRCHR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,CNT10            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        MRET1;










%****************************************
%****************************************

% NO OUTPUT IS WAITING TO GET OUT

%****************************************
% COPCM TO CHECK IF MOPC SHOULD USE TERMINAL INPUT

NOUTP:  A,13                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,JMP       T,PUSH
        COPCM;


%****************************************
% MOPC USES TERMINAL INPUT

INPUT:  AB,STATUS           ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,6                 ALUF,MASKDQ         ALUD,Q
        IDBS,BMG                                T,JMP       T,PUSH
        WSIOC;

                            ALUF,PASSD          ALUD,Q
        IDBS,IOR                                T,NEXT      T,HOLD;

        A,16                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

%CC DA INVERTED

%*******************************
% NO DATA AVAILABLE ?

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        DISPL CONDENABL;


%*******************************
%CC CHECK BAUD RATE THUMBWHEEL

        B,17                ALUF,ANDDQ          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

%CC MASK OFF REST OF IOR

        AB,BAUD             ALUF,XORDQ          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD;

%CC CHECK AGAINST OLD THUMBWHEEL POSITION.

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        RCHAR CONDENABL;

%CC JUMP IF THUMBWHEEL THE SAME AS PREVIOS VALUE

                                                ALUD,NONE
        IDBS,UART           COMM,UART,MODE      T,JMP       T,PUSH
        BAUDS;

%CC SKIP WRITING TO MODE 1 REGISTER

%****************************
% READ CHARACTER

RCHAR:                      ALUF,PASSD          ALUD,Q
        IDBS,UART           COMM,UART,DATA      T,NEXT      T,HOLD;


                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG            COMM,SLOW           T,NEXT      T,HOLD
        177;

%CC 625 NS DELAY

                                                ALUD,NONE
        IDBS,ALU            COMM,XSLOW          T,NEXT      T,HOLD;

%****************************
% PRINT ECHO

        B,R2                ALUF,PASSQ          ALUD,B
        IDBS,ALU            COMM,UART,DATA      T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,15                ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,JMP       T,PUSH
        IN1;


%****************************
% CHARACTER WAS CR, PRINT LF

        B,12                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

        AB,PRCHR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        CONT;



%********************************************
% CHECK IF OCTAL DIGIT (60-71)

IN1:                                            ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP
 COND,F15 CONDENABL;                            F,NEXT      F,POP

        B,R1                ALUF,Q-D            ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        60;

        A,R1 B,10           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        IN2 CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        OCDI2 CONDENABL;



%********************************************
% CHARACTER WAS NOT OCTAL DIGIT. CHECK LETTER

IN2:                        ALUF,Q-D            ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        101;

        B,R5                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        IN3 CONDENABL;
                            ALUF,Q-D            ALUD,NONE
                                                T,NEXT      T,HOLD
        IDBS,ARG
        132;

                                                ALUD,NONE
        IDBS,ALU
        LETTR CONDENABL;



%***********************************************
% CHARACTER WAS NOT LETTER A-Y, CHECK SPECIAL CHARACTERS

IN3:    A,6                 ALUF,Q-D            ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,4                 ALUF,D+Q            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        SPACE CONDENABL;
        B,15                ALUF,D+Q            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        ANGBR CONDENABL;
        B,5                 ALUF,D+Q            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        SLASH CONDENABL;
        B,17                ALUF,D+Q            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        ASTRX CONDENABL;
        B,5                 ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        ESCAP CONDENABL;


        A,7 B,R1            ALUF,Q-D-1          ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        SPACE CONDENABL;

%***********************************************
% OTHER CHARACTERS ONLY LEGAL IN STOP. AND WITHOUT LETTERS IN FRONT


        B,R1                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        STTS0;

        B,1                 ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R1                ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        EXCL CONDENABL;
        B,1                 ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        ZCHAR CONDENABL;
        B,1                 ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        QUOTE CONDENABL;
        B,1                 ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        CROSS CONDENABL;
        B,2                 ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        DOLOA CONDENABL;
        B,10                ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        ETLOA CONDENABL;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        DOT CONDENABL;



%***********************************************%
% ILLEGAL MOPC CONDITION, PRINT ?

ILLEG:                      ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        77;

        AB,PRCHR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        RONLY;












%************************************************%
% RETURN IF MOPC INPUT IS ACTIVE

COPCM:                                          ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP
 COND,STP CONDENABL;                            F,NEXT      F,HOLD


%********************************************
% INPUT IF STOP
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        INPUT CONDENABL;


%********************************************
% REFRESH DISPLAY IF MOPC IS IDLE


DISPL:  AB,DISPL                                ALUD,NONE
        IDBS,REG            COMM,LDLC           T,NEXT      T,HOLD;


%********************************************
% SEND DATA TO DISPLAY PROCESSOR

        AB,OCTAD            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,PUSH
        DSPLY;


        IDBS,ALU                                ALUD,NONE
        CONT;                                   T,JMP       T,HOLD










%********************************************
%********************************************

% SUBROUTINE TO SEND DATA TO OPTIONAL DISPLAY. LC = DISPLAY TYPE. Q = ADDRESS

%********************************************

DSPLY:  A,LC B,R4           ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        174001;

        B,3                                     ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,JMPAOPR   T,HOLD
        VECT4;  % VECTORIZED JUMP, CONTROLLED BY LOOP COUNTER



%****************************************
% LC=0, MEMORY EXAMINE

EXAM1:
        AB,OCTA2            ALUF,PASSD          ALUD,B
        IDBS,REG            COMM,LDSEG          T,NEXT      T,HOLD;

        B,10                                    ALUD,NONE
        IDBS,BARG           COMM,LDPANC         T,NEXT      T,HOLD;

        AB,OCTA2            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,LDPANC         T,JMP       T,PUSH
        DYDAT;

        A,10 B,R3           ALUF,D-1            ALUD,B
        IDBS,BMG                                T,JMP       T,PUSH
        SETEM;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,DBR                                T,JMP       T,PUSH
        DYDAT;


RESEM:
                            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,LDEXM          T,RETURN    T,POP;

SETEM:
        A,PIL B,0           ALUF,PASSD          ALUD,B
        IDBS,REG                                T,NEXT      XRF T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,0 B,4             ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD;

        AB,EXMOD            ALUF,PASSD          ALUD,B  % R1
        IDBS,REG            COMM,LDEXM          T,RETURN    T,POP
        CONDENABL;

        A,R1 B,4            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        30 A,R1 B,R1        ALUF,XORDA          ALUD,SRB
        IDBS,ARG                                T,RETURN    T,POP
        CONDENABL;

% VIRTUAL EXAMINE

        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,RETURN    T,POP;




%****************************************
% LC=1, REGISTER EXAMINE

VC41:                       ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDIRV          T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        IRR;

        A,A                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,POP;

OPAST:  A,R7 B,A            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        DYTP1;




%*******************************
% LC=2, AUXILIARY REGISTER EXAMINE

VC42:                       ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDIRV          T,NEXT      T,HOLD;

        A,R6                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,REG B,LC          ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        DYTP1;



%********************************
% LC = 3 : INTERNAL REGISTER EXAMINE

VC43:                       ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDIRV          T,NEXT      T,HOLD;
                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;


                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        VC431;
        A,A                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,POP
        OPAST;



%*******************************
% USE TRA-INSTRUCTION

VC431:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        TRA;



%********************************
% LC = 17 : ACTIVITY EXAMINE (ACTIVE LEVELS)

VC417:  AB,ACTLV A,PIL      ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        AB,ACTLV            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        DYTP2;




%********************************
% SUBROUTINE TO SEND DATA FROM REGISTER EXAMINE TO NLM

DYTP1:
        B,11                                    ALUD,NONE
        IDBS,BARG           COMM,LDPANC         T,JMP       T,PUSH
        DYDAT;

        A,P                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDPANC         T,JMP       T,HOLD
        DYSWP;




%***********************************************
% SUBROUTINE TO SEND Q AS TWO BYTES TO NMM

DYDAT:                      ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDPANC         T,NEXT      T,HOLD;

DYSWP:                                          ALUD,NONE
        IDBS,SWAP           COMM,LDPANC         T,RETURN    T,POP;



%***********************************************
% SUBROUTINE TO SEND ACTIVE LEVELS DATA TO NMM

DYTP2:
        B,12                                    ALUD,NONE
        IDBS,BARG           COMM,LDPANC         T,JMP       T,HOLD
        DYDAT;









%***********************************************

% SUBROUTINE TO PRINT OCTAL NUMBER AS 6 DIGITS + SPACE

%***********************************************

PROCT:  AB,NUMBR            ALUF,PASSQ          ALUD,SLB    MIS,ROT ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,NUMBR            ALUF,PASSB          ALUD,Q
                            COMM,EWRF           T,NEXT      T,HOLD;
                            ALUF,ANDDQ          ALUD,Q
                                                T,NEXT      T,HOLD
        IDBS,ARG
        1;

                            ALUF,D+Q            ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        60;

        AB,PRCHR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        5;

        AB,CDIGI            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,RETURN    T,POP;





%***********************************************
% SUBROUTINE TO CHECK THAT SCRAM = 0 AND STOP
%***********************************************



STTS0:  AB,SCRAM            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        ILLEG CONDENABL;


%***********************************************
% SUBROUTINE TO CHECK STOP
%***********************************************
STTST:                                          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,STP                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP
        ILLEG CONDENABL;





%****************************************

% SUBROUTINE TO SEND LABEL TO NLM

%****************************************

LABEL:
        B,16                                    ALUD,NONE
        IDBS,BARG           COMM,LDPANC         T,NEXT      T,HOLD;

        AB,TXT1                                 ALUD,NONE
        IDBS,REG            COMM,LDPANC         T,JMP       T,PUSH
        DYSWP;

        AB,TXT2                                 ALUD,NONE
        IDBS,REG            COMM,LDPANC         T,JMP       T,HOLD
        DYSWP;




%************************************************************

% SUBROUTINE TO ASSEMBLE CHARACTERS AS LABELS FOR NLM

%************************************************************

BUILD:  AB,TXT1             ALUF,PASSD          ALUD,B
        IDBS,REG                                T,NEXT      T,HOLD
 COND,LC=0;

        B,6                                     ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD;

        AB,TXT2             ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,PUSH;

        AB,TXT1             ALUF,PASSB          ALUD,SLD    ALUM,MIC
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        A,R2                ALUF,ORAQ           ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,TXT1             ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,TXT2             ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,RETURN    T,POP;





%************************************************************

% SUBROUTINE TO ASSEMBLE AN OCTAL NUMBER FROM A DIGIT

%************************************************************


OCDIG:  AB,OCTN2            ALUF,PASSD          ALUD,B
        IDBS,REG                                T,JMP       T,PUSH
        BUILD;

OCDIX:  AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        B,R5                ALUF,PASSB          ALUD,SLD    ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R5                ALUF,PASSB          ALUD,SLD    ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R5                ALUF,PASSB          ALUD,SLD    ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;

        7 A,R2 B,R2         ALUF,ANDDA          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD;

        A,R2                ALUF,ORAQ           ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,OCTNR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,OCTN2            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,DEPOS                                ALUD,NONE
        IDBS,ARG            COMM,EWRF           T,RETURN    T,POP;




%****************************************
%****************************************

% ROUTINES FOR DIFFERENT MOPC INPUT CARACTERS

%****************************************
% MOPC INPUT CHARACTER WAS 0-7

OCDI2:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        OCDIG;

                                                ALUD,NONE
        IDBS,ALU
        CONT;




%****************************************
% MOPC INPUT CHARACTER WAS ESCAPE

ESCAP:  AB,STATUS           ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,6                 ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,JMP       T,PUSH
        WSIOC;




%****************************************
% ROUTINE TO MAKE DEPOSIT ILLEGAL

RONLY:  AB,RONLY                                ALUD,NONE
        IDBS,ARG            COMM,EWRF           T,JMP       T,HOLD
        SPACE;





%****************************************
% MOPC INPUT CHARACTER WAS SPACE OR @. RESET MOPC

SPACE:  AB,MANIR            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;
        AB,BPFLG            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;
        AB,SINGL            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

%***********************************************
% MOPC INPUT CHARACTER WAS . 'Z PARTIALLY RESET MOPC

SPAC9:  AB,TXT1             ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,PUSH
        SPAC2;
        AB,TXT2             ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        CONT;



%***********************************************
% MOPC OUTPUT CHARACTER WAS LF, PRINT #

LFEED:  AB,PRCHR                                ALUD,NONE
        IDBS,GPR            COMM,EWRF           T,JMP       T,HOLD
        CONT;





%***********************************************
% MOPC INPUT CHARACTER WAS A-Y, SCRAMBLE CHARACTERS

LETTR:  AB,SCRAM            ALUF,PASSD          ALUD,SLB    ALUM,MIC
        IDBS,REG                                T,JMP       T,PUSH
        BUILD;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        37;

        A,R2 B,R2           ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R2 B,R5           ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,SCRAM            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        CONT;




% ******************************
% ! TYPED, START PROGRAM

EXCL:   AB,SCRAM            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        ILLEG CONDENABL;

        AB,DEPOS            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,START          T,JMP       T,HOLD
        ESCAP CONDENABL;


        B,P                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        ESCAP;








% ******************************
% # TYPED, MEMORY TEST

CROSS:
MEMOT:  A,R5 B,A                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        122;

        150000
        AB,OCTNR                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,NEXT      T,HOLD;

MM00:   B,D                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

MM0:    A,0 B,T             ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

MM1:    B,R2                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

MM2:    A,B B,P             ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

MM3:    A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,R2                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        MM31 CONDENABL;

        A,T B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,COND                                      F,JMP       F,HOLD;

MM31:   A,D B,L             ALUF,XORAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        MM4 CONDENABL;

        A,P B,P             ALUF,B+1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,L                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        MM41;

MM4:    A,P B,P             ALUF,B+1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        A,L                 ALUF,XORDA          ALUD,NONE
        IDBS,DBR            COMM,LDGPR          T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        MMERR CONDENABL;

MM41:   A,P B,X             ALUF,A-B-1          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        B,R2                ALUF,INVB           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        MM3 CONDENABL;

        B,R2                ALUF,INVB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        MM2 CONDENABL;

        A,T B,T             ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,D                 ALUF,INVB           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        MM1 CONDENABL;

        B,D                 ALUF,INVB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        MM0 CONDENABL;

        B,A                 ALUF,INVB           ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        443;
                                                ALUD,NONE
        IDBS,ALU                                ALUD,NONE
                                                T,NEXT      T,HOLD
        MM00 CONDENABL;

        AB,PRCHR                                ALUD,NONE
                            COMM,EWRF           T,JMP       T,HOLD
        IDBS,GPR
        RONLY;
MMERR:  B,D                 ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,L B,D             ALUF,XORAB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,T                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        ILLEG;








%**********************************
% " TYPED, SET READY FOR MANUAL INSTRUCTION

QUOTE:  AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        AB,BRKPT            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,MANIR                                ALUD,NONE
        IDBS,ARG            COMM,EWRF           T,JMP       T,HOLD
        SPAC9;





%***********************************************
% STOP-ROUTINE CONTINUED. CHECK FOR MANUAL INSTRUCTION (NOT USED BY MOPC)

MANIR:  AB,MANIR            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        AB,BRKPT                                ALUD,NONE
        IDBS,REG            COMM,LDGPR          T,JMP       T,HOLD
        CONT CONDENABL;


%***********************************************
% DO MANUAL INSTRUCTION

                                                ALUD,NONE
        IDBS,ALU            COMM,CLIRQ          T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,GPR            COMM,MAP            T,JMP       T,HOLD;






%***********************************************
% Z IS TYPED, MAKE READY FOR SINGLE INSTRUCTION

ZCHAR:  AB,BPFLG            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;


%***********************************************
% ILLEGAL IF BREAKPOINT IS ACTIVE

        AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        ILLEG CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        SINIT CONDENABL;





%**************************************************
% PERFORM ONE SINGLE INSTRUCTION IN Z OR BREAKPOINT MODE. USED BY STOP OR NOPC
% ALSO ENTERED FROM PAGE FAULTS & PROT. VIOLS. WHEN IN STOP

SINGL:
BRKZZ:                                          ALUD,NONE
        IDBS,ALU            COMM,START          T,NEXT      T,HOLD;
                                                ALUD,NONE
        IDBS,ALU            COMM,SSTOP          T,NEXT      T,HOLD;

%**************************************************
% EXECUTE ONE INSTRUCTION OR ONE INTERRUPT.

        B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,NEXT      T,HOLD;





%**************************************************
% MULTIPLE SINGLE, USED BY NOPC ONLY

SINIT:  AB,SINGL            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        SPAC9;




%****************************************
% ENTERED FROM INTERRUPT VECTOR. SINGLE BUTTON PRESSED
% ONLY LEGAL IN STOP

SING2:
        IDBS,ALU                                ALUD,NONE
                                                T,NEXT      T,HOLD
 COND,STP                                       F,NEXT      F,HOLD;

        IDBS,ALU                                ALUD,NONE
        SINGL CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;











%****************************************
% < TYPED

ANGBR:  AB,SCRAM            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        ILLEG CONDENABL;

        AB,CURNR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,DUMPF                                ALUD,NONE
        IDBS,BARG           COMM,EWRF           T,NEXT      T,HOLD;

        AB,OCTNR            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        CONT;





%****************************************
% * TYPED

ASTRX:  AB,OCTAD            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,PUSH
        PROCT;


        IDBS,ALU                                ALUD,NONE
        SPACE;                                  T,JMP       T,HOLD








%****************************************
% MOPC JUST PRINTED # AFTER LINE WAS ENDED

CR:     AB,PRCHR            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,DUMPF            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;

        AB,SCRAM            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        CR1 CONDENABL;

%*******************************
% DUMP SHOULD NOT BE STARTED
                            ALUF,Q-D            ALUD,NONE
                                                T,NEXT      T,HOLD
        IDBS,ARG
        114;

        B,0                                     ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD
        CR2 CONDENABL;


%*******************************
% IRD WRITTEN, TEST IF STOP

        B,3                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,PUSH
        STTST;


%*******************************
% SET UP FOR INTERNAL REGISTER DUMP

        AB,DUMPF            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,SCRAM            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        20;

        AB,UPPNR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,CURNR            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        DMP11;


%*******************************
%******************************
% IRD NOT WRITTEN

CR2:    B,5                 ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD;

        B,6                 ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
        CR21 CONDENABL;


%****************
% E WRITTEN

        AB,DEPOS            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        CR22 CONDENABL;

%******************************
% SET VIRTUAL EXAMINE
        B,R1                ALUF,PASSQ          ALUD,SLB
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R2                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        3;

        30 A,R1 B,R1        ALUF,ANDDA          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD;

        A,R1 B,R2           ALUF,ORAB           ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,2                 ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;


CR22:
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        EXM02;



%*******************************
% SEND ONE Q-BYTE TO NMM

DYTP7:                      ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDPANC         T,JMP       T,HOLD
        RONLY;





%*******************************
% E NOT TYPED, CHECK F

CR21:                                           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        CR20 CONDENABL;


%****************
% F TYPED

        B,17                                    ALUD,NONE
        IDBS,BARG           COMM,LDPANC         T,NEXT      T,HOLD;

        AB,OCTNR                                ALUD,NONE
        IDBS,REG            COMM,LDPANC         T,JMP       T,PUSH
        DYSWP;
                                                ALUD,NONE
        IDBS,ALU                                ALUD,NONE
                                                T,JMP       T,HOLD
        RONLY;

%****************************************
% F NOT TYPED, CHECK MACL

CR20:                       ALUF,Q-D            ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        176;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        CR23 CONDENABL;


%****************************************
% MACL TYPED

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MACL;

%****************************************
%CC MACL NOT TYPED, CHECK LCS

CR23:                       ALUF,Q-D            ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        111;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        CR3 CONDENABL;


%****************************************
%CC LCS TYPED
%CC COMM,MACL WILL GENERATE A PULSE ON PWCL, I.E. HARD RESET.
                                                ALUD,NONE
        IDBS,ALU            COMM,MACL           T,JMP       T,HOLD
        MACL;

%*******************************
% MACL NOT TYPED. CHECK STOP

CR3:                        ALUF,Q-D            ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        426;

        IDBS,ALU                                ALUD,NONE
                                                T,NEXT      T,HOLD
        CR16 CONDENABL;


%*******************************
% STOP TYPED

                                                ALUD,NONE
        IDBS,ALU            COMM,SSTOP          T,JMP       T,HOLD
        RONLY;




%*******************************
% NO SPECIAL CR FUNCTION. DEPOSIT OR NEXT MEMORY EXAMINE

CR16:   AB,DEPOS            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        CR4 CONDENABL;


%*******************************
% NOTHING TO DEPOSIT

        AB,SCRAM            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD;

        AB,DISPL            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
        ILLEG CONDENABL;  % ILLEGAL IF ANY LETTER HAS BEEN WRITTEN

        AB,OCTAD            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        RONLY CONDENABL;  % RONLY IF NOT MEMORY EXAMINE


%****************************************
% GET AND PRINT NEXT MEMORY ADDRESS

CR6:    AB,OCTAD            ALUF,Q+1            ALUD,Q
        IDBS,ALU            COMM,EWRF           T,JMP       T,PUSH
        DSPLY;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PROCT;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SPACE;



%****************************************
% SOMETHING TO DEPOSIT

CR4:                        ALUF,D-Q            ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        52;


%****************************************
% IF SCRAM IS UNEQUAL TO 'DEP'. CHECK THAT SCRAM = 0 AND STOP


        IDBS,ALU                                ALUD,NONE
        STTS0 CONDENABL;                        T,NEXT      T,HOLD

        AB,RONLY            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;
        AB,WRTYP            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        ILLEG CONDENABL;  % DEPOSIT IS ILLEGAL NOW


        B,1                 ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
        CR5 CONDENABL;




%*******************************
% MEMORY DEPOSIT


DEPOS:
        AB,OCTA2                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,PUSH
        SETEM;

        AB,OCTAD            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;
        AB,OCTNR                                ALUD,NONE
        IDBS,REG            COMM,DERQ           T,JMP       T,PUSH
        RESEM;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        CR6;

CR5:    B,2                 ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
        CR9 CONDENABL;



%*******************************
% REGISTER DEPOSIT. COMPARES WITH IR#

        AB,WRADR            ALUF,PASSD          ALUD,Q
        IDBS,REG            COMM,LDIRV          T,JMP       T,PUSH
        OPCRB;

        AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        CR10 CONDENABL;

        B,DEST              ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        CR10B;

                            ALUF,PASSQ          ALUD,NONE   STS,LO
        IDBS,ALU                                T,JMP       T,HOLD
        RONLY;

CR10:   A,REG B,DEST        ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,PUSH
        CR10B;

        A,REG B,Z           ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        RONLY;

CR10B:                      ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

        B,DEST              ALUF,PASSD          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP
        RONLY CONDENABL;

CR9:                                            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        CR11 CONDENABL;



%*******************************
% AUXILIARY REGISTER DEPOSIT

        AB,WRADR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,3 B,R6            ALUF,ORDQ           ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDIRV          T,NEXT      T,HOLD;

        A,R6                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,REG B,LC          ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        RONLY;



%*******************************
% INTERNAL REGISTER DEPOSIT

CR11:   A,A B,R7            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        CR12;

        A,R7 B,A            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        RONLY;

CR12:   AB,WRADR            ALUF,PASSD          ALUD,Q
        IDBS,REG            COMM,LDIRV          T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

        AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;



%****************************
% USE TRR

        B,A                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        TRR;










%****************************
% DUMP SHOULD STARTED AFTER CR

CR1:    A,5                 ALUF,Q-D            ALUD,NONE
        IDBS,AARG                               T,NEXT      T,HOLD
        CR13 CONDENABL;


%****************************
% MEMORY DUMP

        AB,OCTNR            ALUF,D+1            ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        AB,UPPNR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        DMP11;

CR13:                                           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        CR14 CONDENABL;


%*******************************
% REGISTER DUMP

        AB,OCTNR            ALUF,D+1            ALUD,B
        IDBS,REG                                T,JMP       T,PUSH
        CR15;

        AB,SCRAM            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        DMP11;

CR14:                       ALUF,Q-D            ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        125;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        ILLEG CONDENABL;


%*******************************
% REGISTER DUMP EXTENDED (AUXILIARY REGISTERS)

        AB,OCTNR            ALUF,D+1            ALUD,B
        IDBS,REG                                T,JMP       T,PUSH
        CR15;

        AB,SCRAM            ALUF,Q+1            ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;





%*******************************
%*******************************
% END OF DUMP SET-UP ROUTINES

DMP11:                      ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        15;

        AB,PRCHR            ALUF,PASSQ          ALUD,NONE
                            COMM,EWRF           T,NEXT      T,HOLD;

        AB,CNT10            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        CONT;



%*******************************
% SUBROUTINE COMMON FOR RD AND RDE

CR15:   AB,CURNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        AB,OCTNR            ALUF,PASSB          ALUD,SLD    ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;
        AB,OCTNR            ALUF,PASSB          ALUD,SLD    ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;
        AB,OCTNR            ALUF,PASSB          ALUD,SLD    ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,CURNR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,OCTNR            ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,UPPNR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,1                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,RETURN    T,POP;








%*******************************
% / TYPED

SLASH:  AB,SCRAM            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,11                ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        RWX CONDENABL;

        B,17                ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        IXX CONDENABL;
        B,4                 ALUF,D+Q            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        XXX CONDENABL;
        B,1                 ALUF,D+Q            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        TXX CONDENABL;
        B,3                 ALUF,D+Q            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        SXX CONDENABL;
        B,4                 ALUF,D+Q            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        PXX CONDENABL;
        B,13                ALUF,D+Q            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        LXX CONDENABL;
        B,1                 ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        AXX CONDENABL;
        B,2                 ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        BXX CONDENABL;
        B,16                ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        DXX CONDENABL;
        B,3                 ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        RXX CONDENABL;
        B,14                ALUF,Q-D            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        UXX CONDENABL;
        B,3                 ALUF,D+Q            ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        IOOPC CONDENABL;
        A,12                ALUF,Q-D            ALUD,Q
        IDBS,AARG                               T,JMP       T,HOLD
        ACTX CONDENABL;
        A,5                 ALUF,D+Q+1          ALUD,Q
        IDBS,AARG                               T,JMP       T,HOLD
        OPRX CONDENABL;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLEG;



%*******************************
% REGISTER NAMES/

SXX:    B,0                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        REGXX;
DXX:    B,1                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        REGXX;
PXX:    B,2                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        REGXX;
BXX:    B,3                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        REGXX;
LXX:    B,4                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        REGXX;
AXX:    B,5                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        REGXX;
TXX:    B,6                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        REGXX;
XXX:    B,7                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        REGXX;

REGXX:  B,R2                ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        OCDIX;



%****************
% R/

RXX:    AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        TYP1;

TYP1:   A,0 B,R1            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        RWY;



%********************
% I/

IXX:    AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

TYP3:   A,1 B,R1            ALUF,D+1            ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        RWY;






%****************************
% MEMORY EXAMINE

RWX:    B,R1                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;



%****************************
% REGISTER EXAMINE

RWY:    AB,OCTAD            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,WRADR            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,OCTN2            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        AB,OCTA2            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,R1                ALUF,PASSA          ALUD,Q
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        AB,DISPL            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,WRTYP            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        RWZ;



%****************************
% GET VALUE OF EXAMINE

RWZ:    AB,OCTAD            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,PUSH
        DSPLY;

        AB,RONLY            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,PUSH
        PROCT;

        AB,DISPL            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;


                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        LABEL CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SPACE;







%****************************
% IO/ TYPED

IOOPC:  A,A B,R4            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG            COMM,LDIRV          T,NEXT      T,HOLD;

        B,R1                ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,OPR              ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        B,A                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        IOXX1;

        A,A                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        PROCT;

        A,R4 B,A            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        RONLY;







%************************
% OPR/ TYPED

OPRX:   A,16                ALUF,D+1            ALUD,Q
        IDBS,AARG                               T,JMP       T,HOLD
        TYP2;







%************************
% U/ TYPED

UXX:                        ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        142;

TYP2:   A,1 B,R1            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        RWY;








%************************
% ACTX/ TYPED


ACTX:   B,17                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

        AB,DISPL            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,PUSH
        RONLY;




% SUBROUTINE FOR PGU- WIP- AND RING-DOWN TRAP

PTC:    A,PIL B,0           ALUF,PASSD          ALUD,Q      XRF
        IDBS,REG                                T,JMP       T,PUSH
        PTC4;
        A,R7                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;


                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,RETURN    T,POP;



PTC4:   A,2                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;
        A,15                ALUF,ANDDA          ALUD,NONE  % R5 .AND. BIT 13
        A,15                ALUF,ANDDA          ALUD,NONE  % R5 .AND. BIT 13
        IDBS,BMG                                T,NEXT      T,HOLD
        PTC3 CONDENABL;

% REX OR SEX-MODE

                            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,NEXT      T,HOLD
        PTC1 CONDENABL;

% REX-MODE

        7400 A,R7 B,R7      ALUF,ORDA           ALUD,B
        IDBS,ARG                                T,RETURN    T,POP;  % ARG IS 177400

% SEX-MODE

PTC1:
        7400 A,R7 B,R7      ALUF,ORDA           ALUD,SLB
        IDBS,ARG                                T,RETURN    T,POP;  % ARG IS 177400

% 20-BIT MODE OR 16-PT MODE

PTC3:                       ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,NEXT      T,HOLD
        PTC2 CONDENABL;

% 20-BIT MODE

        A,R7 B,R7           ALUF,ORDA           ALUD,SLB
        IDBS,ARG                                T,RETURN    T,POP;  % ARG IS 170000

% 16-PT MODE

PTC2:
        6000 A,R7           ALUF,ORDA           ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD;  % ARG IS 176000

        B,R7                ALUF,XORDQ          ALUD,SLB
        IDBS,ARG                                T,RETURN    T,POP
        1400;  % THESE TWO BITS MUST BE INVERTED TO MATCH THE PT LAYOUT




% PART OF BFILL-INSTRUCTION

BFIL3:
        IDBS,ALU                                ALUD,NONE
                                                T,JMP       T,PUSH
        BTR CONDENABL;  % FIRST BYTE NOT ON WORD BOUNDARY -> BTR
        B,T                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;




%******************************************
%******************************************

% FLOATING ADD & SUBTRACT INSTRUCTION. 32 BITS

%******************************************

 3172/
FAD1:   B,4                                     ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD;

        B,R2                ALUF,XORDQ          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

        B,STS               ALUF,PASSD          ALUD,B
        IDBS,STS            COMM,AREAD,NEXT     T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        100077;

        A,R2                ALUF,MASKDA         ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,A B,R4            ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,JMP       T,HOLD
        FAD0 CONDENABL;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,HOLD
        UNSF2 CONDENABL;

        A,R4 B,R3           ALUF,A-Q            ALUD,B
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,LC=0;

        B,R3                ALUF,PASSB COMM,LDGPR ALUD,SRB T,NEXT STS,ES T,POP
        IDBS,ARG
                                                            LCOUNT
        30;

        A,R3                ALUF,D-A            ALUD,NONE T,NEXT T,HOLD
        IDBS,GPR
 COND,F15                                       F,NEXT      F,HOLD;

        A,R3                ALUF,D+A            ALUD,NONE T,JMP T,HOLD
        IDBS,GPR
        STSST CONDENABL;

        B,R3                ALUF,PASSB          ALUD,NONE T,JMP T,HOLD
        IDBS,ALU
        UNSF2 CONDENABL;

        A,R3                ALUF,A+1 COMM,LDLC  ALUD,NONE T,JMP T,HOLD
        IDBS,ALU
        NED1 CONDENABL;

        A,R3                ALUF,PASSA          ALUD,NONE T,NEXT T,HOLD
        IDBS,ALU
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R3                ALUF,A-1 COMM,LDLC  ALUD,NONE T,JMP T,HOLD
        IDBS,ALU
        EQUAL CONDENABL;


%***********************************************
% AD-OPERAND GREATEST

        B,R1                ALUF,PASSB COMM,LDGPR ALUD,Q T,NEXT T,HOLD
        IDBS,ARG
        77;

        A,R2 B,R5           ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,A B,R3            ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,A B,R6            ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,JMP       T,HOLD
        NORM1;

FAD0:                                           ALUD,NONE
        IDBS,DBR                                T,JMP       T,HOLD
        STSST;

%***********************************************%
% MEMORY OPERAND GREATEST


NED1:   B,D                 ALUF,PASSB          ALUD,Q
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        77;

        A,R2 B,R6           ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,A B,R5            ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R1 B,D            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R2 B,R3           ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,JMP       T,HOLD
        NORM1;

%***********************************************%
% EQUAL EXPONENTS


EQUAL:  B,R1                ALUF,PASSB          ALUD,Q
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        77;
        A,A B,R3            ALUF,ANDDA          ALUD,B
        A,A B,R3            ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;
        A,R2 B,R5           ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,A B,R6            ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;


                                                ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        100;

        A,R5 B,R5           ALUF,ORDA           ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R3 B,R3           ALUF,ORDA           ALUD,B
        IDBS,GPR                                T,JMP       T,HOLD
        FADD;

%***********************************************
% ALIGNMENT SHIFT


NORM1:                                          ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        100;

        A,R5 B,R5           ALUF,ORDA           ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R3 B,R3           ALUF,ORDA           ALUD,B
        IDBS,GPR            COMM,CLFF           T,NEXT      T,PUSH
 COND,LC=0;

        B,R5                ALUF,PASSB          ALUD,SRD    MIS,ZIN ALUM,MIC STS,ES
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        B,R5                ALUF,PASSB          ALUD,SLD    MIS,LIN ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;


%****************************************
% EQUAL SIGNS?


FADD:   A,A B,R2            ALUF,XORAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,7 B,R1            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        SUBF CONDENABL;

%****************************************
% EQUAL SIGNS, ADD MANTISSAS


        A,D B,D             ALUF,A+Q            ALUD,Q      STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R5 B,R3           ALUF,A+B            ALUD,B      CRY,C
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R3 B,R1           ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,6 B,D             ALUF,PASSQ          ALUD,B
        IDBS,BMG            COMM,LDGPR          T,JMP       T,HOLD
        NOCRY CONDENABL;

%****************************************
% ADDITION GAVE CARRY


        A,R6 B,R2           ALUF,D+A            ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        B,R3                ALUF,PASSB          ALUD,SRD    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,D                 ALUF,PASSQ          ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        100;

        A,R2                ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,R3           ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,16                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,JMP       T,PUSH
        CHKOF;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        STSEX;

NOCRY:  A,R3 B,A            ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R6 B,A            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        STSST;




%***********************************************
% AD-OPERAND INSIGNIFICANT


UNSF2:  A,R2 B,A            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R1 B,D            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        STSST;


%***********************************************
% UNEQUAL SIGNS, SUBTRACT MANTISSAS

SUBF:   A,D B,D             ALUF,A-Q-1          ALUD,B      STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,R5           ALUF,A-B-1          ALUD,Q      CRY,C
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        INV CONDENABL;

        B,D                 ALUF,B+1            ALUD,B      STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,A                 ALUF,Q              ALUD,B      CRY,C
        IDBS,ALU                                T,JMP       T,HOLD
        NOINV;

%***********************************************
% INVERT ANSWER AFTER SUBTRACTION


INV:    B,A                 ALUF,INVQ           ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        100000;

        A,R6 B,R6           ALUF,XORDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        B,D                 ALUF,INVB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;


%***********************************************
% NORMALIZE ANSWER AFTER SUBTRACTION

NOINV:  B,R1                ALUF,D-1            ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        21;

        A,6 B,A             ALUF,PASSB          ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        B,D                 ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        FAD5 CONDENABL;

        A,R6 B,R4           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        FAD4 CONDENABL;

%***********************************************
% AD-OPERAND = 0


ZAD:    B,A                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,D                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        STSEX;


%***********************************************
% A-REG EQ ZERO D-REG NEQ ZERO

FAD4:   A,16 B,R5           ALUF,PASSD          ALUD,B
        IDBS,BMG            COMM,CLFF           T,NEXT      T,PUSH
 COND,F15;

        B,D                 ALUF,PASSB          ALUD,SLB    MIS,ROT ALUM,MIC
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        B,D                 ALUF,PASSB          ALUD,SRB    MIS,ROT ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,D                 ALUF,PASSB          ALUD,SRB    MIS,ROT ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R1 B,LC           ALUF,A-D            ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,LC=0;

        B,R2                ALUF,D+Q+1          ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        5;

        B,D                 ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,PUSH;

        B,A                 ALUF,PASSB          ALUD,SLD    MIS,ROT ALUM,MIC
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

                                                ALUD,NONE
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        4;

FAD6:   B,D                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,PUSH;

        A,6 B,R2            ALUF,PASSB          ALUD,SLB    MIS,ROT ALUM,MIC
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,POP
                                                            LCOUNT;

        A,A B,A             ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R6 B,R2           ALUF,A-B            ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CHKUF;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        STSEX;
                                                T,JMP       T,HOLD

%******************************************
% A-REG AND D-REG NEQ ZERO

FAD5:   A,A                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD;

        B,D                 ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
        FAD3 CONDENABL;

        A,16 B,R5           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,PUSH
 COND,F11;

        B,A                 ALUF,PASSB          ALUD,SLD    MIS,ZIN ALUM,MIC
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        B,D                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R1 B,LC           ALUF,A-D            ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,LC=0;

        B,R2                ALUF,Q-D-1          ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        5;

        B,D                 ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,PUSH;

        B,A                 ALUF,PASSB          ALUD,SRD    MIS,ZIN ALUM,MIC
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        B,4                                     ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,JMP       T,HOLD
        FAD6;

FAD3:   A,A B,A             ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R6 B,A            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        STSST;


%***********************************************
%***********************************************

% FLOATING MULTIPLY INSTRUCTION

%***********************************************

 3330/
FMU4:   B,R2                ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,AREAD,NEXT     T,NEXT      T,HOLD;

        B,STS               ALUF,PASSD          ALUD,B
        IDBS,STS                                T,NEXT      T,HOLD;

        B,R4                ALUF,PASSD          ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        77;

        A,A                 ALUF,MASKDA         ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,HOLD
        ZAD CONDENABL;

        A,R2 B,R3           ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;


%***********************************************
% ADD EXPONENTS

        A,R3                ALUF,A+Q            ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        ZAD CONDENABL;

        B,R6                ALUF,MASKDQ         ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        100000;

        A,A B,R2            ALUF,XORAB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,17 B,R5           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        FMU2 CONDENABL;

%***********************************************
% UNEQUAL SIGNS, CHANGE SIGNBIT


        A,R5 B,R6           ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

FMU2:   A,16 B,R5           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R5                ALUF,ANDAQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        B,R1                ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD
        FMU1 CONDENABL;

        A,R6 B,A            ALUF,XNORAB         ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R5                ALUF,ANDAQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,16 B,R1           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        OFUF CONDENABL;


%****************************************
% MULTIPLY MANTISSAS
%****************************************
FMU1:   A,R5 B,R6           ALUF,XORAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R4 B,A            ALUF,ANDAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R2 B,R4           ALUF,ANDAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,6 B,R1            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R1 B,R4           ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;


        A,R1 B,A            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,ZERO           ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,LC=0;

        B,R3                ALUF,ZERO           ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,PUSH
        17;

        A,D                 ALUF,A+Q            ALUD,Q      ALUM,FMU STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A B,R3            ALUF,A+B            ALUD,SRD    MIS,ZIN ALUM,FMU STS,EA CRY,C
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        A,R4                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

        B,5                                     ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,PUSH;

        A,D                 ALUF,A+Q            ALUD,Q      ALUM,FMU STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A B,R3            ALUF,A+B            ALUD,SRD    MIS,ZIN ALUM,FMU STS,EA CRY,C
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        A,D                 ALUF,A+Q            ALUD,Q      ALUM,FMU STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A B,R3            ALUF,A+B            ALUD,B      MIS,ZIN ALUM,FMU STS,EA CRY,C
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,7 B,R4            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R3 B,R4           ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,A            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        MCRY1 CONDENABL;

%***********************************************
% NO CARRY FROM LAST ADDITION IN MULTIPLY LOOP

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,D                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        ZAD CONDENABL;

        A,R1 B,A            ALUF,MASKAB         ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R6 B,R1           ALUF,A-B            ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CHKUF;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        STSEX;


%***********************************************
% CARRY FROM LAST ADDITION IN MULTIPLY LOOP

MCRY1:  A,R4 B,A            ALUF,MASKAB         ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,A                 ALUF,PASSB          ALUD,SRD    MIS,ZIN ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,D                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R6 B,A            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        STSEX;

%***********************************************
%***********************************************

% FLOATING DIVIDE INSTRUCTION

%***********************************************


 3405/
FDV4:   B,R2                ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,AREAD,NEXT     T,NEXT      T,HOLD;

        B,STS               ALUF,PASSD          ALUD,B
        IDBS,STS                                T,NEXT      T,HOLD;

        A,R2 B,R4           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        77;

        A,A                 ALUF,MASKDA         ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R5                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,HOLD
        ZAD CONDENABL;

        A,R2 B,R3           ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R3                ALUF,Q-A            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,A B,R2            ALUF,XORAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,17                ALUF,MASKDQ         ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD
        FDV2 CONDENABL;


%****************************************
% UNEQUAL SIGNS, CHANGE SIGNBIT


        A,17                ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;


FDV2:   B,R6                ALUF,XORDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        40000;

        A,R3                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,16 B,R1           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        FLOVF CONDENABL;

        A,R2 B,R1           ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,A B,R6            ALUF,XORAB          ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        FDV1 CONDENABL;

        A,R1                ALUF,ANDAQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,16 B,R1           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        FDV1 CONDENABL;

OFUF:   A,A B,R1            ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        FLOVF CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ZAD;


%****************************************
% DIVIDE MANTISSAS

FDV1:   B,R1                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        100;

        A,R4 B,R4           ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,A B,A             ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        6 A,R1 B,R4         ALUF,ORAB           ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD;

        A,R1 B,A            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,D                 ALUF,PASSB          ALUD,Q
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        0;

        A,7 B,R1            ALUF,PASSD          ALUD,B      STS,LO
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,LC=0;

        A,R5                ALUF,Q-A            ALUD,Q      STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R4 B,A            ALUF,B-A-1          ALUD,SLD    MIS,ZIN ALUM,MIC STS,ES CRY,C
        IDBS,ALU                                T,NEXT      T,PUSH;

        A,R5                ALUF,Q-A-1          ALUD,Q      ALUM,FDV STS,EA CRY,GPR
        IDBS,ALU                                T,NEXT      T,HOLD;
        A,R4 B,A            ALUF,B-A-1          ALUD,SLD    MIS,ZIN ALUM,FDV STS,ES CRY,C
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        B,R3                ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ARG            COMM,LDLC           T,NEXT      T,PUSH
        17;

        A,R5                ALUF,Q-A-1          ALUD,Q      ALUM,FDV STS,EA CRY,GPR
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R4 B,A            ALUF,B-A-1          ALUD,SLD    MIS,ZIN ALUM,FDV STS,ES CRY,C
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        A,R3 B,R1           ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,GPR                                T,JMP       T,HOLD
        POSDV CONDENABL;

        B,R3                ALUF,PASSB          ALUD,SRD    MIS,ZIN ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,6 B,D             ALUF,PASSQ          ALUD,B
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,R6                ALUF,D+A            ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R3 B,R3           ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,16                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,JMP       T,PUSH
        IDBS,BMG            COMM,LDGPR          T,JMP       T,PUSH
        CHKOF;
        A,R7                ALUF,PASSA          ALUD,NONE
        A,R7                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

STSST:
STSEX:  A,STS               ALUF,PASSA          ALUD,NONE   STS,LO
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;

POSDV:  A,6 B,D             ALUF,PASSQ          ALUD,B
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,R3 B,A            ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R6 B,A            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        STSST;

FLOVF:  A,Z B,D             ALUF,INVA           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        77777;

        A,R6 B,A            ALUF,ORDA           ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        10;

        A,STS B,STS         ALUF,ORAQ           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        STSEX;

CHKUF:  A,R6 B,R2           ALUF,MASKAQ         ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,R2 B,R5           ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A B,A             ALUF,ORAQ           ALUD,B
        IDBS,ALU                                T,RETURN    T,POP
        ZAD CONDENABL;

CHKOF:  B,R2                ALUF,INVQ           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R6 B,R2           ALUF,ANDAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        A,R2 B,R2           ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R3 B,A            ALUF,A+Q            ALUD,B
        IDBS,ALU                                T,RETURN    T,POP
        FLOVF CONDENABL;




%****************************************
%****************************************

% NORMALIZE INSTRUCTION

%****************************************

 3501/
NLZ3:   A,10                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        B,D                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        NLZ1 CONDENABL;

        B,A                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;

NLZ1:   B,R6                ALUF,D+Q            ALUD,B
        IDBS,GPR,SEXT                           T,NEXT      T,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,11                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD
        NLZ2 CONDENABL;

        A,R6 B,R6           ALUF,D+A            ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        B,A                 ALUF,-B             ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

NLZ2:   B,R5                ALUF,D-1            ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,PUSH
        21;

        B,A                 ALUF,PASSB          ALUD,SLB    MIS,ZIN ALUM,MIC STS,ES
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        B,A                 ALUF,PASSB          ALUD,SRB    MIS,LIN ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R5 B,LC           ALUF,A-D-1          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

        4 A,R6 B,R6         ALUF,A-Q            ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD;

        B,A                 ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,LC=0;

        B,R6                ALUF,PASSB          ALUD,SLD    ALUM,MIC
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        B,D                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R6 B,A            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;

%****************************************
%****************************************

% DENORMALIZE INSTRUCTION

%****************************************

        J523
DNZ2:   B,D                 ALUF,PASSB          ALUD,Q
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        4;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT                           T,NEXT      T,PUSH
 COND,LC=0;

        B,A                 ALUF,PASSB          ALUD,SRD
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        A,17 B,D            ALUF,PASSQ          ALUD,SRB
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,D B,D             ALUF,ORDA           ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R1 B,A            ALUF,A+B            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;
        B,R2                ALUF,D+Q            ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        20;

        B,R6                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        400;

        A,R2 B,R6           ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,JMP       T,HOLD
        ZAD2 CONDENABL;

        A,10                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        RDIVZ CONDENABL;

        A,11 B,R3           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,PUSH
 COND,LC=0;

        B,D                 ALUF,PASSB          ALUD,SRD    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        B,D                 ALUF,PASSB          ALUD,SLD
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A B,R3            ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,D                 ALUF,PASSB          ALUD,SLD
        IDBS,ALU                                T,JMP       T,HOLD
        DNZ1 CONDENABL;

        B,D                 ALUF,-B             ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

DNZ1:   A,D B,A             ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

ZAD3:   B,D                 ALUF,ZERO           ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


ZAD2:   B,A                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        ZAD3;





%****************************************
%****************************************
% VECTOR TO DETERMINE ALD-VALUES

%****************************************

 3560/

ALDVC:                      ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        0;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        1560;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        20500;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        21540;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        400;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        1600;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        21560;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        0;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        100000;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        101560;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        120500;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        121540;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        100400;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        101600;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        121560;
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        100000;








%****************************************
%******************************************
%******************************************
% VECTOR FOR SINTRAN CORE-MAP INSTRUCTIONS
%******************************************



VCS13:                                          ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        LDA8;
                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        LDX8;
                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        LDAD8;
                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        LDB8;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;
                            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        STAD8;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        STAD8;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        LDA8;
                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        LDX8;
                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        LDAD8;
                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        LDB8;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;
                            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        STAD8;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        STAD8;





%******************************************
%******************************************
% VECTOR FOR MOPC EXAMINE DISPLAY FUNCTION
%******************************************



VECT4:                                          ALUD,NONE  % MEM. EX. (0)
        IDBS,ALU                                T,JMP       T,HOLD
        EXAM1;

        A,A B,R7            ALUF,PASSA          ALUD,B  % REG. EX. (1)
        IDBS,ALU            COMM,CLIRQ          T,JMP       T,HOLD
        VC41;

        A,3 B,R6            ALUF,ORDQ           ALUD,B  % AUX. REG. EX. (2)
        IDBS,BMG            COMM,CLIRQ          T,JMP       T,HOLD
        VC42;

        A,A B,R7            ALUF,PASSA          ALUD,B  % INT. REG. EX. (3)
        IDBS,ALU                                T,JMP       T,HOLD
        VC43;



%********************************
% MOPC STOP-ROUTINE CONTINUED

STOP2:  AB,SINGL            ALUF,PASSD          ALUD,Q
        IDBS,REG            COMM,SSTOP          T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;
        AB,BPFLG            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,JMP       T,HOLD
        BPCHK CONDENABL;


%********************************
% MULTIPLE SINGLE IS ON

        AB,SINGL            ALUF,Q-1            ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        SINGL;

BPCHK:  AB,BRKPT            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        MANIR CONDENABL;


%********************************
% BREAKPOINT IS ON

        A,P                 ALUF,Q-A            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD
 COND,F=0                                       F,JMP       F,HOLD;
        A,6                 ALUF,D-1            ALUD,Q
        A,6                 ALUF,D-1            ALUD,Q
        IDBS,AARG                               T,NEXT      T,HOLD
        SINGL CONDENABL;


%****************************************
% BREAKPOINT IS FINISHED, PRINT

        AB,PRCHR            ALUF,Q-1            ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        RONLY;




%****************************************
% . PRINTED TO MOPC, SET UP BREAKPOINT MODE

DOT:    AB,OCTNR            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        AB,BRKPT            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        AB,BPFLG                                ALUD,NONE
        IDBS,ARG            COMM,EWRF           T,JMP       T,HOLD
        SPAC9;




 3637/
%****************************************
% LAST ENTRY IN VECT4 : DEFAULT DISPLAY MODE (ACTIVITY) (17)

        AB,ACTLV            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        VC417;












%***********************************************
%***********************************************

% VECTOR FOR 1504XX- INSTRUCTIONS (PON ETC.)

%***********************************************

VECT1:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        INPUT;

IOF:    A,17                ALUF,MASKDQ         ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        IOF2;

ION:    A,17                ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        ION2;

        A,7                                     ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,JMP       T,HOLD
        CONT;

POF:    A,16                ALUF,MASKDQ         ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        POF2;

PIOF:   A,16                ALUF,MASKDQ         ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        IOF;

SEX:    A,15                ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        POF2;

REX:    A,15                ALUF,MASKDQ         ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        POF2;

PON:    A,16                ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        POF2;

        A,7                                     ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,JMP       T,HOLD
        CONT;

PION:   A,16                ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        ION;

        A,7                                     ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,JMP       T,HOLD
        CONT;
        A,7                                     ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,JMP       T,HOLD
        CONT;
IOXT:                                           ALUD,NONE
                                                T,JMP       T,HOLD
        IOXT2;

EXAM:   A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        EXAM2;

DEPO:   A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        DEPO2;













%************************************************************
%************************************************************

% VECTOR FOR 1500XX-INSTRUCTIONS (TRA)

%************************************************************

VECT2:  B,A                 ALUF,PASSD          ALUD,B
        IDBS,MAPANS                             T,RETURN    T,HOLD;

TASTS:  B,A                 ALUF,PASSD          ALUD,B
        IDBS,STS                                T,RETURN    T,HOLD;

TAOPR:  AB,OPR              ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        APIE1;

TAPGS:  AB,PGS              ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        APGS1;

TAPVL:  AB,PVL              ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        APVL1;

TAIIC:  PIC,RSTS B,R5       ALUF,PASSD          ALUD,B
        IDBS,PIC            COMM,EPIC           T,JMP       T,HOLD
        AIIC1;

TAPID:  PIC,RMSK B,R1       ALUF,PASSD          ALUD,B
        IDBS,DSABL          COMM,EPIC           T,JMP       T,HOLD
        APID1;

TAPIE:  AB,PIE              ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        APIE1;

TACSR:  B,A                 ALUF,PASSD          ALUD,B
        IDBS,CSR                                T,RETURN    T,HOLD;

TAPIM:  A,PIL B,A           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,RETURN    T,HOLD;

TAALD:                                          ALUD,NONE
        IDBS,ALD            COMM,LDLC           T,JMP       T,HOLD
        AALD1;

TAPES:  B,A                 ALUF,PASSD          ALUD,B
        IDBS,PES                                T,JMP       T,HOLD
        APES1;

TAPGC:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        APGC1;

TAPEA:  B,A                 ALUF,PASSD          ALUD,B
        IDBS,PEA                                T,JMP       T,HOLD
        APES1;

        B,A                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,RETURN    T,HOLD;

TACS:   A,17                ALUF,INVD           ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        ACS;












%*******************************
%*******************************

% VECTOR FOR 1501XX-INSTRUCTIONS (TRR)

%*******************************

VECT3:  A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        RPANC;

TRSTS:                      ALUF,PASSQ          ALUD,NONE   STS,LO
        IDBS,ALU                                T,RETURN    T,HOLD;

TRLMP:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        RLMP1;

TRPCR:  A,17                ALUF,MASKDQ         ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        RPCR1;

TR4:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;

TRIIE:  A,A                 ALUF,A+Q            ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        RIIE1;

TRPID:  AB,PID              ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        RPID1;

TRPIE:  AB,PIE              ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        RPIE1;

TRCCL:  A,3                 ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        RCCL1;

TRCIL:  A,A                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        RCIL1;

TRCIU:  A,A                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        RCIU1;

TRCIPI: B,A                 ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,WCIHM          T,RETURN    T,HOLD;

TR4I:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;

TRECC:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        RECC1;

TR16:                                           ALUD,NONE
        IDBS,ALU                                            T,HOLD
        ILLIN;

TRCS:   A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        RCS;













%****************************************
%****************************************

% VECTOR FOR IOX JOX INSTRUCTIONS

%****************************************

TRMVC:                      ALUF,PASSD          ALUD,Q
        IDBS,IOR            COMM,XSLOW          T,JMP       T,HOLD
        TRM0;

%CC RETURN IF IN OPCOM

                                                ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP;

%CC NOT USED
                            ALUF,PASSD          ALUD,Q
                            COMM,UART,STATUS    T,JMP       T,HOLD
        IDBS,UART
        TRM2;

%CC READ UART STATUS REGISTER

        AB,OLD303           ALUF,XORDA          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        TRM3;

%CC OLD A-REG XOR NEW A-REG

        B,A                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;

%CC 0 -> AREG

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,UART,DATA      T,RETURN    T,POP;

%CC WRITE DATA TO UART

        B,A                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        TRM6;

        AB,STATUS           ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        TRM7;











%****************************************
%****************************************

% VECTOR FOR IOX 10-13

%****************************************

CLKVC:  A,A                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;
        A,7                 ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        CLK1;

        B,A                 ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,RETURN    T,POP
        11;

        A,0                 ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        CLK3;




 3740/
%****************************************
%****************************************
%
% I N T E R R U P T V E C T O R
%
%****************************************
%
%****************************************


ITSRV:  B,12                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        XINT;
        B,13                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        XINT;
        B,14                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        XINT;
        B,15                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        XINT;
        B,16                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        EXT14;
        B,16                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        EXT14;
        B,16                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        EXT14;
        B,16                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        EXT14;
        B,16                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        EXT14;
        B,16                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        EXT14;
        B,16                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        EXT14;
        B,16                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        EXT14;
        B,16                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        EXT14;
        B,16                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        EXT14;
        B,16                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        EXT14;
        B,17                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        XINT;

PANVC:  B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        STOP;
        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        MS20;
        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        PRQ;
        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        SING2;
        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        LOAD;
        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU            COMM,CLRTC          T,JMP       T,HOLD
        CONT;
        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        RSTRT;
        AB,MACL                                 ALUD,NONE
        IDBS,ARG            COMM,EWRF           T,JMP       T,HOLD
        MACL;

%


 4000/

%*******************************
%*******************************

% GECO-INSTRUCTION

%*******************************
%*******************************

GECO1:
        A,D B,R1            ALUF,A              ALUD,B      STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,RESTR                                     F,NEXT      F,PUSH;

        A,A B,R7            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        PRIVI CONDENABL;

        B,R7                ALUF,B              ALUD,B      CRY,C
        IDBS,ALU            COMM,LDSEG          T,NEXT      T,HOLD
 COND,LC=0;

        A,R1 B,R1           ALUF,A+1            ALUD,B,YA   STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        A,0 B,LC                                ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,NEXT      XRF T,POP
                                                            LCOUNT;

        A,B B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R2                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,PUSH
 COND,LC=0;

        A,R1 B,R1           ALUF,A+1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,0 B,LC                                ALUD,NONE
        IDBS,REG            COMM,WRRQ,APT       T,NEXT      XRF T,POP
                                                            LCOUNT;

        A,R2 B,17           ALUF,ANDDA          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

        A,L B,D             ALUF,A+B            ALUD,B      STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,A                 ALUF,B              ALUD,B      CRY,C
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,T B,B             ALUF,A+B            ALUD,B      STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,X                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT CONDENABL;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;



%**********************************
%****************************************

% GECOX-INSTRUCTION

%****************************************
%****************************************


GECX1:
        A,D B,R4            ALUF,A              ALUD,B      STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,RESTR                                     F,NEXT      F,HOLD;

        A,A B,R7            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        PRIVI CONDENABL;

        B,R5                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        4;

        13 A,R5 B,R6        ALUF,PASSA          ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD;

        A,L                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,PUSH;


        B,R7                ALUF,B              ALUD,B      CRY,C
        IDBS,ALU            COMM,LDSEG          T,NEXT      T,HOLD;

        A,R4 B,R4           ALUF,A+Q            ALUD,B,YA   STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R5                ALUF,B-1            ALUD,B
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD
 COND,F=0;

        B,LC                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,POP
                                                            LCOUNT;


        A,B B,Z             ALUF,A-B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;


GEC2:   13 A,T B,Z          ALUF,A+B            ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD;

        B,R5                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,PUSH
        4;


        B,R5                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0;

        B,LC                ALUF,PASSB          ALUD,SLD    MIS,ROT
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,COND;

        B,LC                ALUF,PASSB          ALUD,SLD    MIS,ROT
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,LC                ALUF,PASSB          ALUD,SLD    MIS,ROT
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,LC                ALUF,PASSB          ALUD,SLD    MIS,ROT
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;


        A,Z B,R6            ALUF,B-1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD
        GEC2 CONDENABL;


        A,T B,Z             ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

        A,R4 B,D            ALUF,PASSA          ALUD,B
                                                T,NEXT      T,HOLD;
        IDBS,ALU
        A,R7 B,A            ALUF,A              ALUD,B      CRY,C
                                                T,NEXT      T,HOLD;

        A,B B,B             ALUF,A+Q            ALUD,B      STS,EA
                                                T,NEXT      T,HOLD;

        B,X                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT CONDENABL;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;








%*****************************************************************
%*****************************************************************
%
% INSTRUCTIONS TO SPEED UP SINTRAN III SEGMENT HANDLING %
% THE INSTRUCTION GROUP 'SJSEG' OPCODE 1403XX %
%
%*****************************************************************
%*****************************************************************
%
% OPCODE 140300 : SETPT                                 %
%
% SETPT: JXZ * 10 % FINISHED                            %
% LDDTIX 20                                             %
% BSET ZRO 130 DA % PGU-BIT                             %
% LDBTX 10                                              %
% 177777 % OLD BUG IN LDBTX                             %
% STD ,B % ALWAYS INSIDE PAGE TABLE                     %
% LDDTIX 00                                             %
% JMP * -7                                              %
%
%********************************************************%
%
% OPCODE 140301 : CLEPT                                 %
%
% CLEPT: JXZ * 11 % FINISHED                            %
% LDBTX 10                                              %
% 177777 % OLD BUG IN LDBTX                             %
% LDA ,B                                                %
% JAZ * 3                                               %
% STATX 20 % ALWAYS INSIDE PAGE TABLE                   %
% STZ ,B                                                %
% LDDTIX 00                                             %
% JMP * -10                                             %
%
%********************************************************%
%
% OPCODE 140302 : CLNREENT                              %
%
% READ ADDRESS A+2 TO FIND PAGE TABLE TO BE AFFECTED    %
% READ RT-DESCRIPTION BITMAP WORDS. FOUND FROM ADDRESS X+25. %
% CLEAR PAGE-TABLE ENTRIES CORRESPONDING TO 1-BITS IN BITMAP. %
% THE LAST BITMAP-ADDRESS IS IN ADDRESS X+T.            %
%
%********************************************************%
%
% OPCODE 140303 ; CHREENTPAGES
%
%  1. READ ADDRESS D,X -> R1 ; D,X -> PREVIOUS (SCRATCH REG)
%  2. IF R1 = 0: SKIP RETURN (FINISHED)
%  3. READ ADDRESS T,R1+2
%  4. IF NOT WIF; T,R1 -> PREVIOUS; READ ADDR T,R1 -> R1; GOTO 2
%  5. READ ADDRESS T,R1 -> R2
%  6. WRITE R2 -> ADDRESS PREVIOUS
%  7. R1 -> X ; PREVIOUS -> D,A ; RETURN
%
%***********************************************************************
%
% OPCODE 140304 ; CLEUP
%
% AS 'CLEPT', BUT INCLUDING WORKING SET INFORMATION
% FOR ALL PAGE-TABLE ENTRIES HANDLED
% IF PGU OF ENTRY IS 1
%   D /1 300
%   B /1 776 SHR 1 - D
%   B-REG BITS 0-3 IS NOW BIT NUMBER
%   B-REG BITS 4-6 IS NOW WORD NUMBER
%   SET BIT IN 8-WORD TABLE IN PAGE-MAP BANK
%   POINTED TO BY L-REGISTER
%
% LAYOUT OF 8-WORD TABLE :
%
%   BIT 15                                             BIT 0
%   -----------------------------------------------
% L-REG -> WORD 0 # PAGE 17                             PAGE 0 #
%   WORD 1 # PAGE 37                                   20 #
%   WORD 2 # PAGE 57                                   40 #
%   .
%   WORD 7 # PAGE 177                                  160 #
%   .
%   -----------------------------------------------
%
%***********************************************************************
%***********************************************************************
%
S3SG1:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PVCHK;
        A,A                 ALUF,A+1            ALUD,Q
        A,A                 ALUF,A+1            ALUD,Q
        IDBS,ALU                                T,JMP0-3    T,HOLD
        SETPT;

%**********************************************************


SEPT1:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PATA1;

        B,R1                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,PUSH
        PATA4;

        B,R1                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        B,D                 ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,B                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R7 B,A            ALUF,MASKAB         ALUD,B
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;

        A,B                 ALUF,A+1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,IRQ                                       F,JMP       F,HOLD;

        A,D                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD
        PATA2 CONDENABL;
                            ALUF,B-1            ALUD,B
        B,P                                     T,JMP       T,POP
        IDBS,ALU
        CONT;

%****************************************************************


CLPU1:
CLPT1:
                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        600;

        A,D B,R4            ALUF,ANDAQ          ALUD,SLB
        IDBS,ALU                                T,JMP       T,PUSH
        PATA1;

        A,B                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;
                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,JMP       T,PUSH
        PATA4;

        A,A B,R7            ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        PATA2 CONDENABL;

        B,R1                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,COND                                      F,NEXT      F,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD;

        A,R4                ALUF,Q-A            ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        CLPT3 CONDENABL;
% CLEPU-INSTRUCTION AND PGU-BIT = 1
% CLEPU-INSTRUCTION AND PGU-BIT = 1
                                                T,NEXT      T,HOLD
        B,R3                ALUF,ANDDQ          ALUD,SRB  % BIT NO.
        IDBS,ARG                                T,NEXT      T,HOLD
        36;

        B,R6                ALUF,ANDDQ          ALUD,SLB
        IDBS,ARG                                T,NEXT      T,HOLD
        740;

        A,R6 B,R6           ALUF,A+B            ALUD,SLB
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R6                ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,L B,R6            ALUF,D+A            ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

        A,R6                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        A,R3                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,LC                ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R6                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD;

CLPT3:  A,B                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU
 COND,IRQ                                       T,NEXT      T,HOLD;
                                                F,JMP       F,HOLD
                            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD
        PATA2 CONDENABL;

        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,POP
        CONT;

%**********************************************************


PATA1:  A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,NEXT      T,HOLD;

PATA2:  A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,X                 ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,POP
        CONT CONDENABL;

        B,R1                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        B,B                 ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,B B,B             ALUF,A+B            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,B                 ALUF,ORDQ           ALUD,B
        IDBS,ARG                                T,RETURN    T,HOLD
        177000;




PATA4:  B,A                 ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,RETURN    T,POP
 COND,F=0                                       F,NEXT      F,HOLD;


%**********************************************************

CLNR1:                      ALUF,Q+1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,DBR                                T,JMP       T,POP
        CONT CONDENABL;

        B,R7                ALUF,ANDDQ          ALUD,SLB
        IDBS,ARG                                T,NEXT      T,HOLD
        300;

        B,R1                ALUF,D+A            ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        177000;

        A,X                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R2                ALUF,D+Q            ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        25;

        A,T B,R3            ALUF,A+Q+1          ALUD,B
        IDBS,ALU
 COND,F=0                                       T,NEXT      T,PUSH
                                                F,NEXT      F,HOLD;
        A,R2 B,R2           ALUF,A+1            ALUD,B,YA
        IDBS,ALU                                T,JMP       T,POP
        CONT CONDENABL;
                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,JMP       T,HOLD
        CLNR4;


CLNR4:  B,R4                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R1 B,17           ALUF,PASSA          ALUD,Q
        IDBS,BARG           COMM,LDLC           T,JMP       T,HOLD
        CLNR5 CONDENABL;

        A,0 B,R6            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        B,2                 ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,NEXT      T,PUSH
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R4 B,R6           ALUF,ANDAB          ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        CLNR3;

        B,R6                ALUF,PASSB          ALUD,SLB
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT
                                                F,NEXT      F,HOLD COND,F=0;

CLNR2:  A,R3 B,R2           ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,RETURN    T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;


CLNR3:  A,R1 B,R1           ALUF,A+Q            ALUD,B
        IDBS,ALU                                T,RETURN    T,POP
 COND,LC=0 CONDENABL;

        A,R1                ALUF,A-Q            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,RETURN    T,POP;

CLNR5:  A,5 B,R1            ALUF,D+Q            ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        CLNR2;

%****************************************

CHRE1:  A,D B,R6            ALUF,PASSA          ALUD,B
                            COMM,LDSEG          T,NEXT      T,HOLD;

        A,X B,R7            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

CHRE2:                                          ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,T B,R1            ALUF,B+1            ALUD,B,YA
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        CHRE4 CONDENABL;

        A,R1                ALUF,A+1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        A,R4                ALUF,ANDDA          ALUD,NONE
        IDBS,DBR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R1 B,R1           ALUF,A-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CHRE3 CONDENABL;

% WIP
                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        B,R2                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,R6 B,D            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,LDSEG          T,NEXT      T,HOLD;

        A,R7 B,A            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R2                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD;

        A,R1 B,X            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;

% NOT WIP

CHRE3:  A,T B,R6            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R1 B,R7           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CHRE2;

% FINISHED

CHRE4:  B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;





%*****************************************************************
%************************************************************
%
%
% MOVE-WORDS - INSTRUCTION : OPCODE 1+J1XX
%
%
%************************************************************
%************************************************************

MOVW1:  A,L                 ALUF,A-Q-1          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,CRY                                       F,NEXT      F,HOLD;


        IDBS,ALU                                ALUD,NONE
        CONT CONDENABL;                         T,JMP       T,HOLD  % > 2K WORDS

        A,L                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP0-3 T,NEXT T,HOLD
        MVWVC CONDENABL;

% 0 WORDS
                                                ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


% PT -> PT

MVWO:   A,D                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CPT;

        A,T                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CPTW;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PTRD;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,HOLD
        PTWR;


% PT -> APT

MVW1:   A,D                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CPT;

        A,T                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CAPTW;


        IDBS,ALU                                ALUD,NONE
        PTRD;                                   T,JMP       T,PUSH

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,HOLD
        APTWR;


% PT -> PHYSICAL

MVW2:                                           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,RESTR                                     F,NEXT      F,HOLD;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        PRIVI CONDENABL;

        A,D                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CPT;

                                                ALUD,NONE
        IDBS,DBR                                T,JMP       T,PUSH
        PTRD;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,HOLD
        PHWR;


% APT -> PT

MVW3:   A,D                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CAPT;

        A,T                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CPTW;


        IDBS,ALU                                ALUD,NONE
        APTRD;                                  T,JMP       T,PUSH

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,HOLD
        PTWR;


% APT -> APT

MVW4:   A,D                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CAPT;

        A,T                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CAPTW;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        APTRD;


        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,HOLD
        APTWR;


% APT -> PHYSICAL

MVW5:                                           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,RESTR                                     F,NEXT      F,HOLD;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        PRIVI CONDENABL;

        A,D                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CAPT;

        IDBS,DBR                                ALUD,NONE
        IDBS,DBR                                T,JMP       T,PUSH
        APTRD;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,HOLD
        PHWR;


% PHYSICAL -> PT

MVW6:                                           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,RESTR                                     F,NEXT      F,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        PRIVI CONDENABL;


        A,T                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CPTW;


        IDBS,ALU                                ALUD,NONE
        PHRD;                                   T,JMP       T,PUSH

        B,A                 ALUF,B              ALUD,B      CRY,C
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        PTWR;


% PHYSICAL -> API

MVW7:                                           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,RESTR                                     F,NEXT      F,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        PRIVI CONDENABL;

        A,T                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        CAPTW;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        PHRD;

        B,A                 ALUF,B              ALUD,B      CRY,C
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        APTWR;


% PHYSICAL -> PHYSICAL

MVW8:                                           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,RESTR                                     F,NEXT      F,PUSH;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        PRIVI CONDENABL;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,PUSH
        PHRD;

        A,X B,A             ALUF,B              ALUD,B,YA   CRY,C
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        PHWR;


% SUBROUTINES FOR MOVEM

% CHECK THAT PT-ADDRESSED FIELD IS PRESENT FOR READ

CPT:                        ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,PT        T,JMP       T,HOLD
        CPT1;


% CHECK THAT APT-ADDRESSED FIELD IS PRESENT FOR READ

CAPT:                       ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,JMP       T,HOLD
        CPT1;


CPT1:   A,L B,R2            ALUF,PASSA          ALUD,SRB    MIS,ZIN
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,R2                ALUF,A+Q            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,HOLD      T,NEXT      T,HOLD;

        A,L B,R2            ALUF,A-1            ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,R2                ALUF,A+Q            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,HOLD      T,NEXT      T,HOLD
 COND,IRQ                                       F,RETURN    F,POP;

                                                ALUD,NONE
        IDBS,DBR                                T,RETURN    T,HOLD;


% CHECK THAT PT-ADDRESSED FIELD IS PRESENT FOR WRITE

CPTW:                       ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,PT        T,JMP       T,HOLD
        CPTW1;


% CHECK THAT APT-ADDRESSED FIELD IS PRESENT FOR WRITE

CAPTW:                      ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,JMP       T,HOLD
CPTW1;

CPTW1:  B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,PUSH
        CPTW3;

        A,L B,R2            ALUF,PASSA          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,JMP       T,PUSH
        CPTW2;

        A,L B,R2            ALUF,A-1            ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        CPTW2;


        IDBS,ALU                                ALUD,NONE
                                                T,RETURN    T,HOLD
 COND,IRQ                                       F,RETURN    F,POP;

CPTW2:  A,R2 B,T            ALUF,A+B            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,HOLD      T,NEXT      T,HOLD;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

CPTW3:                      ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,HOLD      T,RETURN    T,POP;


% READ PT-WORD


PTRD:   A,D B,D             ALUF,B+1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD;

        IDBS,ALU                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,PT        T,JMP       T,HOLD
        INTER CONDENABL;


% READ APT-WORD

APTRD:  A,D B,D             ALUF,B+1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD;


        IDBS,ALU                                ALUD,NONE
                            COMM,RDRQ,APT       T,JMP       T,HOLD
        INTER CONDENABL;

% READ PHYSICAL WORD

PHRD:   A,D B,D             ALUF,B+1            ALUD,B,YA   STS,EA
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD
 COND,IRQ                                       F,RETURN    F,POP;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,JMP       T,HOLD
        INTER CONDENABL;


% INSTRUCTION IS INTERRUPTED

INTER:  B,D                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;


% WRITE PT-WORD

PTWR:   A,T B,L             ALUF,B-1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,HOLD;

        A,R1 B,T            ALUF,B+1            ALUD,B,YA
        IDBS,ALU            COMM,WRRQ,PT        T,NEXT      T,HOLD
        CONDENABL COND,IRQ                      F,RETURN    F,POP;

                                                ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


% WRITE APT-WORD

APTWR:  A,T B,L             ALUF,B-1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,HOLD;

        A,R1 B,T            ALUF,B+1            ALUD,B,YA
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD
        CONDENABL COND,IRQ                      F,RETURN    F,POP;

                                                ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


% WRITE PHYSICAL WORD

PHWR:   A,T B,L             ALUF,B-1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,HOLD;

        A,R1 B,T            ALUF,B+1            ALUD,B,YA   STS,EA
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD
 COND,COND                                      F,RETURN    F,HOLD;

        B,X                 ALUF,B              ALUD,B      CRY,C
        IDBS,ALU            COMM,LDSEG          T,NEXT      T,HOLD
        CONDENABL COND,IRQ                      F,RETURN    F,POP;

                                                ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;



%****************************************
%****************************************
% LOAD BYTE
%****************************************



LBYT1:  A,X B,R1            ALUF,PASSA          ALUD,SRB    MIS,ZIN ALUM,MIC
        IDBS,ALU                                T,JMP       T,PUSH
        LBYTM;


        IDBS,DBR            ALUF,PASSD          ALUD,Q
        LBYTU CONDENABL;                        T,JMP       T,PUSH


%****************************************
% CODE FOR BOTH UPPER AND LOWER BYTE

        B,A                 ALUF,ANDDQ          ALUD,B
        IDBS,ARG            COMM,CONTINUE       T,JMP       T,HOLD
        377;


%****************************************
% UPPER BYTE

LBYTU:                      ALUF,PASSD          ALUD,Q
        IDBS,SWAP                               T,RETURN    T,POP;



%****************************************
% SUBROUTINE TO CALCULATE ADDRESS IN LBYT AND SBYT

LBYTM:  A,T B,R1            ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,X B,1             ALUF,ANDDA          ALUD,NONE
        IDBS,BARG           COMM,RDRQ,APT       T,RETURN    T,POP
 COND,F=0                                       F,NEXT      F,HOLD;









%****************************************
%****************************************


% STORE BYTE

%****************************************

SBYT2:  B,R3                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

        A,A B,R3            ALUF,ANDAB          ALUD,B  % ISOLATE BYTE
        IDBS,ALU                                T,JMP       T,PUSH
        LBYTM;
                            ALUF,PASSD          ALUD,Q  % READ WORD
        IDBS,DBR                                T,JMP       T,HOLD

        SBYTU CONDENABL;


%****************************************
% LOWER BYTE

        B,R2                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        177400;



%****************************************
% BOTH BYTES

SBYT1:  A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,R2           ALUF,ORAB           ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,JMP       T,HOLD
        CONT;


%****************************************
% UPPER BYTE

SBYTU:  B,R2                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

        A,R3                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R3                ALUF,PASSD          ALUD,B
        IDBS,SWAP                               T,JMP       T,HOLD
        SBYT1;












%***********************************************
%***********************************************

% REGISTER MULTIPLY

%***********************************************

RMPY4:  A,SRCE B,R1         ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        B,DEST              ALUF,PASSB          ALUD,Q
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD
        RMPY1 CONDENABL;

        B,R1                ALUF,-B             ALUD,B  % FIRST OP. NEG.
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,COND                                      F,JMP       F,HOLD;

RMPY1:  B,16                ALUF,ZERO           ALUD,B
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD
        RMPY2 CONDENABL;

                            ALUF,-Q             ALUD,NONE  % SEC. OP. NEG.
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

RMPY2:                                          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,LC=0;

        A,R1 B,R6           ALUF,A+B            ALUD,SRD    MIS,ZIN ALUM,FMU  % MULTIPLY LOOP
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        A,SRCE B,DEST       ALUF,XORAB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        B,D                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        RMPY3 CONDENABL;

        A,R6 B,A            ALUF,PASSA          ALUD,B  % ANSWER POSITIVE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;

RMPY3:  B,D                 ALUF,-Q             ALUD,B      STS,EA  % ANSWER NEG.
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R6 B,A            ALUF,-A-1           ALUD,B      CRY,C
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;






%***********************************************
%***********************************************

% IDENT-INTRUCTION

%***********************************************

IDNT1:  A,R1 B,R1           ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,JMP       T,PUSH
        PVCHK;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R6                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        43;

        A,R1 B,R6           ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R1 B,4            ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        ID13 CONDENABL;

        A,R1 B,11           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        ID10 CONDENABL;

                            ALUF,PASSD          ALUD,Q
        IDBS,IOR                                T,JMP       T,HOLD
        IDX CONDENABL;


%***********************************************
% IDENT IS ON LEVEL 12, CHECK IF TERMINAL GAVE INTERRUPT

ID12:   A,16                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

%CC DA INV. POLARITY

        A,13                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
        IDX CONDENABL;

        AB,STATUS           ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        ID12B CONDENABL;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IDX;

ID12B:  A,1                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG            COMM,LDLC           T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;



%************************************************
% CPU-BOARD TERMINAL READY FOR TRANSFER

IDSPC:                                          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,COND                                      F,NEXT      F,HOLD;

        B,LC                ALUF,MASKDQ         ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        IDX CONDENABL;



%***********************************************
% DEVICE ON CPU-BOARD (TERMINAL OR CLOCK) READY FOR TRANSFER AND INT. ENABLED

IDRET:  A,0 B,A             ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,SIOC           T,NEXT      T,HOLD;

        AB,STATUS           ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        CONT;


%***********************************************
% IDENT IS ON LEVEL 10, CHECK IF TERMINAL GAVE INTERRUPT

ID10:   A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

                            ALUF,ANDDQ          ALUD,NONE
        IDBS,IOR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

%CC TBMT INVERSE POLARITY

        AB,STATUS           ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        IDX CONDENABL;

        A,2                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG            COMM,LDLC           T,JMP       T,HOLD
        IDSPC;



%***********************************************
% IDENT IS ON LEVEL 13, CHECK IF CLOCK GAVE INTERRUPT

ID13:   AB,STATUS           ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R2                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        11;

        A,R2 B,11           ALUF,D-A            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD;

        A,0                 ALUF,MASKDQ         ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        IDRET CONDENABL;




%***********************************************
% DEVICE IS NOT ON CPU-BOARD, SEND OUT GENERAL IDENT

IDX:    A,R1                ALUF,PASSA          ALUD,NONE  % ADDRESS -> IDENT
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE  % OUTPUT DATA
        IDBS,ALU            COMM,IDENT          T,NEXT      T,HOLD;

        B,A                 ALUF,PASSD          ALUD,B  % INPUT DATA
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;




%***********************************************
%***********************************************

% MULTIPLY SINGLE PRECISION

%***********************************************

MPY5:   B,STS               ALUF,MASKDQ         ALUD,B  % RESET DYN. OVERFLOW
        IDBS,ARG                                T,NEXT      T,HOLD
        20;

        A,A B,R2            ALUF,PASSA          ALUD,B  % COPY A-REG.
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        B,R3                ALUF,PASSD          ALUD,B  % READ MEM. OPERAND
        IDBS,DBR            COMM,LDGPR          T,NEXT      T,HOLD
        MPY1 CONDENABL;

        B,R2                ALUF,-B             ALUD,B  % NEGATIVE A-REG.
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,COND                                      F,JMP       T,HOLD;

MPY1:   B,16                ALUF,ZERO           ALUD,Q  % LOAD LOOP-COUNTER
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD
        MPY2 CONDENABL;

        A,R3                ALUF,-A             ALUD,NONE  % NEG. MEM.-OPERAND
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

MPY2:   B,R5                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,LC=0;

        A,R2 B,R5           ALUF,A+B            ALUD,SRD    MIS,ZIN ALUM,FMU  % MAKE RESULT IN R5
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        B,R5                ALUF,PASSB          ALUD,SLD    MIS,ZIN ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD;
        B,R5                ALUF,PASSB          ALUD,SRD    MIS,ZIN ALUM,MIC
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;
        B,R4                ALUF,ZERO           ALUD,B

        B,R4                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        MPY3 CONDENABL;

        B,R4                ALUF,PASSD          ALUD,B  % SET DYN. & STAT. OVF.
        IDBS,ARG                                T,NEXT      T,HOLD
        60;

MPY3:   A,STS B,R4          ALUF,ORAB           ALUD,NONE   STS,LO
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A B,R3            ALUF,XORAB          ALUD,NONE  % TEST SIGN
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        B,A                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        MPY4 CONDENABL;

        B,A                 ALUF,-B             ALUD,B  % INVERT RESULT
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;

MPY4:                                           ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;









%***********************************************
%************************************************

% SINTRAN III VERSION K MACROINSTRUCTIONS

% INSTRUCTION 1405XX


S3K1:   A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,JMP       T,PUSH
        PVCHK;

        A,1 B,R1            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP0-3    T,HOLD
        S3K1V;


% WRITE GLOBAL BANK POINTERS

WGB1:   AB,STBNK            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,A                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,STSRT            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,D                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,CMBNK            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,POP
        CONT;


% READ GLOBAL POINTERS

RGB1:   B,T                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,STSRT            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        B,A                 ALUF,PASSQ          ALUD,B
                                                T,NEXT      T,HOLD;

        AB,CMBNK            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        B,D                 ALUF,PASSQ          ALUD,B
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;





% INSERT PAGE IN PAGE LIST

INSP1:  A,B B,7             ALUF,D+A            ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;


        IDBS,ALU                                ALUD,NONE
                            COMM,EXRQ           T,NEXT      T,HOLD;
        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD;

        AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,NEXT      T,HOLD;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;
        IDBS,ALU
        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;
                            ALUF,PASSD          ALUD,Q
        AB,STSRT            ALUF,PASSD          ALUD,Q
        IDBS,REG
        INSP2 CONDENABL;

% NORMAL PAGE

        A,R1                ALUF,A+1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        IDBS,ALU                                ALUD,NONE
                            COMM,EXRQ           T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,R1                ALUF,A+1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        INSP3;

% FIRST PAGE

INSP2:  A,B B,R4            ALUF,A-Q            ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R4 B,3            ALUF,ORDA           ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

INSP3:  A,X B,R5            ALUF,A+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD;

        B,R4                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        3;

        A,X B,R4            ALUF,A+B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;


% REMOVE PAGE FROM PAGE LIST

REMP1:  A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,X                 ALUF,A+1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        B,R2                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,R2 B,3            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,1 B,R4            ALUF,D-1            ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD
        REMP2 CONDENABL;

% NORMAL PAGE

        A,R2                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        REMP3;

% LAST PAGE

REMP2:  A,R2 B,R2           ALUF,A+B            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        AB,STSRT            ALUF,D+Q            ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        AB,STBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,NEXT      T,HOLD;

        A,R4                ALUF,ORAQ           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

REMP3:  AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        REMP4 CONDENABL;

% NORMAL PAGE

        A,R1                ALUF,A+1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R2                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD;

REMP4:  A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;
                            ALUF,ZERO           ALUD,NONE
                            COMM,DERQ           T,NEXT      T,HOLD
        IDBS,ALU;
        A,X                 ALUF,A+1            ALUD,NONE
                                                T,NEXT      T,HOLD;
                            ALUF,ZERO           ALUD,NONE
                            COMM,DERQ           T,JMP       T,HOLD

        IDBS,ALU
        CONT;

% CLEAR NON-REENTRANT PAGES


CNRE1:  A,R1 B,A            ALUF,A+B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;
        A,A                 ALUF,PASSA          ALUD,NONE
                            COMM,EXRQ           T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
                                                T,JMP       T,POP
        IDBS,DBR
        CONT CONDENABL;

        B,R7                ALUF,ANDDQ          ALUD,SLB
                                                T,NEXT      T,HOLD
        IDBS,ARG
        1700;
        B,R1                ALUF,D+A            ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        174000;

        A,X                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,T B,R2            ALUF,PASSQ          ALUD,B,YA
        IDBS,ALU            COMM,LDSEG          T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R3                ALUF,D+Q            ALUD,B
        IDBS,ARG                                T,NEXT      T,PUSH
        10;

        A,R2 B,R2           ALUF,A+1            ALUD,B,YA
        IDBS,ALU                                T,JMP       T,POP
        CONT CONDENABL;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        CLNR4;



% CLEAR SEGMENT FROM PAGE TABLE (SIN III K)

CLPK1:  B,R2                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        176000;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,F=0                                       F,NEXT      F,HOLD;

        A,X B,R1            ALUF,A+B+1          ALUD,NONE
        IDBS,ALU                                T,JMP       T,POP
        CONT CONDENABL;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,R2 B,B            ALUF,ORDA           ALUD,SLB
        IDBS,DBR                                T,JMP       T,HOLD
        CLPK4 CONDENABL;

        A,B                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;

        B,R3                ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,X B,R1            ALUF,A+B            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        CLPK3 CONDENABL;

        A,R3 B,A            ALUF,PASSB          ALUD,B,YA
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

CLPK4:  A,B                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        CLPK3 CONDENABL;

                            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,JMP       T,HOLD
        CLPK3;


% ENTER SEGMENT INTO PAGE TABLE (SIN III K)

ENPK1:  A,13 B,R4           ALUF,INVD           ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        REPK2;


% ENTER REENTRANT SEGMENT INTO PAGE TABLE (SIN III K)

REPK1:  B,R4                ALUF,INVD           ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        104000;

REPK2:
        B,R2                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        176000;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,F=0                                       F,NEXT      F,HOLD;

        A,X B,R1            ALUF,A+B            ALUD,NONE
        IDBS,ALU                                T,JMP       T,POP
        CONT CONDENABL;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        A,R4 B,A            ALUF,ANDDA          ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,X B,R1            ALUF,A+B+1          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        A,X B,R3            ALUF,PASSA          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R3                ALUF,PASSB          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R2 B,B            ALUF,ORDA           ALUD,SLB
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,B                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;

        A,B                 ALUF,A+1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,JMP       T,HOLD
        CLPK3;


CLPK3:  A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,IRQ                                       F,RETURN    F,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        B,X                 ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,NEXT      T,POP
        CONDENABL COND,F=0                      F,NEXT      F,HOLD;

        B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;


% LOAD BYTE PHYSICAL

LBYP1:  A,X B,R1            ALUF,PASSA          ALUD,SRB    MIS,ZIN ALUM,MIC
        IDBS,ALU                                T,JMP       T,PUSH
        LBYPM;


        IDBS,DBR            ALUF,PASSD          ALUD,Q
        LBYTU CONDENABL;                        T,JMP       T,PUSH


%****************************************
% CODE FOR BOTH UPPER AND LOWER BYTE

        B,A                 ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;




%****************************************
% SUBROUTINE TO CALCULATE ADDRESS IN LBYT AND SBYT

LBYPM:  A,T B,R1            ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;
        A,X B,1             ALUF,ANDDA          ALUD,NONE
        IDBS,BARG           COMM,EXRQ           T,RETURN    T,POP
 COND,F=0                                       F,NEXT      F,HOLD;



% STORE BYTE PHYSICAL

SBYP1:  B,R3                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        377;
        A,A B,R3            ALUF,ANDAB          ALUD,B  % ISOLATE BYTE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,X B,R1            ALUF,PASSA          ALUD,SRB    MIS,ZIN ALUM,MIC
        IDBS,ALU                                T,JMP       T,PUSH
        LBYPM;


                            ALUF,PASSD          ALUD,Q  % READ WORD
        IDBS,DBR                                T,JMP       T,HOLD
        SBYPU CONDENABL;

%*******************************
% LOWER BYTE


        B,R2                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        177400;




SBYP2:  A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;
        A,R3 B,R2           ALUF,ORAB           ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;

SBYPU:  B,R2                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

        A,R3                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R3                ALUF,PASSD          ALUD,B
        IDBS,SWAP                               T,JMP       T,HOLD
        SBYP2;




% TEST AND SET PHYSICAL

TSTP1:
        A,3                 ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,JMP       T,PUSH
        WTCCL;  % WAIT FOR CACHE CLEAR TO FINISH

        IDBS,ALU                                ALUD,NONE
                            COMM,SSEMA          T,JMP       T,PUSH
        TSEP1;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,Z                 ALUF,A-1            ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD;
                                                ALUD,NONE
                            COMM,CONTINUE       T,JMP       T,HOLD
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD
        IDBS,ALU;

% READ DONT USE CACHE PUSH

% READ DONT USE CACHE PHYSICAL

RDUP1:
        A,3                 ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,JMP       T,PUSH
        WTCCL;  % WAIT FOR CACHE CLEAR TO FINISH

                                                ALUD,NONE
        IDBS,BARG           COMM,SSEMA          T,JMP       T,PUSH
        TSEP1;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        CONT;

TSEP1:  A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

        B,A                 ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,RETURN    T,POP;



% LOAD BIT LOGICAL PRIVILEGED

LBT1:   B,R1                ALUF,PASSB          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,JMP       T,PUSH
        LSBT1;

        A,X B,R1            ALUF,A+B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,LC                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,RDRQ,APT       T,JMP       T,HOLD
        LBT2;



% LOAD BIT PHYSICAL

LBTP1:  B,R1                ALUF,PASSB          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,JMP       T,PUSH
        LSBT1;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,NEXT      T,HOLD;

        A,X B,R1            ALUF,A+B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,LC                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,EXRQ           T,JMP       T,HOLD
        LBT2;


% STORE BIT LOGICAL PRIVILEGED

SBT1:   B,R1                ALUF,PASSB          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,JMP       T,PUSH
        LSBT1;

        A,X B,R1            ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,RDRQ,APT       T,JMP       T,PUSH
        SBT2;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,JMP       T,HOLD
        CONT;



% STORE BIT PHYSICAL

SBTP1:  B,R1                ALUF,PASSB          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,JMP       T,PUSH
        LSBT1;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,NEXT      T,HOLD;

        A,X B,R1            ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;


        IDBS,STS            ALUF,PASSD          ALUD,Q
        SBT2;               COMM,EXRQ           T,JMP       T,PUSH

                            ALUF,PASSQ
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;


LSBT1:  B,R1                ALUF,PASSB          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R1                ALUF,PASSB          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,RETURN    T,POP;


LBT2:                       ALUF,ANDDQ          ALUD,NONE
        IDBS,DBR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,STS                                T,NEXT      T,HOLD
        LBT3 CONDENABL;

        A,2                 ALUF,MASKDQ         ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
LBT4;

LBT3:   A,2                 ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

LBT4:                       ALUF,PASSQ          ALUD,NONE   STS,LO
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;



SBT2:   A,2                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,DBR                                T,NEXT      T,HOLD
 COND,COND                                      F,NEXT      F,HOLD;

        A,LC                ALUF,MASKDQ         ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        SBT4 CONDENABL;

        A,LC                ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

SBT4:   A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP;





% MACROINSTRUCTION 1407XX, S3K2

S3K2:
        AB,STBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,NEXT      T,HOLD
 COND,RESTR                                     F,NEXT      F,HOLD;

        B,SRCE              ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        PRIVI CONDENABL;

        A,B                 ALUF,A+Q            ALUD,NONE
        IDBS,ALU                                T,JMP0-3    T,HOLD
        S3K2V;





% LOAD A FROM COREMAP BANK

LACB1:  A,X                 ALUF,A+Q            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

LAB2:   B,A                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;


% STORE A IN COREMAP BANK

SACB1:  A,X                 ALUF,A+Q            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;


% LOAD X FROM COREMAP BANK


LXCB1:  A,X                 ALUF,A+Q            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;

LXB2:   B,X                 ALUF,PASSD          ALUD,B
        IDBS,DBR            COMM,CONTINUE       T,JMP       T,HOLD;



% STORE ZERO IN COREMAP BANK

SZCB1:  A,X                 ALUF,A+Q            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;
                            ALUF,ZERO           ALUD,NONE
                            COMM,DERQ           T,JMP       T,HOLD
        IDBS,ALU
        CONT;









%**********************************************************
%**********************************************************
%
% TSET - INSTRUCTION. OPCODE 140123. RDUS-INSTRUCTION. OPCODE 140127
%
%**********************************************************
%**********************************************************

TSET:
        A,16                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,T B,R5            ALUF,PASSQ          ALUD,B,YA
        IDBS,ALU                                T,JMP       T,HOLD
        TSET6 CONDENABL;

% PON, TSET-ACCESS WILL THEN ONLY BE DONE WHEN WRITE IS PERMITTED
% WIP WILL BE SET TO 1 BEFORE LOCK IS ISSUED

                            ALUF,PASSD          ALUD,Q
        IDBS,SWAP                               T,NEXT      T,HOLD;

        B,R7                ALUF,ANDDQ          ALUD,SRB  % LOG. P.N. * 2
        IDBS,ARG                                T,NEXT      T,HOLD
        374;
        A,PIL B,0                                           XRF
                            ALUF,PASSD          ALUD,Q  % PCR
        IDBS,REG                                T,JMP       T,PUSH
        TSET4;

        A,R7 B,R7           ALUF,ORAQ           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,NEXT      T,HOLD;  % PT-ENTRY

                            ALUF,PASSD          ALUD,Q
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,17                ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,14                ALUF,ORDQ           ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        TSTPV CONDENABL;

% WPN

        A,R7                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,NEXT      T,HOLD;  % 1 -> WIP

TSET6:
        A,3                 ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,JMP       T,PUSH
        WTCCL;  % WAIT FOR CACHE CLEAR TO FINISH

                                                ALUD,NONE
        IDBS,ALU            COMM,SSEMA          T,JMP       T,PUSH
        TSET1;
        A,T                 ALUF,PASSA          ALUD,NONE
                                                T,NEXT      T,HOLD
        IDBS,ALU;

        A,Z                 ALUF,A-1            ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;

% PAGE IS WRITE PROTECTED. PERFORM ACCESS TO GET TRAP

TSTPV:  A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;

% PV-TRAP OCCURS. THE FOLLOWING INSTRUCTION SHOULD NEVER BE EXECUTED
% MICROPROGRAM/HARDWARE ERROR !!!

TSTLO:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        TSTLO;



% SUBROUTINE TO SHIFT (R1 AND) THE Q-REGISTER 4 BITS RIGHT
QSH4:
        B,R1                ALUF,PASSB          ALUD,SRD    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R1                ALUF,PASSB          ALUD,SRD    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

% SUBROUTINE TO SHIFT (R1 AND) THE Q-REGISTER 2 BITS RIGHT
QSH2:
        B,R1                ALUF,PASSB          ALUD,SRD    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;
        B,R1                ALUF,PASSB          ALUD,SRD    MIS,ZIN
        IDBS,ALU                                T,RETURN    T,POP;



%******************************************
% ROUTINE TO DETERMINE PAGING MODE, AND FIND PT-ELEMENT.

TSET4:  A,2                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,15                ALUF,ANDDA          ALUD,NONE  % R5 .AND. BIT 13
        IDBS,BMG                                T,JMP       T,HOLD
        TSET3 CONDENABL;

% 16 PT-MODE OR 20-BIT MODE

        A,R5 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        TSET2 CONDENABL;

% 16 PT MODE

                            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,PUSH
        QSH4 CONDENABL;

        4000 A,R7 B,R7      ALUF,ORDA           ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD;  % ARG IS 17+4000

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        3600;

% 20-BIT MODE

TSET2:  A,0 B,R1            ALUF,PASSB          ALUD,SLD
        IDBS,AARG           COMM,LDSEG          T,JMP       T,HOLD
        TSET7 CONDENABL;
        B,R1                ALUF,PASSB          ALUD,SLD
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R1                ALUF,PASSB          ALUD,SLD
                                                T,NEXT      T,HOLD
        IDBS,ALU;

TSET7:  B,R1                ALUF,PASSB          ALUD,SLD
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        160000;

        A,R7 B,R7           ALUF,ORDA           ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;


        IDBS,ARG            ALUF,ANDDQ          ALUD,Q
        14000;                                  T,RETURN    T,POP

% REX OR SEX MODE

TSET3:  A,R5 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        TSET5 CONDENABL;

% SEX MODE

                            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,PUSH
        QSH2 CONDENABL;

        7000 A,R7 B,R7      ALUF,ORDA           ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD;  % ARG IS 177000


        IDBS,ARG            ALUF,ANDDQ          ALUD,Q
        600;                                    T,RETURN    T,POP

% REX MODE

TSET5:                      ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,PUSH
        QSH2 CONDENABL;

        7000 A,R7 B,R7      ALUF,ORDA           ALUD,SRD  % SIGN IS COPIED
        IDBS,ARG                                T,NEXT      T,HOLD;  % ARG IS 177000

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,RETURN    T,POP
        300;

% ****************************************

RDUS:
        A,3                 ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,JMP       T,PUSH
        WTCCL;  % WAIT FOR CACHE CLEAR TO FINISH

                                                ALUD,NONE
        IDBS,ALU            COMM,SSEMA          T,JMP       T,PUSH
        TSET1;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;


TSET1:
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;

        B,A                 ALUF,PASSD          ALUD,B
        IDBS,DBR                                T,RETURN    T,POP;


% SUBROUTINE FOR SEMAPHORE INSTRUCTIONS TO WAIT FOR CACHE CLEAR TO FINISH

WTCCL:
                            ALUF,ANDDQ          ALUD,NONE
        IDBS,CSR                                T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,POP;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        WTCCL CONDENABL;

%CC SUBROUTINE TO CHANGE BAUD RATE

BAUDS:                      ALUF,PASSD          ALUD,Q
        IDBS,IOR            COMM,XSLOW          T,NEXT      T,HOLD;

%CC IOR -) Q

        B,17                ALUF,ANDDQ          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

%CC BAUD RATE THUMBWHEEL POSITION IN Q

        AB,BAUD             ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

%CC SAVE IN REG FILE

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,LDIRV          T,NEXT      T,HOLD;

%CC SET UP FOR VECTOR JUMP

                                                ALUD,NONE
        IDBS,ALU                                T,JMP0-3    T,PUSH
        BAUDV;

%CC VECTOR JUMP

                                                ALUD,NONE
        IDBS,ALU            COMM,XSLOW          T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,SLOW           T,NEXT      T,HOLD;

%CC WAIT 625NS

                                                ALUD,NONE
        IDBS,ARG            COMM,UART,COM       T,RETURN    T,POP
        45;

%CC ENABLE TRANSMIT AND RECEIVE



% VECTOR FOR INSTRUCTIONS 1405XX, S3K1

 5660/
BAUDV:  IDBS,ARG 0          COMM,UART,MODE      T,RETURN    T,POP;  % EXT CLOCK
        IDBS,ARG 0          COMM,UART,MODE      T,RETURN    T,POP;  % EXT CLOCK
        IDBS,ARG 360        COMM,UART,MODE      T,RETURN    T,POP;  % 50 BAUD
        IDBS,ARG 361        COMM,UART,MODE      T,RETURN    T,POP;  % 75 BAUD
        IDBS,ARG 363        COMM,UART,MODE      T,RETURN    T,POP;  % 134.5 BAUD
        IDBS,ARG 365        COMM,UART,MODE      T,RETURN    T,POP;  % 200 BAUD
        IDBS,ARG 367        COMM,UART,MODE      T,RETURN    T,POP;  % 600 BAUD
        IDBS,ARG 374        COMM,UART,MODE      T,RETURN    T,POP;  % 2400 BAUD
        IDBS,ARG 376        COMM,UART,MODE      T,RETURN    T,POP;  % 9600 BAUD
        IDBS,ARG 375        COMM,UART,MODE      T,RETURN    T,POP;  % 4800 BAUD
        IDBS,ARG 372        COMM,UART,MODE      T,RETURN    T,POP;  % 1800 BAUD
        IDBS,ARG 371        COMM,UART,MODE      T,RETURN    T,POP;  % 1200 BAUD
        IDBS,ARG 374        COMM,UART,MODE      T,RETURN    T,POP;  % 2400 BAUD
        IDBS,ARG 366        COMM,UART,MODE      T,RETURN    T,POP;  % 300 BAUD
        IDBS,ARG 364        COMM,UART,MODE      T,RETURN    T,POP;  % 150 BAUD
        IDBS,ARG 362        COMM,UART,MODE      T,RETURN    T,POP;  % 110 BAUD

S3K1V:
WGLOB:  A,T                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        WGB1;

RGLOB:  AB,STBNK            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        RGB1;

INSPL:  AB,STBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        INSP1;

REMPL:  AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        REMP1;

CNREK:  AB,STBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        CNRE1;

CLPT:   AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        CLPK1;

ENPT:   AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        ENPK1;

REPT:   AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        REPK1;

LBIT:   A,A B,R1            ALUF,PASSA          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,JMP       T,HOLD
        LBT1;
LBITP:  A,A B,R1            ALUF,PASSA          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,JMP       T,HOLD
        LBTP1;
SBIT:   A,A B,R1            ALUF,PASSA          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,JMP       T,HOLD
        SBT1;
SBITP:  A,A B,R1            ALUF,PASSA          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,JMP       T,HOLD
        SBTP1;

LBYTP:  A,D                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        LBYP1;
SBYTP:  A,D                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        SBYP1;
TSETP:  A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        TSTP1;
RDUSP:  A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        RDUP1;


% VECTOR FOR INSTRUCTIONS 1407XX, S3K2.

 5720/
S3K2V:
LASB:                                           ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        LAB2;
SASB:   A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;
LACB:   AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        LACB1;
SACB:   AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        SACB1;
LXSB:                                           ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        LXB2;
LXCB:   AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        LXCB1;
SZSB:                       ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;
SZCB:   AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        SZCB1;

% DUPLICATED TO ALLOW FOR DISPLACEMENT BIT INSIDE VECTOR FIELD

                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        LAB2;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;
        AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        LACB1;
        AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        SACB1;
                                                ALUD,NONE
        IDBS,ALU            COMM,EXRQ           T,JMP       T,HOLD
        LXB2;
        AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        LXCB1;
                            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,DERQ           T,JMP       T,HOLD
        CONT;
        AB,CMBNK                                ALUD,NONE
        IDBS,REG            COMM,LDSEG          T,JMP       T,HOLD
        SZCB1;





%*************************************************************************
%*************************************************************************

% VECTOR TO FIND TYPE OF MOVE INSTRUCTION

 5740/

MVWVC:
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MVWO;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MVW1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MVW2;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MVW3;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MVW4;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MVW5;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MVW6;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MVW7;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MVW8;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
%


%************************************************************
%************************************************************
% VECTOR TO SELECT BETWEEN INSTRUCTIONS IN THE 1403XX-GROUP
%


 5760/

SETPT:  A,13 B,R7           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        SEPT1;

CLEPT:  B,R7                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CLPT1;

CLNRE:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        CLNR1;

CHREE:  A,14 B,R4           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        CHRE1;

CLEPU:  A,13 B,R7           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        CLPU1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;





%

 6000/
STZ:    A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;
        A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;
        A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;
        A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;

        A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;
        A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;
        A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;
        A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;

        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;
        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;
        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;
        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;

        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;
        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;
        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;
        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;

        A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;
        A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;
        A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;
        A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STZXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STZXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STZXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STZXB;

        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;
        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;
        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;
        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;

        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;
        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;
        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;
        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;


STA:    A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;

        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;

        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STAXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STAXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STAXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STAXB;

        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;

        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;



STT:    A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;

        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;

        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STTXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STTXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STTXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STTXB;

        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;

        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;




STX:    A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        CONT;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        CONT;

        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;
        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;
        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;
        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1I;

        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;
        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;
        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;
        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1I;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        CONT;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STXXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STXXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STXXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STXXB;

        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;
        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;
        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;
        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STR1IX;

        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;
        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;
        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;
        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STR1IX;



STD:    A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        STD1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        STD1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        STD1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        STD1;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        STD1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        STD1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        STD1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        STD1;

        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STDI;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STDI;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STDI;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STDI;

        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STDI;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STDI;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STDI;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STDI;

        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        STD1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        STD1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        STD1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        STD1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STDXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STDXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STDXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STDXB;

        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STDIX;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STDIX;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STDIX;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STDIX;

        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STDIX;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STDIX;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STDIX;
        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STDIX;

LDD:                                            ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDD1;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDD1;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDDI;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDDI;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDD1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDDXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDDXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDDXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDDXB;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDDIX;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDDIX;


STF:    A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        STF1;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        STF1;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        STF1;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,*       T,JMP       T,HOLD
        STF1;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        STF1;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        STF1;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        STF1;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,B       T,JMP       T,HOLD
        STF1;

        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STFI;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STFI;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STFI;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STFI;

        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STFI;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STFI;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STFI;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STFI;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        STF1;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        STF1;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        STF1;
        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,AWRITE,X       T,JMP       T,HOLD
        STF1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STFXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STFXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STFXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        STFXB;

        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STFIX;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STFIX;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STFIX;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        STFIX;

        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STFIX;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STFIX;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STFIX;
        A,T B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        STFIX;

LDF:                                            ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDF1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDF1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDF1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDF1;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDF1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDF1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDF1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDF1;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDFI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDFI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDFI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDFI;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDFI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDFI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDFI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDFI;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDF1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDF1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDF1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDF1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDFXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDFXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDFXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDFXB;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDFIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDFIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDFIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDFIX;
        IDBS,ALU LDFIX      COMM,IREAD,PT       ALUD,NONE T,JMP T,HOLD
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDFIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDFIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDFIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDFIX;

MIN:                                            ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        MIN1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        MIN1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        MIN1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        MIN1;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        MIN1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        MIN1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        MIN1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        MIN1;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        MINI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        MINI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        MINI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        MINI;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        MINI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        MINI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        MINI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        MINI;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        MIN1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        MIN1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        MIN1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        MIN1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        MINXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        MINXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        MINXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        MINXB;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        MINIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        MINIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        MINIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        MINIX;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        MINIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        MINIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        MINIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        MINIX;

LDA:                                            ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDA1;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDA1;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDAI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDAI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDAI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDAI;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDAI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDAI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDAI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDAI;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDA1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDAXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDAXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDAXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDAXB;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDAIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDAIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDAIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDAIX;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDAIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDAIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDAIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDAIX;


LDT:                                            ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDT1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDT1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDT1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDT1;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDT1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDT1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDT1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDT1;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDTI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDTI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDTI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDTI;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDTI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDTI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDTI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDTI;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDT1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDT1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDT1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDT1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDTXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDTXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDTXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDTXB;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDTIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDTIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDTIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDTIX;
        IDBS,ALU LDTIX      COMM,IREAD,APT      ALUD,NONE T,JMP T,HOLD
        IDBS,ALU LDTIX      COMM,IREAD,APT      ALUD,NONE T,JMP T,HOLD
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDTIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDTIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDTIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDTIX;


LDX:                                            ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDX1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDX1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDX1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        LDX1;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDX1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDX1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDX1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        LDX1;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDXI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDXI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDXI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDXI;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDXI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDXI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDXI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDXI;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDX1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDX1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDX1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        LDX1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDXXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDXXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDXXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        LDXXB;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDXIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDXIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDXIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        LDXIX;
        IDBS,ALU LDXIX      COMM,IREAD,APT      ALUD,NONE T,JMP T,HOLD
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDXIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDXIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDXIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        LDXIX;


ADD:                                            ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        ADD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        ADD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        ADD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        ADD1;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        ADD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        ADD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        ADD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        ADD1;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ADDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ADDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ADDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ADDI;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ADDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ADDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ADDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ADDI;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        ADD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        ADD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        ADD1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        ADD1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        ADDXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        ADDXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        ADDXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        ADDXB;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ADDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ADDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ADDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ADDIX;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ADDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ADDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ADDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ADDIX;



SUB:                                            ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        SUB1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        SUB1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        SUB1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        SUB1;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        SUB1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        SUB1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        SUB1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        SUB1;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        SUBI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        SUBI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        SUBI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        SUBI;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        SUBI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        SUBI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        SUBI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        SUBI;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        SUB1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        SUB1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        SUB1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        SUB1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        SUBXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        SUBXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        SUBXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        SUBXB;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        SUBIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        SUBIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        SUBIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        SUBIX;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        SUBIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        SUBIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        SUBIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        SUBIX;



AND:                                            ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        AND1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        AND1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        AND1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        AND1;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        AND1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        AND1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        AND1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        AND1;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ANDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ANDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ANDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ANDI;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ANDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ANDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ANDI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ANDI;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        AND1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        AND1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        AND1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        AND1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        ANDXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        ANDXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        ANDXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        ANDXB;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ANDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ANDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ANDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ANDIX;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ANDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ANDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ANDIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ANDIX;



ORA:                                            ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        ORA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        ORA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        ORA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        ORA1;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        ORA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        ORA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        ORA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        ORA1;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ORAI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ORAI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ORAI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ORAI;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ORAI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ORAI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ORAI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ORAI;

                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        ORA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        ORA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        ORA1;
                                                ALUD,NONE
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        ORA1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        ORAXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        ORAXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        ORAXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        ORAXB;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ORAIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ORAIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ORAIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        ORAIX;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ORAIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ORAIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ORAIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        ORAIX;


FAD:                        ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        FAD1;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        FAD1;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        FAD1;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,*        T,JMP       T,HOLD
        FAD1;

                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        FAD1;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        FAD1;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        FAD1;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,B        T,JMP       T,HOLD
        FAD1;

                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        FADI;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        FADI;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        FADI;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        FADI;

                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        FADI;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        FADI;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        FADI;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        FADI;

                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        FAD1;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        FAD1;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        FAD1;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,AREAD,X        T,JMP       T,HOLD
        FAD1;
        A,X B,B IDBS,GPR FADXB ALUF,A+B         ALUD,NONE T,JMP T,HOLD
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FADXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FADXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FADXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FADXB;

                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        FADIX;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        FADIX;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        FADIX;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        FADIX;
        IDBS,ALU FADIX      ALUF,ZERO COMM,IREAD,APT ALUD,Q T,JMP T,HOLD
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        FADIX;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        FADIX;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        FADIX;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        FADIX;


FSB:    A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,*        T,JMP       T,HOLD
        FAD1;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,*        T,JMP       T,HOLD
        FAD1;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,*        T,JMP       T,HOLD
        FAD1;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,*        T,JMP       T,HOLD
        FAD1;

        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,B        T,JMP       T,HOLD
        FAD1;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,B        T,JMP       T,HOLD
        FAD1;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,B        T,JMP       T,HOLD
        FAD1;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,B        T,JMP       T,HOLD
        FAD1;

        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FADI;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FADI;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FADI;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FADI;

        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FADI;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FADI;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FADI;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FADI;

        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,X        T,JMP       T,HOLD
        FAD1;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,X        T,JMP       T,HOLD
        FAD1;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,X        T,JMP       T,HOLD
        FAD1;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,AREAD,X        T,JMP       T,HOLD
        FAD1;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FSBXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FSBXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FSBXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FSBXB;

        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FADIX;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FADIX;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FADIX;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FADIX;

        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FADIX;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FADIX;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FADIX;
        A,17                ALUF,PASSD          ALUD,Q
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FADIX;

FMU:    A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,*        T,JMP       T,HOLD
        FMU4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,*        T,JMP       T,HOLD
        FMU4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,*        T,JMP       T,HOLD
        FMU4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,*        T,JMP       T,HOLD
        FMU4;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,B        T,JMP       T,HOLD
        FMU4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,B        T,JMP       T,HOLD
        FMU4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,B        T,JMP       T,HOLD
        FMU4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,B        T,JMP       T,HOLD
        FMU4;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FMUI;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FMUI;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FMUI;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FMUI;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FMUI;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FMUI;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FMUI;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FMUI;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,X        T,JMP       T,HOLD
        FMU4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,X        T,JMP       T,HOLD
        FMU4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,X        T,JMP       T,HOLD
        FMU4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,X        T,JMP       T,HOLD
        FMU4;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FMUXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FMUXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FMUXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FMUXB;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FMUIX;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FMUIX;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FMUIX;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FMUIX;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FMUIX;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FMUIX;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FMUIX;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FMUIX;

FDV:    A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,*        T,JMP       T,HOLD
        FDV4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,*        T,JMP       T,HOLD
        FDV4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,*        T,JMP       T,HOLD
        FDV4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,*        T,JMP       T,HOLD
        FDV4;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,B        T,JMP       T,HOLD
        FDV4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,B        T,JMP       T,HOLD
        FDV4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,B        T,JMP       T,HOLD
        FDV4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,B        T,JMP       T,HOLD
        FDV4;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FDVI;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FDVI;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FDVI;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FDVI;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FDVI;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FDVI;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FDVI;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FDVI;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,X        T,JMP       T,HOLD
        FDV4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,X        T,JMP       T,HOLD
        FDV4;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,X        T,JMP       T,HOLD
        FDV4;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,AREAD,X        T,JMP       T,HOLD
        FDV4;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FDVXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FDVXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FDVXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        FDVXB;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FDVIX;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FDVIX;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FDVIX;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,PT       T,JMP       T,HOLD
        FDVIX;

        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FDVIX;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FDVIX;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FDVIX;
        A,1 B,STS           ALUF,INVD           ALUD,B
        IDBS,BMG            COMM,IREAD,APT      T,JMP       T,HOLD
        FDVIX;


MPY:                        ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,*        T,JMP       T,HOLD
        MPY5;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,*        T,JMP       T,HOLD
        MPY5;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,*        T,JMP       T,HOLD
        MPY5;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,*        T,JMP       T,HOLD
        MPY5;

                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,B        T,JMP       T,HOLD
        MPY5;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,B        T,JMP       T,HOLD
        MPY5;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,B        T,JMP       T,HOLD
        MPY5;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,B        T,JMP       T,HOLD
        MPY5;

                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,PT       T,JMP       T,HOLD
        MPYI;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,PT       T,JMP       T,HOLD
        MPYI;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,PT       T,JMP       T,HOLD
        MPYI;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,PT       T,JMP       T,HOLD
        MPYI;

                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,APT      T,JMP       T,HOLD
        MPYI;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,APT      T,JMP       T,HOLD
        MPYI;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,APT      T,JMP       T,HOLD
        MPYI;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,APT      T,JMP       T,HOLD
        MPYI;

                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,X        T,JMP       T,HOLD
        MPY5;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,X        T,JMP       T,HOLD
        MPY5;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,X        T,JMP       T,HOLD
        MPY5;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,AREAD,X        T,JMP       T,HOLD
        MPY5;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        MPYXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        MPYXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        MPYXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        MPYXB;

                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,PT       T,JMP       T,HOLD
        MPYIX;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,PT       T,JMP       T,HOLD
        MPYIX;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,PT       T,JMP       T,HOLD
        MPYIX;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,PT       T,JMP       T,HOLD
        MPYIX;

                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,APT      T,JMP       T,HOLD
        MPYIX;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,APT      T,JMP       T,HOLD
        MPYIX;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,APT      T,JMP       T,HOLD
        MPYIX;
                            ALUF,PASSD          ALUD,Q
        IDBS,STS            COMM,IREAD,APT      T,JMP       T,HOLD
        MPYIX;


JUMP:                                           ALUD,NONE
        IDBS,LA             COMM,JMP,*          T,JMP       T,HOLD;
                                                ALUD,NONE
        IDBS,LA             COMM,JMP,*          T,JMP       T,HOLD;
                                                ALUD,NONE
        IDBS,LA             COMM,JMP,*          T,JMP       T,HOLD;
                                                ALUD,NONE
        IDBS,LA             COMM,JMP,*          T,JMP       T,HOLD;

                                                ALUD,NONE
        IDBS,LA             COMM,JMP,B          T,JMP       T,HOLD;
                                                ALUD,NONE
        IDBS,LA             COMM,JMP,B          T,JMP       T,HOLD;
                                                ALUD,NONE
        IDBS,LA             COMM,JMP,B          T,JMP       T,HOLD;
                                                ALUD,NONE
        IDBS,LA             COMM,JMP,B          T,JMP       T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPI;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPI;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPI;

                                                ALUD,NONE
        IDBS,LA             COMM,JMP,X          T,JMP       T,HOLD;
                                                ALUD,NONE
        IDBS,LA             COMM,JMP,X          T,JMP       T,HOLD;
                                                ALUD,NONE
        IDBS,LA             COMM,JMP,X          T,JMP       T,HOLD;
                                                ALUD,NONE
        IDBS,LA             COMM,JMP,X          T,JMP       T,HOLD;

        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        JMPXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        JMPXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        JMPXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        JMPXB;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPIX;

                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPIX;
                                                ALUD,NONE
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPIX;


JAP:    A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,NF15      T,JMP       T,HOLD
        CJP1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,NF15      T,JMP       T,HOLD
        CJP1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,NF15      T,JMP       T,HOLD
        CJP1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,NF15      T,JMP       T,HOLD
        CJP1;

JAN:    A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F15       T,JMP       T,HOLD
        CJP1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F15       T,JMP       T,HOLD
        CJP1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F15       T,JMP       T,HOLD
        CJP1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F15       T,JMP       T,HOLD
        CJP1;

JAZ:    A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F=0       T,JMP       T,HOLD
        CJP1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F=0       T,JMP       T,HOLD
        CJP1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F=0       T,JMP       T,HOLD
        CJP1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F=0       T,JMP       T,HOLD
        CJP1;

JAF:    A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,NF=0      T,JMP       T,HOLD
        CJP1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,NF=0      T,JMP       T,HOLD
        CJP1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,NF=0      T,JMP       T,HOLD
        CJP1;
        A,A                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,NF=0      T,JMP       T,HOLD
        CJP1;

JPC:    B,X                 ALUF,B+1            ALUD,B
        IDBS,LA             COMM,CJMP,NF15      T,JMP       T,HOLD
        CJP1;
        B,X                 ALUF,B+1            ALUD,B
        IDBS,LA             COMM,CJMP,NF15      T,JMP       T,HOLD
        CJP1;
        B,X                 ALUF,B+1            ALUD,B
        IDBS,LA             COMM,CJMP,NF15      T,JMP       T,HOLD
        CJP1;
        B,X                 ALUF,B+1            ALUD,B
        IDBS,LA             COMM,CJMP,NF15      T,JMP       T,HOLD
        CJP1;

JNC:    B,X                 ALUF,B+1            ALUD,B
        IDBS,LA             COMM,CJMP,F15       T,JMP       T,HOLD
        CJP1;
        B,X                 ALUF,B+1            ALUD,B
        IDBS,LA             COMM,CJMP,F15       T,JMP       T,HOLD
        CJP1;
        B,X                 ALUF,B+1            ALUD,B
        IDBS,LA             COMM,CJMP,F15       T,JMP       T,HOLD
        CJP1;
        B,X                 ALUF,B+1            ALUD,B
        IDBS,LA             COMM,CJMP,F15       T,JMP       T,HOLD
        CJP1;

JXZ:    A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F=0       T,JMP       T,HOLD
        CJP1;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F=0       T,JMP       T,HOLD
        CJP1;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F=0       T,JMP       T,HOLD
        CJP1;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F=0       T,JMP       T,HOLD
        CJP1;

JXN:    A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F15       T,JMP       T,HOLD
        CJP1;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F15       T,JMP       T,HOLD
        CJP1;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F15       T,JMP       T,HOLD
        CJP1;
        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,LA             COMM,CJMP,F15       T,JMP       T,HOLD
        CJP1;


JPL:    A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,LA             COMM,JMP,*          T,JMP       T,HOLD;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,LA             COMM,JMP,*          T,JMP       T,HOLD;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,LA             COMM,JMP,*          T,JMP       T,HOLD;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,LA             COMM,JMP,*          T,JMP       T,HOLD;

        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,LA             COMM,JMP,B          T,JMP       T,HOLD;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,LA             COMM,JMP,B          T,JMP       T,HOLD;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,LA             COMM,JMP,B          T,JMP       T,HOLD;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,LA             COMM,JMP,B          T,JMP       T,HOLD;

        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPI;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPI;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPI;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPI;

        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPI;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPI;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPI;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPI;

        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,LA             COMM,JMP,X          T,JMP       T,HOLD;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,LA             COMM,JMP,X          T,JMP       T,HOLD;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,LA             COMM,JMP,X          T,JMP       T,HOLD;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,LA             COMM,JMP,X          T,JMP       T,HOLD;
        A,X B,B IDBS,GPR JMPXB ALUF,A+B         ALUD,NONE T,JMP T,HOLD
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        JMPXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        JMPXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        JMPXB;
        A,X B,B             ALUF,A+B            ALUD,NONE
        IDBS,GPR                                T,JMP       T,HOLD
        JMPXB;

        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPIX;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPIX;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPIX;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,PT       T,JMP       T,HOLD
        JMPIX;

        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPIX;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPIX;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPIX;
        A,P B,L             ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,IREAD,APT      T,JMP       T,HOLD
        JMPIX;

SKEQL:
        A,SRCE B,DEST       ALUF,B-A            ALUD,NONE
        IDBS,ALU            COMM,CNEXT,NF=0     T,JMP       T,HOLD
        SKIP1;
COMM:   A,6                 ALUF,PASSD          ALUD,Q
        IDBS,AARG                               T,JMP       T,HOLD
        COMME;
SINT4:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;  % SINT-4-INSTR. NOT INCLUDED
S3SEG:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        S3SG1;

        SKEQG
        A,SRCE B,DEST       ALUF,B-A            ALUD,NONE
        IDBS,ALU            COMM,CNEXT,F15      T,JMP       T,HOLD
        SKIP1;
S3K1I:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        S3K1;
EXR:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        EXR1;
S3K2I:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        S3K2;

        SKGRE
        A,SRCE B,DEST       ALUF,B-A            ALUD,NONE
        IDBS,ALU            COMM,CNEXT,NSGR     T,JMP       T,HOLD
        SKIP1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
RMPY:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        RMPY4;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;

SKMGRC:
        A,SRCE B,DEST       ALUF,B-A            ALUD,NONE
        IDBS,ALU            COMM,CNEXT,NCRY     T,JMP       T,HOLD
        SKIP1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
RDIV:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        RDIV6;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;

SKUEQ:
        A,SRCE B,DEST       ALUF,B-A            ALUD,NONE
        IDBS,ALU            COMM,CNEXT,F=0      T,JMP       T,HOLD
        SKIP1;
GECOX:  A,T B,Z             ALUF,PASSA          ALUD,B      XRF
        IDBS,GPR            COMM,EWRF           T,JMP       T,HOLD
        GECX1;
LBYT:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        LBYT1;
RWLBL:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;  % 20-BIT LOG.ADDR. ERRONEOUS

SKLSS:
        A,SRCE B,DEST       ALUF,B-A            ALUD,NONE
        IDBS,ALU            COMM,CNEXT,NF15     T,JMP       T,HOLD
        SKIP1;
PREX:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;  % 20-BIT LOG.ADDR. ERRONEOUS
SBYT:   A,X B,R1            ALUF,PASSA          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,JMP       T,HOLD
        SBYT2;
GECO:   B,R2                ALUF,PASSD          ALUD,B
        IDBS,GPR            COMM,LDLC           T,JMP       T,HOLD
        GECO1;

SKLST:
        A,SRCE B,DEST       ALUF,B-A            ALUD,NONE
        IDBS,ALU            COMM,CNEXT,SGR      T,JMP       T,HOLD
        SKIP1;
MOVEW:  A,13                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        MOVW1;
MIX3:   A,A B,X             ALUF,A-1            ALUD,SLB
        IDBS,ALU            COMM,LDGPR          T,JMP       T,HOLD
        MIX4;
SINTR:  A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDSEG          T,JMP       T,HOLD
        SINT1;

SKMLS:
        A,SRCE B,DEST       ALUF,B-A            ALUD,NONE
        IDBS,ALU            COMM,CNEXT,CRY      T,JMP       T,HOLD
        SKIP1;
WCS:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        CONT;
IDENT:  A,6 B,R1            ALUF,D-1            ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        IDNT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;

SWAP:   B,DEST              ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        SWO;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        SWO;
        B,DEST              ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        SW2;
                            ALUF,ZERO           ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        SW2;

RAND:   A,SRCE B,DEST       ALUF,ANDAB          ALUD,B
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        B,DEST              ALUF,ZERO           ALUD,B
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,DEST       ALUF,MASKAB         ALUD,B
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        B,DEST              ALUF,ZERO           ALUD,B
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;

REXO:   A,SRCE B,DEST       ALUF,XORAB          ALUD,B
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,DEST       ALUF,PASSA          ALUD,B
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,R1         ALUF,INVA           ALUD,B
                                                T,JMP       T,HOLD
        REX02;
        A,SRCE B,DEST       ALUF,INVA           ALUD,B
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;

RORA:   A,SRCE B,DEST       ALUF,ORAB           ALUD,B
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,DEST       ALUF,PASSA          ALUD,B
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,R1         ALUF,INVA           ALUD,B
                                                T,JMP       T,HOLD
        REX02;
        A,SRCE B,DEST       ALUF,INVA           ALUD,B
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;

RADD:
        A,SRCE B,DEST       ALUF,A+B            ALUD,B      STS,EA
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,DEST       ALUF,A              ALUD,B      STS,EA
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,DEST       ALUF,B-A-1          ALUD,B      STS,EA
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,DEST       ALUF,-A-1           ALUD,B      STS,EA
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;

        A,SRCE B,DEST       ALUF,A+B+1          ALUD,B      STS,EA
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,DEST       ALUF,A+1            ALUD,B      STS,EA
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,DEST       ALUF,B-A            ALUD,B      STS,EA
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,DEST       ALUF,-A             ALUD,B      STS,EA
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;

        A,SRCE B,DEST       ALUF,A+B            ALUD,B      CRY,C STS,EA
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,DEST       ALUF,A              ALUD,B      CRY,C STS,EA
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,DEST       ALUF,B-A-1          ALUD,B      CRY,C STS,EA
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;
        A,SRCE B,DEST       ALUF,-A-1           ALUD,B      CRY,C STS,EA
                            COMM,CNEXT,NWP      T,JMP       T,HOLD
        CONT;

                                                ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;
                                                ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;
                                                ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;
                                                ALUD,NONE
        IDBS,ALU            COMM,CONTINUE       T,JMP       T,HOLD;

TRA4:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        TRA1;
TRR4:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        TRR1;
MCL:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MCL1;
MST:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MST1;

PIONF:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        PINF1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILLIN;

WAIT:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        WAIT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        WAIT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        WAIT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        WAIT1;

NLZ:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        NLZ3;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        NLZ3;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        NLZ3;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        NLZ3;

DNZ:    A,16 B,R6           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        DNZ2;
        A,16 B,R6           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        DNZ2;
        A,16 B,R6           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        DNZ2;
        A,16 B,R6           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        DNZ2;

SRB:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SRB2;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SRB2;
LRB:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        LRB2;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        LRB2;

MON:    A,4                                     ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,JMP       T,HOLD
        MON1;
        A,4                                     ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,JMP       T,HOLD
        MON1;
        A,4                                     ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,JMP       T,HOLD
        MON1;
        A,4                                     ALUD,NONE
        IDBS,BMG            COMM,SMPID          T,JMP       T,HOLD
        MON1;

IRWX:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IRW3;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IRW3;
IRRX:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IRR3;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IRR3;

SHT:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHT1;
SHD:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHD1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHD1;

SHA:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHA1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHA1;
SAD:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SAD1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SAD1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHD1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHD1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHA1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHA1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SAD1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SAD1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHD1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHD1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHA1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHA1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SAD1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SAD1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHD1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHD1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHA1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SHA1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SAD1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SAD1;

IOT:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOT1;

IOX:                                            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        IOX1;

SAB:    B,B                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        B,B                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        B,B                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        B,B                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;

SAA:    B,A                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        B,A                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        B,A                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        B,A                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;

SAT:    B,T                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        B,T                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        B,T                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        B,T                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;

SAX:    B,X                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        B,X                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        B,X                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        B,X                 ALUF,PASSD          ALUD,B
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;

AAB:    A,B B,B             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        A,B B,B             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        A,B B,B             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        A,B B,B             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;

AAA:    A,A B,A             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        A,A B,A             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        A,A B,A             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        A,A B,A             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;

AAT:    A,T B,T             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        A,T B,T             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        A,T B,T             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        A,T B,T             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;

AAX:    A,X B,X             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        A,X B,X             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        A,X B,X             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;
        A,X B,X             ALUF,D+A            ALUD,B      STS,EA
        IDBS,GPR,SEXT       COMM,CONTINUE       T,JMP       T,HOLD;

BSET:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSETO;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSETO;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSET1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSET1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSETC;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSETC;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSETK;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSETK;

BSKP:                                           ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSKP0;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSKP0;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSKP1;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSKP1;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSKPC;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSKPC;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSKPK;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSKPK;
        IDBS,ALU BSTC                           ALUD,NONE T,JMP T,HOLD
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSTC;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSTC;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSTA;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSTA;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BLDC;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BLDC;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BLDA;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BLDA;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BANC;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BANC;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BAND;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BAND;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BORC;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BORC;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BORA;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BORA;






 10160/
%****************************************************************
%****************************************************************

% VECTOR FOR DECODING OF BCD, BYTE BLOCK, STACK ,TSET AND RDUS

%****************************************************************
%****************************************************************


COBVC:  A,2 B,11            ALUF,ZERO           ALUD,NONE  %DECIMAL ADD
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        ADDE;

        A,0                                     ALUD,NONE  %DECIMAL SUBTRACT
        IDBS,BMG            COMM,LDGPR          T,JMP       T,HOLD
        SUBD;

        A,0 B,17                                ALUD,NONE  %DECIMAL COMPARE
        IDBS,BARG           COMM,EWRF           T,JMP       XRF T,HOLD
        COMD;

                            ALUF,PASSD          ALUD,Q  % TSET
        IDBS,STS                                T,JMP       T,HOLD
        TSET;

                                                ALUD,NONE  %CONVERT TO BCD
        IDBS,ALU                                T,JMP       T,HOLD
        PACK;

                                                ALUD,NONE  %CONVERT TO ASCII
        IDBS,ALU                                T,JMP       T,HOLD
        UPACK;

                                                ALUD,NONE  %DECIMAL SHIFT
        IDBS,ALU                                T,JMP       T,HOLD
        SHDE;

                                                ALUD,NONE  % RDUS
        IDBS,ALU                                T,JMP       T,HOLD
        RDUS;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BFILL;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MOVB;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        MOVBF;
                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        VERSN;

                                                ALUD,NONE
        IDBS,DBR            COMM,LDGPR          T,JMP       T,HOLD
 5INIT;

                                                ALUD,NONE
        IDBS,DBR            COMM,LDGPR          T,JMP       T,HOLD
        ENTR;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        LEAV;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ELEAV;









%****************************************

% DECIMAL SUBTRACTION SUBROUTINE


SSUB:   B,R5                ALUF,XORDQ          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

                            ALUF,Q-D-1          ALUD,Q      CRY,C STS,EA
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,CRY                                       F,NEXT      F,HOLD;

        A,R5 B,R5           ALUF,XORAQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        SUBB CONDENABL;

                            ALUF,Q-D            ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        60000;

SUBB:   A,L B,R5            ALUF,ANDAB          ALUD,SRB
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R5 B,R2           ALUF,PASSA          ALUD,SRB
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R2 B,R5           ALUF,ORAB           ALUD,SRB
        IDBS,ALU                                T,RETURN    T,POP;

%********************************************************

% DECIMAL ADDITION SUBROUTINE


SADD:   B,R5                ALUF,XORDQ          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

                            ALUF,D+Q            ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        63146;

                            ALUF,D+Q            ALUD,Q      CRY,C STS,EA
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,CRY                                       F,NEXT      F,HOLD;

        A,R5 B,R5           ALUF,XNORAQ         ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        ADDB CONDENABL;

                            ALUF,Q-D            ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        60000;

ADDB:   A,L B,R5            ALUF,ANDAB          ALUD,SRB
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R5 B,R2           ALUF,PASSA          ALUD,SRB
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R2 B,R5           ALUF,ORAB           ALUD,SRB
        IDBS,ALU                                T,RETURN    T,POP;


%********************************************************

% ENTRY-POINT ALL COMMERCIAL INSTRUCTIONS

%********************************************************


COMME:                      ALUF,ANDDQ          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,2                 ALUF,XORDQ          ALUD,NONE
        IDBS,AARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,2 B,16                                ALUD,NONE
        IDBS,STS            COMM,EWRF           T,NEXT      T,HOLD
        ILLIN CONDENABL;

        A,2 B,15                                ALUD,NONE
        IDBS,BARG           COMM,EWRF           T,JMP0-3    T,HOLD
        COBVC;







%****************************************

% SUBROUTINE TO SAVE REGISTERS FROM CURRENT LEVEL
% L -> RF(5,13)
% B -> RF(5,12)
% GPR IS USED AS SCRATCH


CSAV1:  A,L                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

        A,5 B,13                                ALUD,NONE
        IDBS,GPR            COMM,EWRF           T,NEXT      T,HOLD;

        A,B                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

        A,5 B,12                                ALUD,NONE
        IDBS,GPR            COMM,EWRF           T,RETURN    T,POP;

%****************************************

% SUBROUTINE TO UNSAVE REGISTERS TO CURRENT LEVEL
% RF(5,13) -> L
% RF(5,12) -> B
% GPR IS USED AS SCRATCH


CUSV1:  A,5 B,12                                ALUD,NONE
        IDBS,REG            COMM,LDGPR          T,NEXT      T,HOLD;

        B,B                 ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,5 B,13                                ALUD,NONE
        IDBS,REG            COMM,LDGPR          T,NEXT      T,HOLD
                            COMM,LDGPR          T,NEXT      T,HOLD;
        B,L                 ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,RETURN    T,POP;

%***********************************************

% SUBROUTINE TO COMPUTE BOTTOM WORD ADDRESS
% AND NUMBER OF WORDS OF AN ASCII OPERAND
% DESCRIPTORS IN R1,R2
% RETURN WITH NUMBER OF WORDS IN R4
% NUMBER OF BYTES IN R7
% BOTTOM WORD ADDRESS IN R6

LWAB:   B,R2                ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,R2 B,R7           ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
        LWABC CONDENABL;

        B,R7                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

LWABC:  A,R7 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,R7 B,R4           ALUF,PASSA          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD
        LWABB CONDENABL;

        A,R6 B,R4           ALUF,A+B            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R6                ALUF,Q-1            ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;

LWABB:  A,R4 B,R4           ALUF,B+1            ALUD,B,YA
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;
        A,R6 B,R6           ALUF,D+A            ALUD,B
        IDBS,GPR                                T,RETURN    T,POP;


%***********************************************
%
% SUBROUTINE TO COMPUTE NUMBER OF WORDS
% AND BOTTOM WORD ADDRESS OF A BCD-OPERAND
% DESCRIPTORS IN R1,R2
% RETURN WITH NUMBER OF WORDS IN STS
% NUMBER OF NIBLES IN R3
% BOTTOM WORD ADDRESS IN R1
%
LWA:    A,R2 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R2 B,STS          ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,JMP       T,HOLD
        LWAA CONDENABL;

        B,STS               ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

LWAA:   A,R2                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        B,STS               ALUF,PASSB          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD
        LWAC CONDENABL;

        B,STS               ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

LWAC:   A,STS B,R3          ALUF,PASSA          ALUD,SLB    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,STS               ALUF,PASSB          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,STS B,R1          ALUF,A+B            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        LWAD CONDENABL;

        B,STS               ALUF,B+1            ALUD,B
        IDBS,ARG            COMM,LDGPR          T,RETURN    T,POP
        37;

LWAD:   B,R1                ALUF,B-1            ALUD,B
        IDBS,ARG            COMM,LDGPR          T,RETURN    T,POP
        37;

%***********************************************
%
% SUBROUTINE TO MAKE MASK FOR TOPWORD BCD-OPERANDS
% DESCRIPTOR IN R2, RETURN WITH MASK IN Z.

TTPWD:  A,R2                ALUF,PASSA          ALUD,NONE
        IDBS,GPR            COMM,LDLC           T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;


        IDBS,ALU                                ALUD,NONE
        RIGTB CONDENABL;                        T,JMP       T,HOLD

        A,R2 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,POP;

        A,14 B,Z            ALUF,D-1            ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        CONDENABL;

        B,0                 ALUF,D-1            ALUD,B
        IDBS,BARG                               T,RETURN    T,POP;

RIGTB:  A,R2 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,POP;

        A,4 B,Z             ALUF,D-1            ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        CONDENABL;

        A,10 B,Z            ALUF,D-1            ALUD,B
        IDBS,BMG                                T,RETURN    T,POP;






%****************************************

% COMMERCIAL INSTRUCTION: COMPARE

%****************************************


COMD:   A,Z B,R4            ALUF,A+1            ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

        B,R5                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        16;

%****************************************

% TEST SECOND OPERAND EMPTY


        A,T B,R7            ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CFIR CONDENABL;

        A,T B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LWA;

%***********************************************

% IF NOT EMPTY, READ SECOND OPERAND TO XRF(RA,0)

        A,X B,17            ALUF,A-1            ALUD,Q
        IDBS,BARG           COMM,LDLC           T,NEXT      T,PUSH;

                            ALUF,Q+1            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;  %********************

        A,R1 B,LC           ALUF,A-Q-1          ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD
 COND,F15;

        A,0 B,LC                                ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,NEXT      XRF T,POP
                                                            LCOUNT;

        A,R3 B,R7           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,STS B,R4          ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R5                ALUF,D-1            ALUD,B
        IDBS,GPR            COMM,LDLC           T,NEXT      T,HOLD;

        A,T B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        TTPWD;

        A,0 B,17            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,Z                 ALUF,ANDAQ          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,0 B,17            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

%****************************************

% TEST FIRST OPERAND EMPTY


CFIR:   A,D B,R3            ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        ANEMP CONDENABL;

        A,1 B,17                                ALUD,NONE
                                                            XRF
        IDBS,BARG           COMM,EWRF           T,NEXT      T,HOLD;

        A,0 B,STS           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,0 B,R6            ALUF,PASSD          ALUD,B
        IDBS,BARG                               T,JMP       T,HOLD
        STRPS;

ANEMP:  A,D B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LWA;

% ****************************************

% TEST FIRST OPERAND VS. ZERO (A)
% IF NOT EMPTY, READ FIRST OPERAND TO XRF(RA,1)

        A,A B,17            ALUF,A-1            ALUD,Q
        IDBS,BARG           COMM,LDLC           T,NEXT      T,PUSH;

                            ALUF,Q+1            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;  %********************

        A,R1 B,LC           ALUF,A-Q-1          ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD
 COND,F15;

        A,1 B,LC                                ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,NEXT      XRF T,POP
                                                            LCOUNT;

        B,R6                ALUF,D-1            ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,D B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        TTPWD;

        A,1 B,17            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,Z                 ALUF,ANDAQ          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,1 B,17            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

STRPS:  A,2 B,Z             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD;

        B,R5                ALUF,B+1            ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        A,R7 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      XRF T,HOLD
        CLLBY CONDENABL;

        B,R2                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

        A,0 B,LC            ALUF,MASKAQ         ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       XRF T,HOLD
        STRTW;

CLLBY:  A,Z B,R2            ALUF,ANDDA          ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        170000;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

STRTW:  B,R6                ALUF,B+1            ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,JMP       T,PUSH
        BUNOR;

%****************************************
%
% TEST UNSIGNED OPERANDS AND EQUAL SIGNS
%

        A,Z B,17            ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,L                 ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
        PLUS1 CONDENABL;

        B,Z                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

PLUS1:  A,R2 B,17           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,A B,13            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD
        PLUS2 CONDENABL;

        B,R2                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

PLUS2:  A,Z B,R2            ALUF,XORAB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,0                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,3 B,R2            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD
        SDIFF CONDENABL;

%***********************************************

%
% TEST EQUAL LENGTH

        A,R4 B,STS          ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,6                                     ALUD,NONE   STS,LO
        IDBS,BMG                                T,JMP       T,HOLD
        XTSHO CONDENABL;

        A,R4 B,STS          ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,PUSH;

        A,R5 B,R1           ALUF,A+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        COMPA CONDENABL;

%***********************************************

% FIRST OPERAND SHORTEST LENGTH.INSERT ZEROES

        B,R6                ALUF,B+1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        B,R5                ALUF,B+1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        A,1 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,R6 B,17           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,POP;

        A,1 B,LC            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,RETURN    XRF T,HOLD
        CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,PUSH;

        B,R5                ALUF,B+1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        A,R5 B,17           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,POP;

        A,1 B,LC            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,RETURN    XRF T,HOLD
        COMPA CONDENABL;


%******************************************

%       SECOND OPERAND SHORTEST, INSERT ZEROES


XTSHO:  A,R6 B,R1           ALUF,A+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,PUSH;

        B,R5                ALUF,B+1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        B,R6                ALUF,B+1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,R5 B,17           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,POP;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,RETURN    XRF T,HOLD
        CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,PUSH;

        B,R6                ALUF,B+1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        A,R6 B,17           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,POP;

        A,0 B,LC            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,RETURN    XRF T,HOLD
        CONDENABL;

%****************************************

% COMPARE


COMPA:  A,R7 B,R3           ALUF,XORAB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,1                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,10 B,Z            ALUF,D-1            ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        NOTEB CONDENABL;

%****************************************

% BOTH OPERANDS EQUAL BOTTOM BYTE ADDRESS. COMPARE WORDS

        B,17                                    ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,PUSH;

        B,L                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        10420;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,1 B,LC                                ALUD,NONE
        IDBS,REG            COMM,LDGPR          T,JMP       XRF T,PUSH
        SSUB;

        A,R5                ALUF,Q-A            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        A,R1 B,LC           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
        UNEQL CONDENABL;

        A,6 B,A             ALUF,ZERO           ALUD,B      STS,LO
        IDBS,BMG                                T,NEXT      T,POP
                                                            LCOUNT;

EXIT:   A,3 B,12            ALUF,PASSD          ALUD,B
        IDBS,REG                                T,NEXT      T,HOLD;

        A,R2 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,5 B,13            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        EXITB CONDENABL;

        B,A                 ALUF,INVB           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,A                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

EXITB:  B,L                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        EXITC;

%****************************************
%****************************************

% UNEQUAL, TEST CARRY FROM SUBTACT SUBROUTINE


UNEQL:  B,0                 ALUF,D              ALUD,NONE   CRY,C
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        SEOGR CONDENABL;

FIOGR:  A,0 B,A             ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        EXIT;

%***********************************************
%
% DIFFERENT SIGNS
%

SDIFF:  B,17                                    ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD;

        B,R4                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,PUSH;

        A,0 B,LC            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      XRF T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        B,R4                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        SDIFC CONDENABL;


        IDBS,ALU                                ALUD,NONE
                                                T,NEXT      LCOUNT; T,POP

        B,17                                    ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD;

        B,STS               ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,PUSH;

        A,1 B,LC            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      XRF T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        B,STS               ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        SDIFC CONDENABL;

        B,A                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,POP
                                                            LCOUNT
        EXIT;

SDIFC:  A,Z                 ALUF,ANDDA          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,3 B,12            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        FIOGR CONDENABL;

SEOGR:  A,0 B,A             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        EXIT;

%***********************************************
%
% OPERANDS NOT EQUAL BOTTOM BYTE ADDRESS. COMPARE SWAPPED BYTES


NOTEB:  A,R7 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,6 B,R7            ALUF,ZERO           ALUD,B      STS,LO
        IDBS,BMG                                T,NEXT      T,HOLD
        XTHOB CONDENABL;

        B,17                                    ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,PUSH;

        B,L                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        10420;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,Z B,R3            ALUF,ANDDA          ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

        A,Z B,R6            ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R7                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

        B,R3                ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        SSUB;

        A,R5                ALUF,Q-A            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        A,1 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      XRF T,HOLD
        UNEQL CONDENABL;

        A,Z B,R5            ALUF,ANDDA          ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

        A,Z B,R7            ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,6 B,R6            ALUF,PASSB          ALUD,Q      STS,LO
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R5                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,JMP       T,PUSH
        SSUB;

        A,R5                ALUF,Q-A            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,POP;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        UNEQL CONDENABL;

        A,R1 B,LC           ALUF,D-A-1          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15;

        A,6 B,A             ALUF,ZERO           ALUD,B      STS,LO
        IDBS,BMG                                T,JMP       T,POP
                                                            LCOUNT
        EXIT;

XTHOB:  B,17                                    ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,PUSH;

        B,L                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        10420;

        A,1 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,Z B,R3            ALUF,ANDDA          ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

        A,Z B,R6            ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R7                ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,JMP       T,PUSH
        SSUB;

        A,R5                ALUF,Q-A            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      XRF T,HOLD
        UNEQL CONDENABL;

        A,Z B,R5            ALUF,ANDDA          ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

        A,Z B,R7            ALUF,ANDAQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,6 B,R5            ALUF,PASSB          ALUD,Q      STS,LO
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,R6                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,JMP       T,PUSH
        SSUB;

        A,R5                ALUF,Q-A            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,POP;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        UNEQL CONDENABL;

        A,R1 B,LC           ALUF,D-A-1          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15;

        A,6 B,A             ALUF,ZERO           ALUD,B      STS,LO
        IDBS,BMG                                T,JMP       T,POP
                                                            LCOUNT
        EXIT;

BUNOR:  A,R3 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,1 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      XRF T,HOLD
        RLLBY CONDENABL;

        B,Z                 ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

                            ALUF,MASKDQ         ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

        A,1 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,RETURN    T,POP;

RLLBY:  A,Z B,Z             ALUF,ANDDA          ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        170000;

        A,1 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,RETURN    T,POP;









%***********************************************
% COMMERSIAL INSTRUCTION:ADDD (A,D +/- X,T -> A,D)

%***********************************************


SUBD:   A,2 B,11                                ALUD,NONE
        IDBS,GPR            COMM,EWRF           T,NEXT      T,HOLD;

ADDE:                                           ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

        A,T                 ALUF,ANDDA          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,D B,R7            ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
        SECOP CONDENABL;

        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        FIROC CONDENABL;

UTGNG:  B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,POP
        CONT;

SECOP:  A,5 B,16            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,5 B,17            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,T B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LWA;

        A,R1 B,R6           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,STS B,R4          ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,R7           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        TFIRE;


%********************************************

% X,T EMPTY. SET SIGN IN A,D TO 14 (+) OR 15 (-)


FIROC:  A,D B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LWA;

        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG           COMM,RDRQ,APT       T,NEXT      T,HOLD  %********************
 COND,F=0                                       F,NEXT      F,HOLD;


        IDBS,DBR            ALUF,PASSD          ALUD,Q
        FIROL CONDENABL;                        T,JMP       T,HOLD

        B,R4                ALUF,ANDDQ          ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        7400;

        B,R4                ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R4                ALUF,PASSD          ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

                            ALUF,MASKDQ         ALUD,Q
        IDBS,GPR                                T,JMP       T,HOLD
        FIROE;

FIROL:  B,R4                ALUF,ANDDQ          ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        17;

                            ALUF,MASKDQ         ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

FIROE:  A,15                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,D                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;


        IDBS,ALU                                ALUD,NONE
        FIROA CONDENABL;                        T,JMP       T,HOLD

        A,2 B,R4            ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        FIROB;

FIROA:  A,R4 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,14                ALUF,PASSD          ALUD,B
        IDBS,BARG                               T,JMP       T,HOLD
        FIROB CONDENABL;

        B,R4                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

FIROB:  A,R3 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R4                ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        FISOL CONDENABL;

        B,R4                ALUF,PASSD          ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

FISOL:  A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R4                ALUF,ORAQ           ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,JMP       T,HOLD  %******************
        UTGNG;

%***********************************************

% TEST FIRST OPERAND EMPTY

TFIRE:  A,D B,R3            ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        FIROP CONDENABL;

        A,1 B,17                                ALUD,NONE
                                                            XRF
        IDBS,BARG           COMM,EWRF           T,NEXT      T,HOLD;

        A,0 B,STS           ALUF,D              ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        TNOEQ;

FIROP:  A,D B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LWA;

        B,R1                ALUF,B+1            ALUD,Q
        IDBS,ARG            COMM,LDLC           T,NEXT      T,PUSH
        17;

%***********************************************

% READ FIRST OPERAND TO XRF (RA,1)


                            ALUF,Q-1            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;
                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;  %********************

        A,A B,LC            ALUF,Q-A-1          ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD
 COND,F15;

        A,1 B,LC                                ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,NEXT      XRF T,HOLD
 COND,COND;

        IDBS,ALU            ALUF,PASSQ          ALUD,NONE
                                                T,NEXT      T,HOLD;

        A,1 B,LC                                ALUD,NONE
        IDBS,REG            COMM,WRRQ,APT       T,NEXT      XRF T,POP
                                                            LCOUNT;

        A,D B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        TTPWD;

        B,Z                 ALUF,PASSB          ALUD,Q
        IDBS,GPR            COMM,LDLC           T,NEXT      T,HOLD;

        A,2 B,14            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,1 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,Z B,R2            ALUF,MASKAQ         ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,Z                 ALUF,ANDAQ          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,1 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,2 B,12            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;
TNOEQ:  A,R7 B,R3           ALUF,XORAB          ALUD,Q
TNOEQ:  A,R7 B,R3           ALUF,XORAB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,1                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,10 B,R2           ALUF,D-1            ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        NOTEQ CONDENABL;

%****************************************
% READ SECOND OPERAND TO XRF (RA,0)



        B,R6                ALUF,B+1            ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,PUSH
        17;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,X B,R6            ALUF,B-A-1          ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD  %****************
 COND,F15;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,DBR            COMM,EWRF           T,NEXT      XRF T,POP
                                                            LCOUNT;

        B,LC                                    ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD;

        A,T B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        TTPWD;

        B,R2                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

        A,Z B,LC            ALUF,ANDAQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       XRF T,PUSH
        CSAV1;

TSIGN:  A,R3 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,1 B,17            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      XRF T,HOLD
        SLBYT CONDENABL;

%********************************************************

% SIGN IN RIGHT BYTE


        B,Z                 ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

                            ALUF,MASKDQ         ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

        A,1 B,17            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,0 B,17            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        B,R2                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

                            ALUF,MASKDQ         ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

        A,0 B,17            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       XRF T,HOLD
        SIGN;

%********************************************************

% SIGN IN LEFT BYTE FIRST OPERAND

SLBYT:  A,R2 B,Z            ALUF,ANDDA          ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

        B,B                 ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        170000;

        A,1 B,17            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,0 B,17            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,R2 B,R2           ALUF,ANDDA          ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        170000;

        A,0 B,17            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       XRF T,HOLD
        SIGN;

%********************************************************

% SWAP SECOND OPERAND WHEN READING TO XRF LEVEL 0


NOTEQ:  A,R7 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R2 B,R7           ALUF,INVA           ALUD,B
        IDBS,BARG           COMM,LDLC           T,JMP       T,HOLD
        BOTWD CONDENABL;

        A,R6 B,R6           ALUF,B-1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,JMP       T,PUSH  %********************
        CSAV1;

        A,R6 B,X            ALUF,A-B            ALUD,NONE
        IDBS,DBR                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,R2 B,Z            ALUF,ANDDA          ALUD,B
        IDBS,SWAP                               T,JMP       T,HOLD
        NOTEC CONDENABL;

NTECC:  B,17                                    ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,PUSH;

        B,R6                ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;  %************************

        B,R6                ALUF,B-1            ALUD,B
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,R7 B,R5           ALUF,ANDDA          ALUD,B
        IDBS,SWAP           COMM,LDGPR          T,NEXT      T,HOLD;

        A,R5 B,Z            ALUF,ORAB           ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R2 B,Z            ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R6 B,X            ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      XRF T,POP
                                                            LCOUNT;

NOTEC:  B,LC                                    ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,4 B,R2            ALUF,D-1            ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        TOPWD CONDENABL;

        A,T B,1             ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R4                ALUF,B-1            ALUD,B
        IDBS,GPR            COMM,LDLC           T,JMP       T,HOLD
        TSIGN CONDENABL;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        7777;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       XRF T,HOLD
        TSIGN;

TOPWD:  A,T B,1             ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        SAVTP CONDENABL;

        A,R2 B,Z            ALUF,ANDAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

SAVTP:  A,0 B,LC            ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       XRF T,HOLD
        TSIGN;

BOTWD:  B,Z                 ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        CSAV1;

        B,R4                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        NTECC;


%***********************************************

% TEST UNSIGNED OPERAND AND ADD/SUB


SIGN:   A,R2 B,17           ALUF,A-D            ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,2 B,11            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD
        SIGNA CONDENABL;

        B,R2                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

SIGNA:  A,Z B,LC            ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,R2                ALUF,XORAQ          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
        SIGNB CONDENABL;

        A,Z B,Z             ALUF,A-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

SIGNB:  A,R4 B,STS          ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,Z                 ALUF,XORAQ          ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        SIGNC CONDENABL;

        A,STS B,R6          ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        SIGND;

SIGNC:  A,R4 B,R6           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

SIGND:  B,L                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        10420;

        A,0                 ALUF,ANDDQ          ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,5 B,14                                ALUD,NONE
        IDBS,BARG           COMM,EWRF           T,JMP       T,HOLD
        ADDA CONDENABL;

%***********************************************

% SUBTRACTION
                                                ALUD,NONE   STS,LO
                                                T,JMP       T,PUSH
        A,6
        IDBS,BMG
        SUBDC;

        A,1 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

SUBDC:  A,1 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,0 B,LC                                ALUD,NONE
        IDBS,REG            COMM,LDGPR          T,JMP       XRF T,PUSH
        SSUB;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0;

        A,R5                ALUF,Q-A            ALUD,Q
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        A,1 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,5 B,16            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,5 B,17            ALUF,Q-D            ALUD,B
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,R4 B,STS          ALUF,A-B            ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        FINI CONDENABL;

        A,R7                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R5                ALUF,Q+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        EQLLT CONDENABL;

%****************************************

% FIRST OPERAND SHORTEST


        B,R5                ALUF,B-1            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,PUSH;

        B,LC                ALUF,ZERO           ALUD,Q
        IDBS,BARG           COMM,LDGPR          T,JMP       T,HOLD
        EQLLT CONDENABL;

        A,0 B,LC            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      XRF T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        B,R5                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        INVER CONDENABL;


        IDBS,ALU                                ALUD,NONE
        EQLLT;                                  T,JMP       LCOUNT T,POP

INVER:                      ALUF,Q              ALUD,NONE   CRY,C
        IDBS,GPR            COMM,LDLC           T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,2 B,15            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        INVWR CONDENABL;

        A,R4 B,STS          ALUF,A-B-1          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;
        A,0 B,LC            ALUF,D-1            ALUD,NONE
        IDBS,REG                                T,NEXT      XRF T,HOLD
        INVWR CONDENABL;

                                                ALUD,NONE

        IDBS,ALU                                T,NEXT      T,HOLD
        INVWR CONDENABL;

        A,2 B,15                                ALUD,NONE
        IDBS,BARG           COMM,EWRF           T,JMP       T,HOLD
        INVWR;
%***********************************************

% OPERANDS HAVE EQUAL LENGTH


EQLLT:  B,0                 ALUF,D              ALUD,NONE   CRY,C
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        TUSIG CONDENABL;

INVWR:  17 A,STS B,R6       ALUF,PASSA          ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD;

        B,R5                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        360;

        B,R4                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        170000;

        B,R7                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        7400;

        A,1 B,17                                ALUD,NONE
        IDBS,REG            COMM,LDGPR          T,JMP       XRF T,PUSH
        INVWS;

        B,17                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

        A,1 B,LC            ALUF,ANDDQ          ALUD,NONE
        IDBS,REG            COMM,LDGPR          T,JMP       XRF T,HOLD
        INVSS;

INVWS:                      ALUF,ZERO           ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,POP;

INVSS:  A,R5                ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
        INVQ CONDENABL;

        A,R7                ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
        INVR CONDENABL;

        A,R4                ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
        INVS CONDENABL;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        INVT CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,POP
                                                            LCOUNT
        TUSIG;

INVQ:                       ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        114633;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU
        INVWC;                                  T,JMP       T,HOLD

INVR:                       ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        114641;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        INVWC;

INVS:                       ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        115001;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        INVWC;

INVT:                       ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        120001;

INVWC:  B,R6                ALUF,B+1            ALUD,B      STS,EA
        IDBS,ALU                                T,JMP       T,PUSH
        INVCC;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        114631;

INVCC:  A,1 B,LC            ALUF,ZERO           ALUD,NONE
        IDBS,REG            COMM,LDGPR          T,JMP       XRF T,PUSH
        SSUB;

        A,R5                ALUF,Q-A            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0;

        A,1 B,LC            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      XRF T,POP
                                                            LCOUNT;

        A,Z B,Z             ALUF,XORDA          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        TUSIG;


%***********************************************

% SECOND OPERAND SHORTEST


FINI:   B,0                 ALUF,D              ALUD,NONE   CRY,C
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,0 B,R6            ALUF,-Q             ALUD,B      STS,LO
        IDBS,AARG                               T,NEXT      T,HOLD
        TUSIG CONDENABL;


        IDBS,ALU            ALUF,PASSQ          ALUD,NONE
 COND,F=0                                       T,NEXT      T,HOLD
                                                F,NEXT      F,PUSH;
        B,0                                     ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,JMP       T,HOLD
        INVWR CONDENABL;

        IDBS,ALU                                ALUD,NONE
                                                T,NEXT      T,HOLD;

        A,1 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,PUSH
        SSUB;

        A,R5                ALUF,Q-A            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,0                 ALUF,D              ALUD,NONE   CRY,C
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,POP;
        A,1 B,LC            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      XRF T,HOLD
        TUSIG CONDENABL;


        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0;

        A,0                                     ALUD,NONE   STS,LO
        IDBS,AARG                               T,JMP       T,POP
                                                            LCOUNT
        INVWR;

%***********************************************

% ADD, OPERANDS EQUAL LENGTH


LIKE:   B,0                 ALUF,D              ALUD,NONE   CRY,C
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;
        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD

        OVERF CONDENABL;

TUSIG:  A,5 B,17            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;
        A,15                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD
        ATOVE CONDENABL;


        A,2 B,15            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,1 B,17            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,HOLD
        DECP CONDENABL;


        IDBS,ALU                                ALUD,NONE
        EXITD CONDENABL;

DECP:   B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        EXITD;

ATOVE:  A,D                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,14                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        TSIGF CONDENABL;

        A,2 B,Z             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        NOCAR;

TSIGF:  A,Z B,1             ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,Z                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        NOCAR CONDENABL;

        B,Z                 ALUF,Q+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

NOCAR:  A,R3 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,1 B,17            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      XRF T,HOLD
        LFTBY CONDENABL;

        A,Z                 ALUF,ORAQ           ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        TEFIN;

LFTBY:  A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,ORDQ           ALUD,Q
        IDBS,SWAP                               T,NEXT      T,HOLD;

                            ALUF,MASKDQ         ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

        A,B                 ALUF,ORAQ           ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

TEFIN:  A,1 B,17            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,2 B,16                                ALUD,NONE   STS,LO
        IDBS,REG                                T,NEXT      T,HOLD;

        A,R1 B,A            ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,PUSH;

        B,17                                    ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,JMP       T,HOLD
        SKRVC CONDENABL;

        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,1 B,LC                                ALUD,NONE
                                                            XRF
        IDBS,REG            COMM,WRRQ,APT       T,NEXT      T,HOLD;  %************************

        A,R1 B,A            ALUF,A-B-1          ALUD,NONE
        IDBS,ALU            ALUF,A-B-1          ALUD,NONE
 COND,F=0;                                      T,NEXT      T,HOLD
        B,R1                ALUF,B-1            ALUD,B
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,POP
                                                            LCOUNT;

SKRVC:  A,2 B,15            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,1 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,HOLD
        OVFLO CONDENABL;

        A,2 B,14            ALUF,MASKDQ         ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,2 B,14            ALUF,ANDDQ          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        USAVE CONDENABL;

OVFLO:  B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,2 B,14            ALUF,ANDDQ          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

USAVE:  A,2 B,12            ALUF,ORDQ           ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        B,A                 ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;


        IDBS,ALU            ALUF,PASSQ          ALUD,NONE
                            COMM,WRRQ,APT       T,NEXT      T,HOLD;  %*****************
EXITD:                      ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        CUSV1;

EXITC:  A,2 B,16                                ALUD,NONE   STS,LO
        IDBS,REG                                T,JMP       T,HOLD
        UTGNG;




%********************************************************

% ADDITION


ADDA:   A,0                                     ALUD,NONE   STS,LO
        IDBS,AARG                               T,JMP       T,PUSH
        ADDCC;

        A,1 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

ADDCC:  A,1 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,0 B,LC                                ALUD,NONE
        IDBS,REG            COMM,LDGPR          T,JMP       XRF T,PUSH
        SADD;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0;

        A,R5                ALUF,Q-A            ALUD,Q
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

ADSLT:  A,1 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;
        A,5 B,16            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,5 B,17            ALUF,D-Q            ALUD,B
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,R4 B,STS          ALUF,A-B            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
        ADSLC CONDENABL;

%********************************************************

% FIRST OPERAND SHORTEST

        B,0                 ALUF,D              ALUD,NONE   CRY,C
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        B,R6                ALUF,Q+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        OVERF CONDENABL;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,PUSH;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        TUSIG CONDENABL;

        A,0 B,LC            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      XRF T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        OVERF CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,POP
                                                            LCOUNT
        TUSIG;

%********************************************************

% SECOND OPERAND SHORTEST


ADSLC:  A,R7                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,STS B,R4          ALUF,A-B            ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        LIKE CONDENABL;

        B,0                 ALUF,D              ALUD,NONE   CRY,C
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,PUSH;

        B,R6                ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        TUSIG CONDENABL;

        B,0                                     ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,JMP       T,HOLD
        OVERF CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,1 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,PUSH
        SADD;

        A,R5                ALUF,Q-A            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,0                 ALUF,D              ALUD,NONE   CRY,C
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,1 B,LC            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       XRF T,POP
        TUSIG CONDENABL;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0;

        A,1 B,LC            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      XRF T,POP
                                                            LCOUNT;

OVERF:  A,2 B,15            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        TUSIG;





%********************************************************

% COMMERCIAL INSTRUCTION: SHIFT

%********************************************************

SHDE:                                           ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

        A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,D                 ALUF,ANDDA          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD
        STNOE CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        SAEMP CONDENABL;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,POP
        CONT;

%****************************************

% X,T-OPERAND NOT EMPTY, READ FIRST AND LAST WORD

STNOE:  A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,T B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LWA;

        A,R1 B,R2           ALUF,ZERO           ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG           COMM,RDRQ,APT       T,NEXT      T,HOLD  %***************
 COND,F=0                                       F,NEXT      F,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,DBR                                T,NEXT      T,HOLD
 COND,COND                                      F,NEXT      F,HOLD;

        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,JMP       T,HOLD
        RFIRW CONDENABL;

        B,R2                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

RFIRW:  A,2 B,R2            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,STS B,R4          ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R1 B,R6           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,R7           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,T B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,RDRQ,APT       T,JMP       T,PUSH  %****************
        TTPWD;

        A,Z B,STS           ALUF,ZERO           ALUD,B,YA
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

        A,2 B,14                                ALUD,NONE
        IDBS,GPR            COMM,EWRF           T,NEXT      T,HOLD;

        B,Z                 ALUF,INVB           ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;                                                 T,HOLD

                            ALUF,PASSD          ALUD,Q
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;

        A,Z                 ALUF,ANDAQ          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,2 B,11            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

SAEMP:  A,D B,R3
        IDBS,GPR            ALUF,ANDDA          ALUD,B
 COND,F=0                                       T,NEXT      T,HOLD  F,NEXT      F,HOLD;
                                                F,NEXT      F,HOLD
        A,A B,R1            ALUF,A              ALUD,B      STS,EA
        IDBS,ALU                                T,JMP       T,HOLD
        SHCON CONDENABL;

        A,D B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LWA;

%***********************************************
%
% COMPUTE SHIFT COUNT FROM THE DIFFERENCE IN
% DECIMAL POSITION OF THE OPERANDS


SHCON:  A,R3 B,3            ALUF,PASSA          ALUD,Q
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD
 COND,LC=0;

        B,R5                ALUF,PASSQ          ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        1740;

        A,D                 ALUF,ANDDA          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,T B,R2            ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,PUSH;

        B,R2                ALUF,PASSB          ALUD,SRD    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        A,R2                ALUF,A-Q            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;
        A,R7 B,R3           ALUF,XORAB          ALUD,B
        A,R7 B,R3           ALUF,XORAB          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;
        A,R7 B,2            ALUF,ANDDA          ALUD,NONE
                            COMM,LDGPR          T,NEXT      T,HOLD
        IDBS,BARG                               F,JMP       F,HOLD
 COND,F=0;
        A,R3 B,R3           ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
                                                T,NEXT      T,HOLD
        TSHTD CONDENABL;

        B,R3                ALUF,-B             ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

TSHTD:  A,0 B,17                                ALUD,NONE
        IDBS,ARG            COMM,EWRF           T,NEXT      XRF T,HOLD
        14;

        A,R3 B,R3           ALUF,A+Q            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        B,17                                    ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,JMP       T,HOLD
        RSHFT CONDENABL;

%***********************************************
%***********************************************
% LEFT SHIFT



        A,R5 B,17           ALUF,PASSA          ALUD,Q
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,2 B,Z             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD
        LSHFB CONDENABL;

        A,2 B,R1            ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        LSHFT;

%***********************************************

% READ FIRST OPERAND TO RF LEVEL 0

LSHFB:  A,A                 ALUF,A-1            ALUD,Q
        IDBS,ALU                                T,NEXT      T,PUSH;

                            ALUF,Q+1            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;  %********************

        A,R1 B,LC           ALUF,A-Q-1          ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD
 COND,F15;

        A,0 B,LC                                ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,NEXT      XRF T,POP
                                                            LCOUNT;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,D B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        TTPWD;

LSHFT:  A,0 B,17            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,Z                 ALUF,ANDAQ          ALUD,Q
        IDBS,GPR            COMM,LDLC           T,NEXT      T,HOLD;

        A,0 B,17            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       XRF T,PUSH
        CSAV1;

        A,2 B,Z             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,PUSH
        SBUNO;

        A,R1 B,R5           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,4 B,14            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,R5                ALUF,A-1            ALUD,Q
        IDBS,ALU                                T,JMP       T,PUSH
        TEMTS;

        B,3                                     ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,JMP       T,HOLD
        LSHFC;

TEMTS:                                          ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

        A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,POP;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,PUSH
        CONDENABL;

        A,0 B,LC            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      XRF T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        B,LC                ALUF,D-Q            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
        USAV3 CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;
                            ALUF,B+1            ALUD,B
        B,P                                     T,JMP       T,HOLD
        IDBS,ALU
        USAV3;

SBUNO:  A,R5 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      XRF T,HOLD
        SLLBY CONDENABL;

        B,L                 ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

        B,17                ALUF,MASKDQ         ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        BUNNC;

SLLBY:  A,Z B,L             ALUF,ANDDA          ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        170000;

BUNNC:  A,0 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,4 B,10            ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,RETURN    T,POP;

LSHFC:  A,R3 B,4            ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,2 B,B             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        LSHLC CONDENABL;
%
%****************************************
%
% SHIFT-COUNT > 4, MOVE POINTERS
%
        A,R3 B,R2           ALUF,PASSA          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R2                ALUF,PASSB          ALUD,SRB    MIS,ZIN
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,PUSH
        3;

        B,R5                ALUF,B-1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD
 COND,F=0;

        B,R2                ALUF,B-1            ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        3;

        A,0 B,LC            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      XRF T,POP
                                                            LCOUNT;

LSHLC:  A,R3 B,R3           ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R4 B,STS          ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        FINSH CONDENABL;
%
%****************************************
%
% SHIFT INSIDE THE WORD (SHIFT-COUNT<4)
%

        B,R2                ALUF,ZERO           ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        17;

        B,R3                ALUF,PASSB          ALUD,SLD    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R5                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R3                ALUF,PASSB          ALUD,SLD    MIS,ZIN
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        2;

        A,R3 B,R3           ALUF,A-D            ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,2 B,L             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,NEXT      T,PUSH;

        B,R3                ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD
 COND,LC=0;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        B,R1                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,PUSH;

        B,R1                ALUF,PASSB          ALUD,SLD    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        A,L B,R4            ALUF,B-1            ALUD,B,YA
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        A,R2 B,R1           ALUF,ORAB           ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

        A,0 B,LC                                ALUD,NONE
                                                            XRF
        IDBS,GPR            COMM,EWRF           T,NEXT      T,HOLD;

        B,L                 ALUF,B-1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        A,R5 B,LC           ALUF,D-A-1          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,HOLD;

        B,R2                ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,POP
        CONDENABL;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

%***********************************************

% TEST OVERFLOW

FINSH:  A,R5 B,STS          ALUF,A+B            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        A,STS B,17          ALUF,A-D-1          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,12 B,R3           ALUF,INVB           ALUD,B
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,PUSH
        RWRIT CONDENABL;

        A,0 B,LC            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      XRF T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        B,STS               ALUF,B+1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD
        XOVER CONDENABL;

        A,STS B,17          ALUF,D-A            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,RETURN    F,HOLD;

        B,STS               ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,JMP       T,POP
        RWRIT CONDENABL;


%********************************************************

% CARRY FROM ROUNDING, AND LEFT SHIFT


LWRIR:  B,R1                ALUF,B+1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,PUSH;

        A,R1 B,17           ALUF,A-D-1          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,POP;

        A,Z B,R5            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        LWRIT CONDENABL;

        B,R1                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,PUSH
        SADD;

        A,R5                ALUF,Q-A            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R1 B,R4           ALUF,B-1            ALUD,B,YA
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,HOLD;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      XRF T,POP
        CONDENABL;

TCLIR:  B,0                 ALUF,D              ALUD,NONE   CRY,C
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,Z B,R5            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        CAROV CONDENABL;

%********************************************************

% TEST UNSIGNED DESTINATION, AND INSERT SIGN

LWRIT:  A,4 B,10            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,15 B,Z            ALUF,PASSQ          ALUD,B
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R5 B,R5           ALUF,B+1            ALUD,B,YA
        IDBS,ALU            COMM,LDLC           T,JMP       T,HOLD
        CHSIG CONDENABL;

        A,2 B,Z             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        LWRIC;

CHSIG:  A,Z B,17            ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,Z B,1             ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        SSPOS CONDENABL;

        B,15                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        SSPOS CONDENABL;

        B,Z                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        LWRIC;

SSPOS:  B,Z                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        14;

LWRIC:  A,R7 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      XRF T,HOLD
        WLLBY CONDENABL;

WLRBY:  B,17                ALUF,MASKDQ         ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

        A,Z                 ALUF,ORAQ           ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        WRITB;

WLLBY:                      ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        170000;

        A,Z                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,ORDQ           ALUD,Q
        IDBS,SWAP                               T,NEXT      T,HOLD;

        A,2 B,12            ALUF,ORDQ           ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

WRITB:  B,R3                ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       XRF T,HOLD
        RWRIC CONDENABL;

%********************************************************

% WRITE SECOND OPERAND WHEN LEFT SHIFT

        A,X B,R6            ALUF,B-A            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,PUSH;

        A,R5 B,R6           ALUF,B+1            ALUD,B,YA
        IDBS,ALU            COMM,LDLC           T,JMP       T,HOLD
        NOVFL CONDENABL;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;  %******************

        A,R5 B,17           ALUF,D-A            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,PUSH
        ZEROF CONDENABL;

        A,R6 B,X            ALUF,A-B-1          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,HOLD;

        B,R5                ALUF,B+1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,POP
        CONDENABL;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
NOVFL;

ZEROF:  B,0                 ALUF,D              ALUD,Q      CRY,C STS,EA
        IDBS,BARG                               T,RETURN    T,POP;

%****************************************

% TEST OVERFLOW

NOVFL:  A,2 B,15            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,2 B,14            ALUF,MASKDQ         ALUD,NONE
        IDBS,REG                                T,JMP       T,HOLD
        LEOVF CONDENABL;

        A,2 B,14            ALUF,ANDDQ          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        WRITT CONDENABL;

LEOVF:  B,P                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,2 B,14            ALUF,ANDDQ          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

%****************************************

% WRITE TOP-WORD

WRITT:  A,2 B,11            ALUF,ORDQ           ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,X B,P             ALUF,B+1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;  %***************

USAV3:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        CUSV1;

        A,2 B,16                                ALUD,NONE   STS,LO
        IDBS,REG                                T,JMP       T,POP
        CONT;



%****************************************
%****************************************

% RIGHT SHIFT


RSHFT:  A,R5                ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,PUSH;

        A,2 B,Z             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        RSFTC CONDENABL;

%****************************************

% READ SOURCE OPERAND TO XRF (RA,0)

        B,R1                ALUF,B+1            ALUD,Q
        IDBS,ALU                                T,NEXT      T,PUSH;

        IDBS,ALU            ALUF,Q-1            ALUD,Q
                                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;  %********************

        A,A B,LC            ALUF,Q-A-1          ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD
 COND,F15;

        A,0 B,LC                                ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,NEXT      XRF T,HOLD
                                                            LCOUNT;

        A,D B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        TTPWD;

RSFTC:  A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,PUSH
        CSAV1;

        A,4 B,14            ALUF,PASSB          ALUD,B
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,LC                                    ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD;

        A,Z B,17            ALUF,ANDAQ          ALUD,Q
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,B                 ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,2 B,Z             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,PUSH
        SBUNO;

        A,B B,17            ALUF,A-1            ALUD,Q
        IDBS,BARG           COMM,LDLC           T,JMP       T,PUSH
        TEMTS;

        B,R3                ALUF,-B             ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

        A,D                 ALUF,ANDDA          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,2 B,R5            ALUF,D-1            ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD;

        A,R3 B,3            ALUF,A-D-1          ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        B,17                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        RCONT CONDENABL;


%******************************************
% SHIFT COUNT > 4, MOVE POINTERS AND INSERT ZEROES


        A,R3 B,R2           ALUF,PASSA          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R2                ALUF,PASSB          ALUD,SRB    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R2 B,R5           ALUF,B-A            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,B                 ALUF,B-1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,PUSH
 COND,F=0;

        B,R2                ALUF,B-1            ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        3;

        A,0 B,LC            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      XRF T,POP
                                                            LCOUNT;

        B,LC                ALUF,PASSD          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

        B,B                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

RCONT:  A,R3 B,R3           ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R1                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        ZRORS CONDENABL;

%****************************************
%
% SHIFT WITHIN EACH WORD

        B,R3                ALUF,PASSB          ALUD,SLB    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R5 B,L            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        B,R5                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R3                ALUF,B-1            ALUD,SLB
        IDBS,ALU                                T,NEXT      T,PUSH;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,R3 B,R1           ALUF,PASSQ          ALUD,B,YA
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        A,0 B,17            ALUF,ZERO           ALUD,Q
        IDBS,ALU            COMM,EWRF           T,NEXT      XRF T,PUSH
 COND,LC=0;

        B,R1                ALUF,PASSB          ALUD,SRD    MIS,ZIN
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        B,L                 ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        A,R2                ALUF,ORAQ           ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,R4                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        B,L                 ALUF,B-1            ALUD,B
        IDBS,ALU            COMM,LDLC           T,JMP       T,POP
        XTOPR CONDENABL;

        A,B B,LC            ALUF,D-A            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,RETURN    F,HOLD;

        A,R1 B,R2           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,POP
        CONDENABL;

%***********************************************

% FILL ZEROES


ZFILR:  A,R2                ALUF,PASSA          ALUD,Q
        IDBS,ALU                                T,NEXT      T,PUSH;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,R4                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15;

        A,12                ALUF,ZERO           ALUD,Q
        IDBS,BMG            COMM,LDGPR          T,JMP       T,POP
                                                            LCOUNT
        RWRIT;

ZRORS:  A,STS B,R4          ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        IDBS,ALU                                ALUD,NONE
                                                T,JMP       T,HOLD
        ZFILR CONDENABL;

        A,R5 B,R4           ALUF,A-B            ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        B,R1                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

%***********************************************

% TEST OVERFLOW

XTOPR:  A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,12                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD
        XOVER CONDENABL;

        A,B B,LC            ALUF,D-A            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,PUSH;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        RWRIT CONDENABL;

        A,0 B,LC            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      XRF T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        A,B B,LC            ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
        XOVER CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,POP
                                                            LCOUNT
        RWRIT;

XOVER:  A,2 B,15            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

%***********************************************

% TEST ROUNDING


RWRIT:  A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R3 B,R3           ALUF,INVA           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        LWRIT CONDENABL;

        A,R5                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,JMP       T,HOLD
        ROUND;

%***********************************************

% WRITE SECOND OPERAND WHILE RIGHT SHIFT

RWRIC:  A,R6 B,X            ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,PUSH;

        A,R5                ALUF,A-1            ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,JMP       T,HOLD
        NOVFL CONDENABL;

        B,R6                ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,0 B,LC                                ALUD,NONE
                                                            XRF
        IDBS,REG            COMM,WRRQ,APT       T,NEXT      T,HOLD;  %****************

        A,R6 B,X            ALUF,A-B-1          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,HOLD
        NOVFL;

ROUND:  A,R7 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      XRF T,HOLD
        RLFBY CONDENABL;

        B,R1                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        17;
                            ALUF,MASKDQ         ALUD,Q

        IDBS,ARG                                T,NEXT      T,HOLD
        17;

        A,R1 B,5            ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,4                 ALUF,ZERO           ALUD,NONE   STS,EA
        IDBS,BMG            COMM,LDGPR          T,JMP       T,HOLD
        LWRIT CONDENABL;

        B,L                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        10420;

        A,R5 B,R1           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        SADD;

        A,R5                ALUF,Q-A            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

TCARY:  A,0 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,0                 ALUF,D              ALUD,NONE   CRY,C
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R1 B,R5           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        LWRIT CONDENABL;

        A,4 B,14            ALUF,D-1            ALUD,B
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R5                ALUF,A-1            ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,JMP       T,HOLD
        CAROV CONDENABL;

        B,R3                ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,R5 B,Z            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        LWRIR CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        CCARY;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

CCARY:  A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,PUSH
        SADD;

        B,R4                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0;

        A,R5                ALUF,Q-A            ALUD,Q
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,0                 ALUF,D              ALUD,NONE   CRY,C
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R1 B,R5           ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,LDLC           T,JMP       T,HOLD
        LWRIT CONDENABL;

CAROV:  A,2 B,15            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        LWRIT;

RLFBY:  B,R1                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        7400;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        170000;

                                                ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        2400;

        A,R1                ALUF,A-D            ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,14                ALUF,ZERO           ALUD,NONE   STS,EA
        IDBS,BMG            COMM,LDGPR          T,JMP       T,HOLD
        LWRIT CONDENABL;

        B,L                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        10420;

        A,R5 B,R1           ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        SADD;

        A,R5                ALUF,Q-A            ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        TCARY;





%***********************************************
% COMMERCIAL INSTRUCTION: PACK (A,D -ASCII-FIELD -> X,T -BCD-FIELD)
%***********************************************



PACK:   B,R5                ALUF,ZERO           ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

        A,T B,R1            ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,D                 ALUF,ANDDA          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD
        XNOTE CONDENABL;

        A,0 B,STS           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        XADEM CONDENABL;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,POP
        CONT;

XADEM:  A,3 B,11            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,3 B,12            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        TADEM;

%****************************************
%
% READ X,T-OPERAND FIRST AND LAST WORD IF NOT EMPTY

XNOTE:  A,3 B,11            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,3 B,12            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,T B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LWA;

        A,R1 B,R2           ALUF,ZERO           ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG           COMM,RDRQ,APT       T,NEXT      T,HOLD  %*****************%
 COND,F=0                                       F,NEXT      F,HOLD;


        IDBS,DBR            ALUF,PASSD          ALUD,Q
 COND,COND                                      T,NEXT      T,HOLD  F,NEXT      F,HOLD;

        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;


        IDBS,ALU            ALUF,PASSQ          ALUD,NONE
        PRFIR CONDENABL;    COMM,WRRQ,APT       T,JMP       T,HOLD

        B,R2                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

        A,1 B,R5            ALUF,PASSD          ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD;

PRFIR:  A,2 B,R2            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,T B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,RDRQ,APT       T,JMP       T,PUSH  %****************%
        TTPWD;

        A,Z B,Z             ALUF,INVA           ALUD,B,YA
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,DBR                                T,NEXT      T,HOLD;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;

        A,Z                 ALUF,ANDAQ          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,2 B,11            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,2 B,14                                ALUD,NONE
        IDBS,GPR            COMM,EWRF           T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

%********************************************************

% TEST A,D-OPREAND EMPTY, AND READ IT TO RF LEVEL 0

TADEM:  A,3 B,12            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,A B,R6            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        NEMP CONDENABL;

        B,R3                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        30060;

        B,R2                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        CSAV1;

        B,B                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        16;

        A,5 B,R1            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,R4                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        USIGN;

NEMP:   A,D B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LWAB;

        A,R6 B,17           ALUF,A+1            ALUD,Q
        IDBS,BARG           COMM,LDLC           T,NEXT      T,PUSH;

                            ALUF,Q-1            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;  %*****************

        A,A B,LC            ALUF,Q-A-1          ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD
 COND,F15;

        A,0 B,LC                                ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,NEXT      XRF T,POP
                                                            LCOUNT;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,D                 ALUF,PASSA          ALUD,NONE
        IDBS,GPR            COMM,LDLC           T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        B,R2                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        ADEMP CONDENABL;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

                            ALUF,ORDQ           ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        30000;

ADEMP:  A,0 B,LC            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       XRF T,PUSH
        CSAV1;

        B,B                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        16;

        A,R7 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,0 B,17            ALUF,PASSD          ALUD,Q
        IDBS,REG            COMM,LDGPR          T,JMP       XRF T,HOLD
        DECSA CONDENABL;

                            ALUF,PASSD          ALUD,Q
        IDBS,SWAP                               T,NEXT      T,HOLD;

        A,1 B,R2            ALUF,PASSD          ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD;

%********************************************************

% DECODE SIGN REPRESENTATION OF A,D-OPERAND

DECSA:                      ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        177;

        A,5 B,11            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,R3                ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,15 B,R4           ALUF,B-1            ALUD,B
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,D                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,14                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD
        USIGN CONDENABL;

        A,D                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,1 B,R1            ALUF,PASSD          ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD
        LEAD CONDENABL;

        A,D                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F11                                       F,NEXT      F,HOLD;

        A,R1 B,R2           ALUF,A+B            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        SEPTR CONDENABL;

%********************************************************

% EMBEDDED TRAILING/LEADING


EMBC:   B,R1                ALUF,B+1            ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        173;

                            ALUF,D-Q            ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R1 B,Z            ALUF,A+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        PZERO CONDENABL;

                            ALUF,D-Q            ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        175;

        B,Z                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        PZERO CONDENABL;

        B,Z                 ALUF,B-1            ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        112;

                            ALUF,Q-D            ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        B,17                                    ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,JMP       T,HOLD
        POS CONDENABL;

NEG:                        ALUF,D-Q            ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        122;

        A,11                ALUF,Q-D-1          ALUD,Q
        IDBS,AARG                               T,JMP       T,HOLD
        ILCDP CONDENABL;

        A,1 B,Z             ALUF,B+1            ALUD,B
        IDBS,BMG            COMM,LDGPR          T,JMP       T,HOLD
        PZERC;

PZERO:  B,2                 ALUF,ZERO           ALUD,Q
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD;

PZERC:  A,Z B,Z             ALUF,D+A            ALUD,B
        IDBS,GPR                                T,JMP       T,HOLD
        TPLEDC;

POS:    A,10                ALUF,D-Q            ALUD,NONE
        IDBS,AARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,7 B,L             ALUF,D+1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        TPLEC CONDENABL;

        A,6                 ALUF,Q-D            ALUD,NONE
        IDBS,AARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,L                 ALUF,A-Q            ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        ILCDP CONDENABL;


        IDBS,ALU                                ALUD,NONE
        ILCDP CONDENABL;

TPLEC:                      ALUF,ANDDQ          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,1                                     ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,JMP       T,HOLD
        PZERC;

TPLEDC: A,14                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,D                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,2 B,R1            ALUF,D+1            ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        TRAIL CONDENABL;

        A,D                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        TRBYT CONDENABL;

                            ALUF,PASSD          ALUD,Q
        IDBS,SWAP                               T,NEXT      T,HOLD;

TRBYT:  A,0 B,LC            ALUF,ORDQ           ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,0 B,17            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        B,R3                ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        TBOD;

TRAIL:  A,1 B,R7            ALUF,PASSQ          ALUD,B
        IDBS,BMG            COMM,LDLC           T,NEXT      T,HOLD
 COND,LC=0;

        A,1 B,R1            ALUF,D+1            ALUD,B
        IDBS,AARG                               T,NEXT      T,PUSH;

        B,R7                ALUF,PASSB          ALUD,SLB
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

        A,R7 B,Z            ALUF,ORAB           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        TBOD;

%****************************************

% UNSIGNED

USIGN:  B,Z                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        14;
        A,2 B,R1            ALUF,D+1            ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        TBOD;


%****************************************

% LEADING


LEAD:   A,D                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;
        A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG            COMM,LDGPR          T,NEXT      XRF T,HOLD
        LEADA CONDENABL;

        A,6                 ALUF,PASSD          ALUD,Q
        IDBS,AARG                               T,JMP       T,HOLD
        LEADB;


LEADA:                                          ALUD,NONE
        IDBS,SWAP           COMM,LDGPR          T,NEXT      T,HOLD;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

LEADB:                      ALUF,ORDQ           ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        30000;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        177;

        A,D                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F11                                       F,JMP       F,HOLD;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD
        EMBC CONDENABL;

        A,0 B,17                                ALUD,NONE
                                                            XRF
        IDBS,REG            COMM,LDGPR          T,NEXT      T,HOLD;

        B,R3                ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

%***********************************************

% SEPARATE LEADING/TRAILING

SEPTR:  A,2 B,R1            ALUF,D+1            ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                            ALUF,Q-D            ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        53;

        B,14                                    ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,JMP       T,HOLD
        SPOS CONDENABL;

                            ALUF,Q-D            ALUD,NONE
        IDBS,ARG                                T,NEXT      T,HOLD
        55;

        B,Z                 ALUF,D+1            ALUD,B
        IDBS,GPR                                T,JMP       T,HOLD
        TBOD CONDENABL;

        A,4                 ALUF,Q-D            ALUD,NONE
        IDBS,AARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        B,Z                 ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
        ILCDP CONDENABL;

%***********************************************

% TEST UNSIGNED DESTINATION AND PREPARE FOR CONVERSION LOOP

TBOD:   A,15                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,Z B,17            ALUF,MASKDA         ALUD,Q
        IDBS,BARG                               T,JMP       T,HOLD
        TBODC CONDENABL;

        B,Z                 ALUF,ORDQ           ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

TBODC:  B,R5                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,R1 B,R5           ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        PHALB CONDENABL;

        A,Z B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

        A,2 B,Z             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        NONEW;

PHALB:  A,R5 B,17           ALUF,A-D-1          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,Z                 ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        BSAVE CONDENABL;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,SWAP           COMM,LDGPR          T,NEXT      T,HOLD;

        A,2 B,Z             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        NONEW;

BSAVE:  B,R1                ALUF,ZERO           ALUD,B
        IDBS,SWAP           COMM,LDGPR          T,NEXT      T,HOLD;

        B,Z                 ALUF,D-1            ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        17;

        B,STS               ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R5                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        LASTW CONDENABL;

NONEW:  A,1 B,17                                ALUD,NONE
        IDBS,GPR            COMM,EWRF           T,JMP       XRF T,HOLD
        PLOOP;

SPOS:   B,Z                 ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,JMP       T,HOLD
        TBOD;

%***********************************************

% CONVERSION LOOP
%
% R2 = BYTE-COUNTER
% R5 = NIBLE-COUNTER
% R6 = CONSTANT
% GPR = SCRATCH
% R3 = CURRENT ASCII-WORD
% Q = SCRATCH
% L = SCRATCH
% R1 = CURRENT BCD-WORD

PLOOP:  A,3 B,10            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,R7                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,PUSH
        34400;

        A,R2 B,10           ALUF,D-A            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,7 B,R6            ALUF,D+1            ALUD,B
        IDBS,AARG                               T,JMP       T,PUSH
        PREAD CONDENABL;

        A,6 B,R2            ALUF,PASSB          ALUD,NONE
        IDBS,AARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,R3                ALUF,PASSA          ALUD,Q
        IDBS,SWAP           COMM,LDGPR          T,NEXT      T,HOLD
        PLBYT CONDENABL;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        177;

        A,6                 ALUF,Q-D            ALUD,NONE
        IDBS,AARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,R6 B,17           ALUF,A-Q            ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,JMP       T,HOLD
        ILLCH CONDENABL;

        B,L                 ALUF,ANDDQ          ALUD,B
        IDBS,GPR                                T,JMP       T,HOLD
        ILLCH CONDENABL;

CLOOP:  A,R5 B,R2           ALUF,A-B            ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,R2 B,R5           ALUF,A-B-1          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,JMP       T,HOLD
        SRIGT CONDENABL;

        B,L                 ALUF,PASSB          ALUD,SRB    MIS,ROT
        IDBS,GPR            COMM,LDLC           T,NEXT      T,HOLD
 COND,LC=0;

        B,L                 ALUF,PASSB          ALUD,SRB    MIS,ROT
        IDBS,ALU            COMM,CLFF           T,NEXT      T,PUSH;

        A,1 B,L             ALUF,PASSB          ALUD,SLB    MIS,ROT
        IDBS,AARG           COMM,LDGPR          T,JMP       T,POP
                                                            LCOUNT
        TSAVE;

SRIGT:  B,L                 ALUF,PASSB          ALUD,SLB    MIS,ROT
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,LC=0;

        A,1 B,L             ALUF,PASSB          ALUD,SRB    MIS,ROT
        IDBS,AARG           COMM,LDGPR          T,JMP       T,POP
                                                            LCOUNT
        TSAVE;

PLBYT:                      ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        77400;

                            ALUF,Q-D            ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,R7 B,17           ALUF,A-Q            ALUD,NONE
        IDBS,BARG                               T,JMP       T,HOLD
        ILLCV CONDENABL;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,SWAP                               T,JMP       T,HOLD
        ILLCV CONDENABL;

        B,L                 ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        CLOOP;

TSAVE:  A,R2 B,R2           ALUF,D+A            ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R3 B,4            ALUF,PASSA          ALUD,Q
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD;

        A,R5 B,R5           ALUF,D+A            ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R5 B,14           ALUF,D-A            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,RETURN    F,HOLD;

        A,L B,R1            ALUF,ORAB           ALUD,B
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD
        CONDENABL;

        B,R5                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,STS               ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,Z B,Z             ALUF,B-1            ALUD,B,YA
        IDBS,ALU            COMM,LDLC           T,JMP       T,HOLD
        LASTW CONDENABL;

        B,R1                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,1 B,LC                                ALUD,NONE
                                                            XRF
        IDBS,GPR            COMM,EWRF           T,RETURN    T,HOLD;

%****************************************

% SAVE LAST WORD, TEST OVERFLOW


LASTW:  A,R2 B,17           ALUF,A-D-1          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,SWAP                               T,JMP       T,HOLD
        LASTC CONDENABL;

        A,R3                ALUF,ANDAQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

LASTC:  A,1 B,LC                                ALUD,NONE
        IDBS,GPR            COMM,EWRF           T,NEXT      XRF T,HOLD
        POVFL CONDENABL;
        A,B B,R4            ALUF,PASSB          ALUD,B,YA
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;


        IDBS,ALU                                ALUD,NONE
        PWRIT CONDENABL;                        T,JMP       T,HOLD

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,PUSH
        30060;


        IDBS,ARG            ALUF,PASSD          ALUD,Q
        77577;                                  T,NEXT      T,HOLD

        A,0 B,LC            ALUF,ANDDQ          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,R1                ALUF,XORAQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        B,R4                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        POVFL CONDENABL;


        IDBS,ALU                                ALUD,NONE
        PWRIT;                                  T,JMP       LCOUNT T,POP

POVFL:  A,2 B,15            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        PWRIT;

%****************************************
%
% READ NEXT WORD FROM FIRST OPERAND

PREAD:  A,R4                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,B B,R2            ALUF,ZERO           ALUD,B,YA
        IDBS,ALU            COMM,LDLC           T,JMP       T,HOLD
        PSLUT CONDENABL;

        B,R4                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        B,R3                ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,B                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;

PSLUT:  B,R3                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,RETURN    T,POP
        30060;

%********************************************************

% TEST DESTINATION EMPTY, WRITE X,T-FIELD, AND TEST OVERFLOW


PWRIT:  A,X B,R6            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,3 B,11            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,5 B,11            ALUF,PASSD          ALUD,B
        IDBS,REG                                T,JMP       T,HOLD
        POVER CONDENABL;

        A,1 B,17            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,PUSH
        WRITS;

        A,2 B,15            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,1 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,HOLD
        POVEF CONDENABL;

        A,2 B,14            ALUF,MASKDQ         ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,2 B,14            ALUF,ANDDQ          ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        PUSAV CONDENABL;

POVEF:  B,P                 ALUF,B-1            ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

        A,D B,D             ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,D B,D             ALUF,D+A+1          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,2 B,14            ALUF,ANDDQ          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

PUSAV:  A,2 B,11            ALUF,ORDQ           ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,R6 B,P            ALUF,B+1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,JMP       T,HOLD  %*******************
        USAV4;

%****************************************

%       SUBROUTINE TO WRITE FROM XRF LEVEL 1 TO MEMORY

WRITS:  A,2 B,12            ALUF,ORDQ           ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,1 B,17            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,R1 B,R6           ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,PUSH;

        B,17                                    ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,RETURN    T,POP
        CONDENABL;

        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,1 B,LC                                ALUD,NONE
                                                            XRF
        IDBS,REG            COMM,WRRQ,APT       T,NEXT      T,HOLD;  %*****************

        A,R1 B,R6           ALUF,A-B-1          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0;

        B,R1                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

                                                ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP;

%*********************************************************

%       X,T-OPERAND EMPTY, TEST OVERFLOW


POVER:  A,2 B,15            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,4 B,R1            ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        TOVER CONDENABL;

        A,1 B,17            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        B,17                ALUF,MASKDQ         ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        TOVER CONDENABL;

POVEC:  B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        USAV4;

TOVER:  A,R1 B,D            ALUF,MASKAB         ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,D B,D             ALUF,D+A+1          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        USAV4;

%****************************************

% ILLEGAL CODE, SET ADDRESS AND CODE IN A,D-REG.


ILLCV:  A,7 B,STS           ALUF,A+B            ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,D B,R3            ALUF,MASKDA         ALUD,B
        IDBS,SWAP                               T,JMP       T,HOLD
        ILLC;

ILLCH:  A,7 B,STS           ALUF,A+B            ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,D B,R3            ALUF,ORDA           ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

ILLC:   A,3 B,10            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,4 B,R1            ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        TILOV CONDENABL;

        A,STS B,R6          ALUF,A-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,3 B,11            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R1 B,R3           ALUF,MASKAB         ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        TOVER CONDENABL;

        A,1 B,17            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,5 B,11            ALUF,PASSD          ALUD,B
        IDBS,REG                                T,JMP       T,PUSH
        WRITS;

TILOV:  A,R6 B,X            ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,R5                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD
        PNWRT CONDENABL;

        A,17                ALUF,D-1            ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,2 B,14            ALUF,ANDDQ          ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,LC                ALUF,Q-D            ALUD,NONE
        IDBS,BMG                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,4 B,R1            ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        TOVER CONDENABL;

PNWRT:  A,R4 B,A            ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,D            ALUF,D+A+1          ALUD,B
        IDBS,BARG                               T,JMP       T,HOLD
        USAV4;

%***********************************************

% ILLEGAL CODE IN SIGN, GIVE ADDRESS AND CODE IN A,D-REG.

ILCDP:  A,3 B,11            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,4 B,R1            ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        TOVER CONDENABL;

        A,14                ALUF,PASSD          ALUD,Q
        IDBS,BMG                                T,NEXT      T,HOLD;

        A,D                 ALUF,ANDAQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,17 B,D            ALUF,PASSB          ALUD,Q
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD
        BAANN CONDENABL;

        A,R7 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R6 B,A            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        ORDBN CONDENABL;

        A,D                 ALUF,MASKDA         ALUD,Q
        IDBS,GPR                                T,JMP       T,HOLD
        BAANN;

ORDBN:  A,D                 ALUF,ORDA           ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

BAANN:  B,D                 ALUF,MASKDQ         ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        37;

        A,D B,D             ALUF,ORDA           ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        USAV4;








%********************************************************

% COMMERCIAL INSTRUCTION: UPACK (A,D -BCD-FIELD -> X,T -ASCII-FIELD)

%********************************************************

UPACK:  B,R5                ALUF,ZERO           ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

        A,T B,R1            ALUF,ANDDA          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,D                 ALUF,ANDDA          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD
        TNOTE CONDENABL;

        A,0 B,R4            ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD
        TEMPT CONDENABL;

        B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,POP
        CONT;

%********************************************************

% READ FIRST AND LAST WORD OF X,T-OPERAND


TNOTE:  A,3 B,11            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,3 B,12            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,X B,R6            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,T B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LWAB;

        A,R6 B,R2           ALUF,ZERO           ALUD,B,YA
        IDBS,ALU                                T,JMP       T,HOLD
        URBOT;

TEMPT:  A,3 B,11            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,3 B,12            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       T,HOLD
        TAEMP;

URBOT:  A,R7 B,1            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG           COMM,RDRQ,APT       T,NEXT      T,HOLD  %********************
 COND,F=0                                       F,NEXT      F,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,DBR                                T,NEXT      T,HOLD
 COND,COND                                      F,NEXT      T,HOLD;

        A,R6                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,JMP       T,HOLD
        URFIR CONDENABL;

        B,R2                ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        377;

        A,1 B,R5            ALUF,PASSD          ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD;

URFIR:  A,X B,T             ALUF,PASSB          ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        B,T                 ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;  %***********************

        A,2 B,R2            ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD
        URFIC CONDENABL;

        B,Z                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        177400;

URFIC:  A,Z                 ALUF,ANDDA          ALUD,Q
        IDBS,DBR            COMM,LDGPR          T,NEXT      T,HOLD;

        A,X                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,GPR            COMM,WRRQ,APT       T,NEXT      T,HOLD;

        A,2 B,11            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

%********************************************************

% TEST A,D-OPERAND EMPTY, AND READ IT TO RF LEVEL 1


TAEMP:  A,3 B,12            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,A B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        UNEMP CONDENABL;

        A,1 B,17                                ALUD,NONE
                                                            XRF
        IDBS,BARG           COMM,EWRF           T,NEXT      T,HOLD;

        B,R3                ALUF,ZERO           ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        17;

        A,0 B,STS           ALUF,PASSD          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        UEMP1;

POSS:   B,13                                    ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,JMP       T,HOLD
        UDCS;

UNEMP:                                          ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

        A,D B,R2            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,PUSH
        LWA;

        A,R1 B,17           ALUF,A+1            ALUD,Q
        IDBS,BARG           COMM,LDLC           T,NEXT      T,PUSH;

                            ALUF,Q-1            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU            COMM,RDRQ,APT       T,NEXT      T,HOLD;  %***********************

        A,A B,LC            ALUF,Q-A-1          ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD
 COND,F15;

        A,1 B,LC                                ALUD,NONE
        IDBS,DBR            COMM,EWRF           T,NEXT      XRF T,POP
                                                            LCOUNT;

        A,D B,R2            ALUF,PASSA          ALUD,B
        IDBS,GPR            COMM,LDLC           T,JMP       T,PUSH
        TTPWD;

        A,1 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        A,Z                 ALUF,ANDAQ          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,1 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

UEMP1:  A,2 B,Z             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,PUSH
        CSAV1;

        A,R3 B,2            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,1 B,17            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      XRF T,HOLD
        HALVB CONDENABL;

        B,Z                 ALUF,ANDDQ          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

        B,17                ALUF,MASKDQ         ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

        A,1 B,R2            ALUF,D+1            ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        UDECC;

HALVB:  A,Z B,Z             ALUF,ANDDA          ALUD,B
        IDBS,SWAP                               T,NEXT      T,HOLD;

        A,R2                ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        170000;

        B,R2                ALUF,D+1            ALUD,B
        IDBS,BARG                               T,NEXT      T,HOLD;

%***********************************************

% IF X,T-OPERAND EMPTY, TEST OVERFLOW


UDECC:  A,3 B,11            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        B,STS               ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        UDECB CONDENABL;

        B,16                ALUF,PASSQ          ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,NEXT      T,HOLD
        UDECA CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        EOVER CONDENABL;

INCRP:  B,P                 ALUF,B+1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        USAV4;

UDECA:  B,STS               ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,PUSH
        EOVER CONDENABL;

        A,1 B,LC            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      XRF T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        B,STS               ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        EOVER CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,POP
                                                            LCOUNT
        INCRP;

EOVER:                                          ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

        A,D B,D             ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,D B,D             ALUF,D+A+1          ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        USAV4;

%********************************************

% DECODE SIGN REPRESENTATION OF X.T-OPERAND AND CONVERT SIGN

UDECB:  A,15 B,R3           ALUF,PASSQ          ALUD,B
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,2 B,B             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD
        ULEAD CONDENABL;

        A,4 B,R1            ALUF,PASSD          ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD;

        A,Z B,17            ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,Z B,15            ALUF,A-D            ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,JMP       T,HOLD
        POSS CONDENABL;

        A,Z B,1             ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        POSS CONDENABL;

UDCS:   A,R1                ALUF,ORDA           ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,2 B,14            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        B,R1                ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,14 B,R3           ALUF,PASSB          ALUD,Q
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        B,R2                ALUF,B-1            ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD
        ULEAD CONDENABL;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F11                                       F,NEXT      F,HOLD;


        IDBS,ALU                                ALUD,NONE
        USEPT CONDENABL;                        T,JMP       T,HOLD

%***********************************************
%
% EMBEDDED TRAILING


        A,R3 B,Z            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,LC=0;

        A,2 B,Z             ALUF,PASSB          ALUD,SRB    MIS,ZIN
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,POP
                                                            LCOUNT;

        A,Z B,17            ALUF,ANDDA          ALUD,Q
        IDBS,BARG                               T,NEXT      T,HOLD;

        B,Z                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        16;

        B,12                ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,R2 B,R2           ALUF,D+A            ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
        ILLE CONDENABL;


        IDBS,ALU                                ALUD,NONE
        SUBEM;                                  T,JMP       T,PUSH

        A,R5                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        B,R1                ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        SAME CONDENABL;

        B,R3                ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,1 B,R5            ALUF,PASSD          ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        UPLOP;

SUBEM:  A,R1 B,4            ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,JMP       T,HOLD
        EMPOS CONDENABL;

        B,R1                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,RETURN    T,POP
        CONDENABL 175;

        B,R1                ALUF,D+Q            ALUD,B
        IDBS,ARG                                T,RETURN    T,POP
        111;

EMPOS:  B,R1                ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,RETURN    T,POP
        173 CONDENABL;

        A,10 B,R1           ALUF,D+Q            ALUD,B
        IDBS,AARG                               T,RETURN    T,POP;

%****************************************

% SEPARATE TRAILING

USEPT:  A,R5                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,1 B,R5            ALUF,PASSD          ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        UPLOP CONDENABL;
        A,2 B,14                                ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD;

SAME:   A,0 B,17                                ALUD,NONE
                                                            XRF
        IDBS,SWAP           COMM,EWRF           T,NEXT      T,HOLD;

        B,B                 ALUF,PASSD          ALUD,B
        IDBS,ARG            COMM,LDLC           T,NEXT      T,HOLD
        16;

        B,Z                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,HOLD
        IDBS,ARG
        16;
        B,R4                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,R3                ALUF,PASSB          ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        LAWRA CONDENABL;

        B,R1                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R5                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        UCLOP;

%***********************************************

% LEADING SIGN IN X,T-OPERAND


ULEAD:  B,R1                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

UPLOP:  A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD;

        A,0 B,17                                ALUD,NONE
                                                            XRF
        IDBS,GPR            COMM,EWRF           T,NEXT      T,HOLD;

%***********************************************

% CONVERSION LOOP

% R2 = NIBLE-COUNTER
% R5 = BYTE-COUNTER
% R3 = CURRENT BCD-WORD
% R1 = CURRENT ASCII-WORD
% L = SCRATCH
% Q = SCRATCH


UCLOP:  B,R2                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,Z                 ALUF,PASSD          ALUD,B
        IDBS,ARG                                T,NEXT      T,PUSH
        16;

        A,R2 B,14           ALUF,D-A            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;


        IDBS,ALU                                ALUD,NONE
        UPRED CONDENABL;                        T,JMP       T,PUSH

        A,R2 B,R5           ALUF,A-B            ALUD,NONE
        IDBS,ALU            COMM,LDGPR          T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,R3 B,L            ALUF,PASSA          ALUD,B
        IDBS,GPR            COMM,LDLC           T,NEXT      T,HOLD
        POSSH CONDENABL;

        A,R5 B,R2           ALUF,A-B-1          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        B,L                 ALUF,PASSB          ALUD,SRB    MIS,ROT
        IDBS,ALU                                T,NEXT      T,PUSH
 COND,LC=0;

        B,L                 ALUF,PASSB          ALUD,SLB    MIS,ROT
        IDBS,ALU                                T,JMP       T,POP
                                                            LCOUNT
        UPLP;

POSSH:  B,L                 ALUF,PASSB          ALUD,SLB    MIS,ROT
        IDBS,ALU            COMM,CLFF           T,NEXT      T,PUSH
 COND,LC=0;

        B,L                 ALUF,PASSB          ALUD,SRB    MIS,ROT
        IDBS,ALU                                T,NEXT      T,POP
        IDBS,ALU
                                                            LCOUNT;
        B,L                 ALUF,PASSB          ALUD,SLB    MIS,ROT
                                                T,NEXT      T,HOLD;
        IDBS,ALU
UPLP:   A,L                 ALUF,PASSA          ALUD,Q
                                                T,NEXT      T,HOLD;

        A,R5 B,4            ALUF,PASSA          ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,R2 B,R2           ALUF,D+A            ALUD,B
        IDBS,GPR                                T,JMP       T,HOLD
        RBYT CONDENABL;

                            ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        7400;

                                                ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        5000;

                            ALUF,Q-D            ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        B,R5                ALUF,ZERO           ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        ILL CONDENABL;

                            ALUF,ORDQ           ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        30000;

        A,R1                ALUF,ORAQ           ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,B B,R4            ALUF,B-1            ALUD,B,YA
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        B,B                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,POP
        LAWRD CONDENABL;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,RETURN    T,HOLD;

RBYT:                       ALUF,ANDDQ          ALUD,Q
        IDBS,ARG                                T,NEXT      T,HOLD
        17;

        B,12                ALUF,Q-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,1 B,R5            ALUF,PASSD          ALUD,B
        IDBS,AARG                               T,NEXT      T,HOLD
        ILL CONDENABL;

        B,R1                ALUF,ORDQ           ALUD,B
        IDBS,ARG                                T,RETURN    T,HOLD
        60;

%********************************************************
% READ NEXT WORD FROM A,D-OPERAND TO Q,RJ



UPRED:  B,STS               ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,Z B,R2            ALUF,ZERO           ALUD,B,YA
        IDBS,ALU            COMM,LDLC           T,JMP       T,HOLD
        SLUT CONDENABL;
% CONDENABL
        B,STS               ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;
        IDBS,REG                                T,NEXT      XRF T,HOLD
        A,1 B,LC            ALUF,PASSD          ALUD,Q
                                                            XRF
        IDBS,REG                                T,NEXT      T,HOLD;

        B,Z                 ALUF,B-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        SUPRD;

SLUT:                       ALUF,ZERO           ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

SUPRD:  B,R3                ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,RETURN    T,POP;

%***********************************************

% SAVE LAST WORD OF X,T OPERAND AND TEST OVERFLOW


LARDC:  A,0 B,L             ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        LAWRC;

LAWRA:  B,R2                ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

LAWRD:  A,R2                ALUF,PASSA          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE  %OBS! LAST LC (B)
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,R2 B,17           ALUF,A-D-1          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,LC B,L            ALUF,D-1            ALUD,B
        IDBS,BMG                                T,JMP       T,HOLD
        LARDC CONDENABL;

LAWRC:  A,L B,R3            ALUF,MASKAB         ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        B,STS               ALUF,PASSB          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        UPOVR CONDENABL;

        B,Z                 ALUF,PASSB          ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD
        TOVFL CONDENABL;

TLEAD:  A,15                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,JMP       T,HOLD
        TLEAC;

TOVFL:  B,STS               ALUF,B+1            ALUD,B
        IDBS,ALU                                T,NEXT      T,PUSH;

        A,1 B,LC            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      XRF T,HOLD
 COND,F=0                                       F,JMP       F,POP;

        B,STS               ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        UPOVR CONDENABL;

                                                ALUD,NONE
        IDBS,ALU                                T,JMP       T,POP
                                                            LCOUNT
        TLEAD;

UPOVR:  A,2 B,15            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        TLEAD;

%****************************************

% TEST LEADING SIGN OF X,T-OPERAND


TLEAC:  A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        UWRIT CONDENABL;

        A,14                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,13                                    ALUD,NONE
        IDBS,BMG            COMM,LDGPR          T,JMP       T,HOLD
        UWRIT CONDENABL;

        A,T                 ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        B,R3                ALUF,PASSQ          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD
        USEPL CONDENABL;

%****************************************
%****************************************
% EMBEDDED LEADING


        A,2 B,14                                ALUD,NONE
        IDBS,REG            COMM,LDGPR          T,NEXT      T,HOLD;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;
        B,R1                ALUF,PASSD          ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD
        TOPHB CONDENABL;

        B,17                ALUF,ANDDQ          ALUD,Q
        IDBS,BARG                               T,JMP       T,PUSH
        SUBEM;

                                                ALUD,NONE

        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        377;

        A,R3                ALUF,MASKDA         ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R1                ALUF,ORAQ           ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

LEADC:  A,B                 ALUF,A+1            ALUD,NONE
        IDBS,ALU            COMM,LDLC           T,NEXT      T,HOLD;

        A,X B,R1            ALUF,PASSA          ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,0 B,LC            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,JMP       XRF T,HOLD
        UWRIT;

TOPHB:                      ALUF,PASSQ          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSD          ALUD,Q
        IDBS,SWAP                               T,NEXT      T,HOLD;

        B,17                ALUF,ANDDQ          ALUD,Q
        IDBS,BARG                               T,JMP       T,PUSH
        SUBEM;

                                                ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        377;
        A,R3                ALUF,ANDDA          ALUD,Q
        IDBS,GPR                                T,NEXT      T,HOLD;

        A,R1                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;


                            ALUF,ORDQ           ALUD,Q
        IDBS,SWAP                               T,JMP       T,HOLD
        LEADC;

%******************************************
% SEPARATE LEADING


USEPL:  A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,NEXT      F,HOLD;

        A,10                ALUF,D-1            ALUD,Q
        IDBS,BMG                                T,JMP       T,HOLD
        SEPRB CONDENABL;

                                                ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        7400;

        A,R3                ALUF,ANDDA          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;

        A,R3                ALUF,ANDAQ          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
        USOVF CONDENABL;
        A,2 B,14                                ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD;


                            ALUF,ORDQ           ALUD,Q
        IDBS,SWAP                               T,JMP       T,HOLD
        LEADC;

SEPRB:                      ALUF,INVQ           ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,17           ALUF,ANDDA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,PUSH;

        A,R3                ALUF,ANDAQ          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD
        USOVF CONDENABL;

        A,2 B,14            ALUF,ORDQ           ALUD,Q
        IDBS,REG                                T,JMP       T,HOLD
        LEADC;

USOVF:  A,2 B,15            ALUF,ZERO           ALUD,NONE
        IDBS,ALU            COMM,EWRF           T,RETURN    T,POP;

%***********************************************

% WRITE X,T OPERAND, TEST OVERFLOW IN TOP-WORD

UWRIT:  A,0 B,17            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,PUSH
        UWRTS;

        A,2 B,15            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,HOLD
        UVFLT CONDENABL;

        A,T B,17            ALUF,PASSA          ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,SWAP           COMM,LDGPR          T,NEXT      T,HOLD
        WRTOP CONDENABL;

        A,10 B,Z            ALUF,D-1            ALUD,B
        IDBS,BMG                                T,NEXT      T,HOLD;

                            ALUF,ANDDQ          ALUD,NONE
        IDBS,GPR                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,Z                 ALUF,ANDAQ          ALUD,Q
        IDBS,ALU                                T,JMP       T,HOLD
        WRTOP CONDENABL;

UVFLT:  A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,10 B,Z
        IDBS,BMG            ALUF,D-1            ALUD,B
        UVFLO CONDENABL;                        T,NEXT      T,HOLD

        A,Z                 ALUF,ANDAQ          ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

UVFLO:                                          ALUD,NONE
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        37;

        A,D B,D             ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

        B,P                 ALUF,B-1            ALUD,B
        IDBS,ARG            COMM,LDGPR          T,NEXT      T,HOLD
        3;

        A,D B,D             ALUF,ORDA           ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

WRTOP:  A,2 B,11            ALUF,ORDQ           ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,R6 B,P            ALUF,B+1            ALUD,B,YA
        IDBS,ALU                                T,NEXT      T,HOLD;

                            ALUF,PASSQ          ALUD,NONE
        IDBS,ALU            COMM,WRRQ,APT       T,NEXT      T,HOLD;  %********************

%********************************************************

% EXIT, UNSAVE REGISTERS AND STATUS

USAV4:                                          ALUD,NONE
        IDBS,ALU                                T,JMP       T,PUSH
        CUSV1;

        A,2 B,16                                ALUD,NONE   STS,LO
        IDBS,REG                                T,JMP       T,POP
        CONT;

%********************************************************

% SUBROUTINE TO WRITE WORDS FROM RF LEVEL 0 TO MEMORY

UWRTS:  A,2 B,12            ALUF,ORDQ           ALUD,Q
        IDBS,REG                                T,NEXT      T,HOLD;

        A,0 B,17            ALUF,PASSQ          ALUD,NONE
                                                            XRF
        IDBS,ALU            COMM,EWRF           T,NEXT      T,HOLD;

        A,R6 B,R1           ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,PUSH;

        B,17                                    ALUD,NONE
        IDBS,BARG           COMM,LDLC           T,RETURN    T,POP
        CONDENABL;

        A,R6                ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,0 B,LC                                ALUD,NONE
                                                            XRF
        IDBS,REG            COMM,WRRQ,APT       T,NEXT      T,HOLD;  %********************

        A,R6 B,R1           ALUF,A-B-1          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0;

        B,R6                ALUF,B-1            ALUD,B
        IDBS,ALU                                T,NEXT      T,POP
                                                            LCOUNT;

                                                ALUD,NONE
        IDBS,ALU                                T,RETURN    T,POP;

%********************************************************

% ILLEGAL CODE, TEST IN WHITCH BYTE AND GIVE ADDRESS AND CODE IN A,D REG


ILLE:   B,10                                    ALUD,NONE
        IDBS,BARG           COMM,LDGPR          T,NEXT      T,HOLD;

        A,R5 B,R5           ALUF,D+A            ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

ILL:    A,R2 B,14           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

        A,17 B,R4           ALUF,PASSB          ALUD,Q
        IDBS,BMG            COMM,LDGPR          T,NEXT      T,HOLD
        UILCV CONDENABL;
        A,D B,R3            ALUF,ORDA           ALUD,B
        IDBS,GPR                                T,JMP       T,HOLD
        ILC;

UILCV:  A,D B,R3            ALUF,MASKDA         ALUD,B
        IDBS,GPR                                T,NEXT      T,HOLD;

ILC:    A,3 B,10            ALUF,PASSD          ALUD,NONE
        IDBS,REG                                T,NEXT      T,HOLD
 COND,F=0                                       F,NEXT      F,HOLD;

        A,4 B,R7            ALUF,D-1            ALUD,B
        IDBS,AARG                               T,JMP       T,HOLD
        ULONE CONDENABL;

        A,X                 ALUF,A+Q            ALUD,Q
        IDBS,ALU                                T,NEXT      T,HOLD;

        B,R1                ALUF,Q-1            ALUD,B
        IDBS,ALU                                T,JMP       T,HOLD
        IL;

ULONE:  A,X B,R1            ALUF,A+Q            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

IL:     A,R7 B,R3           ALUF,MASKAB         ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,0 B,17            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,JMP       XRF T,PUSH
        UWRTS;

        A,R1 B,X            ALUF,A-B            ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

        A,0 B,LC            ALUF,PASSD          ALUD,Q
        IDBS,REG                                T,NEXT      XRF T,HOLD
        NTOP CONDENABL;

        A,T                 ALUF,PASSA          ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
 COND,F15                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        NTOP CONDENABL;

        A,R5 B,10           ALUF,A-D            ALUD,NONE
        IDBS,BARG                               T,NEXT      T,HOLD
 COND,F=0                                       F,JMP       F,HOLD;

                                                ALUD,NONE
        IDBS,ALU                                T,NEXT      T,HOLD
        EOVER CONDENABL;

NTOP:   A,STS B,A           ALUF,A+B            ALUD,B
        IDBS,ALU                                T,NEXT      T,HOLD;

        A,R3 B,D            ALUF,D+A+1          ALUD,B
        IDBS,BARG                               T,JMP       T,HOLD
        USAV4;




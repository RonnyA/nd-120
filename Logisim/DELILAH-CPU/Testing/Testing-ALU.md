# Testing the Logisim circuits - ALU

## CGA_ALU

The schematic page "ALU_test" contains two modules

| Module | Logic | 
|--------|-------|
| CGA_ALU_SHIFT | Shift logic|
| CGA_ALU | ALU |



## Testing the CGA_ALU_SHIFT

The output on the RB_15_0 bus is a function of the data on the F_15_0 input bus combined with control signals.

* RRI - Rotate Right Input
* RLI - Rotate Left Input

ALU I7 and ALU I8N (N means negated, or inverse)


| I8N | I7  | FUNCTION       | RB_15_0     | Modifier | Status  |
|-----|-----|----------------|-------------|----------|---------|
|  1  |  0  | No change      | F_15_0      |          |  OK     |
|  1  |  1  | No change      | F_15_0      |          |  OK     |
|  0  |  0  | Rotate right   | F_15_0 >> 1 | IF RR1=1, F_15=1 | OK |
|  0  |  1  | Rotate left    | F_15_0 << 1 | IF RRL=1, F_1=1 | OK |


*STATUS: CGA_ALU_SHIFT WORKS 100%*


## Testing the ALU

The ND-120 ALU is identical to the Am2901

Reference docs:
* http://www.whitepubs.com/Am2900_references.html
* http://www.bitsavers.org/pdf/amd/ED2900A_vol1_Jan85.pdf 


The ALU is programmed in microcode through bits 55-65, page 18 "Chapter 3 - Microinstruction word format" in the "ND-06.031.1 EN ND-110 and ND-120 Microprogrammer's Guide"

| Group                        | ALU I       | Bits      |
|------------------------------|-------------|------------|
|ALU Instruction - Source      | ALUI 2-1-0  | Bits 57-55 |
|ALU Instruction - Functon     | ALUI 5-4-3  | Bits 60-58 |
|ALU Instruction - Destination | ALUI 8-7-6  | Bits 63-61 |

**ALU Source**

|Mnemonic  | I2 | I1 | I0 | Source                   | STATUS |
|----------|----|----|----|--------------------------|--------|
|AQ        |0   |0   |0   | R=A operand, S=Q         |
|AB        |0   |0   |1   | R=A operand, S=B operand |
|ZQ        |0   |1   |0   | R=0, S=Q                 |
|ZB        |0   |1   |1   | R=0, S=B operand         |
|ZA        |1   |0   |0   | R=0, S=A operand         |
|DA        |1   |0   |1   | R=Databus, S=A operand   |
|DQ        |1   |1   |0   | R=Databus, S=Q           |
|DZ        |1   |1   |1   | R=Databus, S=0           |

**ALU Function**

|Mnemonic  | I5 | I4 | I3 | Function  | Computation       | STATUS  |
|----------|----|----|----|-----------|-------------------|---------|
|ADD       |0   |0   |0   | R Plus S  | R ⊕ S ⊕ Carry   |
|SUBR      |0   |0   |1   | S Minus R | R' ⊕ S ⊕ Carry  |
|SUBS      |0   |1   |0   | R Minus S | R ⊕ S' ⊕ Carry  |
|OR        |0   |1   |1   | R OR S    | (R' ∧ S') ⊕ 1    |
|AND       |1   |0   |0   | R AND S   | R ∧ S             |  
|NOTRS     |1   |0   |1   | R' AND S  | R' ∧ S            |
|EXOR      |1   |1   |0   | R EX OR S | R ⊕ S' ⊕ 1      |
|EXNOR     |1   |1   |1   | R EX NOR S| R' ⊕ S' ⊕ 1     |

Note for Computation:
* R' means R complemented (ie inverted). Adding the complement of R (R') is the same as substracting R.
* ⊕ Carry means add Carry if set


**ALU Destination**


A and B operands point to a 16 word memory register which can be read or written like an Array

|Mnemonic  | ND Mnemonic |I2  | I1 | I0 | Destination                                       | STATUS |
|----------|-------------|----|----|----|---------------------------------------------------|--------|
|QREG      | ALUD_Q      | 0  |0   |0   | Y=F, Q=F                                          |
|NOP       | ALUD_NONE   | 0  |0   |1   | Y=F                                               |
|RAMA      | ALUD_B_YA   | 0  |1   |0   | Y=[A Operand], [B Operand]=F                      |
|RAMF      | ALUD_B      | 0  |1   |1   | Y=F, [B operand] = F                              |
|RAMQD     | ALUD_SRD    | 1  |0   |0   | Y=F, Q=SHIFT RIGHT(Q), [B operand]=SHIFT_RIGHT(F) |
|RAMD      | ALUD_SRB    | 1  |0   |1   | Y=F, [B operand]=SHIFT_RIGHT(F)                   |
|RAMQU     | ALUD_SLD    | 1  |1   |0   | Y=F, Q=SHIFT LEFT(Q), [B operand]=SHIFT_LEFT(F)   |
|RAMU      | ALUD_SLB    | 1  |1   |1   | Y=F, [B operand]=SHIFT_LEFT(F)                    |




## Test steps

### Test ALL the ALU functions

Use
* ALU Source = DZ (111)
* ALU Destination = QREG (000)
* EA_15_0 <= Input bus

* CSIDBS = 


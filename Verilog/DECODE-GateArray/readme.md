
# Verilog code for DGA (Decode Gate Array)

## Status of Verilog code for DGA 

| Page name                |  QA  | Status                                                     | Test                                            |  Description/Comment                          
|--------------------------|------|------------------------------------------------------------|-------------------------------------------------|-------------------------------------------------------------------------|
| DECODE_DGA.v             |      |  [Verilog created](DGA/circuit/DECODE_DGA.v)               |                                                 | Top module of the DGA 
| DECODE_DGA_COMM.v        |      |  [Verilog created](DGA/circuit/DECODE_DGA_COMM.v)          |                                                 | Decode Internal Databus Commands    
| DECODE_DGA_IDBS.v        |      |  [Verilog created](DGA/circuit/DECODE_DGA_IDBS.v)          |                                                 | Decode Internal Databus SOURCE (IDBS). Generates ENABLE signals for the chips to be read or written            
| DECODE_DGA_PFIFC.v       |      |  [Verilog created](DGA/circuit/DECODE_DGA_PFIFC.v)         |                                                 | FIFO controller. Replaced by FIFO_8BIT.v  
| DECODE_DGA_PFIFC_DELAY.v |      |  [Verilog created](DGA/circuit/DECODE_DGA_PFIFC_DELAY.v)   |                                                 | FIFO delay. Replaced by FIFO_8BIT.v  
| DECODE_DGA_PFIFD.v       |      |  [Verilog created](DGA/circuit/DECODE_DGA_PFIFD.v)         |                                                 | FIFO data. Replaced by FIFO_8BIT.v  
| DECODE_DGA_POW.v         |      |  [Verilog created](DGA/circuit/DECODE_DGA_POW.v)           |                                                 | POWER detection 
| F091.v                   |      |  [Verilog created](DGA/circuit/F091.v)                     |                                                 | NEC F091 - H,L LEVEL GENERATOR     
| F103.v                   |      |  [Verilog created](DGA/circuit/F103.v)                     |                                                 | NEC F103 - Inverter x3 signal drive
| F571.v                   |      |  [Verilog created](DGA/circuit/F571.v)                     |                                                 | NEC F571 - 2 TO 1 MULTIPLEXER
| F595.v                   |      |  [Verilog created](DGA/circuit/F595.v)                     |  ** NEED TO ADD TEST **                         | NEC F595 - R/S Latch with Gated input
| F617.v                   |      |  [Verilog created](DGA/circuit/F617.v)                     |  ** NEED TO ADD TEST **                         | NEC F617 - D Flip-Flop with RB, SB
| F714.v                   |      |  [Verilog created](DGA/circuit/F714.v)                     |  ** NEED TO ADD TEST **                         | NEC F714 - T Flip-Flop with R, S      
| F924.v                   |      |  [Verilog created](DGA/circuit/F924.v)                     |  ** NEED TO ADD TEST **                         | NEC F924 - 4-BIT D-TYPE FLIP-FLOP
                                     
                                                                               
# Test program verification

[GTKWave](DGA\readme.md)


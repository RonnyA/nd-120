# Verilog code

The Verilog code has been split into subfolder matching the structure of the LogiSim and Design Documents

1. DELILAH-CPU
2. DECODE-GateArray
3. CPU-BOARD-3202


## Status

| Folder           | Status Logisim           |  Status Verilog                                | Comment    |
|------------------|--------------------------|------------------------------------------------|------------|
| DELILAH-CPU      | Logisim drawing complete | Verilog compiles - Missing a lot of testcases  |
| DECODE-GateArray | Logisim drawing complete | Verilog compiles - Missing a lot of testcases  |
| CPU-BOARD-3202   | Logisim drawing complete | Generated Verilog code needs to be tested - and then apply many fixes for PAL's and BUS signals | Need to implement support chips like UART and all PAL's. Need to implement missing support chips TTL/MEMORY/++ |

## Verilog code status

| Folder           | # of Verilog Files       | Lines of Verilog code  |
|------------------|--------------------------|------------------------|
| DELILAH-CPU      | 147   | 22,976 |
| DECODE-GateArray |  28   | 4,316  |
| CPU-BOARD-3202   |  84   | 48,219 |
| TOTAL            | 259   | 75,511 |

Note: When all modules are merged, number of files and number of lines will be reduced as there is multiple copies of "base components" from Logisim

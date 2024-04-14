
# Verilog code for CPU BOARD 3202D

## Status of Verilog code for 3202D pr sheet ##

| Page name         |                       | Sheet number       | Area         | Status                                      | Comment                                                                 |
|-------------------|-----------------------|--------------------|--------------|---------------------------------------------|-------------------------------------------------------------------------|
| **Main PCB**                              |
| DELILAH TOP LEVEL | BLOCK DIAGRAM         | 1                  | D3202        |
| DELILAH TOP LEVEL | A PLUG                | 2                  | D3202        |
| DELILAH TOP LEVEL | B PLUG                | 3                  | D3202        |
| DELILAH TOP LEVEL | C PLUG                | 4                  | D3202        |
| **Bus interface**
| BIF               | BUS IF                | 5                  | BIF          |
| BIF/BCTL          | BIF CONTROL           | 6                  | BIF          |
| BIF/BCTL/BDRV     | BUS DRIVERS           | 7                  | BIF          |
| BIF/DPATH         | BIF SYNC              | 8                  | BIF          |
| BIF DATA PATH     | BIF SYNC              | 9                  | BIF          |
| BIF/DPATH/BDLBD   | BIF BD TO LBD         | 10                 | BIF          |
| BIF/DPATH/CDLBD   | BIF CD TO LBD         | 11                 | BIF          |
| BIF/DPATH/LBCTL   | LBD CONTROL           | 12                 | BIF          |
| BIF/DPATH/PESPEA  | BIF PES & PEA         | 13                 | BIF          |
| BIF/DPATH/PPNLBD  | BIF PPN to LBD        | 14                 | BIF          |
| **CPU**                                                                       |
| CPU               | TOP LEVEL             | 15                 | CPU          |
| CPU/CS            | CONTROL STORE         | 16                 | CPU          |
| CPU/CS/ACAL       | MICRO ADDR CALC       | 17                 | CPU          | [Verilog created](circuit/CPU_CS_ACAL_17.v)    | [Test](circuit/CPU_CS_ACAL_17/readme.md)
| CPU/CS/CTL        | CS CONTROL            | 18                 | CPU          | [Verilog created](circuit/CPU_CS_CTL_18.v)    | [Test](circuit/CPU_CS_CTL_18/readme.md)
| CPU/CS/PROM       | CS PROMS              | 19                 | CPU          |
| CPU/CS/TCV        | CS TRANSCIEVERS       | 20                 | CPU          |
| CPU/CS/WCS        | Register file         | 21-22              | CPU          |
| CPU/LAPA          | LA TO PPN BUFF        | 23                 | CPU          |
| CPU/MMU           | MMU TOP LEVEL         | 24                 | CPU          |
| CPU/MMU/CACHE     | CACHE                 | 25                 | CPU          |
| CPU/MMU/CSR       | CACHE STATUS REG      | 26                 | CPU          | [Verilog created](circuit/CPU_MMU_CSR_26.v)    | [Test](circuit/CPU_MMU_CSR_26/readme.md)
| CPU/MMU/HIT       | HIT DETECTION         | 27                 | CPU          | 
| CPU/MMU/PPNX      | PPN TO IDB            | 28                 | CPU          | [Verilog created](circuit/CPU_MMU_PPNX_28.v)    | [Test](circuit/CPU_MMU_PPNX_28/readme.md)
| CPU/MMU/PT        | PAGE TABLES           | 29                 | CPU          | [Verilog created](circuit/CPU_MMU_PT_29.v)      | [Test](circuit/CPU_MMU_PT_29/readme.md) (More test!!)
| CPU/MMU/PTIDB     | PT TO IDB             | 30                 | CPU          | [Verilog created](circuit/CPU_MMU_PTIDB_30.v)   | [Test](circuit/CPU_MMU_PTIDB_30/readme.md) (Bidirectional bus not working correctly in Verilator, maybe in FPGA?)
| CPU/MMU/WCA       | PPN TO CPN            | 31                 | CPU          | [Verilog created](circuit/CPU_MMU_WCA_31.v)     | [Test](circuit/CPU_MMU_WCA_31/readme.md)
| CPU/PROC          | PROCESSOR TOP LEVEL   | 32                 | CPU          | [Verilog created](circuit/CPU_PROC_32.v)        | [Test](circuit/CPU_PROC_32/readme.md)
| CPU/PROC/CGA      | CPU GATE ARRAY        | 33                 | CPU          | [Verilog created](circuit/CPU_PROC_CGA_33.v)    | [Test](circuit/CPU_PROC_CGA_33/readme.md)
| CPU/PROC/CMDDEC   | COMMANDS & IDB DECODE | 34                 | CPU          | [Verilog created](circuit/CPU_PROC_CMDDEC_34.v) | [Test](circuit/CPU_PROC_CMDDEC_34/readme.md)
| CPU/STOC          | IDB TO CD             | 35                 | CPU          | [Verilog created](circuit/CPU_STOC_35.v)        | [Test](circuit/CPU_STOC_35/readme.md)
| **Cycle control**
| CYC               | CYCLE CONTROL         | 36                 | CYC          | [Verilog created](circuit/CYC_36.v)             | [Test](circuit/CYC_36/readme.md)
| **IO**
| IO                | IO TOP LEVEL          | 37                 | IO           | [Verilog created](circuit/IO_37.v)              | [Test](circuit/IO_37/readme.md)  - Need more test!
| IO/DCD            | IO DECODING           | 38                 | IO           | [Verilog created](circuit/IO_DCD_38.v)          | [Test](circuit/IO_DCD_38/readme.md) - Connected DGA. Need more test! 
| IO/DCD/DGA        | DECODE GATE ARRAY     | 39                 | IO           | Directly integrated in Sheet 38                 | Sheet 39 has no code.
| IO/PANCAL         | PANEL PROC & CALENDAR | 40                 | IO           | [Verilog created](circuit/IO_PANCAL_40.v)       | (test not create)
| IO/REG            | IOC, ALD & INR REGS   | 41                 | IO           | [Verilog created](circuit/IO_REG_41.v)          | (test not create)  Need to fix IDB so that IDB_15_0 and IDB_7_0_io is the same bus
| IO/UART           | UART AND IOR REG      | 42                 | IO           | [Verilog created](circuit/IOUART_42.v)          | (test not create)  Need to create the UART chip and test it. Also fix IDB IO bus
| **Memory**                                                                     
| MEM               | MEMORY TOP LEVEL      | 43                 | MEM          |
| MEM/ADDR          | MEM ADDR MUX          | 44                 | MEM          |
| MEM/ADEC          | ADDRESS DECODER       | 45                 | MEM          |
| MEM/DATA          | DATA & PARITY TCV     | 46                 | MEM          |
| MEM/ERROR         | LOCAL PES & PEA       | 47                 | MEM          |
| MEM/LBDIF         | LOCAL BD CONTROL      | 48                 | MEM          |
| MEM/RAM           | LOCAL RAM             | 49                 | MEM          |
| MEM/RAMC          | LOCAL RAM CONTROL     | 50                 | MEM          |

# Test program verification

![Screenshot from GTKWave](gtkwave.png)

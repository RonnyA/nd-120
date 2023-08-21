# 3202D CPU Board for ND-120 CPU #

The 3202D CPU Board is described in the design documents in a PDF spanning 50 pages.

![Photo of 3202D board](3202D-Photo.PNG)

# 3202D Circuits #

No Logisim file has been created.

* TODO: Make decision if HDL should be used direct instead of Logisim files.

## Status of Logisim drawings from 3202D Schematics PDF ##



| Page name         |                       | PDF page number(s) | LogiSim file | Status | Comment |
|-------------------|-----------------------|--------------------|--------------|--------|---------|
| **Main PCB**|                    |   -     |
| DELILAH TOP LEVEL | BLOCK DIAGRAM         | 1 | D3202| | Combines CYC + CPU + BIF + IO + MEM |
| DELILAH TOP LEVEL | A PLUG                | 2 | D3202|
| DELILAH TOP LEVEL | B PLUG                | 3 | D3202|
| DELILAH TOP LEVEL | C PLUG                | 4 | D3202|
| **Bus interface**|                    |   -     |
| BIF               | BUS IF                | 5   | BIF  |
| BIF/BCTL          | BIF CONTROL           | 6   | BIF  |
| BIF/BCTL/BDRV     | BUS DRIVERS           | 7   | BIF  |
| BIF/DPATH         | BIF SYNC              | 8   | BIF  |
| BIF DATA PATH     | BIF SYNC              | 9   | BIF  |
| BIF/DPATH/BDLBD   | BIF BD TO LBD         | 10  | BIF  |
| BIF/DPATH/CDLBD   | BIF CD TO LBD         | 11  | BIF  |
| BIF/DPATH/LBCTL   | LBD CONTROL           | 12  | BIF  |
| BIF/DPATH/PESPEA  | BIF PES & PEA         | 13  | BIF  |
| BIF/DPATH/PPNLBD  | BIF PPN to LBD        | 14  | BIF  |
| **CPU**|                    |   -     |
| CPU               | TOP LEVEL             | 15  | CPU |
| CPU/CS            | CONTROL STORE         | 16  | CPU |
| CPU/CS/ACAL       | MICRO ADDR CALC       | 17  | CPU |
| CPU/CS/CTL        | CS CONTROL            | 18  | CPU |
| CPU/CS/PROM       | CS PROMS              | 19  | CPU | | Microcode EPROMS |
| CPU/CS/TCV        | CS TRANSCIEVERS       | 20  | CPU |
| CPU/CS/WCS        | Register file         | 21-22 | CPU |
| CPU/LAPA          | LA TO PPN BUFF        | 23  | CPU |
| CPU/MMU           | MMU TOP LEVEL         | 24  | CPU |
| CPU/MMU/CACHE     | CACHE                 | 25  | CPU |
| CPU/MMU/CSR       | CACHE STATUS REG      | 26  | CPU |
| CPU/MMU/HIT       | HIT DETECTION         | 27  | CPU |
| CPU/MMU/PPNX      | PPN TO IDB            | 28  | CPU |
| CPU/MMU/PT        | PAGE TABLES           | 29  | CPU |
| CPU/MMU/PTIDB     | PT TO IDB             | 30  | CPU |
| CPU/MMU/WCA       | PPN TO CPN            | 31  | CPU |
| CPU/PROC          | PROCESSOR TOP LEVEL   | 32  | CPU |
| CPU/PROC/CGA      | CPU GATE ARRAY        | 33  | CPU | | DELILAH Circuits plugin |
| CPU/PROC/CMDDEC   | COMMANDS & IDB DECODE | 34  | CPU | | PAL 44407, 44608, 44511 |
| CPU/STOC          | IDB TO CD             | 35  | CPU |
| **Cycle control**|                    |   -     |
| CYC               | CYCLE CONTROL         | 36  | CYC |
| **IO**|                    |   -     |
| IO                | IO TOP LEVEL          | 37  | IO | 
| IO/DCD            | IO DECODING           | 38  | IO | 
| IO/DCD/DGA        | DECODE GATE ARRAY     | 39  | IO | | DECODE GATE ARRAY (DGA) Plugin |
| IO/PANCAL         | PANEL PROC & CALENDAR | 40  | IO | | PANEL CPU |
| IO/REG            | IOC, ALD & INR REGS   | 41  | IO | | ALD register has also STRAP 5-9 info in IDB11-IDB8 (For reading ECO level) IDB4-6 has "Print level", 0b100 for version D. IDB7 has info on CX, 0=Enabled|
| IO/UART           | UART AND IOR REG      | 42 | IO | 
| **Memory**|                    |   -     |
| MEM               | MEMORY TOP LEVEL      | 43 | MEM |
| MEM/ADDR          | MEM ADDR MUX          | 44 | MEM |
| MEM/ADEC          | ADDRESS DECODER       | 45 | MEM |
| MEM/DATA          | DATA & PARITY TCV     | 46 | MEM |
| MEM/ERROR         | LOCAL PES & PEA       | 47 | MEM |
| MEM/LBDIF         | LOCAL BD CONTROL      | 48 | MEM |
| MEM/RAM           | LOCAL RAM             | 49 | MEM | | 3 Banks with 1 MegaWord RAM = 6MB |
| MEM/RAMC          | LOCAL RAM CONTROL     | 49 | MEM | | PAL 44803,44902 |


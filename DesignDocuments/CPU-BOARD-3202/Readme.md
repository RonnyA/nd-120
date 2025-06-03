# ND-120 CPU Board 3202 Revision D #

[Board schematics](3202-REV-D-OCT-87-600DPI.pdf) - 50 pages

#### Chips for the CPU Board ####

This list of chips are used on the 3202 CPU Board and needs to be implemented in HDL or Logisim

Chips for the 3202D board:

| Chip        | Description                                              | Link                                                                          |  Status                   |
|-------------|----------------------------------------------------------|-------------------------------------------------------------------------------|---------------------------|
| 27256       | 32KB EPROM with ND-120 microcode (23B + 26B)             | https://www.futurlec.com/Memory/27256_Datasheet.shtml                         | EPROM content secured     |
| UART        | Microchip AY2661                                         | https://datasheetspdf.com/pdf-file/1412058/SMSC/COM2661-3/1 http://bitsavers.org/components/microchipTechnology/_dataBooks/1990_Microchip_Data_Book.pdf |Not started |
| SIP1M9      | Local RAM page 49                                        | | Implemented using BLOCK RAM |
| IDT6168A    | 16K (4Kx4) Static RAM                                    | https://www.alldatasheet.com/datasheet-pdf/view/65830/IDT/IDT6168.html | Implemented using BLOCK RAM |
| IMS1403_25  | 16K x 1 Static RAM                                       | https://datasheetspdf.com/pdf-file/537395/Inmos/IMS1403/1 |
| TMM2018D_25 | 2K x 8 Static RAM (Cache)                                | |
| AM9150_20   | 1024 x 4 High-Speed Static R/W RAM                       | http://www.sintran.com/library/libother/extern/AM9150.pdf |
| AM29C821    | Bus Driver 10 bits. Positive edge-triggered registeres with D-type flip-flops and 3-state| https://www.digikey.com/en/products/detail/rochester-electronics-llc/AM29C821-BLA/12095382 |
| AM29841     | Bus Driver 10 bit (D-Latch) with 3-state output          | https://www.alldatasheet.com/datasheet-pdf/pdf/107079/AMD/AM29841.html | 
| AM29833A    | PARITY BUS TRANSCEIVERS                                  | https://pdf1.alldatasheet.com/datasheet-pdf/view/165880/AMD/AM29833A.html | 
| AM29861A    | 10 Bit High Performance Bus Transceivers                 | https://datasheetspdf.com/datasheet/AM29861.html |
Data%20Sheets/Fairchild%20PDFs/DM74LS534.pdf) | 
| 74S132      | QUADRUPLE 2-INPUT POSITIVE-NAND SCHMITT TRIGGERS         | https://www.alldatasheet.com/datasheet-pdf/pdf/27365/TI/SN74S132.html | 
| 74F139      | DUAL 2-LINE TO 4-LINE DECODERS/DEMULTIPLEXERS            | https://www.alldatasheet.com/view.jsp?Searchword=SN74S139 |
| 74F241      | OCTAL BUFFERS AND LINE DRIVERS WITH 3-STATE OUTPUTS      | https://www.alldatasheet.com/view.jsp?Searchword=SN74S241 | 
| 74LS248     | BCD-TO-SEVEN-SEGMENT DECODERS/DRIVERS                    | https://www.alldatasheet.com/datasheet-pdf/pdf/5697/MOTOROLA/SN54/74LS248.html | 
| 74273       | 8-bit D-type register                                    |
| 74LS244     | Octal Buffers and Line Drivers With 3-State Outputs      | https://www.ti.com/lit/ds/symlink/sn74ls244.pdf |
| 74LS245     | Octal Bus Transceivers With 3-State Outputs              | https://www.ti.com/lit/ds/symlink/sn74ls245.pdf | Not started |
| 74PCT373    | Octal Transparent Latch with 3-state                     |
| 74ALS374    | Octal D flip-flop Register (3-State)                     | https://www.alldatasheet.com/datasheet-pdf/pdf/15260/PHILIPS/74ALS374.html  | |
| 74LS393     | Dual 4-bit binary counters with individual clocks        | https://www.ti.com/lit/ds/symlink/sn74ls390.pdf |
| 74FCT521A   | 8-BIT COMPARATOR                                         | https://datasheetspdf.com/pdf-file/1348201/IDT/IDT74FCT521AT/1 | Easy to recreate | 
| 74LS534     | Octal D-Type Flip-Flop with 3-STATE Output               | [https://media.digikey.com/pdf/Data%20Sheets/Fairchild%20PDFs/DM74LS534.pdf](https://media.digikey.com/pdf/
| 74AS646     | Octal Bus Transciever and registers with 3-State Outputs | https://www.ti.com/lit/ds/symlink/sn54as646.pdf| 
| 74AS648     | Octal Bus Transciever and registers with 3-State Outputs | https://www.ti.com/lit/ds/symlink/sn74als648a.pdf | 



Simple 74-series chips

| Chip name | Description                                      | Link                                                     |
|-----------|--------------------------------------------------|----------------------------------------------------------|
| 74LS112   | Dual Negative-Edge J-K flip-flop                 | https://www.futurlec.com/74LS/74LS112.shtml              |
| 74F74     | Dual D-type flip-flop                            | https://docs.rs-online.com/ae89/0900766b800255bb.pdf     |
| 7437      | Quadruple 2-Input Positive-NAND Buffers          |
| 74F32     | Quad 2-Input OR Gate                             |
| 74F14     | Hex Inverter Schmitt Trigger                     | https://www.mouser.com/datasheet/2/308/74F14-1190321.pdf |
| 7410      | Triple 3-input NAND Gate                         |
| 7406      | Hex inverting buffer with open collector outputs |
| 7404      | Hex inverter                                     |
| 7402      | Quad 2-input NOR gate                            |
| 7400      | Quad 2-input NAND gate                           |

#### Chips for the Panel Processor Board ####

Schematic page 40

| Chips                                                    | Link   |  Status |
|----------------------------------------------------------|--------|---------|
| MM58274 -  Microprocessor Compatible Real Time Clock     | http://www.applelogic.org/files/MM58274C.pdf | |
| MC68705U3 - M6805 8-bit CPU, on-chip RAM, I/O and Tiemer | https://www.alldatasheet.com/datasheet-pdf/pdf/1614569/NXP/MC68705U3.html | We dont have a ROM dump of the code in this CHIP. It should be 4K. Waiting for read by http://matthieu.benoit.free.fr/device_list.htm |

#### PAL Chips ####

Status for the PAL Chips (PAL code converted to HDL)

| PAL Chip                  | PAL Type       | Schematic page | Board Location | Status |
|---------------------------|----------------|----------------|----------------|--------|
| 44801 UBARB               | PAL16R8D       | 6              | 10D            |        |
| 44401 UBTIM               | PAL16R4D       | 6              | 5D             |        |
| 45001 UBAPAR              | PAL16L8B       | 6              | 8D             |        |
| 44302 ULBC1               | PAL16L8_12     | 12             | 11D            |        |
| 44303 ULBC2               | PAL16L8_12     | 12             | 2C             |        |
| 44304 ULBC3               | PAL16L8_12     | 12             | 1C             |        |
| 44305 UCSCTL              | PAL16L8_12     | 18             | 15F            |        |
| 44306 UMOCTL              | PAL16L8_12     | 24             | 21G            |        |
| 44402 UBITS               | PAL16R4D       | 25             | 18F            |        |
| 44407 UERFIX              | PAL16R4D       | 34             | 19F            |        |
| 44408 VEXFIX              | PAL16R6D       | 34             | 22F            |        |
| 44511 ULEV0               | PAL16R4D       | 34             | 26H            |        |
| 44404 UCYIN1              | PAL16R4D       | 36             | 15D            |        |
| 44403 UCYIN0              | PAL16R4D       | 36             | 14D            |        |
| 44601/44611 UYCFSM        | PAL16R6D       | 36             | 12D            |        |
| 44307 UCYCLK              | PAL16L8_12     | 36             | 13D            |        |
| 44904 UMSIZE              | PAL16R8B       | 45             | 7G             |        |
| 44425/44445/44465 UCADEC  | PAL16R4D       | 45             | 9G             |        |
| 44426/44446/44466 UBADEC  | PAL16R4D       | 45             | 6G             |        |
| 45008 UDATA               | PAL16L8B       | 46             | 2F             |        |
| 45009 UERROR              | PAL16L8B       | 47             | 4F             |        |
| 44310 ULBDIF              | PAL16L8_12     | 48             | 3F             |        |
| 44803 URAMA - RAM Arbiter | PAL16R8D       | 50             | 5F             |        |
| 44902 URAMC - RAM Control | PAL16R8D       | 50             | 6F             |        |

Note: PAL in location 22F was UVXFIX, but has been replaced by 44408B/VEXFIX

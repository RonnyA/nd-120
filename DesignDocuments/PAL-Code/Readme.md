# PAL Code 

The PAL chips on the 3202 CPU Board was programmedin in a language called [PALASM](https://en.wikipedia.org/wiki/Programmable_Array_Logic)


```wikipedia
The PALASM (from "PAL assembler") language was developed by John Birkner in the early 1980s and 
the PALASM compiler was written by MMI in FORTRAN IV on an IBM 370/168. 

MMI made the source code available to users at no cost. By 1983, MMI customers ran versions on the DEC PDP-11, 
Data General NOVA, Hewlett-Packard HP 2100, MDS800 and others.

It was used to express boolean equations for the output pins in a text file which was then converted to the 'fuse map' 
file for the programming system using a vendor-supplied program; 

later the option of translation from schematics became common, and later still, 'fuse maps' could be 'synthesized' from an HDL (hardware description language) such as Verilog.

```


PALASM Language guide
* http://orion.ipt.pt/~fmbarros/ed/PALASM%20Language%20Guide.htm

PALASM Software
* http://www.pldworld.com/_otherplds/palasm/-engr.uky.edu/_melham01/ee481/software.htm
* http://www.brouhaha.com/~eric/retrocomputing/mmi/palasm/

PALASM Under Linux
* https://systemembedded.eu/viewtopic.php?t=43

References:
* https://en.wikipedia.org/wiki/PALASM
* https://en.wikipedia.org/wiki/Programmable_Array_Logic

* [HDL Windows Designer Compatible with the PALASM Platform](http://www.wseas.us/e-library/conferences/2013/Malaysia/ACACOS/ACACOS-12.pdf)
* [MMI Datebook" with PALASM examples and users guide](http://bitsavers.trailing-edge.com/components/mmi/palasm_pleasm/PALASM_2_Software_Jul87.pdf)

# From 3202D Design documentaion 

PAL's for board no. 3202. ND120/CX. Last update 27. January 1988.
Standard is 4Mb memory configured contiguosly from address 0.

|Pos. no.| 3202D Sheet |Checksum| Device | Max. delay| Stock no.| Reg. no. | Mnemonic  | PALASM Image                | PALASM SRC (PDS format)      | Converted to Verilog |
|--------|-------------|--------|--------|-----------|----------|----------|-----------|-----------------------------|------------------------------|----------------------|
|11D     | 12          |3B8B    | 16L8-12| 12ns      | 513035   | 44302B   | LBC1      | [B IMG](IMG/44302B.png)     | [B PDS](SRC/44302B.txt)      | [Converted.](../../Verilog/PAL/44302B/PAL_44302B.v) Needs more test |
|2C      | 12          |3932    | 16L8-12| 12ns      | 513085   | 44303B   | LBC2      | [B IMG](IMG/44303B.png)     | [B PDS](SRC/44303B.txt)      | [Converted.](../../Verilog/PAL/44303B/PAL_44303B.v) Needs more test |
|1C      | 12          |508A    | 16L8-12| 12ns      | 5130385  | 44304E   | LBC3      | [E IMG](IMG/44304E.png)     | [E PDS](SRC/44304E.txt)      | [Converted.](../../Verilog/PAL/44304E/PAL_44304E.v) Needs more test. Especially on signal EBADR_n |
|15F     | 18          |        | 16L8-12| 12ns      | 513085   | 44305D   | CSCTL     | [D IMG](IMG/44305D.png)     | [D PDS](SRC/44305D.txt)      | [Converted.](../../Verilog/PAL/44305D/PAL_44305D.v) Needs more test |
|21G     | 24          |7856    | 16L8-12| 12ns      | 513035   | 44306A   | MMUCTL    | [A IMG](IMG/44306A.png)     | [A PDS](SRC/44306A.txt)      | [Converted.](../../Verilog/PAL/44306A/PAL_44306A.v) Needs more test |
|13D     | 36          |8345    | 16L8-12| 12ns      | 513085   | 44307C   | CYCLK     | [C IMG](IMG/44307C.png)     | [C PDS](SRC/44307C.txt)      | [Converted.](../../Verilog/PAL/44307C/PAL_44307C.v) Needs more test |
|3F      | 48          |46FA    | 16L8-12| 12ns      | 513085   | 44310D   | LBDIF     | [D IMG](IMG/44310D.png)     | [D PDS](SRC/44310D.txt)      | [Converted.](../../Verilog/PAL/44310D/PAL_44310D.v) Tested! |
|5D      | 6           |59AF    | 16R4D  | 10ns      | 513060   | 44401B   | BTIM      | [B IMG](IMG/44401B.png)     | [B PDS](SRC/44401B.txt)      | [Converted.](../../Verilog/PAL/44401B/PAL_44401B.v). Needs more test |
|18F     | 25          |        | 16R4D  | 10ns      | 513060   | 44402D   | UBITS     | [D IMG](IMG/44402D.png)     | [D PDS](SRC/44402D.txt)  
|14D     | 36          |        | 16R4D  | 10ns      | 513060   | 44403D   | CYIN0     | [C IMG](IMG/44403C.png) / [D IMG](IMG/44403D.png)    | [C PDS](SRC/44403C.txt) / Missing D | [Converted C](../../Verilog/PAL/44403C/PAL_44403C.v) Needs more test |
|15D     | 36          |        | 16R4D  | 10ns      | 513060   | 44404D   | CYIN1 NEW | [C IMG](IMG/44404C.png) / Missing D                  | [C PDS](SRC/44404C.txt) / Missing D | [Converted C](../../Verilog/PAL/44404C/PAL_44404C.v) Needs more test. Guessed at logics for D.. |
|19F     | 34          |OF93    | 16R4D  | 10ns      | 513060   | 44407A   | ERFIX     | [A IMG](IMG/44407A.png)     | [A PDS](SRC/44407A.txt)  
|9G      | 45          |44C7    | 16R4D  | 10ns      | 513060   | 44445B   | CADEC     | [B IMG](IMG/44445B.png)     | [B PDS](SRC/44445B.txt)  
|6G      | 45          |3EF5    | 16R4D  | 10ns      | 513060   | 44446B   | BADEC     | [B IMG](IMG/44446B.png)     | [B PDS](SRC/44446B.txt)  
|22F     | 34          |        | 16R6D  | 10ns      | 513061   | 44408B   | VEXFIX    | [B IMG](IMG/44408B.png)     | [B PDS](SRC/44408B.txt)     | [Converted.](../../Verilog/PAL/44408B/PAL_44408B.v).  Tested! |
|12D     | 36          |7F40    | 16R6D  | 10ns      | 513061   | 44601B   | CYCFSM    | [B IMG](IMG/44601B.png)     | [B PDS](SRC/44601B.txt)  
|10D     | 6           |6B08    | 16R8D  | 10ns      | 513062   | 44801A   | BARBA <-  | [A IMG](IMG/44801A.png)     | [A PDS](SRC/44801A.txt)  
|5F      | 50          |605E    | 16R8D  | 10ns      | 513062   | 44803A   | RAMA      | [A IMG](IMG/44803A.png)     | [A PDS](SRC/44803A.txt)  
|6F      | 50          |        | 16R8B  | 15ns      | 500829   | 44902A   | RAMC      | [A IMG](IMG/44902A.png)     | [A PDS](SRC/44902A.txt)  
|7G      | 45          |48B4    | 16R8B  | 15ns      | 500829   | 44904B   | MSIZE     | [B IMG](IMG/44904B.png)     | [B PDS](SRC/44904B.txt)  
|8D      | 6           |5963    | 16L8B  | 15ns      | 500827   | 45001B   | BPAR      | [B IMG](IMG/45001B.png)     | [B PDS](SRC/45001B.txt)  
|2F      | 46          |        | 16L8B  | 15ns      | 500827   | 45008B   | DATA      | [B IMG](IMG/45008B.png)     | [B PDS](SRC/45008B.txt)  
|4F      | 47          |43ED    | 16L8B  | 15ns      | 500827   | 45009B   | ERROR     | [B IMG](IMG/45009B.png)     | [B PDS](SRC/45009B.txt)  
|26H     | 34          |        | 16R4B  | 15ns      |          | 44511A   | LEVO      | [A IMG](IMG/44511A.png)     | [A PDS](SRC/44511A.txt)  
          
Note: 22F was  44608A/VXFIX, but has been replaced with 44408B/VEXFIX

## 2MB

PAL's for board no. 3202. ND120/CX 2Mb version.

Replace 44445xX with 44425x, and 44446X with 44426x.
9G 411E 16R4D 10ns 513060 444258 CADEC
6G 42EF 16R4D 10ns 513060 44426B BADEC

## 6MB

PAL's for board no. 3202. ND120/CX 6Mb version.

Replace 44445X with 44465xX, and 44446X with 44466x.

|Pos. no.|Checksum| Device | Max. delay| Stock no.| Reg. no. | Mnemonic  |  PALASM Image               | PALASM SRC (PDS format)      |
|--------|--------|--------|-----------|----------|----------|-----------|-----------------------------|------------------------------|
|9G      | 4441   | 16R4D  | 10ns      | 513060   | 44465B   | CADEC     | [B IMG](IMG/44465B.png)       | [B PDS](SRC/44465B.txt)  
|6G      | 42EF   | 16R4D  | 10ns      | 513060   | 44466B   | BADEC     | [B IMG](IMG/44466B.png)       | [B PDS](SRC/44466B.txt)  

## STD

PAL's for board no. 3202. ND120 STD.
Replace 44402X with 44412X, and 44601X with 44611x.

|Pos. no.|Checksum| Device | Max. delay| Stock no.| Reg. no. | Mnemonic   | PALASM IMG | 
|--------|--------|--------|-----------|----------|----------|------------|------------|
| 18F    |        | 16R4D  | 10ns      | 513060   | 44412A   | UBITS NEW  |
| 12D    |        | 16R6D  | 10ns      | 513061   | 44611A   | CYCFSM NEW |

## PROM's

Microcode PROM's. One set for 32 bit FPU and one set for 48 Bit FPU opcodes.

|Pos. no.|Checksum| Device | Max. delay| Stock no.| Reg. no. | Floating format | Bit no.|
|--------|--------|--------|-----------|----------|----------|-----------------|--------|
| 23B    |        | 27256  | 250ns     | 500854   | [45132L](/Microcode/AM27256_45132L.bin)   | 32 bit          | 0-7    |
| 26B    |        | 27256  | 250ns     | 500854   | [45133L](/Microcode/AM27256_45133L.bin)   | 32 bit          | 8-15   |
| 23B    |        | 27256  | 250ns     | 500854   | 45148L   | 48 bi           | 0-7    |
| 26B    |        | 27256  | 250ns     | 500854   | 45149L   | 48 bi           | 8-15   |

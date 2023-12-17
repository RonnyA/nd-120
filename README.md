
# ND-120 CPU #

## Content ##

This repo contains:

* Original **Norsk Data** ND-120 CPU Design Documents from 1988. Scanned in 2023
* Modern Logisim and HDL implementation from 2023.

You can read more about this [CPU](https://www.ndwiki.org/wiki/3202) and much more in [NDWiki](https://www.ndwiki.org/) and the official website for [Norsk Data](http://sintran.com/)

The goal of this repo is to re-create the scheamtics and create the HDL files so we can program an FPGA to run as the original ND-120 CPU Card.

On the way to the FPGA code, there will be testable Logisim Circuits and Logisim code that can be converted and tested in C++ using Verilator.


#### Requirements ####

For that the minimum requirements are:

| Component                      | Schematic    |  HDL   | Status | 
|--------------------------------|--------------|--------|--------|
| [DELILAH CPU Gate Array (CGA)](DesignDocuments\DELILAH-CPU\readme.md) | Completed | Logisim generated Verilog | QA on schematic/Verilog ongoing |
| [NEC Decoder Gate Array (DGA)](DesignDocuments\DECODE-GateArray\readme.md) | Completed | Logisim generated Verilog | QA on schematic/Verilog ongoing |
| [ND 3202 CPU Board revision D](DesignDocuments/CPU-BOARD-3202/Readme.md) | Drawing not started | 

In the CPU Board we will plug in the DELILAH CPU and the Decoder, and several other chips. 


### Stretch goals ###

Design and implement I/O devices for reading and writing files from FLASH memory simulating the device.

* Floppy 
* Hard Drive



# Design documents

All the design documents are in the [Design Documents](DesignDocuments/Readme.md) folder.

# Norsk Data documents

Functional Description, Instruction set, Microprogramming guide and more are in the [NorskData-Doc](NorskData-Doc/Readme.md) folder.



# Microcode #

The [Microcode](Code/Microcode/readme.md) dump is from a ND-120 3202 CPU Board is Version 14/L
The source code is also for the L version.

# 68705 #

[ROM dump](Code/68705/readme.md) of the MC68705U3 (M6805 8-bit CPU, on-chip RAM, I/O and Timer)

Big thanks to Matthieu Benoit for reading the data out of the chip.

# Schematic drawings #

## Logisim ##

All the Logisim files are stored in the [Logisim folder](Logisim/readme.md)

### Logisim Requirements ###
You need to install the Logisim-Evolution design tool from [Logisim Evolution Repository](https://github.com/logisim-evolution/logisim-evolution)

The Logisim diagrams has been drawn with [Version 3.8.0](https://github.com/logisim-evolution/logisim-evolution/releases/tag/v3.8.0)

# FPGA #

## Verilog ##

Most Verilog files are generated from the Logisim drawings, using Logisim-Evolution FPGA tools.

All the Verilog files are stored in the [Verilog folder](Verilog/)


## Verilator ##

To test the Verilog code using Verilator you need to install the [Verilator](https://www.veripool.org/verilator/) tool




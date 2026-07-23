# ND-BUS seam gate (RTL ⟷ portable C core, in Verilator)

**Status: WORKING, validated 2026-07-19.** `make` prints `TB_RESULT: PASS` (6/6).

This is the first gate that proves the **portable C device cores** behave
correctly when driven through the **authoritative Verilog bus seam**
(`../circuit/ND_BUS_SLAVE.v`) — with **no ND-100 CPU and no hardware**, so it
runs in CI. It is the Verilator twin of the Tang-20K `nd-bus-test` exerciser:
the exerciser generates the same IOX cycles from a UART menu on silicon; here a
scripted C++ harness generates them in simulation.

## What it does

`nd_bus_gate.cpp`:
1. Instantiates the Verilated `ND_BUS_SLAVE`.
2. Drives the **CPU side** (BAPR/BIOXE/BINACK/BD…) to issue real IOX read/write
   cycles.
3. Bridges the **device side** (`iox_addr/wr/wdata/rd/rdata`, `int_pending`,
   `ident_*`) to a real `nd_lineprinter` core — **the "one C++ adapter"** from
   `NDModulE/docs/rtl-gate-plan.md`. `iox_wr`→`write()`, `iox_rd`→`iox_rdata`
   from `read()`, `interrupt_bits`→`int_pending`, `ident_strobe`→`ident()`.
4. Asserts the core's behaviour end-to-end through the RTL: a printed byte
   reaches the paper, status reads back, and enabling the interrupt makes the
   RTL assert BINT10.

Char devices gate first (no DMA infra), per the gate plan. Next: terminal
(rx/tx), then a full IDENT cycle, then wire `ND_DMA_MASTER` for the DMA devices
(floppy/SMD), then turn the scripted driver into the UART-menu exerciser for the
Tang rig.

## Build / run

```sh
make                 # normal `verilator` on PATH (WSL/Linux)
```

The C cores come from `$(NDDEVICECORE)`, intended to be the nd-120 submodule
`Verilog/ND-BUS-DEVICES/portable` **once it is wired** (it is not yet). Until
then, point it at the populated NDModulE copy:

```sh
# Windows / oss-cad-suite (the perl `verilator` wrapper is broken here):
export VERILATOR_ROOT=/c/Utils/oss-cad-suite/share/verilator
export PATH="/c/Utils/oss-cad-suite/lib:/c/Utils/w64devkit/bin:/c/Utils/oss-cad-suite/bin:$PATH"
make VERILATOR=verilator_bin.exe NDDEVICECORE=/e/Dev/Ronny/NDModulE/lib/NDDeviceCore
```

## TODO to make this the real gate

- Wire the `Verilog/ND-BUS-DEVICES/portable` submodule so `$(NDDEVICECORE)`
  defaults resolve without an override.
- Register in the machine-checkable test harness (it already emits
  `TB_RESULT: PASS`).
- Add terminal + IDENT + DMA (ND_DMA_MASTER) coverage.

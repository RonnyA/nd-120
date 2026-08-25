# MILESTONE — CONFIGURATION diagnostic passes 100% in VERILATOR (trap-vector fix)

Date: 2026-07-27. **Platform: VERILATOR (FF-mode), the fixed hand-maintained RTL.**

> UPDATE 25-AUG-2026: the Tang boot divergence described in the correction below
> is RESOLVED. The Tang Nano 20K boots SINTRAN III (24-AUG-2026, bus bank-decode
> fix in `ND3202D.v:533`), and CONFIGURE, INSTRUCTION, PAGING and MEMORY all run
> on the board. The correction below is kept as the record of where things stood
> on 27-JUL-2026.
>
> CORRECTION: this diagnostic pass is in the **Verilator simulation**, NOT on the Tang
> silicon. The Tang was flashed with this same RTL (`make flash-gowin`, config flash,
> persistent) but **still hard-hangs on boot** — BOTH `400$` (tape) and `1560&` (floppy)
> hang on the board. So the fixes are validated in sim; the Tang boot divergence is a
> separate open problem (see `DEBUG-PLAN-floppy-tape-boot.md`). In particular `400$` on the
> flashed build now updates NO memory at all (before the fixes it loaded ~23244 words then
> hung on an instruction) — a possible FPGA-side regression from one of the fixes (prime
> suspect: the MMU cache HIT-gate in `CPU_MMU_CACHE_25.v`, whose `s_hit` may behave
> differently on silicon).

## The win

The TPE (Test Program Executive) **CONFIGURATION** diagnostic (`CONFIGURATION - Version:
D05 - 1988-11-08`) runs to completion **in Verilator** with **`NO ERRORS DETECTED`** and
correctly enumerates the whole machine. It is loaded from the boot floppy with the TPE
monitor commands `load conf` then `run`.

This is on the build that carries three CPU-core RTL fixes made this session (all in the
hand-maintained Verilog under `Verilog/`):

1. **Trap-vector generator** — `DELILAH-CPU/CGA_TRAP/circuit/CGA_TRAP_TVGEN_P2.v`: the three
   `TVEC0/1/2` muxes had `muxIn_3` tied to `1'b0` (a 3-input `MUX31LP` mis-modeled as a
   4-input `Multiplexer_4` with a grounded phantom D3). Fixed to `muxIn_3 = muxIn_2` so a
   simultaneous page-fault (level-1) + PGU (level-2) resolves to the page-fault vector (1)
   instead of the unimplemented "SINTRAN-4" vector 7, which self-jumps forever (hard hang).
2. **MMU cache CD output** — `CPU-BOARD-3202/circuit/CPU_MMU_CACHE_25.v`: gate the cache data
   output by `HIT` so a stale line can't jam the wired-OR CD bus (the INSTRUCTION-banner
   `INST␡␡CTION` corruption).
3. **Cache-updated bit (CUP)** — `PAL/PAL_44511A.v` + `PAL/PAL_44511A_EN.v`: corrected the
   registered CUP equation (`/CUP := /CWR*MREQ + /CUP*/MREQ`).

## Measured output (CONFIGURATION D05, `NO ERRORS DETECTED`)

```
                  H A R D W A R E   C O N F I G U R A T I O N
CPU type.............: ND-120/CX
Floating format......: 32 bits
Memory management....: MMS-2 included on CPU board
Cache................: Yes
ALD register content.: 400B
Print number.........: 3202
Print release version: D
Microprogram version.: 100014B
ECO level............: P
Total memory size....: 4.000 Mbytes

HARDWARE DEVICE NAME     FIRST  LAST   IDENT(LEV10/11/12/13)   LOG.DEVNO
  REAL TIME CLOCK   1     10     13                        13:1        1
  TERMINAL INTERFACE 1   300    307    (ident not checked)             1
  PAPER TAPE READER 1    400    403    12:2                            2
  LINE PRINTER      1    430    433    10:3                            5
  FLOPPY DISC DMA   1   1560   1567    11:21                        1145
  ECCR                 100115 100115

  INTERRUPT PRIORITY:  L13 id1 RTC | L12 id2 PaperTape | L11 id21 FloppyDMA | L10 id3 LinePrinter

  MEMORY MAP: banks 0-7, rows 000B..030B all "Mpm 5"  =>  4.000 Mbytes
=== END OF INVESTIGATION ===   ===  NO ERRORS DETECTED  ===
```

## Tang build + flash (persistent)

- Build (Windows Gowin EDA flow, from `Verilog/fpga/tang-nano-20k/`):
  `make gowin VARIANT=slow` → synth + place + route + bitstream all completed; **design fits**.
  Bitstream:
  `Verilog/fpga/tang-nano-20k/build/nd120_tang20k_build/impl/pnr/nd120_tang20k_build.fs`
- Attach board to WSL: `./usb-attach.sh` (usbipd, FTDI `0403:6010` busid 3-2 →
  `/dev/ttyUSB0`=JTAG, `/dev/ttyUSB1`=console 9600 8N1).
- **Persistent flash to config SPI flash:** `make flash-gowin`
  (`openFPGALoader -b tangnano20k -f <fs>`) — completed 100%, survives power-cycle.
  Volatile (SRAM, non-persistent) alternative: `make load-gowin`.

## Status / still open

- The INSTRUCTION verifier's **Cx-instructions** group now runs end-to-end (was a hard hang
  before the trap-vector fix): TSET, RDUS pass; MOVEW runs.
- **One residual bug** (separate, under analysis): `MOVEW APT ==> APT` drops exactly the
  destination page-boundary word at `176000` octal (reads 0, expected `24`). Root-cause
  analysis + the decisive backdoor-vs-cache experiment are recorded in the auto-memory
  `cx-tset-wip-trap-vector7-hang` (leading hypotheses: MMU PT-write-back displacing the data
  write at the crossing, vs a cache read-back slip).
- Note the microcode reports `Microprogram version: 100014B` and `Cache: Yes` on this build.

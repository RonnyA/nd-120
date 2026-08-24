# ND-120 machine facts - the invariants that keep getting re-derived

Last verified: 24-AUG-2026. Every entry is measured or drawing-verified in
this repo's campaigns; each names its source. Add new facts WITH their
evidence; correct wrong ones rather than appending contradictions.

## Address spaces

- **Logical space: 64K words (16-bit word address) - per bank.** Any main-
  memory backend smaller than this WRAPS silently and corrupts software
  state (the 24-AUG LIST-FILE-NAMES runaway: `ND120_BLOCKRAM_ADDR_BITS=15`).
  Enforced by `test-blockram-space`.
- Physical: 24-bit; the 3202D board decodes banks BANK0/1/2. The Nexys
  BLOCKRAM carries 3 x 64K words (384 KB); the Tang SDRAM carries 4 MB =
  2M words in banks BANK0 (phys 0-1M) + BANK2 (phys 1M-2M) - address
  order BANK0, BANK2, BANK1, silicon-validated (MEM_RAM_49_SDRAM.v).
- DRAM protocol (sheet 49): AA carries the ROW at the RAS rising edge,
  the COLUMN one clock later; write data valid BEFORE CAS rises;
  window = RAS & CAS & bank. `lin = {row, col}` - the 2024 `{col,row}`
  reversal aliased everything (the 400& junk bug).

## Console terminal (internal device, IOX 0o300-0o307)

- Register map: 300 read data, 302 read input status, 303 write input
  control, 305 write data, 306 read output status, 307 write output
  control (nd100x `deviceTerminal.h`, verified against behavior).
- Input status bits: 0 = interrupt enabled, 2 = device activated (a soft
  latch from control-word bit 2), 3 = data available, 4-7 error bits,
  11 carrier missing.
- FILSYS's control word is 0o044004 (activate, 7-bit, parity).
- The IOX 30x service is MICROCODE (TRM2x at CSA 0o0520-0o0545): result =
  hardware IOR word OR scratch register R6 (the soft activated/interrupt
  state). The IOR word (CHIP_33G capture in `IO_UART_42.v`) is
  `{TBMT_n, DA_n, EAUTO_n, LOCK_n, CONSOLE_n, 1, BAUD[3:0]}`.
- Console interrupts (IO_REG_41.v): BINT10 = IOC bit2 & TBMT (output),
  BINT12 = IOC bit1 & DA (input), BINT13 = IOC bit3 & bit0 (RTC).
  Measured 24-AUG: TPE never sets IOC bit 1 - TPE input is POLLED (RTC
  tick), not interrupt-driven.
- The SC2661: TxEN=0 must NOT abort a character in flight (real chip
  finishes it) - fixed 24-AUG, guarded by `test-uart-txabort`.

## CPU registers

- WRF register file (`CGA_WRF_RBLOCK.v`): regs 0-7 = Z, D, P, B, L, A,
  T, X; reg 8 = STS; regs 9-15 = microcode scratch R1-R7 (so microcode
  field "A,R6" = physical reg 14).
- BSKP 0o1752xx: op field (bits 10:7), bit number (bits 6:3), register
  (bits 2:0, 5=A). `BSKP ONE 30 DA` (0o175235) = skip if A bit 3 set.
- ND-100 P-relative addressing: 8-bit SIGNED displacement, EA = own
  address + disp (0o203 = -125, not +131).

## Microcode

- WCS: 8192 x 64-bit microwords; the loaded listing ends at LUA 0o012513.
  CSA values above that are bus transients, never real states.
- The word layout: bits [15:0] = PROM RF=0 group ... [63:48] = RF=3;
  PROM byte index = LUA*4 + RF (see `Code/Microcode/gen_wcs_image.py`).
- TWO variants of word 0o2002 (MACL+1) exist historically: raw PROM
  (0x...60e0) and the 07-DEC-2024 run-simulator patch (0x...00e0,
  commit 895f360, clears the COND/F,JMP bits). BOTH pass everything
  (measured 24-AUG: rig raw PASS, rig patched PASS, Tang raw PASS).
  Canonicalization pending (Ronny); `test-microcode-sync` guards
  against any NEW split.
- A second single-bit variant exists in
  `CPU-BOARD-3202/circuit/BIF_BCTL_SYNC_8/sim/AM27256_45132L.hex`
  (byte 4109, LUA 0o2003 MACL3) - UNINVESTIGATED, listed in the gate.

## Boards - intended configuration differences (Tang vs Nexys)

| item | Tang Nano 20K | Nexys 4 DDR |
|---|---|---|
| main memory | SDRAM 4 MB, PACK16 | BLOCKRAM 3 x 64K words |
| CPU cache | `ND120_NO_CACHE` | enabled by default (never validated; `-tclargs nocache` for parity) |
| CPU clock | ~6.75 MHz | 16.67 MHz (`clk=8..100` selectable) |
| WCS | preload (SKIP_WCS_LOAD) | preload (SKIP_WCS_LOAD; `-promload` for runtime) |
| storage | SD via nd_storage, discs uncached | SD + DDR2 region, Winchester cached |
| console | 9600 8N1 | 9600 8N1 (COM11) |

Shadow RAM (TMM2018D page tables): IDENTICAL on both boards - sync-read
model, `TMM_ASYNC_READ` defined by no build (verified 24-AUG).

Board-parity sim builds: `make rig-nexys` / `make rig-tang` in
`Verilog/dmaSim/`.

## Panel processor

- Accessed via TRA PANS / TRR PANC (message protocol with a calendar
  clock, see nd100x `src/devices/panel/`). Our RTL has the DGA register
  plumbing but NO panel processor - TPE prints `==TPE42=> The clock is
  not updated (display panel wrong or unexisting)`, which a real
  panel-less machine also prints.

## Known software behaviors (for expect scripts)

- FILSYS: bare CR to "User no." = list user 0; letters at numeric
  prompts are silently swallowed; unknown device name prints the legal-
  answers list; prompts sit silent indefinitely (no timeout reprint).
- TPE: `HELP` is interactive (prompts `Command:`); an unknown command
  returns straight to `TPE>`. Golden dialogs: `Verilog/tests/golden-console/`.

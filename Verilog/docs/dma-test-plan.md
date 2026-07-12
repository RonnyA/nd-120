# DMA controller test - plan and status (12-JUL-2026)

Request: "after ~100000 ticks after system boot, trigger a transfer that
writes known data into ND-120 CPU memory over the bus, then reads it back
after a delay and validates it. Also use OPCOM memory/nnn to write
something to another address and read it back with DMA to validate."

## What already exists (and PASSES)

The full-system DMA bus-master test the request describes is already
built and green - it was implemented by the device workstream and
verified again on 12-JUL-2026.

- **RTL under test**: `ND-BUS-DEVICES/DMA/circuit/ND_DMA_MASTER.v` - the
  ND-100 request/grant + memory-reference engine every DMA controller
  (floppy DMA, SMD) sits on. It is instantiated *inside* `ND120_TOP` and
  exposed on the top ports `DMA_REQ / DMA_WR / DMA_ADDR / DMA_WDATA /
  DMA_RDATA / DMA_ACK / DMA_ERR / DMA_BUSY`. It masters the REAL bus
  arbiter while the CPU is live - a true cycle steal, not a stub.

- **Unit gate** (already registered in `tests/run_all_tests.sh`):
  `ND-BUS-DEVICES/DMA/sim :: test-dma-master :: TB_RESULT: PASS` - the
  standalone testbench with a fake memory model.

- **Full-RTL system gate** (`Verilog/Makefile` target `test-dma-rtl`,
  lines 149-159): builds the FF-mode Verilog-device sim, boots the real
  microcode, then via the `dma_test_tick()` harness in
  `runSim/Run120.cpp` (armed by `ND120_DMA_TEST=<octal addr>:<count>`):
  1. waits until the boot `#` prompt has appeared, then + a settle margin
     (`g_boot_done_cnt + 3_000_000` cnt) - the "after boot" trigger;
  2. DMA-**writes** a known pattern (`052525 ^ a ^ (a<<7)`) word by word
     into ND-120 RAM through the arbiter;
  3. **verifies the RAM arrays directly** (`ram_hi/ram_lo`, the CPU's own
     memory) - proves the words actually landed;
  4. DMA-**reads** every word back and compares;
  5. prints `[dmatest] RESULT: PASS/FAIL`.

  Verified 12-JUL-2026 with `ND120_DMA_TEST=200000:16`:
  ```
  [dmatest] armed: 16 words at 200000
  [dmatest] starting: 16 words at 200000
  [dmatest] write pass done, RAM verified, reading back
  [dmatest] RESULT: PASS
  ```

  Addressing note: `DMA_ADDR` is a **word** address and indexes the same
  RAM array element the write verified, so DMA word address == CPU word
  address - the read-back and the direct RAM check agree.

## What was missing - the OPCOM cross-check (now added)

The second half of the request - an *independent* writer proving DMA and
the CPU see the same memory - was not implemented. Added 12-JUL-2026 as a
purely additive, env-gated path (off by default; zero effect on the
golden-console gate or the device flows):

- `runSim/Run120.cpp`: `dma_xcheck_tick()`, armed by `ND120_DMA_XCHECK=1`.
  The independent writer is the CPU itself - the `-DSCRIPT_CMD_DMAXCHECK`
  script types OPCOM deposits (`A/V<CR>`) that store known octal words to
  low memory (word addresses 1000-1002) through the normal MOPC store
  path. After the deposits settle, `ND_DMA_MASTER` DMA-reads those same
  word addresses and asserts:
  * the value is present in the RAM array (OPCOM/CPU really wrote it), and
  * the DMA read returns exactly that value (DMA read the same word).
  Verdict line: `[dmaxcheck] RESULT: PASS/FAIL`.
- The deposit table (`g_dmax_addr/g_dmax_val`) and the
  `SCRIPT_CMD_DMAXCHECK` string are kept in lockstep in one file, with a
  comment tying them together.

  Verified 12-JUL-2026 with `ND120_DMA_XCHECK=1` (console shows OPCOM
  depositing at cells 1000-1002, then the DMA master reading them back):
  ```
  [dmaxcheck] @001000 OPCOM=054321 DMA=054321 OK
  [dmaxcheck] @001001 OPCOM=012345 DMA=012345 OK
  [dmaxcheck] @001002 OPCOM=077777 DMA=077777 OK
  [dmaxcheck] RESULT: PASS
  ```

Safety of the addition: `dma_xcheck_tick` and `SCRIPT_CMD_DMAXCHECK` are
compiled only under `ND120_VERILOG_DEVICES && SCRIPT_INPUT`, and the tick
early-returns unless `ND120_DMA_XCHECK` is set. The default and golden
console builds (no `VERILOG_TAPE=1`) never compile it, so the
`make test-full` golden gate is unaffected.

## Test matrix

| Gate | Where | Proves | Registered |
|---|---|---|---|
| `test-dma-master` | `ND-BUS-DEVICES/DMA/sim` | arbiter FSM vs fake memory | yes (unit) |
| `test-dma-rtl` | `Verilog/Makefile` | DMA write+read vs REAL RAM after boot | standalone heavy gate |
| `test-dma-xcheck` | `Verilog/Makefile` (new) | OPCOM-deposited word read back over DMA | standalone heavy gate |

`test-dma-rtl` and `test-dma-xcheck` are heavy (~12 min: one runSim
compile + boot). They match the convention of the other heavy boot gates
(`test-floppy-boot`, `test-smd-boot`): standalone `make` targets, run on
demand, not folded into the quick `make test` unit sweep.

## Remaining decision for Ronny

Whether to fold `test-dma-rtl` + `test-dma-xcheck` into `make test-full`
(adds ~24 min to the full suite) or keep them as on-demand standalone
gates. Current default: keep standalone, matching the floppy/SMD boot
gates.

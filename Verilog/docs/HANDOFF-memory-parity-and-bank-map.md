# HANDOFF: main-memory parity policy, backend selection, SDRAM bank map

Written 4-AUG-2026. Commit `451b05b` on branch `nd-bus-seam-gate`.
All paths in this document are relative to the repository root.

---

## 1. What this work was

Three connected pieces of main memory (schematic sheet 49), all finished and
gated:

1. **Parity is computed on read and never stored** - on every FPGA target and
   in simulation.
2. **The Basys3 build now selects its memory backend explicitly**, and a build
   that selects none fails instead of picking one silently.
3. **The SDRAM testbench was using a stale bank map** and had been failing for
   two weeks behind a fail-fast abort. Testbench fault, not an RTL fault.

Full unit suite after all of it: `ALL 175 TESTS PASSED` (514 s), from
`Verilog/` with `make test`.

---

## 2. Parity: the policy and the facts behind it

Ronny, 3-AUG-2026: *"we will not waste memory in fpga's on storing parity.
never."*

Facts, each read from the RTL, not assumed:

- An 18-bit ND memory word is **data in `DD[7:0]` and `DD[16:9]`**, and
  **parity in `DD[8]` and `DD[17]`**. Proof:
  `CPU-BOARD-3202/circuit/MEM_DATA_46.v` lines 239-242 (AM29833A chip 1H,
  `PAR` / `PAR_OUT`) and lines 266-269 (chip 2H).
- The AM29833A uses **odd** parity: `PAR_OUT = ~(^data)`. It reports an error
  when the 9-bit group `{data, PAR}` comes out even.
  (`Shared/support/AM29833A.v`.)
- Nothing in the machine reads a stored parity bit as data - see
  `docs/nd120-parity-analysis.md` sections 3-5.

So every backend now stores 16 bits per word and regenerates
`{~(^d[15:8]), d[15:8], ~(^d[7:0]), d[7:0]}` on read. A write's parity bits are
accepted on the bus and dropped. A deliberately WRONG parity write is therefore
absorbed: the data comes back intact and `CORR_n` stays 1.

Backends changed:

| file | change |
|:--|:--|
| `Shared/support/SIP1M9.v` | `bram9` / `sdram_9` arrays and the `RAM_PARITY_STORAGE` ifdef deleted |
| `CPU-BOARD-3202/circuit/MEM_RAM_49_BLOCKRAM.v` | array narrowed 18 -> 16 bits, new `with_parity()` on read |
| `CPU-BOARD-3202/circuit/MEM_RAM_49_SIM.v` | regeneration made unconditional (it had been behind `ND_SDRAM_PACK16`, so that define silently changed parity semantics) |
| `fpga/tang-nano-20k/sdram-bridge/MEM_RAM_49_SDRAM.v` | already correct (`ND_SDRAM_PACK16`), unchanged |

`MEM_RAM_49_SIM.v` keeps its `b*_p` arrays: `runSim/Run120.cpp` and
`sim/nd120_probe.cpp` reference them by name.

### Still open, needs Ronny's decision

**Parity is never CHECKED anywhere**, for two independent reasons:

1. `CPU-BOARD-3202/circuit/MEM_43.v:234` masks `LPERR_n`.
2. `Shared/support/AM29833A.v:126` only loads the error register
   `else if (!ReceiveMode)` - that is, it does not evaluate the check in the
   memory-READ direction at all.

Either one alone would be enough to make a parity error invisible. This was
discovered while writing the new testbench (the first version drove receive
mode and produced 257 "errors" that were really no-checks). Nothing depends on
it today because nothing stores parity any more, but if parity checking is ever
wanted, both must be addressed. Written up in
`docs/nd120-parity-analysis.md` section 6b.

---

## 3. Backend selection - the silent Basys3 fallthrough

`CPU-BOARD-3202/circuit/MEM_43.v` picks one of five sheet-49 backends:

| define | backend |
|:--|:--|
| `MAIN_RAM_SDRAM` | `fpga/tang-nano-20k/sdram-bridge/MEM_RAM_49_SDRAM.v` (Tang, 4 MB SDRAM) |
| `MAIN_RAM_BLOCKRAM` | `CPU-BOARD-3202/circuit/MEM_RAM_49_BLOCKRAM.v` (Basys3, Cmod A7 - BRAM, 24 KB) |
| `VERILATOR_SIM` | `CPU-BOARD-3202/circuit/MEM_RAM_49_SIM.v` |
| `MAIN_RAM_SIP1M9` | `Shared/support/MEM_RAM_49.v` -> `Shared/support/SIP1M9.v` (the original six-chip DRAM sheet) |

The Basys3 synthesis defined **none** of them and fell through the `else` into
SIP1M9 - confirmed by reading the real synthesis logs under
`fpga/basys3/logs/`, not inferred. The `else` branch's own comment asserted no
build used it.

Two changes:

- `fpga/basys3/vivado_build.tcl` now appends `MAIN_RAM_BLOCKRAM` to the
  synthesis defines (same backend the Cmod A7 build already used).
- `MEM_43.v` has no fallthrough left. An unselected backend instantiates
  `ND120_ERROR_no_main_ram_backend_selected`, which does not exist, so
  elaboration fails. **If a board build ever dies on that module name, add the
  correct `MAIN_RAM_*` define - do not restore a default.**

Verified by verilator lint in four define combinations: BLOCKRAM clean apart
from the Xilinx primitives `MMCME2_BASE`/`BUFG`; the old Basys3 define set
fires the guard at `MEM_43.v:616`; `VERILATOR_SIM` and `MAIN_RAM_SIP1M9` are
clean.

---

## 4. The bank map - BANK0 + BANK2 populated, BANK1 absent

The board decode PAL `PAL_44445B` wires the three 1M-word banks in **physical
address order BANK0, BANK2, BANK1**. Therefore:

- populated: **BANK0** (phys 0-1M) and **BANK2** (phys 1M-2M) - the contiguous
  4 MB
- absent: **BANK1** (phys 2M-3M)

`BANK1` is not the second bank. Commit `81462c0` (23-JUL-2026) fixed the SDRAM
bridge to match, and that is what made the Tang report 4 MB instead of 2 MB on
silicon - see `MEM_RAM_49_SDRAM.v` lines 375-384.

`fpga/tang-nano-20k/sdram-bridge/sim/mem_ram_49_sdram_tb.v` was last touched
11-JUL and still used the pre-fix map (banks 0/1 populated, bank 2 absent), so
three of its four targets failed: reads of BANK1 returned 0 (absent) where the
tb expected written data, and the BANK2 "absent" case returned real data.

The errors *looked* like a late timing or soak problem - the reported times
clustered around 1.556-1.565 s of simulated time - because the random soak
repeats the same mismatch thousands of times. The first three errors actually
fire immediately after the directed writes. **Read the FIRST error, not the
loudest cluster.**

`test-pack16-part` passed throughout, which was the strongest clue: with
`TB_PART_ROWS=1024` only BANK0 is inside the CPU partition, so the stale tb and
the fixed RTL agreed by accident that banks 1 and 2 were both unreachable.

Fix (testbench only, no RTL change): the tb derives the physical bank index
from the real map (`phys(bank) = (bank == 2)`), does its directed first/last
word writes on BANK0 and BANK2, uses BANK1 as the unpopulated case, and soaks
over {0,2}.

`MEM_RAM_49_BLOCKRAM.v` is immune to this class of bug: it gives each of the
three banks its own storage region (`bidx`, line 78), so it does not depend on
physical order.

---

## 5. Gates

New and updated, all registered in `tests/run_all_tests.sh` with strict
`TB_RESULT: PASS` patterns:

| test | directory | what it proves |
|:--|:--|:--|
| `test-am29833a-parity` | `Shared/support/sim/` | all 256 byte values, 3 phases: regenerated parity never faults, inverted always faults, constant 0 faults exactly 128/256 |
| `test-memchain` | `CPU-BOARD-3202/circuit/sim/` | 16-pattern sweep writing deliberately INVERTED parity, requiring correct regenerated parity back |
| `test-blockram` | `CPU-BOARD-3202/circuit/sim/` | bad-parity write absorbed, data intact, `CORR_n` stays 1 |
| `test-memparity` | `CPU-BOARD-3202/circuit/sim/` | `ND_SDRAM_PACK16` does NOT change parity semantics (both builds expect absorption) |
| `test`, `test-pack16`, `test-pack16-part`, `test-storage-port` | `fpga/tang-nano-20k/sdram-bridge/sim/` | measured DRAM protocol, correct bank map, N+4 data deadline, N+5 hold |

**`make test` is fail-fast.** A green run only means "green up to the first
failure". The three sdram-bridge failures survived for two weeks behind an
earlier abort. When something fails, deliberately run the registry entries
after it too before drawing any conclusion about suite health.

---

## 6. What is NOT done

1. **No Basys3 build has been run with these changes.** Nobody has confirmed
   that `MAIN_RAM_BLOCKRAM` synthesizes on the Basys3, and this is the gate on
   everything in point 2. Run it on the Windows host from `fpga\basys3`:

   ```
   .\vivado_build.ps1
   ```

   That defaults to a fresh full synthesis (~1 h) and does not program a board.
   Do NOT use `-ReuseSynth`: the memory backend changed, so the `synth_1`
   checkpoint is stale. Vivado's log lands in `fpga/basys3/logs/vivado_build.log`.
   Two things to check: that the build does not stop on
   `ND120_ERROR_no_main_ram_backend_selected` (if it does, the define is not
   reaching synthesis), and the RAMB18 count - the `xc7a35t` has 100, and the
   array is now 16 bits wide instead of 18.

2. **`SIP1M9.v` and `MEM_RAM_49.v` are still in the tree.** Deleting them was
   agreed in principle and deliberately deferred until a Basys3 build proves
   BLOCKRAM works. That deletion also has to port or archive
   `fpga/basys3/mem-test/basys3_mem_test_top.v` and
   `fpga/qmtech-a35t/mem-test/qmtech_mem_test_top.v`, retire `test-ram`, and
   drop the SIP variant of `test-memchain`.

3. **Parity checking** - section 2 above, needs a decision.

4. Not touched, owned elsewhere: the SMD controller and its adapter, the
   storage cache (`SD-FAT/circuit/nd_storage_cache.v`), and the `sim/` probe
   files. Their working-tree changes were deliberately left out of commit
   `451b05b`.

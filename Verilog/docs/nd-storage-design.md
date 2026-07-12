# nd_storage - RTL design and implementation plan

Status: PLAN OF RECORD 11-JUL-2026. Derived from nd-storage-interface-spec.md; amendments from nd-storage-spec-validation.md are folded in. Implementation proceeds step by step per section 7; every step ends in a registered passing test.

IMPLEMENTATION STATUS (11-JUL-2026):
  step 1 DONE  nds_sync.v + CDC word bridge      gate: SD-FAT/sim test-nds-cdc
  step 2 DONE  nds_mem_model.v + engine read path gate: SD-FAT/sim test-nds-engine
               (round-robin arbiter, client front-ends, range check)
  step 3 DONE  engine write path vs real sd_writer gate: SD-FAT/sim test-nds-write
               (card-first/SDRAM-second proven mid-flight; injected CMD24
               failure leaves SDRAM intact; found+fixed a one-cycle-early
               client-buffer sample that shifted blocks by one word)
  step 4 DONE  nd_storage_mount.v + nd_storage.v top gate: SD-FAT/sim test-nds-mount
               (full stack vs a real FAT16 image: preload byte-exact incl
               zero-padded tail word, n_blocks=ceil, missing-file and
               oversize-file open_err with zero payload traffic, SMD
               clients refused via PRELOAD_MASK with zero SD traffic,
               block read through the client port, reopen/rewind; the
               engine's client indices widened to 3 bits / SLOT4..6 added
               as flagged above; SDFAT_STORAGE added to sd_fat_features.vh;
               M_CHK is a pass-through placeholder until step 5)
  step 5 DONE  nd_storage_fatchk.v contiguity gate  gates: SD-FAT/sim
               test-nds-fatchk-unit (checker vs scripted engine stub:
               FAT16+FAT32 entry formats, EOC thresholds, sector-cache
               read counts, hop cap, err/no-wedge) and test-nds-fatchk
               (full stack vs the image's deliberately fragmented
               FRAG.IMG - built and SELF-VERIFIED by
               make_storage_image.sh, which refuses to emit an
               accidentally-contiguous image: open_err/no open_ok,
               contiguous neighbor still opens, failed open retryable;
               plus a -DSDFAT_NO_STORAGE_CHECK elaboration lint).
               SDFAT_STORAGE_CHECK is live; mount M_CHK pulses
               chk_start and follows chk_ok; the checker owns the
               sd_writer command mux (rd_mode=1) while chk_busy. The
               mount latch set grew fs_is_fat32 + the file size
               (chk_is_fat32/chk_size), as anticipated. Split into its
               own registered target to keep test-nds-mount's runtime.
  step 6 DONE  Verilator system gate               gate: SD-FAT/sim
               test-storage (registered): nd_storage_vtop.v (the full
               stack; SD lines resolved WITHOUT 'z' - DUT oe wins, then
               the card model, then the pullup; clients 0..3 wired out,
               client 3 put inside PRELOAD_MASK for the missing-file
               case) + test_nd_storage.cpp: C++ SD card model adapted
               from the proven sd-fat-test model (CMD17/18/24/25/
               ACMD23/CMD12, CRC both ways) with the always-on illegal-
               write assertion TIGHTENED to "only the mounted files'
               data sectors are legal", plus a C++ mem model (the
               nds_mem_model contract, randomized 4..40-cycle latency);
               clocks 27.03/23.04 MHz (CDC stress). Acceptance 1 (open
               + preload byte-exact incl. the zero-padded tail word,
               size_bytes exact, n_blocks proven behaviorally at both
               edges), 2 (block reads byte-exact; post-run fsck in C++:
               boot-sector snapshot, root dir entries, contiguous
               chains + EOC, and a whole-image compare against an
               expected image patched only at the verified writes;
               fsck.vfat -n on the dumped post image in the Makefile),
               3 (simultaneous requests on all mountable clients,
               served exactly once each, distinct patterns, no cross-
               leak, ZERO SD traffic - v1 has 3 preloadable clients,
               so "4 clients" = 3 concurrent + the SMD/missing-file
               open), write-through (4 CMD24 commits, LAST card commit
               measurably before the FIRST SDRAM write, neighbors
               untouched on card and SDRAM, read-back exact), 5
               (injected CMD24 CRC-status "101" -> done+err, SDRAM slot
               intact, card image unchanged, open_ok STAYS UP, sd_status
               ERROR, retry succeeds; missing file -> open_err;
               out-of-range -> err with zero mem AND zero SD traffic).
               make_storage_image.sh extended with a SELF-VERIFIED
               nds_storage_full.img (TAPE.BPUN 3001 B + FLOPPY1.IMG
               12288 B + FLOPPY2.IMG 8192 B; contiguity re-walked +
               fsck before emit; the step-4/5 image is unchanged).
               First green run was against the clean-room
               sd_file_reader.v replacement (CMD18 run streaming).
               FLAG for steps 7/8: writing the partial TAIL block of a
               file whose size is not a 2048 multiple (e.g. TAPE.BPUN
               block 1) would spill CMD24s past the file's cluster
               chain into the NEXT file's sectors - adapters must never
               write the tail block of an unaligned file (tape is
               read-only; floppy/SMD images are block multiples).
  step 7 DONE  nd_storage_tape_adapter.v            gate: SD-FAT/sim
               test-nds-tape (registered): single-clock (clk_cpu)
               byte-stream adapter per section 2.5, pin-for-pin against
               ND_TAPE_400's byte port (byte_req/byte_valid/byte_data/
               source_rewind) plus one client port and an open_start
               pulse input; 1024x16 local block buffer, s_bptr byte
               position, big-endian even-byte-high serve (4.1); EOF
               (bptr >= size_bytes) and not-open = SILENCE with zero
               client/mem traffic; rewind = bptr 0 + buffer invalidated
               (an in-flight fetch is discarded on completion, no card
               access); c_err = drop have_blk, stay silent, retryable.
               READ-ONLY by construction (c_wr and c_buf_rdata tied 0),
               so the step-6 partial-tail-write FLAG holds trivially.
               Two-tier tb (nd_storage_tape_adapter_tb.v): tier A vs a
               scripted client-port stub with a 0xEE-poisoned tail
               (full 3001-byte stream byte-exact, explicit block-
               boundary fetch at byte 2048, EOF silence on the
               non-2048-multiple size, mid-stream rewind, c_err
               no-wedge + retry, rewind during an in-flight fetch);
               tier B = the adapter on client 0 of the REAL stack vs
               nds_storage.img (TAPE.BPUN streamed whole and byte-
               compared, EOF silence with zero req/mem traffic, rewind
               + first-100-byte re-read, card health clean).
  step 8 DONE  nd_storage_floppy_adapter.v          gate: SD-FAT/sim
               test-nds-floppy (registered): single-clock (clk_cpu)
               block adapter against ND_FLOPPY_DMA's disk-image backend
               port AS FOUND IN THE SOURCE (one logical SECTOR per
               disk_req: disk_wr/lsect[15:0]/format[1:0]/drive[1:0]/
               wordcount[10:0] -> disk_done + disk_err, dbuf_addr/
               wdata/we fill the device's sector buffer on reads,
               combinational dbuf_rdata on writes - NOT the
               disk_start/blkaddr1/blkaddr2/unit shape the interview
               note guessed; section 2.6 documents the real contract).
               Parameter DRIVE selects the served drive; a mismatching
               disk_drive is ignored with all outputs 0 so two
               instances (FLOPPY1.IMG=client 1, FLOPPY2.IMG=client 2)
               can OR their outputs. Block math: word offset =
               lsect << log2(wps), block = off[24:10]; every sector
               size divides 1024 so no block straddle. 1024x16 local
               buffer doubles as a one-block cache (sequential-read
               hits skip the client fetch). Writes are RMW (pre-read
               unless cached or a full aligned 1024-word block), and
               the step-6 tail FLAG is a hard gate: a write errs
               unless (block+1)*2048 <= size_bytes. Not-open/
               out-of-range/c_err all end in disk_done WITH disk_err,
               cache dropped, retryable, never a wedge. Two-tier tb:
               tier A vs scripted client stub + disk driver replaying
               the device tb's handshake (full expectation-shadow
               compare after every write proves RMW preservation;
               tail rule, c_err on fetch AND commit, drive-mismatch
               silence); tier B on client 1 of the REAL stack vs
               nds_storage.img (reads byte-exact, sector + RMW writes
               verified IN THE CARD IMAGE at first_sector and read
               back through the disk port, whole-4MB card shadow
               compare against stray writes, card health clean).
               OWNER DECISIONS 11-JUL (interview): (i) the adapter
               targets ND_FLOPPY_DMA's backend, NOT ND_FLOPPY_PIO's
               sector port: 1560& mass boot is the proven path; a PIO
               adapter is optional later work.
               (ii) SMD images are 75 MB real-world - SMD stays Phase 4
               (tag-based caching), no small-image shortcut.
               (iii) Step 10 integration into ND120_TOP/Tang top is
               owned by the DEVICE workstream; this side delivers
               nd_storage + adapters as a black box with a written
               interface handoff. (iv) Order stands: 6 then 7 then 8.
  step 9 DONE  storage device port in the SDRAM bridge  gate:
               fpga/tang-nano-20k/sdram-bridge/sim :: test-storage-port
               (registered). New build define ND_STORAGE_PORT (requires
               ND_SDRAM_PACK16; set by the step-10 Tang storage build and
               the gate only - every existing build is bit-identical):
               sdram18.v grew a full-location access path (acc32/din32/
               dout32 ports: rd/wr with acc32=1 moves the whole 32-bit
               location at addr[21:1], writes drive all four DQM lanes,
               same 5-cycle state machine, acc32=0 bit-identical);
               MEM_RAM_49_SDRAM grew the section-5.2 mem port (stor_clk
               domain: mem_start/we/addr[19:0]/wdata[31:0]/rdata[31:0]/
               busy/done, toggle-CDC into clk2x) whose ops are granted
               EXACTLY like refresh - B_POST slot after each CPU access,
               B_TAIL during absent-row accesses, B_IDLE behind the
               idle_cnt watchdog guard, always behind refresh priority -
               so CPU accesses always win. Device address D is issued as
               half-word {1'b1, D, 1'b0}: the leading 1 is FORCED in the
               grant, so device traffic physically cannot reach the CPU
               half of the chip (the caveat below is handled: the port
               speaks full-location addresses, bit 0 of the CPU-side
               half-word address never exists on the device side). The
               tb runs device traffic CONCURRENTLY with the 2000-access
               CPU protocol replay (1800+ device ops served) with the
               late-N+4/N+5 sampling still asserting every CPU access,
               plus directed first/last-location ops, a below-partition
               write attempt proven to land in the storage half with the
               CPU alias words intact, idle-slot service, and a 1M-
               location mirror integrity check. Existing gates test /
               test-pack16 / test-pack16-part re-run green unmodified.
               Historical unblock note (11-JUL, commit d26fd66):
               ND_SDRAM_PACK16 stores two 16-bit ND words per 32-bit
               location (DQM lane-masked single-access writes, parity
               computed on read - the self-test is PROVEN parity-free,
               see docs/nd120-parity-analysis.md). CPU keeps the full
               4 MB; storage owns the upper 4 MB as 32-bit locations
               {1'b1, addr[19:0]} - exactly this design's mem-port
               address contract. ND_STORAGE_PARTITION is SUPERSEDED.
               The CPU/storage boundary knob is MEM_RAM_49_SDRAM
               #(CPU_PART_ROWS) (1K-word ND rows, default 2048 = full
               4 MB CPU; keep multiples of 1024; never hardcode the
               boundary). CAVEAT for the device-port implementer:
               under pack16 sdram18.v's CPU-side address is a 22-bit
               HALF-word address (bit 0 = which 16-bit half); the
               device port must use the full-location (32-bit word)
               view. Bridge gates: sdram-bridge/sim test (legacy),
               test-pack16, test-pack16-part - all registered.
  step 10      device-workstream handoff (Tang top wiring: define
               ND_STORAGE_PORT, connect stor_clk/stor_rst_n + the mem_*
               group of MEM_RAM_49_SDRAM to nd_storage's mem port 1:1)

Design for the multi-client storage facade specified in
`Verilog/docs/nd-storage-interface-spec.md` (the binding contract).
Companions: `Verilog/docs/device-bus-todo.md` (master plan),
`Verilog/docs/sd-bpun-device-plan.md` (SD pins/card recipe),
`Verilog/SD-FAT/README.md` (library state), `Verilog/docs/nd120-dram-memory.md`
(memory bridge). All paths relative to the repository root.

Everything generic lands in `Verilog/SD-FAT/circuit/` (MIT project code next
to the vendored GPL reader, same arrangement as today); board glue lands in
`Verilog/fpga/tang-nano-20k/sdram-bridge/`. Nothing touches DELILAH-CPU/,
DECODE-GateArray/ or CPU-BOARD-3202/.

## 1. Clocking, layering and the SDRAM decision

### 1.1 Clock domains

| Domain | Name | Tang value | Contents |
|---|---|---|---|
| storage | `clk_stor` | 27 MHz crystal/rPLL | nd_storage core, sd_file_reader (CLK_DIV=2), sd_writer (CLKDIV=5), mount FSM, block engine |
| client | `clk_cpu` | ND sysclk (27 MHz on Tang, ~16.7 MHz on Basys3) | per-client front-ends, all `open_*`/`req`/`done`/`buf_*` client signals (spec section 4: CDC is INSIDE nd_storage) |
| memory | `clk2x` | 54 MHz (2x OSC, same rPLL) | MEM_RAM_49_SDRAM bridge + sdram18 (existing) |

nd_storage is designed for `clk_stor != clk_cpu` (2-flop toggle synchronizers
everywhere); on Tang they may be the same 27 MHz net, which simply makes the
synchronizers fast. No new derived clocks; both clocks are PLL outputs
(standing constraint).

### 1.2 Which SDRAM controller nd_storage targets

Decision: **the 18-bit sdram18.v controller behind MEM_RAM_49_SDRAM**, via a
new device port added to the bridge - NOT the standalone byte controller
(`sdram-test/src/sdram.v`). Reasons:

- One controller must own the chip, and the CPU port already lives on
  sdram18 through the bridge.
- The "CPU absolute priority" rule can only be enforced where CPU access
  timing is visible: the bridge FSM knows RAS rise and owns the
  guaranteed-idle B_POST slot (it already schedules refresh there). Device
  ops are granted exactly like refresh: in B_POST after each CPU access, and
  in B_IDLE behind the same `idle_cnt` guard. A device op is 5 clk2x cycles;
  the post-access slot has >= 14 free cycles before the earliest next CPU
  access (N+11 rule) - a device op can never push CPU read data past the
  proven worst case.

nd_storage itself never sees sdram18. It talks to an abstract **mem port**
(section 5.2) in `clk_stor`; board glue (`sdram-bridge`) implements it, sim
uses a behavioral model.

### 1.3 SDRAM partition (the concrete map)

Fact from the current bridge: `s_addr = {bank_q, row_q[9:0], AA_9_0}` covers
the ENTIRE 2M-word SDRAM (ND BANK0 -> addr[20]=0, ND BANK1 -> addr[20]=1).
There is no spare word-address space today; the "spare" is only the unused
DQ[31:18] bits (14 bits - too narrow for a 16-bit disk word, and dropping
parity was already rejected because the self-test writes bad parity).

Decision: **give up ND BANK1 when storage is enabled** (new build define
`ND_STORAGE_PARTITION`, set only by the Tang storage build):

```
SDRAM word address space (2M x 32):
  0x000000 - 0x0FFFFF  addr[20]=0  ND-120 BANK0, 1M x 18-bit words = 2 MB main memory
  0x100000 - 0x1FFFFF  addr[20]=1  disk-image region, 1M x 32-bit words = 4 MB payload
```

With the define set, MEM_RAM_49_SDRAM treats BANK1 like BANK2 (`bsel_q <=
BANK0` only, access falls into B_TAIL); the ND-120's boot-time memory sizing
detects one bank - exactly how the machine shipped with less memory. Device
data uses the FULL 32 bits per SDRAM word (two 16-bit disk words), so the
4 MB region holds 2048 blocks of 2048 bytes.

Default slot map (all values in 2048-byte blocks, parameters of nd_storage;
the spec's "tape 64 KB / floppy 2 MB" defaults do not fit two floppies in a
4 MB partition, so the Tang defaults use 1.25 MB floppy slots - real ND
floppy images are <= 1.2 MB; SLOT_* are generics per spec section 6, so any
board can override):

OWNER UPDATE 11-JUL-2026: the card file set is fixed as TAPE.BPUN,
FLOPPY1.IMG, FLOPPY2.IMG (floppies are 1-based), SMD0.IMG..SMD3.IMG.
That makes SEVEN clients. SMD images (tens of MB) cannot be fully
preloaded into the 4 MB region: the SMD clients keep the same client
port contract but their slots are CACHE WINDOWS - full-slot preload
does not apply, they are served by the Phase-4 tag-based cache (spec
section 8 scope fence). v1 implements full preload for clients 0-2
only; SMD clients may be parameterized in but return open_err until
Phase 4 lands. N_CLIENTS therefore grows to 7 (grant_id and any
2-bit client indices in the engine widen to 3 bits - flag for the
step-4+ implementer; the step-1..3 engine is parameterized but was
exercised at N=2..4).

| client | device | file (root, fixed) | SLOTn_BASE_BLK | SLOTn_SIZE_BLK | bytes | preload |
|---|---|---|---|---|---|---|
| 0 | tape-400 | TAPE.BPUN | 0 | 32 | 64 KB | full (v1) |
| 1 | floppy unit 1 | FLOPPY1.IMG | 32 | 640 | 1.25 MB | full (v1) |
| 2 | floppy unit 2 | FLOPPY2.IMG | 672 | 640 | 1.25 MB | full (v1) |
| 3 | SMD unit 0 | SMD0.IMG | 1312 | 160 | 320 KB | cache window (Phase 4) |
| 4 | SMD unit 1 | SMD1.IMG | 1472 | 160 | 320 KB | cache window (Phase 4) |
| 5 | SMD unit 2 | SMD2.IMG | 1632 | 160 | 320 KB | cache window (Phase 4) |
| 6 | SMD unit 3 | SMD3.IMG | 1792 | 160 | 320 KB | cache window (Phase 4) |

(blocks 1952..2047 = 192 KB spare. The parity refactor LANDED
(ND_SDRAM_PACK16, commit d26fd66): the CPU keeps 4 MB and this whole
4 MB region exists without sacrifice; CPU_PART_ROWS is the knob for
trading CPU rows for a bigger cache region if SMD caching needs it.)

## 2. Module breakdown (Verilog/SD-FAT/circuit/ unless noted)

| File | Responsibility (one line) | approx size |
|---|---|---|
| `nd_storage.v` | Top: SD reader+writer instances, SD pin mux (phase_write), mount/engine/fatchk wiring, status outputs | ~450 lines |
| `nd_storage_engine.v` | Round-robin arbiter, per-client pending latches + clk_cpu front-ends (generate), CDC word bridge, block read/write engine, 512x32 staging BRAM | ~750 lines |
| `nd_storage_mount.v` | Open/preload FSM: drive sd_file_reader per open, capture geometry/size/first-sector, stream file bytes -> 32-bit packer -> mem port, park reader | ~320 lines |
| `nd_storage_fatchk.v` | Mount-time contiguity walker: verify FAT[c]=c+1 over the whole chain + EOC, via sd_writer read mode; ok/bad flag (SDFAT_STORAGE_CHECK) | ~180 lines |
| `nd_storage_tape_adapter.v` | Byte-stream adapter (spec section 5): one 1024x16 block buffer over one client port; byte_req/byte_valid/rewind, EOF = silence | ~230 lines |
| `nd_storage_floppy_adapter.v` | Sector-device glue: ND_FLOPPY_PIO disk_*/dbuf_* onto one client port; read = stream filter, write = read-modify-write with internal 1024x16 buffer | ~280 lines |
| `nds_sync.v` | 2-flop toggle/pulse synchronizer primitive (one module, instantiated everywhere) | ~50 lines |
| `Verilog/SD-FAT/sim/nds_mem_model.v` | Behavioral mem-port model: 1M x 32 array, parameterized/randomized ack latency, $readmem preload + hierarchical checking | ~110 lines |
| `Verilog/fpga/tang-nano-20k/sdram-bridge/sdram18.v` (edit) | Add 32-bit data path: `din` widened to [31:0] internally via new `din32`, new `dout32` (nand2mario's sdram.v already has the dout32 pattern); CPU 18-bit path bit-identical | ~25 line diff |
| `Verilog/fpga/tang-nano-20k/sdram-bridge/MEM_RAM_49_SDRAM.v` (edit) | Device port: mem-port toggles synced into clk2x, grant in B_POST/idle slots (same policy as refresh), `ND_STORAGE_PARTITION` bank gating | ~90 line diff |

### 2.1 nd_storage.v (top)

Owns the single set of SD signals and both SD cores, exactly the
sd_fat_test_top pattern:

- `sd_file_reader` instance: `rstn = rst_stor_n & s_mount_active &
  ~s_mount_park` - the reader is HELD IN RESET except while a mount runs
  (per-open full re-init = the proven rewind/card-swap recovery).
  `target_name`/`target_len` muxed from the granted client's FILE parameters.
- `sd_writer` instance: `rst_n = rst_stor_n`, always alive. Its command pins
  are muxed: fatchk owns it while `chk_busy`, otherwise the engine's
  write-through path (the arbiter serializes mount and block ops, so there is
  never contention).
- Pin mux (the ONLY consumers; tristate stays at the board top):

```
assign sd_clk_o   = s_phase_write ? wr_sdclk  : rd_sdclk;
assign sd_cmd_o   = s_phase_write ? wr_cmd_o  : rd_cmd_o;
assign sd_cmd_oe  = s_phase_write ? wr_cmd_oe : rd_cmd_oe;
assign sd_dat0_o  = wr_dat0_o;
assign sd_dat0_oe = s_phase_write & wr_dat0_oe;
```

- `s_phase_write` register (clk_stor): cleared by the mount FSM in M_INIT
  (reader owns the card), set in M_PARK and out of reset. Geometry/size/
  first-sector latches are captured from the reader on `file_found` BEFORE
  parking (same-edge capture, the ST_C_FIND lesson).

Reset/park ownership summary (task item): mount FSM is the only agent that
releases the reader; the engine/fatchk are the only agents that pulse
sd_writer `start`, and only while `s_phase_write=1`; both are mutually
exclusive by arbiter construction.

### 2.2 nd_storage_engine.v

**Arbiter** (clk_stor): per client `s_pend_open[c]`, `s_pend_blk[c]` with
latched `s_op_wr[c]`, `s_op_block[c][15:0]` (set on the synced request
toggles, cleared at op end). Scan: grant the first pending client at
`ptr+1, ptr+2, ... ptr` (mod N_CLIENTS); at op completion `ptr <= grant`.
One op runs to completion, no preemption. No FIFOs anywhere - exactly the
one-request-per-client model of spec section 3.

**Engine FSM** (clk_stor):

```
E_IDLE    : scan; on grant -> E_GRANT
E_GRANT   : open pending  -> E_OPEN (hand to mount FSM)
            block pending -> range check: s_op_block >= n_blocks[c]
                             -> E_DONE with err=1 (NO SD/SDRAM traffic)
            read  -> R_MEM,  write -> W_PULL
E_OPEN    : mnt_start pulse; wait mnt_done/mnt_err -> E_DONE
R_MEM     : mem_start=1, mem_we=0, mem_addr={s_blk_abs[10:0], s_wcnt[8:0]}
R_WAIT    : mem_done -> latch mem_rdata -> R_PUSH_HI
R_PUSH_HI : word bridge push mem_rdata[31:16] (client word 2m)   -> R_PUSH_LO
R_PUSH_LO : push mem_rdata[15:0] (word 2m+1); s_wcnt++;
            s_wcnt==511 done ? E_DONE : R_MEM
W_PULL    : word bridge pull 1024 words -> staging BRAM (512x32,
            pack big-endian pairs); then W_SEC_GO with s_sec=0
W_SEC_GO  : wr_start=1, sector = s_first_sector[c] + {s_op_block,2'b00} + s_sec,
            rd_data served from staging (see 4.2)              -> W_SEC_WAIT
W_SEC_WAIT: wr_done -> s_sec==3 ? W_MEM : W_SEC_GO(s_sec+1)
            wr_err  -> E_DONE with err=1  (SDRAM NOT touched - test 5)
W_MEM     : 512 mem writes from staging (mem_we=1), W_MEM_WAIT loop
E_DONE    : set s_err_c, flip done_tgl[grant]; clear pend; ptr<=grant -> E_IDLE
```

Ordering rule (from acceptance test 5): **card first, SDRAM second, done
last.** A failed CMD24 leaves the SDRAM copy untouched; a successful write
commits to the card before `done` (spec: card always consistent, safe to
pull).

Every SD/mem wait state carries the WD_MAX watchdog (sd-fat-test pattern);
timeout -> E_DONE err=1 plus `sd_status <= SD_ERROR`.

**Per-client front-end** (clk_cpu, generate block, one per client):

```
on req[c] & ~fe_busy[c] & open_ok_sync[c]:
    fe_busy[c]<=1; latch {wr[c], block[c]}; flip req_tgl[c]
    (req while fe_busy is IGNORED - spec allows it)
read stream : on rd_have_tgl edge (synced) & grant_id_sync==c:
    buf_addr[c]<=fe_cnt; buf_wdata[c]<=bridge_rd_data; buf_we[c]<=1 (1 cycle);
    fe_cnt++; flip rd_ack_tgl
write stream: on wr_want_tgl edge & grant_id_sync==c:
    cycle A: buf_addr[c]<=fe_cnt
    cycle B: bridge_wr_data<=buf_rdata[c]; flip wr_have_tgl; fe_cnt++
    (address presented one cycle ahead - works for the floppy's
     combinational dbuf_rdata and for registered BRAMs alike)
on done_tgl[c] edge: err[c]<=err_sync; done[c] 1-cycle pulse;
    fe_busy[c]<=0; fe_cnt<=0
open: open_req[c] & ~fe_busy -> flip open_tgl[c];
    open_ok/open_err are 2-flop-synced levels; size_bytes[c] sampled
    when open_ok_sync rises (stable long before the toggle).
busy[c] = fe_busy[c]   (covers arbiter wait, per the spec waveform)
```

### 2.3 nd_storage_mount.v

FSM (clk_stor), invoked by the engine per granted open:

```
M_IDLE  -> M_INIT : phase_write<=0; release reader reset; clear open_ok[c]
M_CARD  : wait card_stat>=8 (card_ready) | watchdog -> M_FAIL(SD_NOCARD)
M_SCAN  : file_found -> latch {size, found_file_first_sector, fs geometry,
          found_file_cluster}; size > SLOT_SIZE_BLK[c]*2048 -> park+M_FAIL
          (before the first outen byte - the reader needs hundreds of
          cycles to start READ_A_FILE, checked combinationally at latch)
          scan_done without file_found | watchdog -> M_FAIL
M_LOAD  : consume outen/outbyte -> 4-byte big-endian packer -> 8x32 sync
          FIFO -> mem writes at {SLOT_BASE_BLK[c],9'b0}+byte_cnt[21:2];
          until scan_done & fifo empty (pad tail word with 0x00)
          (rates: 1 byte per ~64 clk_stor from the reader vs ~20 clk_stor
          per 4-byte mem write - the FIFO only absorbs jitter; tb asserts
          no overflow)
M_PARK  : reader rstn low (parked), phase_write<=1
M_CHK   : `ifdef SDFAT_STORAGE_CHECK: chk_start; ok -> M_OK, bad -> M_FAIL
M_OK    : open_ok[c]<=1; n_blocks[c]<=ceil(size/2048); mnt_done
M_FAIL  : open_err[c]<=1; mnt_done (engine converts to done)
```

`open_ok` stays up across later write errors (spec section 7); only a new
open_req clears/rebuilds it.

### 2.4 nd_storage_fatchk.v

sd_fat_check emits a human report, not a machine verdict, so mount uses a
dedicated walker (reusing sd_fat_check's `fat_sec`/`fat_off`/`is_eoc`
functions and its cache-one-FAT-sector pattern): for
`n = ceil(size_bytes / (cluster_size*512))` clusters starting at
`first_cluster`, require `FAT[first+i] == first+i+1` for i<n-1 and EOC at
`FAT[first+n-1]`. Output `ok` level with `done`. Reads via sd_writer
rd_mode=1 (reader parked). This enforces the v1 contiguity requirement at
open (spec sections 6/8).

### 2.5 nd_storage_tape_adapter.v (clk_cpu, single clock)

Ports mirror ND_TAPE_400's byte source 1:1 (`byte_req` in pulse,
`byte_valid` out pulse, `byte_data[7:0]`, `rewind` in pulse - wire
`source_rewind` to `rewind`) plus one full client port (c_open_req out,
c_open_ok/err/size in, c_req/c_wr=0/c_block out, c_busy/done/err in,
c_buf_addr/wdata/we in, c_buf_rdata out = 16'd0) and an `open_start` input
for the board/boot logic.

Internals: `blkbuf[0:1023]` (BRAM) filled by c_buf_we; `bptr[31:0]` byte
position; `cur_blk[15:0]`, `have_blk`. FSM: on byte_req: `bptr >=
c_size_bytes` -> never answer (EOF = RFT stays low, C-model behavior);
hit (`bptr[26:11]==cur_blk && have_blk`) -> byte_valid with
`bptr[0] ? word[7:0] : word[15:8]` (big-endian), bptr++; miss -> c_req with
c_block=bptr[26:11], wait c_done, then serve. `rewind`: bptr<=0,
have_blk<=0 - **no card access** (image lives in SDRAM). c_err on done:
drop have_blk, stay silent (tape runout).

### 2.6 nd_storage_floppy_adapter.v (clk_cpu) - AS BUILT (step 8)

Retargeted 11-JUL (owner decision) to ND_FLOPPY_DMA's disk-image backend
port - 1560& mass boot is the proven path; a PIO adapter is optional later
work. The interview note guessed a disk_start/blkaddr1/blkaddr2/unit shape;
the DEVICE SOURCE (ND-BUS-DEVICES/FLOPPY-DMA/circuit/ND_FLOPPY_DMA.v) is
authoritative and differs: the backend moves ONE LOGICAL SECTOR per
request, addressed by a 16-bit logical sector number, not by a 32-bit
block address pair. The actual contract (adapter side, pin-for-pin):

```
disk_req        in   1-cycle pulse: move one sector (fields registered in
                     the device, stable from the pulse until disk_done)
disk_wr         in   0 = image -> device buffer, 1 = device buffer -> image
disk_lsect      in   [15:0] logical sector number
disk_format     in   [1:0]  words/sector: 0=256, 1=128, 2=64, 3=512
disk_drive      in   [1:0]  drive select (command word b7:6; boot uses 0)
disk_wordcount  in   [10:0] words to move (the device passes words/sector)
disk_done       out  1-cycle pulse (the device waits on it as a level)
disk_err        out  valid with disk_done (wire to the device disk_err_in)
dbuf_addr/wdata/we   out: fill the device's 1024x16 sector buffer (reads)
dbuf_rdata      in   device buffer readout (combinational in the device;
                     the adapter samples with a settle cycle, so a
                     registered backend would also be correct)
```

Parameter DRIVE[1:0]: one instance serves one drive (FLOPPY1.IMG =
client 1 = DRIVE 0, FLOPPY2.IMG = client 2 = DRIVE 1). A request with
disk_drive != DRIVE is ignored completely, all outputs parked at 0, so two
instances share the controller's disk_* outputs with disk_done/disk_err/
dbuf_* OR-combined.

Geometry: linear word offset = lsect << log2(words/sector); c_block =
offset[24:10], word-in-block = offset[9:0]. Every sector size divides
1024, so a sector never straddles a client block. The 1024x16 local buffer
doubles as a one-block cache: the '1560&' sequential boot stream fetches
each block once per two 512-word chunks.

```
READ  : cache hit -> serve wordcount words via dbuf_*; miss -> one c_req
        read into the local buffer, then serve.
WRITE : read-modify-write: c_req read of the containing block (skipped on
        a cache hit or a full aligned 1024-word transfer), overlay the
        device's words (dbuf_addr walk, settle cycle, sample), then one
        c_req write served from the local buffer (registered c_buf_rdata;
        the engine's A/B/C sampling gives it 2 cycles). After a successful
        commit the buffer stays valid as the cache.
errors: not-open, out-of-range, c_err  ->  disk_done WITH disk_err, cache
        dropped, zero card/SDRAM side effects, always retryable.
        HARD RULE (step-6 FLAG): a write errs unless the WHOLE containing
        block lies inside the file ((block+1)*2048 <= size_bytes) - never
        write the partial tail block of a non-2048-multiple file. Floppy
        images are block multiples, so in-range requests are never refused.
```

open_start (board/boot pulse) passes through as c_open_req, as in the tape
adapter. This module is used both by acceptance test 6 (gate
test-nds-floppy) and by the real Tang build.

## 3. Parameterization and feature flags

`nd_storage` parameters (Verilog-2001, per-index pairs like the existing
FILE2_NAME/FILE3_NAME pattern; N_CLIENTS <= 4 uses the first N):

```
parameter         N_CLIENTS   = 4
parameter [2:0]   RD_CLK_DIV  = 3'd2          // sd_file_reader (27 MHz class)
parameter [7:0]   WR_CLKDIV   = 8'd5          // sd_writer bit clock
parameter [31:0]  WD_MAX      = 32'd270_000_000
parameter         SIMULATE    = 0             // short SD init in sim
parameter         N_CLIENTS   = 7   (owner file set, 11-JUL-2026)
parameter [52*8-1:0] FILE0_NAME = "TAPE.BPUN"   , parameter [7:0] FILE0_LEN = 8'd9
parameter [52*8-1:0] FILE1_NAME = "FLOPPY1.IMG" , parameter [7:0] FILE1_LEN = 8'd11
parameter [52*8-1:0] FILE2_NAME = "FLOPPY2.IMG" , parameter [7:0] FILE2_LEN = 8'd11
parameter [52*8-1:0] FILE3_NAME = "SMD0.IMG"    , parameter [7:0] FILE3_LEN = 8'd8
parameter [52*8-1:0] FILE4_NAME = "SMD1.IMG"    , parameter [7:0] FILE4_LEN = 8'd8
parameter [52*8-1:0] FILE5_NAME = "SMD2.IMG"    , parameter [7:0] FILE5_LEN = 8'd8
parameter [52*8-1:0] FILE6_NAME = "SMD3.IMG"    , parameter [7:0] FILE6_LEN = 8'd8
SLOT bases/sizes per the client map table above (v1 preload only for
clients 0-2; SMD slots reserved as Phase-4 cache windows)
```

The name parameters are left-justified string literals converted to the
reader's byte-0-in-low-byte `target_name` layout by the same generate loop
sd_fat_test_top uses (`g_target_names`), muxed per granted client.

`sd_fat_features.vh` additions (follow the existing dependency-resolution
pattern; storage needs the write engine for write-through AND for the
fatchk/mount read path):

```
`ifdef SDFAT_WRITE
  `ifndef SDFAT_NO_STORAGE
    `define SDFAT_STORAGE
  `endif
`endif
`ifdef SDFAT_STORAGE
  `ifdef SDFAT_CHECK
    `ifndef SDFAT_NO_STORAGE_CHECK
      `define SDFAT_STORAGE_CHECK        // mount-time contiguity gate
    `endif
  `endif
`endif
```

Without SDFAT_STORAGE_CHECK, mount skips M_CHK (card recipe still guarantees
contiguity; the flag only strips the enforcement area).

## 4. Data-path definition and exact timing

### 4.1 Byte/word order (normative)

One block = 2048 bytes = 4 SD sectors = 1024 client words = 512 SDRAM words.
Let `k` = linear byte 0..2047 within the block (`k = 512*s + b`, sector s,
sector byte b), `w` = client word 0..1023, `m` = SDRAM 32-bit word 0..511:

```
client word w  = {byte 2w, byte 2w+1}        big-endian, byte 2w = [15:8]
                                             (identical to the proven WRBLK1
                                              pattern: even byte = high byte)
SDRAM word m   = {word 2m, word 2m+1}
               = {byte 4m, byte 4m+1, byte 4m+2, byte 4m+3}   byte 4m = dq[31:24]
SD sector addr = found_file_first_sector[c] + 4*block + s
SDRAM word addr= mem_addr[19:0] = {blk_abs[10:0], m[8:0]},
                 blk_abs = SLOT_BASE_BLK[c][10:0] + block
```

The mount preload packer and the engine both use this order, so a byte on
the card, in SDRAM and in a client buffer always corresponds 1:1.

### 4.2 Read op (spec section 4 waveform, annotated)

```
clk_cpu : req[c]   _/\____________________________________________
          busy[c]  __/--------------------------------------\_____
clk_stor:            [req_tgl 2-flop, arbiter wait, grant]
          per m=0..511:
            mem_start _/\    (mem_we=0, addr={blk_abs,m})
            mem_done  ....\_/    (~10-30 clk_stor: sync into clk2x,
                                  wait leftover slot, 5-cycle op, sync back)
            rd_have_tgl flips twice (hi word, then lo word); data bus
            bridge_rd_data[15:0] is stable ONE clk_stor before each flip
clk_cpu : buf_we[c]  ____/- 1024 single-cycle pulses, buf_addr 0..1023 -\__
          (each pulse: 2-flop edge detect on rd_have_tgl, then ack toggle)
clk_stor: done_tgl flips after word 1023 acked
clk_cpu : done[c]  ________________________________________/\_____
          err[c]   valid during done (0 here)
```

Per-word CDC round trip ~= 3 clk_stor + 3 clk_cpu each way; block read total
~= 0.5-0.9 ms at 27/27 MHz including SDRAM handshakes. (Permitted
optimization, not required for v1: issue mem read m+1 while pushing word
pair m - the FSM shape above allows adding one skid register later.)

### 4.3 Write op

```
Phase 1 - pull:   engine flips wr_want_tgl 1024x; FE presents buf_addr one
                  cycle ahead, samples buf_rdata the next cycle (standard
                  synchronous-BRAM timing; also correct for the floppy's
                  combinational dbuf_rdata), returns wr_have_tgl + data.
                  Engine packs pairs into staging BRAM (512x32).
Phase 2 - card:   4x sd_writer CMD24. sd_writer's byte fetch contract is a
                  REGISTERED read port with 1-clk latency and ~80 clk_stor
                  between fetches (8 bit-ticks at CLKDIV=5): serve
                  rd_data <= staging[{s_sec[1:0], rd_addr[8:2]}] byte lane
                  ~rd_addr[1:0] via a 2-stage registered read - trivially
                  inside the budget. wr_err at ANY sector -> done+err,
                  skip phase 3 (SDRAM copy stays intact - test 5).
Phase 3 - SDRAM:  512 mem writes (mem_we=1, mem_wdata = staging[m]).
done[c] fires only after phase 3 - i.e. after the card has acknowledged all
4 sectors AND the SDRAM copy matches (write-through commits before done).
```

The 2 KB staging BRAM is a deliberate, engine-internal deviation from the
"nd_storage never stores payload" rationale: that rule bans per-client
buffering/queueing; one shared staging block avoids pulling the client
buffer twice over the CDC and makes the card-first/SDRAM-second ordering of
test 5 natural. Document it in the module header.

Timing: dominated by 4x CMD24 at 2.7 MHz ~= 10-20 ms/block; worst-case
client wait (N-1) ops ~= 60 ms - inside every device budget (spec section 3).

### 4.4 CDC inventory (all 2-flop, toggle-based, via nds_sync.v)

| Crossing | Signals | Data rule |
|---|---|---|
| cpu->stor, per client | `open_tgl[c]`, `req_tgl[c]` | `wr[c]`, `block[c]` latched by the FE and stable until done |
| stor->cpu, per client | `done_tgl[c]` | `err_c`, updated open_ok/open_err/size_bytes stable >= 2 clk_stor before the flip; sampled after edge detect |
| stor->cpu, shared | `rd_have_tgl`, `bridge_rd_data[15:0]`, `grant_id[1:0]` | data/grant stable one clk_stor before flip; grant changes only while bridge idle |
| cpu->stor, shared | `rd_ack_tgl`, `wr_have_tgl`, `bridge_wr_data[15:0]` | same rule mirrored |
| stor->cpu, levels | `open_ok[N]`, `open_err[N]`, `sd_status[1:0]` | quasi-static, plain 2-flop per bit |
| stor<->clk2x (shim) | `mem_start_tgl` out / `mem_done_tgl` back | `{mem_we, mem_addr, mem_wdata}` stable from start to done; `mem_rdata` stable at done flip. Same-PLL integer-ratio clocks - the 2-flop pattern is conservative-safe |

## 5. External interfaces (exact)

### 5.1 nd_storage port list

```verilog
module nd_storage #(...parameters of section 3...) (
    input  wire clk_stor,  input wire rst_stor_n,
    input  wire clk_cpu,   input wire rst_cpu_n,
    // SD pads (single tristate at the board top, repo rule)
    output wire sd_clk_o,
    input  wire sd_cmd_i,  output wire sd_cmd_o,  output wire sd_cmd_oe,
    input  wire sd_dat0_i, output wire sd_dat0_o, output wire sd_dat0_oe,
    // SDRAM device port (clk_stor domain, see 5.2)
    output wire        mem_start,   // 1-cycle pulse, only when mem_busy=0
    output wire        mem_we,
    output wire [19:0] mem_addr,    // 32-bit-word address inside the region
    output wire [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,   // valid at mem_done, then held
    input  wire        mem_busy,
    input  wire        mem_done,    // 1-cycle pulse
    // client ports (clk_cpu domain, flattened; names/widths per spec sec 4)
    input  wire [N_CLIENTS-1:0]     open_req,
    output wire [N_CLIENTS-1:0]     open_ok,
    output wire [N_CLIENTS-1:0]     open_err,
    output wire [N_CLIENTS*32-1:0]  size_bytes,
    input  wire [N_CLIENTS-1:0]     req,
    input  wire [N_CLIENTS-1:0]     wr,
    input  wire [N_CLIENTS*16-1:0]  block,
    output wire [N_CLIENTS-1:0]     busy,
    output wire [N_CLIENTS-1:0]     done,
    output wire [N_CLIENTS-1:0]     err,
    output wire [N_CLIENTS*10-1:0]  buf_addr,
    output wire [N_CLIENTS*16-1:0]  buf_wdata,
    output wire [N_CLIENTS-1:0]     buf_we,
    input  wire [N_CLIENTS*16-1:0]  buf_rdata,
    // status (for board LEDs / console, spec sec 7)
    output wire [1:0] sd_status,    // 0 NOTCHK, 1 NOCARD, 2 ERROR, 3 OK
    output wire [1:0] card_type,
    output wire [1:0] fs_type
);
```

### 5.2 Mem-port shim (board glue contract)

The nd_storage-facing side is the `mem_*` group above (start/busy/done
idiom, same shape as sd_writer's command interface). The Tang implementation
lives in MEM_RAM_49_SDRAM: sync `mem_start` toggle into clk2x; hold
`{we,addr,wdata}` stable; issue to sdram18 with
`s_addr = {1'b1, mem_addr[19:0]}` (device region), `din32 = mem_wdata`,
grant ONLY in B_POST (after refresh_needed is serviced) or in B_IDLE behind
the existing `idle_cnt == IDLE_REFRESH_AFTER` guard; on
`data_ready`/write-complete flip `mem_done` toggle with `mem_rdata = dout32`.
One outstanding op; CPU traffic keeps absolute priority by construction.
The sim model `nds_mem_model.v` implements the identical contract with
randomized 4..40-cycle latency.

## 6. Simulation strategy (acceptance tests, spec section 9)

Models: `SD-FAT/sim/sd_card_model.v` (exists - CMD17/CMD24 with CRC, image
in/out, iverilog only); the C++ card model in
`fpga/tang-nano-20k/sd-fat-test/sim/test_sd_fat.cpp` (Verilator path,
reused); `SD-FAT/sim/nds_mem_model.v` (new) as the SDRAM stand-in for all
storage tbs - the REAL sdram18 chain is exercised separately at the bridge
level (step 9). Card images built by a `make_test_image.sh` variant creating
2-4 contiguous files with distinct patterns, plus one deliberately
fragmented file for the fatchk case. All tbs run `clk_cpu` and `clk_stor` at
DIFFERENT, non-integer-ratio frequencies (e.g. 23/27 MHz) to stress the CDC.

Split, following the sd-fat-test precedent (fast Verilator gate + registered
unit tbs; heavyweight iverilog full-system stays a manual target):

| Spec test | Vehicle | Tool | Registered as |
|---|---|---|---|
| 1 round-robin + integrity (2 clients) | `SD-FAT/sim/test_nd_storage.cpp` + `nd_storage_vtop.v` (tristate wrapper + C++ card + C++ mem model) | Verilator | `SD-FAT/sim :: test-storage` |
| 2 write-through + fsck recheck | same Verilator program: write block k, compare card-model memory AND mem-model word-for-word before `done` returns; Makefile runs `fsck.vfat -n` on the post-image | Verilator + fsck | part of `test-storage` |
| 3 concurrency, 4 clients, distinct patterns, no starvation/leak | same program, phase 3 | Verilator | part of `test-storage` |
| 4 tape adapter (stream/rewind/EOF) | `SD-FAT/sim/nd_storage_tape_tb.v` - adapter against a SCRIPTED client-port stub serving an array image (no SD, no SDRAM - pure unit tb) | iverilog | `SD-FAT/sim :: test-nds-tape` |
| 5 errors (range, injected write fail) | range-err asserted in the engine unit tb (below); write-fail injected via the C++ card model's error flag in `test-storage` (verify done+err, SDRAM word unchanged) | both | `test-nds-engine` + `test-storage` |
| 6 system: ND_FLOPPY_PIO through the full stack | `ND-BUS-DEVICES/FLOPPY/sim/nd_floppy_storage_tb.v`: ND_FLOPPY_PIO + nd_storage_floppy_adapter + nd_storage + sd_card_model (image with FLOPPY0.IMG) + nds_mem_model; drives the same iox_* sequences as the existing floppy tb (seek/read/write/read-back), compares against the card image | iverilog | `ND-BUS-DEVICES/FLOPPY/sim :: test-floppy-storage` |

Plus engine-level unit tbs that need no card: `nd_storage_cdc_tb.v` (word
bridge + toggle sync across skewed clocks, x1000 words, random stalls) and
`nd_storage_engine_tb.v` (arbiter order, read integrity from a preloaded
mem model, range err path; write path against the real sd_writer +
sd_card_model as in the existing `sd_writer_tb`). Every tb prints
`TB_RESULT: PASS` and is registered in `Verilog/tests/run_all_tests.sh`
(standing rule). A pure-iverilog full-system tb (`nd_storage_tb.v`,
mount + 2 opens + interleaved ops with tiny files, SIMULATE=1) exists as a
manual `test-system`-style target, mirroring the sd-fat-test arrangement.

## 7. Implementation order (one-session increments, each ends green)

1. **CDC primitives + word bridge.** `nds_sync.v`, the shared word bridge
   and one client FE skeleton; `nd_storage_cdc_tb.v` at 23/27 MHz.
   Register `SD-FAT/sim :: test-nds-cdc`.
2. **Mem model + engine read path.** `nds_mem_model.v`; `nd_storage_engine.v`
   with arbiter, pending latches, FEs, R_* states (open state forced by tb
   hierarchy); `nd_storage_engine_tb.v`: preload model, two clients
   interleaved reads, round-robin order, range->err with zero mem traffic.
   Register `test-nds-engine`.
3. **Engine write path.** Staging BRAM, W_* states, real sd_writer +
   sd_card_model on a raw image; verify card-first/SDRAM-second ordering and
   the wr_err -> SDRAM-intact path. Extend `test-nds-engine`.
4. **Mount + top.** `nd_storage_mount.v`, `nd_storage.v` (SD cores, pin mux,
   phase_write/reset ownership), features `SDFAT_STORAGE`; iverilog
   `nd_storage_tb.v` with a small 2-file FAT16 image: open both, verify
   SDRAM preload + size_bytes + open_err on missing/oversized file.
   Register `SD-FAT/sim :: test-nds-mount`.
5. **fatchk.** `nd_storage_fatchk.v` + fragmented-file image case ->
   open_err; contiguous -> open_ok. Extend `test-nds-mount`
   (SDFAT_STORAGE_CHECK on).
6. **Verilator system gate.** `nd_storage_vtop.v` + `test_nd_storage.cpp`
   (C++ card + mem models): acceptance 1, 2 (+fsck), 3, 5-inject in one
   program. Register `SD-FAT/sim :: test-storage`. This is the
   run-before-hardware gate.
7. **Tape adapter.** `nd_storage_tape_adapter.v` + `nd_storage_tape_tb.v`
   (acceptance 4: byte-compare, mid-stream rewind, EOF silence).
   Register `test-nds-tape`.
8. **Floppy adapter + system test 6.** `nd_storage_floppy_adapter.v` +
   `nd_floppy_storage_tb.v`. Register
   `ND-BUS-DEVICES/FLOPPY/sim :: test-floppy-storage`.
9. **Board glue.** sdram18 din32/dout32 edit, MEM_RAM_49_SDRAM device port +
   `ND_STORAGE_PARTITION` gating; extend
   `fpga/tang-nano-20k/sdram-bridge/sim` tb with concurrent CPU protocol
   traffic + device-port traffic, assert CPU N+4 deadline still met and
   device data intact. Existing registration
   `sdram-bridge/sim :: test` stays the gate. Baseline build with the
   define OFF must remain bit-identical.
10. (Hands off to the device workstream: Tang top instantiation of
    nd_storage + ND_TAPE_400/ND_FLOPPY_PIO behind ND120_VERILOG_DEVICES,
    per device-bus-todo Phase 2/3 - not part of this library plan.)

Risks to keep visible: (a) the BANK1 partition halves ND main memory to
2 MB on Tang when storage is enabled - flag to the owner, it is the only
option that doesn't touch parity semantics; (b) spec's 2 MB floppy slot
default is board-overridden to 1.25 MB here; (c) block read latency is
~0.5-1 ms (CDC word handshake), not "microseconds" as the spec's rationale
sketches - still far inside all device budgets, with a documented pipelining
hook if it ever matters.

---

### Critical Files for Implementation
- /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/docs/nd-storage-interface-spec.md (binding contract: ports, handshake, tests)
- /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/sd-fat-test/src/sd_fat_test_top.v (proven reader/writer pin-mux, park/re-init, geometry-latch and watchdog patterns to lift)
- /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/SD-FAT/circuit/sd_file_reader.v (mount source: target_name port, geometry/first-sector exports, outen/outbyte stream semantics)
- /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/SD-FAT/circuit/sd_writer.v (write-through engine contract: start/busy/done/err, registered rd_addr/rd_data timing)
- /mnt/e/Dev/Repos/Ronny/nd-120/Verilog/fpga/tang-nano-20k/sdram-bridge/MEM_RAM_49_SDRAM.v (device-port + partition edits; B_POST/idle grant slots)

# ILA probe semantics on the ND-120 (Nexys 4 DDR)

Last verified: 24-AUG-2026, during the LIST-FILE-NAMES campaign. Every rule
below was learned by producing a WRONG root cause first. Read this before
interpreting any capture.

Flow files: `fpga/nexys4ddr/build.tcl` (`-tclargs ila`, define
`ND120_ILA_MARK_DEBUG`), `fpga/nexys4ddr/ila_capture.tcl` (capture modes).

## What the address probes actually show

- **`s_ica_15_0` (CGA_MAC effective address) is EVERY memory access, not
  the fetch stream.** Instruction fetches, operand reads, operand writes,
  and pipeline transients all appear. A single-sample ICA value is
  usually a transient (measured: instruction words like `0xBA15` appear
  on ICA during JPL execution). Trust multi-sample dwells (5+); never
  build a story on a 1-sample hit.
- **`CSA_12_0` flickers between microinstructions.** The flicker has the
  measured form `{3'b111, ICA[9:0]}` - values 0o16000-0o17777 are NEVER
  real microaddresses (the microcode ends at 0o012513). The 23-AUG
  "CPU executes text at 0o016004" theory was built entirely on this
  flicker.
- **The CSV columns skew by 1-2 samples** relative to each other. Pairing
  "address at row N with data at row N" mis-attributes reads. For
  read/write truth use the RAM-port probes (`s_ila_ram_addr/wr/wdata` in
  `MEM_RAM_49_BLOCKRAM.v`) - they are one clean registered domain.
- **`s_cd_15_0` carries memory read data at the strobe** and junk between
  strobes. The delivered value is the one held for several samples.

## Capture-flow rules

- **The `.ltx` must match the bitstream ON THE BOARD.** A background build
  finishing overwrites `nd120_nexys4ddr.bit/.ltx`; arming with a
  mismatched ltx yields garbage triggers and empty uploads. Save every
  probe revision as `nd120_nexys4ddr_ila_vN.bit/.ltx` and never capture
  while a build is in its write-out phase.
- **`wait_on_hw_ila -timeout` is in MINUTES.** On timeout it can RETURN
  normally with an empty buffer: a 2-line csv means NO TRIGGER, not a
  capture.
- **JTAG TCK must be 5 MHz** (`PARAM.FREQUENCY 5000000`) or uploads
  corrupt (Labtools 27-3312).
- `get_nets -hier <pattern>` matches the LEAF name only - a pattern
  containing `/` never matches. Select marked nets with
  `-filter {MARK_DEBUG && NAME =~ <glob>}`; `[` opens a character class
  in the glob, so match bus base names as substrings.
- Basic-mode triggers AND across probes; per-bit don't-cares
  (`eq16'bX0XX_...`) work. An OE-gated bus reads 0 when idle - a
  "bit==0" compare fires on idle unless ANDed with the enable.
- A 4096-sample window at 16.67 MHz is 246 us. One 9600-baud character
  is 1.04 ms. A window cannot bridge printed output; use BASIC capture
  mode with a `CAPTURE_COMPARE_VALUE` qualifier (e.g. store only RAM
  writes) to stretch the window over seconds.

## Probe inventory (ILA v8, `nd120_nexys4ddr_ila_v8.bit/.ltx`)

CSA_12_0 (10 hierarchy aliases), cpu_txd, CGA_MAC `s_cd_15_0` /
`s_ica_15_0` / `s_la_23_10_out`, IO_UART_42 `s_io_idb_15_0_out` /
`s_tbmt_n` / `s_clk_en` / `s_eiorn_n`, device chain `s_dev_iox_*` /
`s_dev_int_pending` / IDENT seam, WRF `s_reg14_r6_15_0` + write port,
RAM write port `s_ila_ram_addr/wr/wdata`.

## Machine-behavior baselines (measured, for comparison)

- Healthy console print: next char starts ~10 us after TBMT ready;
  ~60 busy-polls per character at 9600.
- IOR word at rest: `0x7818` (TBMT ready, no char); with a char pending:
  bit14=0; during TX: bit15=1.
- A standing level-11 `s_dev_int_pending` at idle is NORMAL (FILSYS
  completes floppy ops by status polling; the last interrupt stays
  pending unserviced).

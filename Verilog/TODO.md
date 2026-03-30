# ND-120 Verilog TODO

> Last updated: 29-MAR-2026

---

## High Priority

> Items that may affect self-test failures (7/14 tests currently fail)

### CPU_15: IDB output assignment

Add assign of IDB out of `CPU_15` based on IDB out from PROC or CS. Also validate:

- `s_rt_n` -- also output from `CPU_PROC_32`. Verify which source to use (PROC or PCB top module).
- `s_rwcs_n` -- also output from `CPU_PROC_32`. Same question.

**File**: `CPU-BOARD-3202/circuit/CPU_15.v`

### CPU_15: MMU/LAPA/STOC validation

Previously marked as fixed but needs double-checking. IN/OUT signal assignments must be validated.

**File**: `CPU-BOARD-3202/circuit/CPU_15.v`

### AM29833A: Parity and error not implemented

Error flag and parity output are hardcoded:

```verilog
assign ERR_n = 1;    // Should detect parity errors
assign PAR_OUT = 0;  // Should compute parity
```

This affects parity error testing and may cause self-test failures.

**File**: `Shared/support/AM29833A.v`

---

## Medium Priority

### CPU_MMU_WCA_31: WCA_n polarity check

Should `WCA_n` be switched in this assignment?

```verilog
assign PPN_23_10 = WCA_n ? 14'b0 : CPN_23_10;
```

**File**: `CPU-BOARD-3202/circuit/CPU_MMU_WCA_31.v`

### 3-state outputs: Verify all return 0 not z

For FPGA, tri-state (`z`) doesn't work internally. Check that all "3-state" buffers output `0` when disabled, not `z`.

**Relevant modules**: `TTL_74245`, `TTL_74244`, `TTL_74241`, `AM29841`, `AM29861A`

### Search for `TODO:` in code

Periodic cleanup -- grep for `TODO:` comments and address remaining items.

---

## Low Priority

### CGA/MAC and CGA_MAC_FASTADD: Unit tests

No dedicated unit tests. CPU self-test exercises these through the ALU path. Lower priority unless specific MAC bugs found.

### Tang Nano: SPI flash for microcode ROM

Gowin project has `` `ifdef GOWIN `` placeholder in `CPU_CS_PROM_19.v` but no SPI flash implementation yet. Needed for Tang Nano deployment.

**File**: `CPU-BOARD-3202/circuit/CPU_CS_PROM_19.v`

### MEM_ADDR_44: Add test code

No dedicated test. Works in full sim.

**File**: `CPU-BOARD-3202/circuit/MEM_ADDR_44.v`

### MEM_RAM_49: Refactor DD_17_0 signals for hardware

RAM works in simulation. For real FPGA hardware, the `DD_17_0` IN/OUT signals may need refactoring depending on memory type.

**File**: `CPU-BOARD-3202/circuit/MEM_RAM_49.v`

---

## Completed

| Item | Status |
|------|--------|
| `s_logisimNet`/`s_logisimBus` cleanup | Done -- dead PFIFC/PFIFD files deleted |
| BusDriver16 | Validated working |
| Static/Dynamic RAM refactoring for FPGA | IDT6168A BRAM fix done |
| Bus Connectors A-B-C | All connected in ND3202D |
| `s_acond_n` | Connected from `CGA_MIC_CONDREG` (was hardcoded to 1) |
| `s_brk_n` | Connected through CGA TRAP/INTR path |
| `s_inr_7_0` | Connected from `installation_number` via `INR_7_0` port |
| MEM_ADEC_45, MEM_DATA_46, MEM_LBDIF_48 | Logisim naming cleaned up |
| MEM_RAMC_50 | PAL chips connected |
| Latch-to-FF migration | Complete -- see `verilog-remove-latch.md` |
| LINT and latches | All latches converted to FFs with ifdef guards |
| CPU_15 "disconnected" signals | Verified: `s_eccr` -> MEM_43, `s_ioni` -> IO_37, `s_rrf_n` -> CYC_36, `s_mreq_n` is input from CYC_36. All properly connected. |

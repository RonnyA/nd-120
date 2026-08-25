# IDB (Internal Data Bus) Deep Analysis — ND-120 CPU Verilog

> Generated: 2026-04-06  
> Purpose: Pre-refactoring reference — "before state" for sysclk clocking changes  
> Rule: ALL values in octal. Never hex.

---

## 1. BUS SIGNAL NAMES BY HIERARCHY LEVEL

### CGA (CPU Gate Array) internal
- `s_FIDBO_15_0` — FIDBO output (ORed: ALU + IDBCTL), `CGA.v:606`
- `s_FIDBI_15_0` — FIDBI input (from IDBCTL), `CGA.v`
- `s_alu_IDB_15_0_OUT` — ALU → FIDBO contribution
- `s_idbctl_IDB_15_0_OUT` — IDBCTL → FIDBI/FIDBO contribution
- `s_xfidbi_15_0` — External XFIDB after BusDriver16

### CPU Board (ND3202D) level
- `s_cpu_idb_15_0_in` / `s_cpu_idb_15_0_out` — CPU/CGA ↔ main bus
- `s_io_idb_15_0_out` — IO_37 → main bus
- `s_mem_idb_15_0_out` — MEM_43 → main bus
- `s_bif_idb_15_0_out` — BIF_5 → main bus

### DGA (Decode Gate Array) level
- `s_idb_7_0_in` — DGA input (8-bit lower)
- `IDB_15_0_OUT` — DGA output (UART | PANCAL | REG | DCD)

---

## 2. IDB SOURCES (DRIVERS)

### A. CGA_ALU — ALU output mux
- **File**: `DELILAH-CPU/CGA_ALU/circuit/CGA_ALU.v`, `CGA_ALU_OUTMUX_IDBS.v`
- **Output**: `FIDBO_15_0_OUT` (16-bit, **inverted**: `= ~s_g_15_0`)
- **Enable**: `CSIDBS_4_0[4:0]` selects one of 8 sources per bit via `ND38GLP` decoders
- **Clock**: `ALUCLK` clocks `CSIDBS[2]` DFF that gates the mux (`CGA_ALU.v:196`); mux output itself is combinatorial
- **Sources selected by CSIDBS**:
  - BMG = B-register sign extension
  - DBR = Data Buffer Register
  - ARG = Argument register
  - STS = Status register
  - SWAP = Swap register
  - FIDB = FIDBI feedback (loopback)
  - GPR = General Purpose Registers (L/H/S)

### B. CGA_IDBCTL — IDB control mux
- **File**: `DELILAH-CPU/CGA_IDBCTL/circuit/CGA_IDBCTL.v`, `CGA_IDBCTL_SEL6.v`
- **Output**: `FIDBI_15_0_OUT` (16-bit, 16× `CGA_IDBCTL_SEL6` one per bit)
- **Enable per bit**: 6-input OR of {ED, EM, EV, ES, EPCR, EPGS} enables
- **Type**: Fully combinatorial mux — no clock on the output logic
- **PGS sub-register**: `CGA_IDBCTL_PGSREG` captures `LA_21_10` on **MCLK** rising edge (`SCAN_FF` × 14, `CGA_IDBCTL_PGSREG.v:65-190`)

### C. IO_37 — IO module output OR
- **File**: `CPU-BOARD-3202/circuit/IO_37.v:281-285`
- **Output**: `IDB_15_0_OUT` (16-bit OR):
  ```verilog
  assign IDB_15_0_OUT =
      s_idb_15_0_uart_out   |   // CSIDBS=EIORN (o20)
      s_idb_15_0_pancal_out |   // Panel/Calendar
      s_idb_15_0_reg_out    |   // TRAALD_n (o32) or RINRN (o23)
      {8'b0, s_idb_7_0_dcd_out}; // DCD lower 8-bit
  ```
- **Submodule clocks**: UART (IO_UART_42: internal UART clock), PANCAL (IO_PANCAL_40: RTC), REG: see section D below
- **DCD contribution**: combinatorial from DECODE_DGA

### D. IO_REG_41 — ALD / INR / IOC registers
- **File**: `CPU-BOARD-3202/circuit/IO_REG_41.v`
- **ALD register (TTL_74244)**: tristate buffer, enable = `TRAALD_n` (active low), **combinatorial output** (`line 187`)
- **INR**: `assign s_idb_7_0_inr_out = s_rinr_n ? 8'b0 : s_inr_7_0;` — combinatorial mux (`line 178`)
- **IOC register output** (`s_idb_15_0_reg_out`): `s_idb_15_0_ald_out | s_idb_7_0_inr_out` (`line 181-182`)
- **IOC register input**: `s_ioc_idb_7_0_in = s_idb_7_0_in | s_idb_7_0_inr_out | s_idb_15_0_ald_out` (`line 116`)
- **IOC write clock**: `TTL_74273 CHIP_28A_IOC`, clock = `~s_sioc_n` (`line 160`) — **clocked by inverted SIOC_n**

### E. MEM_43 — Memory read data
- **File**: `CPU-BOARD-3202/circuit/MEM_43.v`
- **Output**: `IDB_15_0_OUT` — memory read data
- **Clock**: internal memory control signals

### F. BIF_5 — Bus interface
- **File**: `CPU-BOARD-3202/circuit/BIF_5.v`
- **Output**: `IDB_15_0_OUT`
- **Clock**: internal BIF control

---

## 3. IDB DESTINATIONS (READERS/WRITERS)

### A. CGA_ALU input
- **File**: `DELILAH-CPU/CGA_ALU/circuit/CGA_ALU.v`
- **Input**: `FIDBI_15_0` → ALU A/B operand selection (combinatorial)
- **No clock on input path** — used directly in ALU operations

### B. CGA_IDBCTL PGS register
- **File**: `CGA_IDBCTL_PGSREG.v:65-190`
- **Register**: `SCAN_FF` × 14 bits
- **Data in**: `LA_21_10` (address bus)
- **Clock**: **MCLK** rising edge
- **Enable**: `VACC = ~VACCN` (test enable)
- **Latency**: 1 MCLK cycle before new PGS value affects IDBCTL output

### C. IOC register in IO_REG_41
- **File**: `CPU-BOARD-3202/circuit/IO_REG_41.v:159-174`
- **Register**: `TTL_74273 CHIP_28A_IOC`
- **Data in**: `s_ioc_idb_7_0_in[7:0]` (IDB[7:0] | INR | ALD merged)
- **Clock**: `~s_sioc_n` (inverted SIOC_n) — **NOT ALUCLK or MCLK**
- **Clear**: `CLR_n` (asynchronous active low)
- **Outputs**: interrupt enables (BINT10/12/13), CONSOLE_n, EMCL_n, LED, reset

### D. DGA IDBS registered outputs
- **File**: `DECODE-GateArray/DGA/circuit/DECODE_DGA_IDBS.v:502-569`
- **Register**: `F924` × 3 (4-bit shift register latches)
- **Clock0** (line 540): ECSRN, EIORN, EPESN, EPEAN
- **Clock1** (line 523): EPANSN, RINRN, EPANN, TRAALD_n
- **Latency**: 1 CLK0/CLK1 cycle before new CSIDBS decode affects IO enables

### E. CPU input bus (ND3202D)
- **File**: `CPU-BOARD-3202/circuit/ND3202D.v:465-466`
- CPU sees: `s_cpu_idb_15_0_in = s_bif_idb_15_0_out | s_io_idb_15_0_out | s_mem_idb_15_0_out`
- IO_37 sees: `s_io_idb_7_0_in = s_bif[7:0] | s_cpu[7:0] | s_mem[7:0]`

---

## 4. OR-LOGIC TREES (SHARED BUS — CURRENT STATE)

All of these should eventually become IDBS-controlled muxes:

| Location | Signal | Sources (OR'd together) |
|----------|--------|-------------------------|
| `ND3202D.v:518` | main IDB | BIF \| IO \| MEM \| CPU |
| `ND3202D.v:465` | cpu_idb_in | BIF \| IO \| MEM |
| `ND3202D.v:466` | io_idb_7_0_in | BIF[7:0] \| CPU[7:0] \| MEM[7:0] |
| `CGA.v:606` | FIDBO | ALU_OUT \| IDBCTL_OUT |
| `IO_37.v:281` | io_idb_out | UART \| PANCAL \| REG \| DCD[7:0] |
| `IO_REG_41.v:116` | ioc_data_in | IDB[7:0] \| INR \| ALD |
| `IO_REG_41.v:181` | reg_idb_out | ALD \| INR |

---

## 5. CSIDBS DECODE MAP (from DECODE_DGA_IDBS.v)

| CSIDBS (octal) | Decimal | Active enable | Source |
|----------------|---------|---------------|--------|
| o00–o17 range | 0–15 | EDON | ALU/IDBCTL (all "data out") |
| o20 | 16 | EIORN | IO Register / UART |
| o23 | 19 | RINRN | INR (Installation Number Register) |
| o24 | 20 | EPANSN | Panel Status |
| o32 | 26 | TRAALD_n | ALD register |
| o35 | 29 | EPANN | Panel Interrupt Vector |
| o37 | 31 | RUARTN | UART (explicit) |
| o30 | 24 | ECSRN | Cache Status Register |

---

## 6. CLOCKS THAT GATE IDB WRITES INTO REGISTERS

| Clock | Source | Modules affected | Notes |
|-------|--------|-----------------|-------|
| **ALUCLK** | CYC_36.v | CGA_ALU (GPR, STS, CSIDBS[2] DFF) | ~1 µs per step |
| **MCLK** | CYC_36.v | CGA_IDBCTL_PGSREG (PGS register) | ~5 µs per step |
| **SIOC_n** | Internal IO | IO_REG_41 CHIP_28A_IOC | Unrelated to ALUCLK/MCLK |
| **CLK0** | DGA | DECODE_DGA_IDBS (ECSRN, EIORN, EPESN, EPEAN) | DGA registered outputs |
| **CLK1** | DGA | DECODE_DGA_IDBS (EPANSN, RINRN, EPANN, TRAALD_n) | DGA registered outputs |

---

## 7. CROSS-DOMAIN HAZARDS (relevant for sysclk refactor)

1. **PGS → IDBCTL path spans MCLK/ALUCLK boundary**: PGS is written on MCLK but read combinatorially in IDBCTL for FIDB output. Any change to MCLK timing affects when new PGS values become visible on FIDB.

2. **CSIDBS[2] DFF (ALUCLK) → ALU output mux**: The DFF at `CGA_ALU.v:196` holds IDBS[2] across a clock edge. Changing to sysclk changes the sample point.

3. **SIOC_n is self-clocking** (from IO state machine): Not ALUCLK-derived. Synchronizing IOC writes to sysclk requires understanding the SIOC_n generation logic.

4. **DGA CLK0/CLK1**: These clock the CSIDBS decode output registers. Must stay coherent with CSIDBS microcode field timing.

5. **No explicit cross-domain synchronizers exist**: The design assumes all clocks are phase-aligned (they all come from the same oscillator divided down). Changing individual modules to sysclk breaks this assumption unless all modules are migrated simultaneously.

---

## 8. FILE LOCATIONS (full paths)

| Module | Full path |
|--------|-----------|
| CGA top | `Verilog/DELILAH-CPU/CGA/circuit/CGA.v` |
| CGA_ALU | `Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_ALU.v` |
| CGA_ALU_OUTMUX_IDBS | `Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_ALU_OUTMUX_IDBS.v` |
| CGA_IDBCTL | `Verilog/DELILAH-CPU/CGA_IDBCTL/circuit/CGA_IDBCTL.v` |
| CGA_IDBCTL_SEL6 | `Verilog/DELILAH-CPU/CGA_IDBCTL/circuit/CGA_IDBCTL_SEL6.v` |
| CGA_IDBCTL_PGSREG | `Verilog/DELILAH-CPU/CGA_IDBCTL/circuit/CGA_IDBCTL_PGSREG.v` |
| ND3202D (CPU board top) | `Verilog/CPU-BOARD-3202/circuit/ND3202D.v` |
| CPU_PROC_CGA_33 | `Verilog/CPU-BOARD-3202/circuit/CPU_PROC_CGA_33.v` |
| IO_37 | `Verilog/CPU-BOARD-3202/circuit/IO_37.v` |
| IO_REG_41 | `Verilog/CPU-BOARD-3202/circuit/IO_REG_41.v` |
| IO_UART_42 | `Verilog/CPU-BOARD-3202/circuit/IO_UART_42.v` |
| IO_PANCAL_40 | `Verilog/CPU-BOARD-3202/circuit/IO_PANCAL_40.v` |
| BIF_5 | `Verilog/CPU-BOARD-3202/circuit/BIF_5.v` |
| MEM_43 | `Verilog/CPU-BOARD-3202/circuit/MEM_43.v` |
| DECODE_DGA | `Verilog/DECODE-GateArray/DGA/circuit/DECODE_DGA.v` |
| DECODE_DGA_IDBS | `Verilog/DECODE-GateArray/DGA/circuit/DECODE_DGA_IDBS.v` |

---

## 9. PLAN FOR SYSCLK REFACTOR — BEFORE/AFTER CONTROL STRATEGY

### Before state (current):
- Each register uses its own domain clock (ALUCLK, MCLK, SIOC_n, CLK0, CLK1)
- OR-bus logic, no mux control
- Combinatorial paths from IDB drivers to receivers

### Proposed after state:
- All clocked elements use `posedge sysclk` with `if (original_clock_condition)`
- OR-bus at ND3202D/IO_37 replaced with CSIDBS-controlled case mux
- All latches converted to posedge FF + enable

### Safe migration order (to be decided by user):
1. Instrument/snapshot current signal values at key nodes (GTKWave .gtkw)
2. Migrate one module at a time, re-run sim after each change
3. Compare VCD outputs before/after each change
4. Rollback: git stash / feature branch per module change

### Key signals to monitor in GTKWave for regression:
- `s_cpu_idb_15_0_out` vs `s_cpu_idb_15_0_in` timing
- `s_FIDBO_15_0` vs `s_FIDBI_15_0`
- `ALUCLK`, `MCLK`, `SIOC_n` relative phases
- `CSIDBS_4_0` active value per clock cycle
- `s_idb_15_0_*_out` from each source — verify only one non-zero per cycle

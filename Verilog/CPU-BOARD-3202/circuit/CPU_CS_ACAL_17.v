/**************************************************************************
** ND120 CPU, MM&M                                                       **
** CPU/CS/ACAL                                                           **
** MICRO ADDR CALC UNIT                                                  **
** SHEET 17 of 50                                                        **
**                                                                       **
** Last reviewed: 6-APR-2025                                             **
** Ronny Hansen                                                          **
***************************************************************************/


module CPU_CS_ACAL_17 (
    input         sysclk,   //! FPGA system clock — used for latch-equivalent FFs
    input         CLK,
    input  [12:0] CSA_12_0,
    input  [ 9:0] CSCA_9_0,
    input         MACLK,
    input         PD1,
    output [12:0] LUA_12_0,
    output [11:0] UUA_11_0
);

  /*******************************************************************************
   ** The wires and registers are defined here                                   **
   *******************************************************************************/

  // MACLK is the MICRO-ADDRESS LATCH STROBE - the latch enable for these
  // chips, and their ONLY clock. It is not a "memory access clock"; these
  // latches are its only consumer on the whole board. Confirmed against the
  // drawing (08-AUG-2026): CHIP_31F pin LE = MACLK, CHIP_30H pin C = MACLK,
  // and both output enables (/OE, /OC) = PD1. See PAL_44307C.v for the
  // equation and the naming note.
  //
  // Original chips (74373, AM29841) are TRANSPARENT LATCHES with enable.
  // When enable (MACLK) = 1: output follows input (transparent, ZERO latency).
  // When enable = 0: output holds last value (latch).
  // The capture is therefore MACLK's FALLING edge.
  //
  // CORRECTION (08-AUG-2026): the line that used to sit here claimed "during
  // execution, MACLK = 1 always (TERM_n=0), so LUA = CSA with no delay". That
  // is WRONG and was never measured. MACLK pulses once per microcycle - the
  // PAL_44307C equation asserts it only for MAP, TRAP and RWCS cases, and the
  // board's MACLK = ~(TERM_n & MACLK_n) adds only TERM. Measured in the
  // waveform, MACLK goes low mid-cycle on ordinary microwords. LUA does still
  // need to track CSA with ZERO latency while MACLK is high (see below) - that
  // part of the reasoning stands - but not because MACLK is permanently high.
  // LUA is the WCS control-store READ ADDRESS and feeds the WCS BRAM
  // combinationally, so LUA MUST track CSA with zero latency - on a microcode
  // JUMP the target's microword must be read the same cycle the address changes.
  //
  // BOTH build modes now implement the TRANSPARENT latch:
  //  - VERILATOR_SIM: always @(*) latch (matches real hardware).
  //  - FPGA (else):   synthesizable transparent latch = mux + hold-FF
  //                   (Shared/ndlib/LATCH.v pattern), ZERO latency, no inferred latch.
  // HISTORY: the FPGA branch was previously a plain posedge FF+CE that lagged
  // LUA by 1 cycle. That lag corrupted CSBITS on JUMPs and was the Tang Nano 20K
  // boot hang (wedge at microcode 06000 = STZ->CONT). Root-caused + fixed 19-JUL;
  // the old "1-cycle lag acceptable / ILA-confirmed" claim was WRONG.
  // Regression tests: sim/CPU_CS_ACAL_17_tb.v (asserts zero-latency transparency).

  reg [7:0]  s_q_chip30h_7_0;  // CHIP_30H: LUA[12:10], UUA[11:10]
  reg [9:0]  s_lua_9_0;        // CHIP_31F: LUA[9:0]
  reg [9:0]  s_uua_32g_9_0;   // CHIP_32G: UUA[9:0] when lua12=1
  reg [9:0]  s_uua_31g_9_0;   // CHIP_31G: UUA[9:0] when lua12=0

  wire [12:0] s_lua;
  wire [11:0] s_uua;
  wire [ 9:0] s_csca_9_0;
  wire [12:0] s_csa_12_0;
  wire [ 7:0] s_d_chip30h_7_0;
  wire        s_lua12;
  wire        s_lua12_n;
  wire        s_pd1;
  (* mark_debug = "true", DONT_TOUCH = "true" *) wire s_maclk;
  wire        s_clk;

  /*******************************************************************************
   ** Wiring                                                                     **
   *******************************************************************************/

  // LUA[12:10] from CHIP_30H registered output
  assign s_lua[12] = s_pd1 ? 1'b0 : s_q_chip30h_7_0[0];
  assign s_lua[11] = s_pd1 ? 1'b0 : s_q_chip30h_7_0[1];
  assign s_lua[10] = s_pd1 ? 1'b0 : s_q_chip30h_7_0[2];

  // LUA[9:0] from CHIP_31F registered output
  assign s_lua[9:0] = s_pd1 ? 10'b0 : s_lua_9_0;

  // UUA[11:10] from CHIP_30H registered output
  assign s_uua[11] = s_pd1 ? 1'b0 : s_q_chip30h_7_0[5];
  assign s_uua[10] = s_pd1 ? 1'b0 : s_q_chip30h_7_0[6];

  // UUA[9:0]: CHIP_32G when lua12=1, CHIP_31G when lua12=0
  assign s_uua[9:0] = s_lua12 ? s_uua_32g_9_0 : s_uua_31g_9_0;

  // CHIP_30H D inputs (same logic as original)
  assign s_d_chip30h_7_0[0] = s_csa_12_0[12];
  assign s_d_chip30h_7_0[1] = s_csa_12_0[11];
  assign s_d_chip30h_7_0[2] = s_csa_12_0[10];
  assign s_d_chip30h_7_0[3] = 1'b0;  // not used
  assign s_d_chip30h_7_0[4] = 1'b0;  // not used
  assign s_d_chip30h_7_0[5] = s_csa_12_0[11] | s_lua12_n;
  assign s_d_chip30h_7_0[6] = s_csa_12_0[10] | s_lua12_n;
  assign s_d_chip30h_7_0[7] = 1'b0;

  assign s_lua12   = s_lua[12];
  assign s_lua12_n = ~s_lua12;

  // Unused CHIP_30H bits — keep for linter
  (* keep = "true", DONT_TOUCH = "true" *) wire [2:0] unused_CHIP30h_bits;
  assign unused_CHIP30h_bits = {s_q_chip30h_7_0[7], s_q_chip30h_7_0[4], s_q_chip30h_7_0[3]};

  /*******************************************************************************
   ** Inputs / Outputs                                                           **
   *******************************************************************************/
  assign s_csca_9_0  = CSCA_9_0;
  assign s_csa_12_0  = CSA_12_0;
  assign s_pd1       = PD1;
  assign s_maclk     = MACLK;
  assign s_clk       = CLK;

  assign LUA_12_0    = s_lua[12:0];
  assign UUA_11_0    = s_uua[11:0];

  /*******************************************************************************
   ** Latch logic — transparent latch (sim) vs posedge FF+CE (FPGA)             **
   *******************************************************************************/

`ifdef VERILATOR_SIM
  // True transparent latch behavior matching original chips.
  // always @(*) + conditional assign = transparent when enable=1, holds when 0.
  // Required so LUA = CSA with zero latency while MACLK is high.
  // Without this, LUA lags CSA by 1 sysclk causing stale CSBITS on 1-cycle steps.

  // CHIP_30H: 74373 transparent latch, enable=MACLK
  always @(*) begin
    if (s_maclk) s_q_chip30h_7_0 = s_d_chip30h_7_0;
  end

  // CHIP_31F: AM29841 transparent latch, enable=MACLK
  always @(*) begin
    if (s_maclk) s_lua_9_0 = s_csa_12_0[9:0];
  end

  // CHIP_32G: AM29841 transparent latch, enable=MACLK && lua12
  always @(*) begin
    if (s_maclk && s_lua12) s_uua_32g_9_0 = s_csa_12_0[9:0];
  end

  // CHIP_31G: AM29841 transparent latch, enable=CLK && !lua12
  always @(*) begin
    if (s_clk && ~s_lua12) s_uua_31g_9_0 = s_csca_9_0[9:0];
  end

`else
  // FPGA mode: SYNTHESIZABLE TRANSPARENT LATCH = mux + hold-FF (the sanctioned
  // Shared/ndlib/LATCH.v pattern), NOT a plain posedge FF.
  //
  // ROOT CAUSE FIX (19-JUL, Tang boot hang): the previous `posedge sysclk`
  // FF+CE version lagged LUA (the WCS control-store READ ADDRESS) by 1 cycle.
  // LUA is combinational into the WCS BRAM, so on a microcode JUMP (e.g. STZ at
  // 06000 -> CONT at 0145) LUA held the stale address for a cycle and the WCS
  // returned the WRONG microword; the sequencer then computed a garbage jump
  // target (measured on silicon: CSBIT_11_0=0xC00 = the address, s_jmpaddr=
  // 16000 instead of 0145) and wedged at 06000 forever. The transparent latch
  // (LUA follows CSA with ZERO latency while MACLK=1, exactly as the original
  // 74373/AM29841 chips and the VERILATOR_SIM path above) removes the lag.
  // The hold-FF captures on posedge sysclk when enable is high; the output mux
  // is transparent when enable is high, held otherwise -> no inferred latch.

  reg [7:0] r_chip30h_hold;
  reg [9:0] r_lua_9_0_hold;
  reg [9:0] r_uua_32g_hold;
  reg [9:0] r_uua_31g_hold;

  // CHIP_30H: 74373 transparent latch, enable=MACLK
  always @(posedge sysclk) if (s_maclk) r_chip30h_hold <= s_d_chip30h_7_0;
  always @(*) s_q_chip30h_7_0 = s_maclk ? s_d_chip30h_7_0 : r_chip30h_hold;

  // CHIP_31F: AM29841 transparent latch, enable=MACLK
  always @(posedge sysclk) if (s_maclk) r_lua_9_0_hold <= s_csa_12_0[9:0];
  always @(*) s_lua_9_0 = s_maclk ? s_csa_12_0[9:0] : r_lua_9_0_hold;

  // CHIP_32G: AM29841 transparent latch, enable=MACLK && lua12
  always @(posedge sysclk) if (s_maclk && s_lua12) r_uua_32g_hold <= s_csa_12_0[9:0];
  always @(*) s_uua_32g_9_0 = (s_maclk && s_lua12) ? s_csa_12_0[9:0] : r_uua_32g_hold;

  // CHIP_31G: AM29841 transparent latch, enable=CLK && !lua12
  always @(posedge sysclk) if (s_clk && ~s_lua12) r_uua_31g_hold <= s_csca_9_0[9:0];
  always @(*) s_uua_31g_9_0 = (s_clk && ~s_lua12) ? s_csca_9_0[9:0] : r_uua_31g_hold;

`endif

endmodule

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

  // Original chips (74373, AM29841) are TRANSPARENT LATCHES with enable.
  // When enable (MACLK) = 1: output follows input (transparent).
  // When enable = 0: output holds last value (latch).
  // During execution, MACLK = 1 always (TERM_n=0), so LUA = CSA with no delay.
  //
  // VERILATOR_SIM mode: true transparent latch via always at(*) - matches real hardware.
  // This is necessary to avoid a 1-cycle LUA lag that corrupts CSBITS on jumps.
  //
  // FPGA mode: posedge FF+CE - synthesizable equivalent (1-cycle latency acceptable
  // because FPGA build confirmed correct by ILA measurement).

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
  // Required so LUA = CSA with zero latency during execution (MACLK=1 always).
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
  // FPGA mode: posedge FF+CE (standard synthesizable pattern, no inferred latches).
  // 1-cycle LUA lag is acceptable on FPGA because each step spans many clock cycles.

  // CHIP_30H equivalent: 74373 transparent latch → posedge FF+CE
  always @(posedge sysclk) begin
    if (s_maclk) s_q_chip30h_7_0 <= s_d_chip30h_7_0;
  end

  // CHIP_31F equivalent: AM29841 → posedge FF+CE
  always @(posedge sysclk) begin
    if (s_maclk) s_lua_9_0 <= s_csa_12_0[9:0];
  end

  // CHIP_32G equivalent
  always @(posedge sysclk) begin
    if (s_maclk && s_lua12) s_uua_32g_9_0 <= s_csa_12_0[9:0];
  end

  // CHIP_31G equivalent
  always @(posedge sysclk) begin
    if (s_clk && ~s_lua12) s_uua_31g_9_0 <= s_csca_9_0[9:0];
  end

`endif

endmodule

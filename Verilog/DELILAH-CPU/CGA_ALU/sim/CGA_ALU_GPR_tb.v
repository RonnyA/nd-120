/**************************************************************************
** ND120 CGA (CPU Gate Array / DELILAH)                                  **
** CGA_ALU_GPR testbench                                                 **
**                                                                       **
** Verification of the 16-bit GPR shift register (drawing page 50).      **
**                                                                       **
** Reference model source: READ FROM THE NETLIST                         **
** (Verilog/DELILAH-CPU/CGA_ALU/circuit/CGA_ALU_GPR.v), not from any     **
** drawing or ND documentation. Every MUX41P instance in that file was   **
** transcribed by hand into the per-bit map below, so a single wrong     **
** D0/D1/D2/D3 pin in the netlist shows up as a failing bit.             **
**                                                                       **
** MUX41P select is {B,A} = {GPRC_2_0[1], GPRC_2_0[0]} (A is the LSB),   **
** so with SEL = GPRC_2_0[1:0] and Q = the current GPR value:            **
**   SEL=0 : bit n <= FIDBO_15_0[n]            (parallel load, FIDBO)    **
**   SEL=1 : bit n <= CD_15_0[n]               (parallel load, CD)       **
**   SEL=2 : bit n <= Q[n+1], bit15 <= 0       (shift toward LSB, 0 in)  **
**   SEL=3 : bit n <= Q[n-1], bit0  <= GPRLI   (shift toward MSB, LI in) **
** GPRC_2_0[2] is the SCAN_FF TE with TI=Q on every bit, i.e. a HOLD     **
** that overrides SEL completely.                                        **
**                                                                       **
** Bit 0 is NOT a SCAN_FF: it is D_FLIPFLOP_EN MEMORY_1 whose *qBar*     **
** drives GPR_15_0[0] and whose d is DGPR0N, with MUX21LP GPR0M21        **
** (S=GPRC_2_0[2]) doing the hold. Net effect on GPR_15_0[0] is the same **
** as the other bits; the visible extra is the combinational output      **
**   DGPR0N = ~( GPRC_2_0[2] ? Q[0] : next-bit0 )                        **
** i.e. DGPR0N shows the inverted *next* bit-0 value while loading and   **
** the inverted *current* bit-0 value while holding. That asymmetry is   **
** CHARACTERISED here (recorded as what the RTL does) - no drawing was   **
** consulted to decide whether it is intended.                           **
**                                                                       **
** CHARACTERISED oddity: bit 0 comes from MEMORY_1.qBar and the internal    **
** D_FLIPFLOP powers up at q=0, so GPR_15_0 reads 0x0001 out of reset      **
** while every other bit reads 0. Recorded here, not judged.              **
**                                                                       **
** Test plan:                                                            **
**   1. walking-one on FIDBO_15_0 (16 loads) - per-bit D0 wiring         **
**   2. walking-one on CD_15_0    (16 loads) - per-bit D1 wiring         **
**   3. walking-zero on both buses (32 loads) - stuck-at-1 per bit       **
**   4. cross-talk: FIDBO=~CD, load each, confirm the other bus ignored  **
**   5. shift toward LSB: load 8000h then 17 shifts (walking one out)    **
**   6. shift toward MSB: 17 shifts with GPRLI toggled per step          **
**   7. hold (GPRC_2_0[2]=1) for all four SEL values, inputs changing    **
**   8. hold with no clock at all                                        **
**   9. 512 fixed-seed LFSR steps, all inputs random                     **
**  10. DGPR0N compared on every single check above                      **
**                                                                       **
** Registered module (SCAN_FF_EN + D_FLIPFLOP_EN switched by             **
** FPGA_FF_MODE): the Makefile target test-alu-gpr runs this twice -     **
** default latch/CP mode (posedge ALUCLK) and -DFPGA_FF_MODE (posedge    **
** sysclk gated by ALUCLK_EN).                                           **
**                                                                       **
** How to run:                                                           **
**   cd Verilog/DELILAH-CPU/CGA_ALU/sim && make test-alu-gpr             **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** 20-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CGA_ALU_GPR_tb;

  reg         sysclk = 0;
  reg         ALUCLK_EN = 0;
  reg         ALUCLK = 0;
  reg  [15:0] CD_15_0 = 0;
  reg  [15:0] FIDBO_15_0 = 0;
  reg  [ 2:0] GPRC_2_0 = 3'b100;  // start held
  reg         GPRLI = 0;

  wire        DGPR0N;
  wire [15:0] GPR_15_0;

  integer errors = 0;
  integer checks = 0;
  integer i;

  reg  [15:0] m_q;      // model GPR state
  reg  [15:0] m_next;
  reg  [31:0] lfsr;

  CGA_ALU_GPR dut (
      .sysclk    (sysclk),
      .ALUCLK_EN (ALUCLK_EN),
      .ALUCLK    (ALUCLK),
      .CD_15_0   (CD_15_0),
      .FIDBO_15_0(FIDBO_15_0),
      .GPRC_2_0  (GPRC_2_0),
      .GPRLI     (GPRLI),
      .DGPR0N    (DGPR0N),
      .GPR_15_0  (GPR_15_0)
  );

  always #5 sysclk = ~sysclk;

  initial begin
    $dumpfile("CGA_ALU_GPR_tb.vcd");
    $dumpvars(0, CGA_ALU_GPR_tb);
  end

  // Independent next-state function, transcribed per bit from the netlist.
  function [15:0] model_next(input [15:0] q, input [15:0] fidbo, input [15:0] cd,
                             input [2:0] gprc, input gprli);
    integer b;
    begin
      if (gprc[2]) model_next = q;
      else
        case (gprc[1:0])
          2'd0: model_next = fidbo;
          2'd1: model_next = cd;
          2'd2: begin
            for (b = 0; b < 15; b = b + 1) model_next[b] = q[b+1];
            model_next[15] = 1'b0;
          end
          default: begin
            for (b = 1; b < 16; b = b + 1) model_next[b] = q[b-1];
            model_next[0] = gprli;
          end
        endcase
    end
  endfunction

  // One ALUCLK event, valid in BOTH build modes.
  task pulse_aluclk;
    begin
      @(negedge sysclk);
      ALUCLK_EN = 1;
      @(posedge sysclk);
      #1 ALUCLK = 1;
      @(negedge sysclk);
      ALUCLK    = 0;
      ALUCLK_EN = 0;
    end
  endtask

  task compare(input [255:0] name);
    reg exp_dgpr0n;
    reg [15:0] nxt;
    begin
      nxt = model_next(m_q, FIDBO_15_0, CD_15_0, GPRC_2_0, GPRLI);
      // DGPR0N is combinational: inverted next bit-0 while loading/shifting,
      // inverted current bit-0 while holding (model_next returns q on hold).
      exp_dgpr0n = ~nxt[0];
      checks = checks + 1;
      if (GPR_15_0 !== m_q) begin
        errors = errors + 1;
        $display("FAIL %0s: GPR got %04h expected %04h (GPRC=%b FIDBO=%04h CD=%04h LI=%b)",
                 name, GPR_15_0, m_q, GPRC_2_0, FIDBO_15_0, CD_15_0, GPRLI);
      end
      checks = checks + 1;
      if (DGPR0N !== exp_dgpr0n) begin
        errors = errors + 1;
        $display("FAIL %0s: DGPR0N got %b expected %b (GPRC=%b Q0=%b)",
                 name, DGPR0N, exp_dgpr0n, GPRC_2_0, m_q[0]);
      end
    end
  endtask

  // apply inputs, clock once, update the model, compare
  task step(input [2:0] gprc, input [15:0] fidbo, input [15:0] cd, input gprli,
            input [255:0] name);
    begin
      GPRC_2_0   = gprc;
      FIDBO_15_0 = fidbo;
      CD_15_0    = cd;
      GPRLI      = gprli;
      pulse_aluclk;
      m_q = model_next(m_q, fidbo, cd, gprc, gprli);
      #2;
      compare(name);
    end
  endtask

  function [31:0] lfsr_next(input [31:0] x);
    lfsr_next = {x[30:0], x[31] ^ x[21] ^ x[1] ^ x[0]};
  endfunction

  initial begin
`ifdef FPGA_FF_MODE
    $display("CGA_ALU_GPR_tb: FPGA_FF_MODE (sysclk+ALUCLK_EN capture)");
`else
    $display("CGA_ALU_GPR_tb: latch/CP mode (posedge ALUCLK capture)");
`endif

    // CHARACTERISED power-up value: every SCAN_FF powers up at 0, but bit 0
    // is taken from MEMORY_1.qBar, so GPR_15_0 powers up as 0x0001, not 0.
    m_q = 16'h0001;
    #12;
    compare("power-up");

    // 1. walking-one on FIDBO (SEL=0). CD held at the complement so that a
    //    swapped D0/D1 pin cannot pass.
    for (i = 0; i < 16; i = i + 1)
      step(3'b000, 16'h0001 << i, ~(16'h0001 << i), 1'b0, "walk1 FIDBO");

    // 2. walking-one on CD (SEL=1), FIDBO at the complement.
    for (i = 0; i < 16; i = i + 1)
      step(3'b001, ~(16'h0001 << i), 16'h0001 << i, 1'b1, "walk1 CD");

    // 3. walking-zero on both buses
    for (i = 0; i < 16; i = i + 1)
      step(3'b000, ~(16'h0001 << i), 16'h0001 << i, 1'b0, "walk0 FIDBO");
    for (i = 0; i < 16; i = i + 1)
      step(3'b001, 16'h0001 << i, ~(16'h0001 << i), 1'b0, "walk0 CD");

    // 4. cross-talk pair
    step(3'b000, 16'hAAAA, 16'h5555, 1'b0, "xtalk FIDBO AAAA");
    step(3'b001, 16'hAAAA, 16'h5555, 1'b0, "xtalk CD 5555");
    step(3'b000, 16'h5555, 16'hAAAA, 1'b0, "xtalk FIDBO 5555");
    step(3'b001, 16'h5555, 16'hAAAA, 1'b0, "xtalk CD AAAA");

    // 5. shift toward LSB: single one at bit15 walks out, then zeros fill
    step(3'b000, 16'h8000, 16'h0000, 1'b0, "preload 8000");
    for (i = 0; i < 17; i = i + 1)
      step(3'b010, 16'hFFFF, 16'hFFFF, 1'b1, "shift LSB");

    // 6. shift toward MSB with GPRLI toggling: builds 0101... from the bottom
    step(3'b000, 16'h0000, 16'hFFFF, 1'b0, "preload 0000");
    for (i = 0; i < 17; i = i + 1)
      step(3'b011, 16'hFFFF, 16'hFFFF, i[0], "shift MSB");

    // 7. hold: all four SEL values under GPRC[2]=1, buses driven with junk
    step(3'b000, 16'h1234, 16'h0000, 1'b0, "preload 1234");
    step(3'b100, 16'hFFFF, 16'hFFFF, 1'b1, "hold sel0");
    step(3'b101, 16'h0000, 16'h0000, 1'b0, "hold sel1");
    step(3'b110, 16'hDEAD, 16'hBEEF, 1'b1, "hold sel2");
    step(3'b111, 16'hBEEF, 16'hDEAD, 1'b0, "hold sel3");

    // 8. hold with no clock at all
    GPRC_2_0 = 3'b000; FIDBO_15_0 = 16'hFFFF; CD_15_0 = 16'h0F0F; GPRLI = 1'b1;
    #40;
    checks = checks + 1;
    if (GPR_15_0 !== m_q) begin
      errors = errors + 1;
      $display("FAIL no-clock hold: GPR got %04h expected %04h", GPR_15_0, m_q);
    end

    // 9. fixed-seed pseudo-random soak
    lfsr = 32'h1BADF00D;
    for (i = 0; i < 512; i = i + 1) begin
      lfsr = lfsr_next(lfsr);
      step(lfsr[2:0], lfsr[19:4], {lfsr[7:0], lfsr[23:16]}, lfsr[24], "lfsr step");
    end

    // Verdict. 2 checks per step.
    // steps = 1(power-up) + 16+16 + 16+16 + 4 + 1+17 + 1+17 + 1+4 + 512 = 622
    // checks = 622*2 + 1 (no-clock hold) = 1245
    if (errors == 0 && checks == 1245)
      $display("checks=%0d failures=%0d", checks, errors);
    else $display("checks=%0d failures=%0d (expected 1245 checks)", checks, errors);
    if (errors == 0 && checks == 1245) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

`default_nettype wire

/****************************************************************************
** LATCH - self-checking functional testbench, BOTH BUILD MODES            **
**                                                                         **
** LATCH.v is one of only three cells in Shared (with L4.v and L8.v) whose **
** behaviour is switched by a `ifdef, and the switch is                    **
** USE_TRANSPARENT_LATCHES - NOT FPGA_FF_MODE. Getting that wrong on a     **
** build line silently gives you the other cell.                           **
**                                                                         **
**   -DUSE_TRANSPARENT_LATCHES  (original 1988 hardware model)             **
**       always @(*) if (ENABLE) regD = D;   assign Q = regD;              **
**       A true level-sensitive transparent latch. sysclk is IGNORED.      **
**                                                                         **
**   default, no define      (the FPGA path that actually ships)           **
**       always @(posedge sysclk) if (ENABLE) regD <= D;                   **
**       assign Q = ENABLE ? D : regD;                                     **
**       Transparent through a MUX while ENABLE is high, but the value it  **
**       KEEPS is whatever was sampled on the last sysclk rising edge      **
**       inside the ENABLE window.                                         **
**                                                                         **
** IDENTICAL IN BOTH MODES:                                                **
**   - power-up Q = 0                                                      **
**   - while ENABLE is high, Q tracks D combinationally, with no sysclk    **
**     edge needed                                                         **
**   - while ENABLE is low, D may do anything and Q does not move          **
**   - QN is always the exact complement of Q                              **
**                                                                         **
** DIFFERENT BETWEEN THE MODES - and this is the whole point of the file:  **
**   (1) D changes after the last sysclk edge of the ENABLE window and     **
**       then ENABLE falls. Transparent mode keeps the NEW D. The FPGA     **
**       path keeps the OLD, sysclk-sampled D.                             **
**   (2) An ENABLE pulse that opens and closes entirely BETWEEN two sysclk **
**       rising edges. Transparent mode captures D. The FPGA path captures **
**       NOTHING and reverts to the previous value when ENABLE falls -     **
**       Q glitches out and back.                                          **
**   Both are asserted explicitly per mode, so a build that silently used  **
**   the wrong branch fails rather than passing quietly.                   **
**                                                                         **
** FPGA_FF_MODE is deliberately irrelevant here: LATCH.v never reads it.   **
** The tb is run with -DFPGA_FF_MODE too, and must give the identical      **
** result to the plain build.                                              **
**                                                                         **
** Run: cd Verilog/Shared/ndlib/sim && make test-latch                     **
**                                                                         **
** Last reviewed: 20-AUG-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

`ifdef USE_TRANSPARENT_LATCHES
  `define LATCH_MODE_NAME "TRANSPARENT (USE_TRANSPARENT_LATCHES defined)"
`else
  `define LATCH_MODE_NAME "FPGA-SYSCLK (default build)"
`endif

module LATCH_tb;

  integer checks = 0;
  integer errors = 0;

`define CHK(NM, GOT, EXP) \
  begin \
    checks = checks + 1; \
    if ((GOT) !== (EXP)) begin \
      errors = errors + 1; \
      $display("FAIL t=%0t %0s : got=%b expected=%b", $time, NM, (GOT), (EXP)); \
    end \
  end

  reg sysclk = 1'b0;
  reg D = 1'b0;
  reg ENABLE = 1'b0;
  wire Q, QN;

  LATCH DUT (.sysclk(sysclk), .D(D), .ENABLE(ENABLE), .Q(Q), .QN(QN));

  // sysclk is stepped by hand so the tb can place events precisely
  // inside and outside the sampling edges.
  task sysclk_tick;
    begin
      #5 sysclk = 1'b1;
      #5 sysclk = 1'b0;
      #1;
    end
  endtask

  task check_qn;
    begin
      `CHK("QN complement", QN, ~Q)
    end
  endtask

  initial begin
    $dumpfile("LATCH_tb.vcd");
    $dumpvars(0, LATCH_tb);
  end

  initial begin
    $display("LATCH_tb: build mode = %0s", `LATCH_MODE_NAME);
    #1;

    // ---- 1. power-up (IDENTICAL in both modes) ----
    `CHK("power-up Q", Q, 1'b0)
    check_qn;

    // ---- 2. ENABLE low: D is ignored, with and without sysclk edges ----
    D = 1'b1; #5;
    `CHK("ENABLE low, no sysclk edge: Q holds", Q, 1'b0)
    sysclk_tick;
    `CHK("ENABLE low, WITH sysclk edge: Q still holds", Q, 1'b0)
    sysclk_tick; sysclk_tick;
    `CHK("ENABLE low, many sysclk edges: Q still holds", Q, 1'b0)
    check_qn;

    // ---- 3. transparency: ENABLE high, Q follows D with NO clock edge ----
    ENABLE = 1'b1; #2;
    `CHK("ENABLE rises with D=1: Q goes transparent to 1", Q, 1'b1)
    D = 1'b0; #2;
    `CHK("ENABLE high, D->0 with no sysclk edge: Q follows", Q, 1'b0)
    D = 1'b1; #2;
    `CHK("ENABLE high, D->1 with no sysclk edge: Q follows", Q, 1'b1)
    check_qn;

    // ---- 4. clean close: a sysclk edge inside the window, then ENABLE
    //         falls with D unchanged. Both modes must keep the value. ----
    sysclk_tick;                 // samples D=1 into regD (FPGA path)
    ENABLE = 1'b0; #2;
    `CHK("clean close: value 1 kept in BOTH modes", Q, 1'b1)
    check_qn;

    // ---- 5. DIVERGENCE (1): D moves AFTER the last sysclk edge of the
    //         window, then ENABLE falls. ----
    ENABLE = 1'b1; D = 1'b0; #1;
    sysclk_tick;                 // regD <= 0   (FPGA path samples 0 here)
    D = 1'b1; #2;                // no sysclk edge after this change
    `CHK("still transparent before the fall: Q=1", Q, 1'b1)
    ENABLE = 1'b0; #2;
`ifdef USE_TRANSPARENT_LATCHES
    `CHK("DIVERGENCE 1 - transparent mode keeps the NEW D (1)", Q, 1'b1)
`else
    `CHK("DIVERGENCE 1 - FPGA path keeps the sysclk-SAMPLED D (0)", Q, 1'b0)
`endif
    check_qn;

    // ---- 6. DIVERGENCE (2): an ENABLE pulse entirely between two sysclk
    //         rising edges. ----
    // bring both modes to a known held value of 0 first
    ENABLE = 1'b1; D = 1'b0; #1; sysclk_tick; ENABLE = 1'b0; #2;
    `CHK("both modes now hold 0", Q, 1'b0)
    // now the pulse: no sysclk rising edge occurs while ENABLE is high
    D = 1'b1;
    ENABLE = 1'b1; #2;
    `CHK("during the pulse both modes show 1", Q, 1'b1)
    ENABLE = 1'b0; #2;
`ifdef USE_TRANSPARENT_LATCHES
    `CHK("DIVERGENCE 2 - transparent mode captured the pulse (1)", Q, 1'b1)
`else
    `CHK("DIVERGENCE 2 - FPGA path missed the pulse, reverts to 0", Q, 1'b0)
`endif
    check_qn;

    // ---- 7. ENABLE held high across several sysclk edges with D churning:
    //         Q must equal D at every instant, in both modes. ----
    ENABLE = 1'b1;
    D = 1'b0; #1; `CHK("wide window D=0", Q, 1'b0)
    sysclk_tick;
    D = 1'b1; #1; `CHK("wide window D=1", Q, 1'b1)
    sysclk_tick;
    D = 1'b0; #1; `CHK("wide window D=0 again", Q, 1'b0)
    sysclk_tick;
    D = 1'b1; #1; `CHK("wide window D=1 again", Q, 1'b1)
    sysclk_tick;                 // sample 1
    ENABLE = 1'b0; #2;
    `CHK("wide window closed cleanly on 1 in BOTH modes", Q, 1'b1)
    check_qn;

    // ---- 8. after the close, D churn with ENABLE low must not leak ----
    D = 1'b0; sysclk_tick; sysclk_tick;
    `CHK("no leak with ENABLE low", Q, 1'b1)
    check_qn;

    $display("LATCH_tb (%0s): checks=%0d failures=%0d", `LATCH_MODE_NAME, checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule
`default_nettype wire

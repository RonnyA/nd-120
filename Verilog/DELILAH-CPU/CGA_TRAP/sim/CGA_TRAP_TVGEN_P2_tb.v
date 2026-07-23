/**************************************************************************************************
** ND120 CGA (DELILAH) - /CGA/TRAP/TVGEN/P2 unit test                                             **
**                                                                                                **
** DUT: CGA_TRAP_TVGEN_P2 (Verilog/DELILAH-CPU/CGA_TRAP/circuit/CGA_TRAP_TVGEN_P2.v, page 104 sh2) **
**                                                                                                **
** The trap-vector priority core. Seven TCLK-clocked flip-flops latch the per-level vector bits    **
** (l1v0/l1v1, l2v0/l2v1/l2v2, l3v0/l3v1); a live 4-way MUX selected by {LEV1,LEV2} drives the      **
** 4-bit TVEC_3_0 output. Priority (verified from the mux wiring):                                  **
**   {LEV1,LEV2}=00 -> level 3 (hardware/interrupt/ftrap traps)                                     **
**   {LEV1,LEV2}=01 -> level 2 (RD ring-down / PGU / WIP software traps)                            **
**   {LEV1,LEV2}=10 -> level 1 (page fault / protect+ring violations)                              **
**   {LEV1,LEV2}=11 -> vector 7                                                                     **
**                                                                                                **
** Default clocking (no FPGA_FF_MODE): D_FLIPFLOP_EN USE_ENABLE=0 -> the FFs clock on posedge TCLK, **
** sysclk/TCLK_EN unused. This tb tests that default path (tie sysclk=0, TCLK_EN=0).                **
**                                                                                                **
** Golden model: an INDEPENDENT clocked model of the 7 FFs (init 0) + the mux, re-derived from the  **
** schematic - compared after every TCLK edge across a directed suite + randomized soak.            **
** SPEC ANCHORS: five directed vectors assert the ABSOLUTE octal TVEC value taken from the DELILAH  **
** microcode trap-vector table (ND-120-DELILAH-L.LISTING addr 0..5): page fault=1, protect/ring     **
** violation=2, ring-down=3, PGU=4, WIP=5 - a true spec check independent of the gate netlist.      **
**                                                                                                **
** Teeth (-DTEETH_TEST): one bit of the golden TVEC is flipped so the checker MUST report FAIL.    **
**                                                                                                **
** Last reviewed: 15-JUL-2026                                                                     **
** Ronny Hansen                                                                                   **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_TRAP_TVGEN_P2_tb;

`ifdef TEETH_TEST
  localparam [3:0] TEETH = 4'b0001;
`else
  localparam [3:0] TEETH = 4'b0000;
`endif

  // free-running TCLK
  reg TCLK = 0;
  always #5 TCLK = ~TCLK;

  // FF-mode ports unused in the default path
  reg sysclk = 0, TCLK_EN = 0;

  // DUT inputs
  reg DSTOPN, FTRAPN, IFETCH, INTRQ, LEV1, LEV2, PAN;
  reg PGF, PGU, PGUN, PVIOL, RD, RV, VACC, VTRAPN, WIP, WIPN;

  wire [3:0] TVEC_3_0;

  CGA_TRAP_TVGEN_P2 DUT (
      .sysclk(sysclk), .TCLK_EN(TCLK_EN),
      .DSTOPN(DSTOPN), .FTRAPN(FTRAPN), .IFETCH(IFETCH), .INTRQ(INTRQ),
      .LEV1(LEV1), .LEV2(LEV2), .PAN(PAN), .PGF(PGF), .PGU(PGU), .PGUN(PGUN),
      .PVIOL(PVIOL), .RD(RD), .RV(RV), .TCLK(TCLK), .VACC(VACC), .VTRAPN(VTRAPN),
      .WIP(WIP), .WIPN(WIPN),
      .TVEC_3_0(TVEC_3_0)
  );

  // ---------------- independent golden -----------------
  // D-inputs (combinational, re-derived from page-104-sheet2)
  wire g_ftrap = ~FTRAPN;
  wire g_vt    = ~VTRAPN;
  wire g_nvfi  = ~(VACC & g_ftrap & IFETCH);                 // NAND3 vacc,ftrap,ifetch
  wire g_nvv   = ~(g_vt & VACC);                             // NAND vtrap,vacc
  wire g_g6    = ~(g_nvv & IFETCH & INTRQ & PAN & DSTOPN);   // NAND5
  wire g_d_l1v0 = (~PGF) & (PVIOL | RV);                     // gates9
  wire g_d_l1v1 = PGF;
  wire g_d_l2v0 = ~(WIPN & PGU);                             // gates11 NAND(WIPN,PGU)
  wire g_d_l2v1 = ~(WIP | PGU);                              // gates7 NOR
  wire g_d_l2v2 = ~(RD & WIPN & PGUN);                       // gates8 NAND3(RD,WIPN,PGUN)
  wire g_d_l3v0 = g_nvfi & g_g6;                             // gates10
  wire g_d_l3v1 = g_nvv & g_nvfi;                            // gates5

  // FF state (init 0, matching D_FLIPFLOP)
  reg q_l1v0=0, q_l1v1=0, q_l2v0=0, q_l2v1=0, q_l2v2=0, q_l3v0=0, q_l3v1=0;
  always @(posedge TCLK) begin
    q_l1v0 <= g_d_l1v0;  q_l1v1 <= g_d_l1v1;
    q_l2v0 <= g_d_l2v0;  q_l2v1 <= g_d_l2v1;  q_l2v2 <= g_d_l2v2;
    q_l3v0 <= g_d_l3v0;  q_l3v1 <= g_d_l3v1;
  end

  // the FF net names carry the "_n" sense: l1* wire = q, l2*/l3* wire = qBar
  wire l1v0_n = q_l1v0, l1v1_n = q_l1v1;
  wire l2v0_n = ~q_l2v0, l2v1_n = ~q_l2v1, l2v2_n = ~q_l2v2;
  wire l3v0_n = ~q_l3v0, l3v1_n = ~q_l3v1;

  reg  g_t2n, g_t1n, g_t0n;
  always @(*) begin
    case ({LEV1, LEV2})
      2'b00: begin g_t2n = 1'b0;   g_t1n = l3v1_n; g_t0n = l3v0_n; end
      2'b01: begin g_t2n = l2v2_n; g_t1n = l2v1_n; g_t0n = l2v0_n; end
      2'b10: begin g_t2n = 1'b1;   g_t1n = l1v1_n; g_t0n = l1v0_n; end
      2'b11: begin g_t2n = 1'b0;   g_t1n = 1'b0;   g_t0n = 1'b0;   end
    endcase
  end
  wire [3:0] g_tvec_raw = { (~LEV2 & ~LEV1), ~g_t2n, ~g_t1n, ~g_t0n };
  wire [3:0] g_tvec = g_tvec_raw ^ TEETH;

  integer errors = 0, checks = 0, i;

  // capture golden BEFORE the edge is not needed: we hold inputs across the edge.
  task tick_and_check(input [255:0] name);
    begin
      @(posedge TCLK);
      #1;
      checks = checks + 1;
      if (TVEC_3_0 !== g_tvec) begin
        errors = errors + 1;
        if (errors <= 15)
          $display("FAIL [%0s] sel={LEV1,LEV2}=%b%b  TVEC exp=%b(%0o) got=%b(%0o)",
                   name, LEV1, LEV2, g_tvec, g_tvec, TVEC_3_0, TVEC_3_0);
      end
    end
  endtask

  // spec anchor: assert the ABSOLUTE octal vector (independent of golden model)
  task assert_tvec(input [3:0] expo, input [255:0] name);
    begin
      @(posedge TCLK);
      #1;
      checks = checks + 1;
      // in a teeth build the DUT is unchanged, so compare against expo^TEETH so
      // that the teeth-corrupted expectation still forces a divergence.
      if (TVEC_3_0 !== (expo ^ TEETH)) begin
        errors = errors + 1;
        $display("FAIL SPEC [%0s] expected TVEC=%0o got=%0o", name, expo, TVEC_3_0);
      end
    end
  endtask

  // set a clean idle background then override
  task clr;
    begin
      DSTOPN=1; FTRAPN=1; IFETCH=0; INTRQ=0; LEV1=0; LEV2=0; PAN=0;
      PGF=0; PGU=0; PGUN=1; PVIOL=0; RD=0; RV=0; VACC=0; VTRAPN=1; WIP=0; WIPN=1;
    end
  endtask

  initial begin
`ifdef DUMP_VCD
    $dumpfile("CGA_TRAP_TVGEN_P2_tb.vcd");
    $dumpvars(0, CGA_TRAP_TVGEN_P2_tb);
`endif
    clr;
    @(negedge TCLK);

    // ---- SPEC ANCHORS (octal vectors from the DELILAH microcode table) ----
    // Page fault: level 1, pgf latched, pviol set -> vector 1
    clr; LEV1=1; LEV2=0; VACC=1; PGF=1; PVIOL=1; RV=0;
    @(negedge TCLK); assert_tvec(4'o1, "page-fault=1");

    // Protect/ring violation: level 1, pgf=0, pviol set -> vector 2
    clr; LEV1=1; LEV2=0; VACC=1; PGF=0; PVIOL=1; RV=0;
    @(negedge TCLK); assert_tvec(4'o2, "protect-violation=2");

    // Ring-down: level 2, RD only -> vector 3
    clr; LEV2=1; LEV1=0; VACC=1; RD=1; WIP=0; WIPN=1; PGU=0; PGUN=1;
    @(negedge TCLK); assert_tvec(4'o3, "ring-down=3");

    // PGU trap: level 2, PGU only -> vector 4
    clr; LEV2=1; LEV1=0; VACC=1; PGU=1; PGUN=0; WIP=0; WIPN=1; RD=0;
    @(negedge TCLK); assert_tvec(4'o4, "pgu-trap=4");

    // WIP trap: level 2, WIP set -> vector 5
    clr; LEV2=1; LEV1=0; VACC=1; WIP=1; WIPN=0; PGU=0; PGUN=1; RD=0;
    @(negedge TCLK); assert_tvec(4'o5, "wip-trap=5");

    // both levels active -> vector 7
    clr; LEV1=1; LEV2=1; VACC=1; PGF=1; PVIOL=1; WIP=1; WIPN=0;
    @(negedge TCLK); assert_tvec(4'o7, "both-levels=7");

    // ---- directed FF-exercise: toggle every D-input, latch, compare to golden ----
    clr; VACC=1; INTRQ=1; IFETCH=1; PAN=1; DSTOPN=1;  // level-3 hardware-ish
    @(negedge TCLK); tick_and_check("lev3-a");
    FTRAPN=0;  @(negedge TCLK); tick_and_check("lev3-ftrap");
    VTRAPN=0;  @(negedge TCLK); tick_and_check("lev3-vtrap");
    DSTOPN=0;  @(negedge TCLK); tick_and_check("lev3-dstop");

    // ---- randomized soak: hold inputs across each edge, compare golden ----
    for (i = 0; i < 4000; i = i + 1) begin
      @(negedge TCLK);
      DSTOPN = $random; FTRAPN = $random; IFETCH = $random; INTRQ = $random;
      LEV1   = $random; LEV2   = $random; PAN    = $random;
      PGF    = $random; PVIOL  = $random; RD     = $random; RV = $random;
      VACC   = $random; VTRAPN = $random;
      PGU    = $random; PGUN   = ~PGU;      // keep complementary pair consistent
      WIP    = $random; WIPN   = ~WIP;
      tick_and_check("soak");
    end

    $display("checks=%0d errors=%0d teeth=%b", checks, errors, TEETH);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d errors, teeth=%b)", errors, TEETH);
    $finish;
  end

endmodule

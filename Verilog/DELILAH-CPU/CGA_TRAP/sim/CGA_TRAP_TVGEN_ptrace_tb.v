/*****************************************************************************
** ND120 CGA - CGA_TRAP/TVGEN - PT-BUS ARRIVAL TIMING vs THE LATCHED VECTOR **
**                                                                          **
** THE QUESTION THIS ANSWERS                                                **
**   On silicon, SINTRAN halts in ERRFATAL reporting IIC 3 (Page Fault).     **
**   The suspicion is NOT that the microcode is wrong, but that the signals  **
**   reaching the trap logic are mistimed, so a perfectly legal access - or  **
**   a DIFFERENT trap - gets latched as a page fault.                        **
**                                                                          **
** WHY THAT IS PLAUSIBLE, FROM THE RTL ITSELF                               **
**   CGA_TRAP_TVGEN.v:252                                                   **
**       PGFN = NAND4( VACC, ~PT[6], ~PT[5], ~PT[4] )                        **
**       PGF  = VACC & ~PT[6] & ~PT[5] & ~PT[4]                              **
**   A page fault is decoded as "the page-table entry's three permission     **
**   bits are ALL ZERO". But all-zero is ALSO what that bus reads when       **
**   nothing drives it: this project's rule is that a disabled driver puts   **
**   out 0, never z, because the buses are OR-ed together.                   **
**                                                                          **
**   So "no permissions" and "no data yet" are THE SAME PATTERN on this bus. **
**   The seven trap-vector bits are FD1 flip-flops clocked from TCLK         **
**   (DELILAH p.104 sheet 2 of 2). If a TCLK edge lands while VACC is high   **
**   and PT_15_9 has not yet arrived - or has already been released - the    **
**   flip-flops capture a page fault that never happened.                    **
**                                                                          **
** WHAT THIS BENCH DOES                                                     **
**   Holds a LEGAL access whose PTE grants permission, then sweeps WHEN      **
**   PT_15_9 arrives relative to the TCLK rising edge, in 1 ns steps across  **
**   a whole TCLK period, and records the vector actually latched.           **
**   It repeats the sweep for an EARLY RELEASE case (PT valid, then dropped  **
**   back to 0 before the edge).                                            **
**                                                                          **
** WHAT PASS AND FAIL MEAN - read this before believing the verdict          **
**   PASS = for every arrival offset tested, the latched vector matched the  **
**          settled inputs. No timing window turns a legal access into a     **
**          page fault.                                                     **
**   FAIL = at least one offset latched a page fault from a legal access.    **
**          The offsets are printed. That is a REAL hazard in the RTL, not   **
**          a testbench artifact - the same flip-flops and the same bus      **
**          behaviour exist on the FPGA.                                    **
**                                                                          **
**   A PASS here does NOT clear the design. It only says the hazard is not   **
**   reachable by shifting PT arrival alone; VACC timing, TCLK skew and the  **
**   MMU's own PTE fetch are separate questions.                             **
**                                                                          **
** Run: cd Verilog/DELILAH-CPU/CGA_TRAP/sim && make test-tvgen-ptrace        **
**                                                                          **
** 21-AUG-2026                                                              **
** Ronny Hansen                                                             **
*****************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CGA_TRAP_TVGEN_ptrace_tb;

  // ---- TCLK: 100 ns period, generated so stimulus can be placed anywhere
  localparam integer TCLK_PERIOD = 100;

  reg TCLK = 1'b0;
  reg sysclk = 1'b0;
  always #(TCLK_PERIOD / 2) TCLK = ~TCLK;
  always #1 sysclk = ~sysclk;          // only used by the FF_MODE enable path

  // ---- DUT inputs
  reg        vacc = 1'b0;
  reg  [6:0] ipt = 7'h00;
  reg        ifetch = 1'b0, iind = 1'b0, iwrite = 1'b0;
  reg        intrq = 1'b0, pan = 1'b1, poni = 1'b1;
  reg        dstop_n = 1'b1, ftrap_n = 1'b1, vtrap_n = 1'b1;
  reg  [1:0] ipcr = 2'b11;

  wire [6:0] ipt_n = ~ipt;
  wire [1:0] ipcr_n = ~ipcr;

  wire       PVIOL, RESTR;
  wire [3:0] TVEC_3_0;

  // TCLK_EN is only consumed in FPGA_FF_MODE; tie it so the bench runs in
  // BOTH builds and a difference between them is visible rather than hidden.
`ifdef FPGA_FF_MODE
  reg tclk_d = 1'b0;
  always @(posedge sysclk) tclk_d <= TCLK;
  wire TCLK_EN = TCLK & ~tclk_d;        // rising-edge pulse, one sysclk wide
`else
  wire TCLK_EN = 1'b0;
`endif

  CGA_TRAP_TVGEN DUT (
      .sysclk (sysclk),
      .TCLK_EN(TCLK_EN),
      .DSTOPN (dstop_n),
      .FTRAPN (ftrap_n),
      .IFETCH (ifetch),
      .IFETCHN(~ifetch),
      .IIND   (iind),
      .IINDN  (~iind),
      .INTRQ  (intrq),
      .IPCR_1_0(ipcr),
      .IPCR_1_0_N(ipcr_n),
      .IPT_15_9(ipt),
      .IPT_15_9_N(ipt_n),
      .IWRITE (iwrite),
      .IWRITEN(~iwrite),
      .PAN    (pan),
      .PONI   (poni),
      .TCLK   (TCLK),
      .VACC   (vacc),
      .VTRAPN (vtrap_n),
      .PVIOL  (PVIOL),
      .RESTR  (RESTR),
      .TVEC_3_0(TVEC_3_0)
  );

  // ---- the page-fault term, straight from CGA_TRAP_TVGEN.v:252 ------------
  // PGF = VACC & ~PT[6] & ~PT[5] & ~PT[4]
  function automatic pgf_of;
    input       v;
    input [6:0] pt;
    begin
      pgf_of = v & ~pt[6] & ~pt[5] & ~pt[4];
    end
  endfunction

  integer errors = 0;
  integer checks = 0;
  integer offsets_bad = 0;

  // A PTE that GRANTS permission: WPM(15)=PT[6], RPM(14)=PT[5], FPM(13)=PT[4].
  // 7'b111_0000 -> all three permits set, so PGF must be 0 and no protect
  // violation term can fire for a plain read.
  localparam [6:0] PTE_GRANTED = 7'b1110000;
  localparam [6:0] PTE_IDLE = 7'b0000000;  // undriven bus == "no permissions"

  // The stimulus is placed between a negedge and the following posedge, so the
  // largest usable offset is half a period minus one. Sweeping past that gave a
  // NEGATIVE delay, which Verilog reinterprets as a huge unsigned one: the run
  // jumped out of range and exited 0 with no summary, looking like a pass.
  localparam integer MAX_OFF = TCLK_PERIOD / 2 - 2;

  // Sample well after the capturing edge. In FPGA_FF_MODE the vector
  // flip-flops are clocked by sysclk qualified with a TCLK_EN pulse that
  // arrives AFTER the TCLK rise, so a 1 ns sample reads the PREVIOUS value and
  // reports a failure that belongs to the bench, not the RTL.
  localparam integer SAMPLE_DLY = 8;

  reg [3:0] seen;
  reg       pgf_seen;

  // -------------------------------------------------------------------------
  // SWEEP 1 - LATE ARRIVAL.
  // VACC is already asserted; PT_15_9 arrives `d` ns before the TCLK edge.
  // For every d, the vector latched must be the NO-FAULT vector.
  // -------------------------------------------------------------------------
  task automatic sweep_late;
    integer d;
    begin
      $display("");
      $display("--- SWEEP 1: PT_15_9 arrives late (VACC already high) --------");
      $display("    offset = ns of valid PT before the TCLK rising edge");
      for (d = 0; d <= MAX_OFF; d = d + 1) begin
        // settle: no access at all
        @(negedge TCLK);
        vacc   = 1'b0;
        ipt    = PTE_IDLE;
        ifetch = 1'b0;
        iwrite = 1'b0;
        iind   = 1'b0;
        @(negedge TCLK);

        // start the access with the PT bus still idle (== all zeros)
        vacc = 1'b1;
        ipt  = PTE_IDLE;

        // present valid PT `d` ns before the next rising edge
        if (TCLK_PERIOD / 2 - d - 1 < 0) begin
          $display("    BENCH DEFECT: negative delay at d=%0d - aborting", d);
          $finish;
        end
        #(TCLK_PERIOD / 2 - d - 1);
        ipt = PTE_GRANTED;
        #(d + 1);  // rising edge occurs inside this delay

        #(SAMPLE_DLY);
        seen     = TVEC_3_0;
        pgf_seen = pgf_of(vacc, PTE_GRANTED);  // settled inputs => must be 0
        checks   = checks + 1;

        // With the settled PTE granting all three permits, a page fault is
        // impossible. Anything that latched one came from the idle bus.
        if (seen == 4'd1) begin  // level-1 page-fault encoding
          errors      = errors + 1;
          offsets_bad = offsets_bad + 1;
          if (offsets_bad <= 12)
            $display("    FAIL offset=%0d ns : latched TVEC=%0d (page fault) from a GRANTED PTE",
                     d, seen);
        end
      end
      $display("    offsets swept: %0d (0..%0d ns), bad: %0d", MAX_OFF + 1, MAX_OFF, offsets_bad);
    end
  endtask

  // -------------------------------------------------------------------------
  // SWEEP 2 - EARLY RELEASE.
  // PT_15_9 is valid, then released back to the idle all-zero state `d` ns
  // BEFORE the TCLK edge. Same requirement: no page fault may be latched.
  // -------------------------------------------------------------------------
  integer offsets_bad2 = 0;
  task automatic sweep_early_release;
    integer d;
    begin
      $display("");
      $display("--- SWEEP 2: PT_15_9 released early (back to the idle 0 bus) --");
      $display("    offset = ns the bus was already idle before the TCLK edge");
      for (d = 0; d <= MAX_OFF; d = d + 1) begin
        @(negedge TCLK);
        vacc = 1'b0;
        ipt  = PTE_IDLE;
        @(negedge TCLK);

        vacc = 1'b1;
        ipt  = PTE_GRANTED;

        if (TCLK_PERIOD / 2 - d - 1 < 0) begin
          $display("    BENCH DEFECT: negative delay at d=%0d - aborting", d);
          $finish;
        end
        #(TCLK_PERIOD / 2 - d - 1);
        ipt = PTE_IDLE;  // driver released
        #(d + 1);

        #(SAMPLE_DLY);
        seen   = TVEC_3_0;
        checks = checks + 1;
        if (seen == 4'd1) begin
          errors       = errors + 1;
          offsets_bad2 = offsets_bad2 + 1;
          if (offsets_bad2 <= 12)
            $display("    FAIL offset=%0d ns : latched TVEC=%0d (page fault) after early release",
                     d, seen);
        end
      end
      $display("    offsets swept: %0d (0..%0d ns), bad: %0d", MAX_OFF + 1, MAX_OFF, offsets_bad2);
    end
  endtask

  // -------------------------------------------------------------------------
  // CONTROL: prove the bench can SEE a page fault, so a clean PASS above is
  // meaningful and not just a bench that never triggers anything.
  // -------------------------------------------------------------------------
  task automatic control_real_pagefault;
    begin
      $display("");
      $display("--- CONTROL: a REAL page fault must be detected ---------------");
      @(negedge TCLK);
      vacc = 1'b1;
      ipt  = PTE_IDLE;  // genuinely no permissions
      @(posedge TCLK);
      #(SAMPLE_DLY);
      checks = checks + 1;
      if (TVEC_3_0 !== 4'd1) begin
        errors = errors + 1;
        $display("    FAIL CONTROL: a real page fault gave TVEC=%0d, expected 1", TVEC_3_0);
        $display("    -> the SWEEP results above are WORTHLESS: this bench cannot");
        $display("       detect the very condition it is looking for.");
      end else begin
        $display("    ok: real page fault latched TVEC=1, so the sweeps are meaningful");
      end
    end
  endtask

  initial begin
    // Level 1 only, and switched OFF after the control case. Dumping the
    // whole gate hierarchy across ~200 sweep steps produced a VCD large
    // enough to make the run time out - the waveform is documentation, the
    // sweep verdict is the result.
    $dumpfile("CGA_TRAP_TVGEN_ptrace_tb.vcd");
    $dumpvars(1, CGA_TRAP_TVGEN_ptrace_tb);

    $display("=========================================================");
    $display(" CGA_TRAP_TVGEN - PT arrival timing vs the latched vector");
`ifdef FPGA_FF_MODE
    $display(" build: FPGA_FF_MODE (edge-triggered)");
`else
    $display(" build: default (transparent-latch model)");
`endif
    $display("=========================================================");

    repeat (4) @(negedge TCLK);

    control_real_pagefault();
    $dumpoff;                       // sweeps are counted, not drawn
    sweep_late();
    sweep_early_release();

    $display("");
    $display("---------------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) begin
      $display(" No PT-arrival offset turned a granted PTE into a page fault.");
      $display(" NOTE: this does NOT clear the design - VACC timing, TCLK skew");
      $display(" and the MMU's own PTE fetch are separate and untested here.");
      $display("TB_RESULT: PASS");
    end else begin
      $display(" A legal access latched a PAGE FAULT at %0d late-arrival and", offsets_bad);
      $display(" %0d early-release offsets. PGF decodes an all-zero PT bus, and", offsets_bad2);
      $display(" an idle bus reads all-zero, so the trap cannot tell them apart.");
      $display("TB_RESULT: FAIL");
    end
    $display("=========================================================");
    $finish;
  end

endmodule

`default_nettype wire

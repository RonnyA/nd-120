/**************************************************************************************************
** ND120 - PAL 44306A (21G, MMUCTL) exhaustive golden testbench                                   **
**                                                                                                **
** DUT: PAL_44306A  (Verilog/PAL/PAL_44306A.v)                                                    **
** Golden source: the PALASM listing, DesignDocuments/PAL-Code/SRC/44306A.txt, re-checked          **
**                against the scan DesignDocuments/PAL-Code/IMG/44306A.png (the scan is the        **
**                original; the .txt is OCR). The golden below is re-derived term by term from     **
**                that listing - it is NOT copied from PAL_44306A.v, or the test would only        **
**                prove the file equals itself.                                                    **
**                                                                                                **
** WHAT THE TEETH ARE                                                                              **
**   1. Every one of the 8 outputs is compared against the golden on ALL 1024 input combinations   **
**      (10 inputs, so the space is swept exhaustively - no sampling, no soak).                    **
**   2. 13 named directed checks pin the terms this PAL is historically dangerous for.             **
**      THE ONE THAT MATTERS: on 29-JUL-2026 the EIPL third term carried an extra `DOUBLE &` that  **
**      the PALASM does not have (copy-paste from the EIPU term above it). In REX mode DOUBLE=0,   **
**      so EIPL never fired, the page-number map RAM was never written, and every paged access ran **
**      in physical page 0. The asymmetry is DELIBERATE and is asserted by name here:              **
**          EIPU third term = DOUBLE * LSHADOW * WRITE   (SEX mode only)                           **
**          EIPL third term =          LSHADOW * WRITE   (REX and SEX alike - NO DOUBLE)           **
**      Checks "ASYM-EIPL-REX-write" and "ASYM-EIPU-REX-write-off" fail loudly if a future edit    **
**      "tidies" the two equations into symmetry.                                                  **
**                                                                                                **
** COVERAGE (all 8 outputs of the listing, all exhaustively compared):                             **
**   ECD_n, LAPA_n, EIPUR_n, EIPU_n, EIPL_n, EPTI_n, EPMAP_n, EPT_n                                **
**                                                                                                **
** POLARITY CONVENTION taken from the PAL16L8 pin declaration lines:                               **
**   CA0 WRITE /DVACC /RT /WCHIM DOUBLE /EMCL /CC2 /WCA GND                                        **
**   LSHADOW /LAPA /EPT /EPMAP /EPTI /EIPL /EIPU /EIPUR /ECD VCC                                   **
**   An input pin written with a leading '/' is active low: the logical name used inside the        **
**   equations is the inverse of the pin. CA0, WRITE, DOUBLE, LSHADOW carry no '/' - logical =      **
**   pin. All 8 outputs carry a '/', so the physical pin is the inverse of its equation.            **
**                                                                                                **
** RUN:  cd Verilog/PAL/sim && make test-pal44306a                                                  **
** TEETH PROOF: iverilog -g2012 -DTEETH_TEST ...  corrupts the golden EIPL bit; the checker MUST   **
**              then report TB_RESULT: FAIL.                                                        **
**                                                                                                **
** Last reviewed: 11-AUG-2026                                                                      **
** Ronny Hansen                                                                                    **
***************************************************************************************************/
`timescale 1ns / 1ps

module PAL_44306A_tb;

  // Deliberate golden corruption for the teeth build: XORed into the golden
  // EIPL pin value so the DUT (which is correct) MUST disagree.
`ifdef TEETH_TEST
  localparam TEETH_EIPL = 1'b1;
`else
  localparam TEETH_EIPL = 1'b0;
`endif

  // 10 inputs -> 1024 vectors, 8 outputs each = 8192 comparisons,
  // plus 13 named directed checks.
  localparam integer NVEC            = 1024;
  localparam integer NOUT            = 8;
  localparam integer NNAMED          = 13;
  localparam integer EXPECTED_CHECKS = NVEC * NOUT + NNAMED;
  localparam integer MAX_PRINT       = 10;

  integer errors = 0;
  integer checks = 0;
  integer printed = 0;
  integer v;

  // ---------------- DUT pins (physical polarity, as in the module) -------- //
  reg CA0, WRITE, DVACC_n, RT_n, WCHIM_n, DOUBLE, EMCL_n, CC2_n, WCA_n, LSHADOW;

  wire ECD_n, LAPA_n, EIPUR_n, EIPU_n, EIPL_n, EPTI_n, EPMAP_n, EPT_n;

  PAL_44306A DUT (
      .CA0    (CA0),
      .WRITE  (WRITE),
      .DVACC_n(DVACC_n),
      .RT_n   (RT_n),
      .WCHIM_n(WCHIM_n),
      .DOUBLE (DOUBLE),
      .EMCL_n (EMCL_n),
      .CC2_n  (CC2_n),
      .WCA_n  (WCA_n),
      .LSHADOW(LSHADOW),

      .ECD_n  (ECD_n),
      .LAPA_n (LAPA_n),
      .EIPUR_n(EIPUR_n),
      .EIPU_n (EIPU_n),
      .EIPL_n (EIPL_n),
      .EPTI_n (EPTI_n),
      .EPMAP_n(EPMAP_n),
      .EPT_n  (EPT_n)
  );

  // ------------- INDEPENDENT GOLDEN MODEL, from the PALASM listing -------- //
  // Step 1: pin -> logical name, per the '/' markers on the pin declaration.
  wire l_CA0     = CA0;        // no '/'
  wire l_WRITE   = WRITE;      // no '/'
  wire l_DOUBLE  = DOUBLE;     // no '/'
  wire l_LSHADOW = LSHADOW;    // no '/'
  wire l_DVACC   = ~DVACC_n;   // /DVACC
  wire l_RT      = ~RT_n;      // /RT
  wire l_WCHIM   = ~WCHIM_n;   // /WCHIM
  wire l_EMCL    = ~EMCL_n;    // /EMCL
  wire l_CC2     = ~CC2_n;     // /CC2
  wire l_WCA     = ~WCA_n;     // /WCA

  // Step 2: the equations, transcribed straight from the listing.
  //   ECD = WCA * /LSHADOW + RT * /LSHADOW * /CC2
  wire g_ECD = (l_WCA & ~l_LSHADOW)
             | (l_RT  & ~l_LSHADOW & ~l_CC2);

  //   LAPA = DVACC * /LSHADOW * /WCHIM
  wire g_LAPA = (l_DVACC & ~l_LSHADOW & ~l_WCHIM);

  //   EIPUR = /DOUBLE * LSHADOW * WRITE          (REX-mode shadow write only)
  wire g_EIPUR = (~l_DOUBLE & l_LSHADOW & l_WRITE);

  //   EIPU = WCHIM + DOUBLE * LSHADOW * CA0 + DOUBLE * LSHADOW * WRITE
  //   NOTE: the third term DOES carry DOUBLE - SEX mode only. Compare EIPL.
  wire g_EIPU = (l_WCHIM)
              | (l_DOUBLE & l_LSHADOW & l_CA0)
              | (l_DOUBLE & l_LSHADOW & l_WRITE);

  //   EIPL = WCHIM + DOUBLE * LSHADOW * CA0 + LSHADOW * WRITE
  //   NOTE: the third term has NO DOUBLE - "WRITING LOWER BYTE (SAME FOR REX
  //   AND SEX)". Adding DOUBLE here is the 29-JUL-2026 bug. Do not add it.
  wire g_EIPL = (l_WCHIM)
              | (l_DOUBLE & l_LSHADOW & l_CA0)
              | (l_LSHADOW & l_WRITE);

  //   EPTI = LSHADOW * /EMCL * WRITE + LSHADOW * /EMCL * /DOUBLE
  //        + LSHADOW * /EMCL * /CA0
  wire g_EPTI = (l_LSHADOW & ~l_EMCL & l_WRITE)
              | (l_LSHADOW & ~l_EMCL & ~l_DOUBLE)
              | (l_LSHADOW & ~l_EMCL & ~l_CA0);

  //   EPMAP = /WCHIM * /DVACC * /WRITE   + /WCHIM * /DVACC * /LSHADOW
  //         + /WCHIM * /DVACC * /DOUBLE  + /WCHIM * /DVACC * CA0
  //         + /WCHIM * LSHADOW * /WRITE  + /WCHIM * LSHADOW * /DOUBLE
  //         + /WCHIM * LSHADOW * CA0
  wire g_EPMAP = (~l_WCHIM & ~l_DVACC  & ~l_WRITE)
               | (~l_WCHIM & ~l_DVACC  & ~l_LSHADOW)
               | (~l_WCHIM & ~l_DVACC  & ~l_DOUBLE)
               | (~l_WCHIM & ~l_DVACC  &  l_CA0)
               | (~l_WCHIM &  l_LSHADOW & ~l_WRITE)
               | (~l_WCHIM &  l_LSHADOW & ~l_DOUBLE)
               | (~l_WCHIM &  l_LSHADOW &  l_CA0);

  //   EPT = /WRITE * /EMCL + /LSHADOW * /EMCL + /DOUBLE * /EMCL + /CA0 * /EMCL
  wire g_EPT = (~l_WRITE   & ~l_EMCL)
             | (~l_LSHADOW & ~l_EMCL)
             | (~l_DOUBLE  & ~l_EMCL)
             | (~l_CA0     & ~l_EMCL);

  // Step 3: every output pin is declared '/', so pin = ~equation.
  wire e_ECD_n   = ~g_ECD;
  wire e_LAPA_n  = ~g_LAPA;
  wire e_EIPUR_n = ~g_EIPUR;
  wire e_EIPU_n  = ~g_EIPU;
  wire e_EIPL_n  = (~g_EIPL) ^ TEETH_EIPL;   // teeth corruption lands here
  wire e_EPTI_n  = ~g_EPTI;
  wire e_EPMAP_n = ~g_EPMAP;
  wire e_EPT_n   = ~g_EPT;

  // ------------------------------ checkers -------------------------------- //
  task check_eq(input got, input exp, input [511:0] sig);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (printed < MAX_PRINT) begin
          printed = printed + 1;
          $display(
              "MISMATCH %0s: got=%b exp=%b  [CA0=%b WRITE=%b DVACC_n=%b RT_n=%b WCHIM_n=%b DOUBLE=%b EMCL_n=%b CC2_n=%b WCA_n=%b LSHADOW=%b]",
              sig, got, exp, CA0, WRITE, DVACC_n, RT_n, WCHIM_n, DOUBLE, EMCL_n, CC2_n, WCA_n,
              LSHADOW);
          if (printed == MAX_PRINT)
            $display("... further mismatches suppressed (first %0d shown)", MAX_PRINT);
        end
      end
    end
  endtask

  // Named directed check: compared against a hand-written literal, not the
  // golden expression, so it states the intended behaviour independently.
  task check_named(input got, input exp, input [511:0] name);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        $display("MISMATCH named check %0s: got=%b exp=%b", name, got, exp);
      end else begin
        $display("  ok  %0s", name);
      end
    end
  endtask

  // Drive one vector from a 10-bit index and let the combinational logic settle.
  task apply(input [9:0] bits);
    begin
      {CA0, WRITE, DVACC_n, RT_n, WCHIM_n, DOUBLE, EMCL_n, CC2_n, WCA_n, LSHADOW} = bits;
      #1;
    end
  endtask

  // Drive a named MMU situation directly.
  task drive(input ca0, input wr, input dvacc_n, input rt_n, input wchim_n, input dbl,
             input emcl_n, input cc2_n, input wca_n, input lshadow);
    begin
      CA0 = ca0; WRITE = wr; DVACC_n = dvacc_n; RT_n = rt_n; WCHIM_n = wchim_n;
      DOUBLE = dbl; EMCL_n = emcl_n; CC2_n = cc2_n; WCA_n = wca_n; LSHADOW = lshadow;
      #1;
    end
  endtask

  // ------------------------------ watchdog -------------------------------- //
  initial begin
    #200000;
    $display("TB_RESULT: TIMEOUT (watchdog fired at %0t)", $time);
    $finish;
  end

  // ------------------------------- stimulus ------------------------------- //
  initial begin
`ifdef DUMP_VCD
    $dumpfile("PAL_44306A_tb.vcd");
    $dumpvars(0, PAL_44306A_tb);
`endif
    $display("PAL_44306A (21G, MMUCTL) - exhaustive vs PALASM golden");
    $display("10 inputs -> %0d vectors x %0d outputs + %0d named = %0d checks",
             NVEC, NOUT, NNAMED, EXPECTED_CHECKS);

    // ---- 1. exhaustive sweep of the whole 10-input space ----
    for (v = 0; v < NVEC; v = v + 1) begin
      apply(v[9:0]);
      check_eq(ECD_n,   e_ECD_n,   "ECD_n");
      check_eq(LAPA_n,  e_LAPA_n,  "LAPA_n");
      check_eq(EIPUR_n, e_EIPUR_n, "EIPUR_n");
      check_eq(EIPU_n,  e_EIPU_n,  "EIPU_n");
      check_eq(EIPL_n,  e_EIPL_n,  "EIPL_n");
      check_eq(EPTI_n,  e_EPTI_n,  "EPTI_n");
      check_eq(EPMAP_n, e_EPMAP_n, "EPMAP_n");
      check_eq(EPT_n,   e_EPT_n,   "EPT_n");
    end

    // ---- 2. named directed checks ----
    $display("named checks:");

    // --- THE ASYMMETRY (the 29-JUL-2026 bug) ---------------------------- //
    // REX-mode shadow write: DOUBLE=0, LSHADOW=1, WRITE=1, CA0=0, WCHIM off.
    // EIPL MUST fire here (lower PPN byte is written in REX and SEX alike);
    // EIPU MUST NOT (its matching term is qualified by DOUBLE). If someone
    // makes the two equations symmetric, exactly one of these two fails.
    //     CA0 WR DVACC_n RT_n WCHIM_n DOUBLE EMCL_n CC2_n WCA_n LSHADOW
    drive(0,  1,  1,      1,   1,      0,     1,     1,    1,    1);
    check_named(EIPL_n,  1'b0, "ASYM-EIPL-REX-write (EIPL fires with DOUBLE=0)");
    check_named(EIPU_n,  1'b1, "ASYM-EIPU-REX-write-off (EIPU needs DOUBLE=1)");
    check_named(EIPUR_n, 1'b0, "EIPUR-REX-write (protect bits masked in REX)");

    // SEX-mode shadow write: DOUBLE=1 - now both EIPL and EIPU fire, and
    // EIPUR drops out (its term is /DOUBLE).
    drive(0,  1,  1,      1,   1,      1,     1,     1,    1,    1);
    check_named(EIPL_n,  1'b0, "ASYM-EIPL-SEX-write (EIPL fires with DOUBLE=1 too)");
    check_named(EIPU_n,  1'b0, "ASYM-EIPU-SEX-write (EIPU fires only in SEX)");
    check_named(EIPUR_n, 1'b1, "EIPUR-SEX-write-off (term is /DOUBLE)");

    // --- EPT_n: the page-table RAM select ------------------------------- //
    // EPT is the OR of four /-terms, all gated by /EMCL: it is DEASSERTED
    // exactly on the SEX-mode shadow write (WRITE & LSHADOW & DOUBLE & CA0).
    drive(1,  1,  1,      1,   1,      1,     1,     1,    1,    1);
    check_named(EPT_n, 1'b1, "EPT-off-on-SEX-shadow-write");
    // A read cycle (WRITE=0) asserts EPT through the /WRITE * /EMCL term.
    drive(1,  0,  1,      1,   1,      1,     1,     1,    1,    1);
    check_named(EPT_n, 1'b0, "EPT-on-for-read-cycle");
    // EMCL asserted (EMCL_n=0) kills every term.
    drive(0,  0,  1,      1,   1,      0,     0,     1,    1,    0);
    check_named(EPT_n, 1'b1, "EPT-off-while-EMCL-asserted");

    // --- EPMAP_n: the PPN map RAM select -------------------------------- //
    // Every EPMAP term is gated by /WCHIM, so asserting WCHIM (WCHIM_n=0)
    // must deassert EPMAP outright.
    drive(0,  0,  1,      1,   0,      0,     1,     1,    1,    0);
    check_named(EPMAP_n, 1'b1, "EPMAP-off-while-WCHIM-asserted");
    // WCHIM inactive, DVACC inactive, WRITE=0 -> first term fires.
    drive(0,  0,  1,      1,   1,      0,     1,     1,    1,    0);
    check_named(EPMAP_n, 1'b0, "EPMAP-on-read-no-wchim-no-dvacc");

    // --- LAPA_n: logical address straight to PPN ------------------------ //
    // LAPA = DVACC * /LSHADOW * /WCHIM (a single product term).
    drive(0,  0,  0,      1,   1,      0,     1,     1,    1,    0);
    check_named(LAPA_n, 1'b0, "LAPA-on-dvacc-no-shadow-no-wchim");
    // Shadow access removes it.
    drive(0,  0,  0,      1,   1,      0,     1,     1,    1,    1);
    check_named(LAPA_n, 1'b1, "LAPA-off-during-shadow-access");

    // ------------------------------ verdict ------------------------------ //
    $display("checks=%0d expected=%0d errors=%0d", checks, EXPECTED_CHECKS, errors);
    if ((errors == 0) && (checks == EXPECTED_CHECKS))
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)", errors, checks,
               EXPECTED_CHECKS);
    $finish;
  end

endmodule

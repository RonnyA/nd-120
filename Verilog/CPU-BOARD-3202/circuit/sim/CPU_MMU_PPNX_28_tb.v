/**************************************************************************
** ND120 CPU - unit test                                                 **
** CPU_MMU_PPNX_28: PPN <-> IDB transceivers (sheet 28 of 50)            **
**                                                                       **
** WHAT THE DRAWING SHOWS (3202-REV-D-OCT-87, sheet 28 of 50,            **
** ID NO 35000EDD, PRINT 3202D, "ND120 CPU,MM&M  CPU/MMU/PPNX            **
** PPN TO IDB", drawn 5/18/87). Three chips, no others:                   **
**                                                                       **
**   10B  74PCT245  A1..A8 = PPN25..PPN18   B1..B8 = IDB15..IDB8         **
**                  pin 1  DIR = ESTOF~     pin 19 /G = EIPU~            **
**   9B   74PCT245  A1..A8 = PPN17..PPN10   B1..B8 = IDB7..IDB0          **
**                  pin 1  DIR = ESTOF~     pin 19 /G = EIPL~            **
**   8B   74LS244   1A1..1A4,2A1..2A3 tied to GND, 2A4 (pin 17) = IDB8   **
**                  1Y1..2Y4 = PPN25..PPN18, 1G and 2G both = EIPUR~     **
**                                                                       **
** So the IDB side is TWO INDEPENDENT BYTE ENABLES: the HIGH byte of     **
** IDB is enabled by EIPU~ alone and the LOW byte by EIPL~ alone, with   **
** one shared direction control ESTOF~. A 74x245 with /G high drives     **
** NEITHER port; with /G low it drives exactly ONE port, chosen by DIR   **
** (DIR high = A to B = PPN to IDB; DIR low = B to A = IDB to PPN).      **
** 8B is gated ONLY by EIPUR~ and forces PPN25..PPN19 to 0 while         **
** passing IDB8 to PPN18 - the protect-bit mask.                        **
**                                                                       **
** Port index mapping used throughout: PPN_25_10[15] = PPN25 ...          **
** PPN_25_10[0] = PPN10, so PPN_25_10[15:8] is 10B's A side and          **
** PPN_25_10[7:0] is 9B's A side.                                        **
**                                                                       **
** THE HOUSE 3-STATE CONVENTION: inside the FPGA there is no z. A        **
** disabled driver must drive 0 and the drivers are merged with a        **
** wired-OR by the parent (CPU_MMU_24.v). The reference model for this   **
** is Verilog/Shared/support/TTL_74245.v:25-28, which is exactly         **
**   B_OUT = (OE_n == 0 && DIR == 1) ? bus : 8'b0;                       **
**   A_OUT = (OE_n == 0 && DIR == 0) ? bus : 8'b0;                       **
** This bench asserts that same rule per byte, which is the ONLY reason  **
** a disabled byte is expected to read 000 rather than z.                **
**                                                                       **
** WHY THIS BENCH EXISTS: sheet 28 had no coverage of any kind. The      **
** specific suspicion is that the two /G enables never reached the IDB   **
** output path, leaving the sheet driving IDB on every cycle including   **
** the cycles where DIR points the other way.                           **
**                                                                       **
** Coverage:                                                             **
**   A  full sweep: 6 IDB patterns x 6 PPN patterns x all 4 combinations **
**      of (EIPU_n, EIPL_n) x both ESTOF_n levels, EIPUR_n inactive.     **
**      Patterns include all-ones, all-zeros, 052525/125252 and two      **
**      byte-asymmetric words, so a high/low byte swap cannot pass.      **
**   B  per-byte independence, named: one byte enabled, the other        **
**      disabled, in both directions. The disabled byte must read 000.   **
**   C  direction control: with ESTOF_n low (IDB to PPN) the sheet must  **
**      not drive IDB at all, and vice versa. Both bytes enabled.        **
**   D  EIPUR_n protect-bit mask (chip 8B): PPN25..PPN19 forced to 0,    **
**      PPN18 = IDB8; and the same masked byte is what 10B forwards to   **
**      IDB15..IDB8 when it is enabled in the PPN-to-IDB direction.      **
**   E  fully disabled sheet drives NOTHING: with EIPU_n, EIPL_n and     **
**      EIPUR_n all inactive both outputs must be 000000 whatever is on  **
**      the input buses. This is the check that a pass-through of the    **
**      input to the output cannot survive; such a pass-through forms a  **
**      combinational ring through the parent's wired-OR merges.         **
**                                                                       **
** One combination is deliberately NOT asserted: EIPUR_n low together    **
** with EIPU_n low and ESTOF_n low puts 8B and 10B on the same PPN high  **
** byte at the same time, which on the real board is driver contention.  **
** Section D prints what the RTL resolves it to and does not judge it.   **
**                                                                       **
** The DUT is purely combinational. A clock is present only so that      **
** stimulus is applied on the negedge, the anti-race convention of the   **
** other benches in this directory; outputs are sampled after a settle   **
** delay.                                                                **
**                                                                       **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).          **
**                                                                       **
** Run: make test-mmuppnx   (CPU-BOARD-3202/circuit/sim)                 **
**                                                                       **
** 11-AUG-2026                                                           **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps

module CPU_MMU_PPNX_28_tb;

  // Expected number of checks - the verdict is gated on this too, so a
  // silently skipped section cannot pass.
  localparam integer EXPECTED_CHECKS = 784;

  reg         sysclk;

  reg         EIPU_n;
  reg         EIPL_n;
  reg         ESTOF_n;
  reg         EIPUR_n;
  reg  [15:0] IDB_15_0_IN;
  reg  [15:0] PPN_25_10_IN;

  wire [15:0] IDB_15_0_OUT;
  wire [15:0] PPN_25_10_OUT;

  integer     errors = 0;
  integer     checks = 0;

  CPU_MMU_PPNX_28 DUT (
      .EIPU_n       (EIPU_n),
      .EIPL_n       (EIPL_n),
      .ESTOF_n      (ESTOF_n),
      .EIPUR_n      (EIPUR_n),
      .IDB_15_0_IN  (IDB_15_0_IN),
      .IDB_15_0_OUT (IDB_15_0_OUT),
      .PPN_25_10_IN (PPN_25_10_IN),
      .PPN_25_10_OUT(PPN_25_10_OUT)
  );

  // 100 MHz clock - stimulus timing only, the DUT has no clock input
  initial sysclk = 0;
  always #5 sysclk = ~sysclk;

  /*************************************************************************
   ** Helpers                                                             **
   *************************************************************************/

  task check_eq(input [15:0] got, input [15:0] exp, input [(8*72):1] msg);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        $display("  FAIL: %0s  got=%06o expected=%06o", msg, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  // Apply one input vector on the negedge, then let it settle.
  task drive(input [15:0] idb, input [15:0] ppn, input eipu_n, input eipl_n,
             input estof_n, input eipur_n);
    begin
      @(negedge sysclk);
      IDB_15_0_IN  = idb;
      PPN_25_10_IN = ppn;
      EIPU_n       = eipu_n;
      EIPL_n       = eipl_n;
      ESTOF_n      = estof_n;
      EIPUR_n      = eipur_n;
      #1;
    end
  endtask

  /*************************************************************************
   ** Golden model, taken from the drawing and from TTL_74245.v           **
   *************************************************************************/

  // The PPN high byte NODE, i.e. what sits on 10B's A side. 8B overdrives
  // it whenever EIPUR_n is low; otherwise it is whatever the shadow RAM
  // presents on PPN25..PPN18.
  function [7:0] ppn_hi_node(input [15:0] idb, input [15:0] ppn,
                             input eipur_n);
    begin
      ppn_hi_node = (eipur_n == 1'b0) ? {7'b0, idb[8]} : ppn[15:8];
    end
  endfunction

  // What sheet 28 drives onto IDB. Each byte is enabled by its own /G and
  // only in the A-to-B direction (ESTOF_n high).
  function [15:0] exp_idb(input [15:0] idb, input [15:0] ppn, input eipu_n,
                          input eipl_n, input estof_n, input eipur_n);
    reg [7:0] hi;
    reg [7:0] lo;
    begin
      hi = (eipu_n == 1'b0 && estof_n == 1'b1) ? ppn_hi_node(
          idb, ppn, eipur_n
      ) : 8'h00;
      lo = (eipl_n == 1'b0 && estof_n == 1'b1) ? ppn[7:0] : 8'h00;
      exp_idb = {hi, lo};
    end
  endfunction

  // What sheet 28 drives onto PPN. 8B contributes whenever EIPUR_n is low,
  // independently of the two transceivers; the transceivers contribute only
  // in the B-to-A direction (ESTOF_n low). Merged wired-OR, house rule.
  function [15:0] exp_ppn(input [15:0] idb, input [15:0] ppn, input eipu_n,
                          input eipl_n, input estof_n, input eipur_n);
    reg [7:0] hi_244;
    reg [7:0] hi_10b;
    reg [7:0] lo_9b;
    begin
      hi_244 = (eipur_n == 1'b0) ? {7'b0, idb[8]} : 8'h00;
      hi_10b = (eipu_n == 1'b0 && estof_n == 1'b0) ? idb[15:8] : 8'h00;
      lo_9b  = (eipl_n == 1'b0 && estof_n == 1'b0) ? idb[7:0] : 8'h00;
      exp_ppn = {hi_244 | hi_10b, lo_9b};
    end
  endfunction

  /*************************************************************************
   ** Stimulus                                                            **
   *************************************************************************/

  // Data patterns. All-ones and all-zeros catch a stuck driver; the
  // 052525/125252 pair catches a bit reversal; the last two are byte
  // asymmetric so a high/low byte swap cannot pass.
  localparam integer NPAT = 6;
  reg [15:0] pat[0:NPAT-1];

  integer    i;
  integer    j;
  integer    e;
  integer    d;
  reg        eu;
  reg        el;
  reg        es;

  initial begin
    pat[0] = 16'o177777;  // all ones
    pat[1] = 16'o000000;  // all zeros
    pat[2] = 16'o052525;  // alternating
    pat[3] = 16'o125252;  // alternating, inverted
    pat[4] = 16'o123456;  // byte asymmetric: hi=247, lo=056
    pat[5] = 16'o000377;  // low byte only

    EIPU_n       = 1;
    EIPL_n       = 1;
    ESTOF_n      = 1;
    EIPUR_n      = 1;
    IDB_15_0_IN  = 0;
    PPN_25_10_IN = 0;
    repeat (2) @(posedge sysclk);

    // =================================================================== //
    // A. Full sweep with the protect-bit mask INACTIVE (EIPUR_n high):
    //    every data pattern pair against all four byte-enable combinations
    //    in both directions. 6*6*4*2 = 288 vectors, two checks each.
    // =================================================================== //
    for (i = 0; i < NPAT; i = i + 1) begin
      for (j = 0; j < NPAT; j = j + 1) begin
        for (e = 0; e < 4; e = e + 1) begin
          for (d = 0; d < 2; d = d + 1) begin
            eu = e[1];
            el = e[0];
            es = d[0];
            drive(pat[i], pat[j], eu, el, es, 1'b1);
            check_eq(IDB_15_0_OUT, exp_idb(pat[i], pat[j], eu, el, es, 1'b1),
                     "sweep IDB out");
            check_eq(PPN_25_10_OUT, exp_ppn(pat[i], pat[j], eu, el, es, 1'b1),
                     "sweep PPN out");
          end
        end
      end
    end

    // =================================================================== //
    // B. PER-BYTE INDEPENDENCE. One /G asserted, the other released. The
    //    disabled byte must read 000; the enabled byte must carry data.
    //    A bench that only ever enables both bytes together would not
    //    catch a missing enable at all, so these are spelled out.
    // =================================================================== //

    // B1: high byte only, PPN -> IDB. PPN 123456 -> IDB high byte 247.
    drive(16'o177777, 16'o123456, 1'b0, 1'b1, 1'b1, 1'b1);
    check_eq({8'h00, IDB_15_0_OUT[15:8]}, 16'o000247,
             "B1 high byte enabled carries PPN25..PPN18");
    check_eq({8'h00, IDB_15_0_OUT[7:0]}, 16'o000000,
             "B1 low byte DISABLED drives 0 on IDB");
    check_eq(IDB_15_0_OUT, 16'o123400, "B1 whole IDB word");
    check_eq(PPN_25_10_OUT, 16'o000000, "B1 nothing driven back onto PPN");

    // B2: low byte only, PPN -> IDB.
    drive(16'o177777, 16'o123456, 1'b1, 1'b0, 1'b1, 1'b1);
    check_eq({8'h00, IDB_15_0_OUT[15:8]}, 16'o000000,
             "B2 high byte DISABLED drives 0 on IDB");
    check_eq({8'h00, IDB_15_0_OUT[7:0]}, 16'o000056,
             "B2 low byte enabled carries PPN17..PPN10");
    check_eq(IDB_15_0_OUT, 16'o000056, "B2 whole IDB word");
    check_eq(PPN_25_10_OUT, 16'o000000, "B2 nothing driven back onto PPN");

    // B3: high byte only, IDB -> PPN.
    drive(16'o123456, 16'o177777, 1'b0, 1'b1, 1'b0, 1'b1);
    check_eq({8'h00, PPN_25_10_OUT[15:8]}, 16'o000247,
             "B3 high byte enabled carries IDB15..IDB8");
    check_eq({8'h00, PPN_25_10_OUT[7:0]}, 16'o000000,
             "B3 low byte DISABLED drives 0 on PPN");
    check_eq(PPN_25_10_OUT, 16'o123400, "B3 whole PPN word");
    check_eq(IDB_15_0_OUT, 16'o000000, "B3 nothing driven back onto IDB");

    // B4: low byte only, IDB -> PPN.
    drive(16'o123456, 16'o177777, 1'b1, 1'b0, 1'b0, 1'b1);
    check_eq({8'h00, PPN_25_10_OUT[15:8]}, 16'o000000,
             "B4 high byte DISABLED drives 0 on PPN");
    check_eq({8'h00, PPN_25_10_OUT[7:0]}, 16'o000056,
             "B4 low byte enabled carries IDB7..IDB0");
    check_eq(PPN_25_10_OUT, 16'o000056, "B4 whole PPN word");
    check_eq(IDB_15_0_OUT, 16'o000000, "B4 nothing driven back onto IDB");

    // B5: the two bytes must not leak into each other. Enable only the
    //     high byte with a word that is non-zero ONLY in the low byte;
    //     both outputs must then be completely empty.
    drive(16'o000377, 16'o000377, 1'b0, 1'b1, 1'b1, 1'b1);
    check_eq(IDB_15_0_OUT, 16'o000000,
             "B5 low-byte-only PPN data with high byte enabled");
    drive(16'o177400, 16'o177400, 1'b1, 1'b0, 1'b1, 1'b1);
    check_eq(IDB_15_0_OUT, 16'o000000,
             "B5 high-byte-only PPN data with low byte enabled");

    // =================================================================== //
    // C. DIRECTION CONTROL. ESTOF_n is one shared DIR for both chips. With
    //    ESTOF_n low the sheet transfers IDB to PPN and must NOT drive IDB
    //    at the same time; with ESTOF_n high the reverse.
    // =================================================================== //
    for (i = 0; i < NPAT; i = i + 1) begin
      // IDB -> PPN, both bytes enabled: IDB side must stay silent
      drive(pat[i], 16'o177777, 1'b0, 1'b0, 1'b0, 1'b1);
      check_eq(IDB_15_0_OUT, 16'o000000,
               "C IDB-to-PPN direction must not drive IDB");
      check_eq(PPN_25_10_OUT, pat[i], "C IDB-to-PPN transfers the word");

      // PPN -> IDB, both bytes enabled: PPN side must stay silent
      drive(16'o177777, pat[i], 1'b0, 1'b0, 1'b1, 1'b1);
      check_eq(PPN_25_10_OUT, 16'o000000,
               "C PPN-to-IDB direction must not drive PPN");
      check_eq(IDB_15_0_OUT, pat[i], "C PPN-to-IDB transfers the word");
    end

    // =================================================================== //
    // D. EIPUR_n - chip 8B, the protect-bit mask. It is gated by EIPUR_n
    //    ALONE: PPN25..PPN19 are pulled to 0 and PPN18 takes IDB8.
    // =================================================================== //

    // D1: mask on, both transceivers off, IDB8 = 1 (000400 sets bit 8).
    drive(16'o000400, 16'o177777, 1'b1, 1'b1, 1'b1, 1'b1);
    check_eq(PPN_25_10_OUT, 16'o000000, "D1 control: mask off, nothing driven");
    drive(16'o000400, 16'o177777, 1'b1, 1'b1, 1'b1, 1'b0);
    check_eq(PPN_25_10_OUT, 16'o000400,
             "D1 mask on with IDB8=1 -> PPN18=1, PPN25..19=0");
    check_eq(IDB_15_0_OUT, 16'o000000, "D1 mask does not drive IDB");

    // D2: mask on, IDB8 = 0 but every other IDB bit set - the mask must
    //     swallow all of them.
    drive(16'o177377, 16'o177777, 1'b1, 1'b1, 1'b1, 1'b0);
    check_eq(PPN_25_10_OUT, 16'o000000,
             "D2 mask on with IDB8=0 -> whole PPN high byte 0");
    check_eq(IDB_15_0_OUT, 16'o000000, "D2 mask does not drive IDB");

    // D3: mask on and the direction is PPN -> IDB, so 10B forwards the
    //     MASKED high byte to IDB, not the raw PPN25..PPN18.
    drive(16'o000400, 16'o177777, 1'b0, 1'b1, 1'b1, 1'b0);
    check_eq({8'h00, IDB_15_0_OUT[15:8]}, 16'o000001,
             "D3 masked high byte reaches IDB (IDB8=1)");
    check_eq(IDB_15_0_OUT, 16'o000400, "D3 whole IDB word, low byte silent");
    drive(16'o177377, 16'o177777, 1'b0, 1'b1, 1'b1, 1'b0);
    check_eq(IDB_15_0_OUT, 16'o000000,
             "D3 masked high byte reaches IDB (IDB8=0)");

    // D4: mask on, both transceivers enabled, PPN -> IDB. High byte is the
    //     masked value, low byte is the untouched PPN17..PPN10.
    drive(16'o000400, 16'o123456, 1'b0, 1'b0, 1'b1, 1'b0);
    check_eq(IDB_15_0_OUT, 16'o000456, "D4 masked high byte + real low byte");
    check_eq(PPN_25_10_OUT, 16'o000400,
             "D4 8B still drives the PPN node while 10B reads it");

    // D5: mask on but the mask input IDB8 sweeps against every pattern,
    //     with the transceivers held off. Nothing but PPN18 may move.
    for (i = 0; i < NPAT; i = i + 1) begin
      drive(pat[i], 16'o177777, 1'b1, 1'b1, 1'b1, 1'b0);
      check_eq(PPN_25_10_OUT, {7'b0, pat[i][8], 8'h00}, "D5 mask output");
      check_eq(IDB_15_0_OUT, 16'o000000, "D5 mask never drives IDB");
    end

    // D6: RECORDED ONLY, not asserted. EIPUR_n low together with EIPU_n low
    //     and ESTOF_n low puts 8B and 10B on the PPN high byte at the same
    //     time - real driver contention on the board. Printed so a future
    //     change to the resolution is at least visible in the log.
    drive(16'o177777, 16'o000000, 1'b0, 1'b1, 1'b0, 1'b0);
    $display("[record] 8B/10B contention on PPN high byte: PPN_OUT=%06o",
             PPN_25_10_OUT);

    // =================================================================== //
    // E. A FULLY DISABLED SHEET DRIVES NOTHING. Both /G released and the
    //    mask released: whatever is on either input bus, both outputs must
    //    be 000000 in both directions. If the sheet instead copies its
    //    input to its output, the parent's wired-OR merges in
    //    CPU_MMU_24.v and CPU_15.v turn that copy into a combinational
    //    ring that feeds a driver's own output back into its input.
    // =================================================================== //
    for (i = 0; i < NPAT; i = i + 1) begin
      for (j = 0; j < NPAT; j = j + 1) begin
        for (d = 0; d < 2; d = d + 1) begin
          es = d[0];
          drive(pat[i], pat[j], 1'b1, 1'b1, es, 1'b1);
          check_eq(IDB_15_0_OUT, 16'o000000, "E disabled sheet drives IDB 0");
          check_eq(PPN_25_10_OUT, 16'o000000, "E disabled sheet drives PPN 0");
        end
      end
    end

    // =================================================================== //
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)", errors,
               checks, EXPECTED_CHECKS);
    $finish;
  end

  initial begin
    #500000;
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule

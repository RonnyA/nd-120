`timescale 1ns / 1ps

/**************************************************************************
** Testbench for CPU_STOC_35 - IDB to CD gate (sheet 35 of 50)           **
**                                                                       **
** Exhaustive: all 65536 IDB values under both STOC_n levels.            **
** Golden function re-derived from the schematic intent: STOC_n low      **
** passes IDB through to CD; STOC_n high disables the driver, which in   **
** this FPGA-targeted netlist means CD drives 0 (repo tri-state          **
** convention - the source comment still says "high-impedance", the      **
** code drives 16'b0; comment/code mismatch reported, not changed).      **
**                                                                       **
** No VERILATOR_SIM / FPGA_FF_MODE ifdefs in the DUT - one build covers  **
** the only code path.                                                   **
**                                                                       **
** Verdict: TB_RESULT: PASS (<n> checks) with a hard expected count.     **
***************************************************************************/

module CPU_STOC_35_tb;

  localparam EXPECTED_CHECKS = 131072;  // 2 * 65536

  reg [15:0] idb;
  reg stoc_n;
  wire [15:0] cd;

  CPU_STOC_35 dut (
      .IDB_15_0(idb),
      .CD_15_0 (cd),
      .STOC_n  (stoc_n)
  );

  integer checks;
  integer errors;
  integer s;
  integer v;
  reg [15:0] expected;

  initial begin
    checks = 0;
    errors = 0;

    for (s = 0; s < 2; s = s + 1) begin
      stoc_n = s[0];
      for (v = 0; v < 65536; v = v + 1) begin
        idb = v[15:0];
        #1;
        expected = s[0] ? 16'b0 : v[15:0];
        checks = checks + 1;
        if (cd !== expected) begin
          errors = errors + 1;
          if (errors <= 10)
            $display("ERROR: STOC_n=%b IDB=%04h -> CD=%04h expected %04h", stoc_n, idb, cd,
                     expected);
        end
      end
    end

    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)", errors, checks, EXPECTED_CHECKS);
    $finish;
  end

endmodule

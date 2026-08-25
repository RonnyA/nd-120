/**************************************************************************
** CPU_MMU_CSR_26 - exhaustive contract testbench                        **
** (sheet 26, CACHE STATUS REGISTER)                                     **
**                                                                       **
** The module is two things bolted together and BOTH are pure            **
** combinational fan-out, so it can be tested EXHAUSTIVELY - all 128     **
** input combinations, no sampling:                                      **
**                                                                       **
**   a) one 74LS244 (chip 27H) buffering STP / EMPID~ / EDO~ / LCS~,     **
**      disabled by PD2. A swapped pair here silently reroutes the       **
**      cache-disable and control-store-load lines.                      **
**   b) the 4-bit cache status word onto IDB, gated by ECSR~:            **
**          IDB0 = CUP, IDB1 = CON, IDB2 = ~CON, IDB3 = 1                **
**      IDB1 and IDB2 must be COMPLEMENTS of each other on every         **
**      pattern - that pair is exactly the shape of the transcription    **
**      bugs this project keeps finding (CGA_INTR_CNTLR swapped FIDBO    **
**      bits 1 and 2), so it is checked as a named property, not just    **
**      as part of the vector compare.                                   **
**                                                                       **
** Repo convention verified explicitly: with ECSR~ high (not selected)   **
** and with PD2 asserted, the outputs must be ZERO, not z - these feed   **
** OR-ed buses.                                                          **
**                                                                       **
** This is a SPECIFICATION test: the bit assignment is stated in the     **
** port comments of the RTL and in the chip function.                    **
**                                                                       **
** Run: cd Verilog/CPU-BOARD-3202/sim && make test-csr26                 **
**                                                                       **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CPU_MMU_CSR_26_tb;

  reg  STP, EMPID_n, EDO_n, LCS_n, PD2, CUP, CON, ECSR_n;
  wire BSTP, BEMPID_n, BEDO_n, BLCS_n;
  wire [3:0] IDB_3_0;

  integer errors = 0;
  integer checks = 0;
  integer v;

  CPU_MMU_CSR_26 DUT (
      .STP(STP), .EMPID_n(EMPID_n), .EDO_n(EDO_n), .LCS_n(LCS_n), .PD2(PD2),
      .CUP(CUP), .CON(CON), .ECSR_n(ECSR_n),
      .BSTP(BSTP), .BEMPID_n(BEMPID_n), .BEDO_n(BEDO_n), .BLCS_n(BLCS_n),
      .IDB_3_0(IDB_3_0)
  );

  task expect1;
    input [255:0] name;
    input got, want;
    begin
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: got %b want %b  (STP=%b EMPID_n=%b EDO_n=%b LCS_n=%b PD2=%b CUP=%b CON=%b ECSR_n=%b)",
                 name, got, want, STP, EMPID_n, EDO_n, LCS_n, PD2, CUP, CON, ECSR_n);
      end
    end
  endtask

  initial begin
    $dumpfile("CPU_MMU_CSR_26_tb.vcd");
    $dumpvars(0, CPU_MMU_CSR_26_tb);
    // Keep the committed waveform SHORT and readable: this testbench
    // runs far more stimulus than anyone wants to open in GTKWave, so
    // only the opening 300 ns is recorded. The pass/fail verdict comes
    // from the text output, never from the waveform.
    #300 $dumpoff;
  end

  initial begin
    $display("=====================================================");
    $display(" CPU_MMU_CSR_26 (sheet 26) exhaustive testbench");
    $display(" all 256 input combinations");
    $display("=====================================================");

    for (v = 0; v < 256; v = v + 1) begin
      {STP, EMPID_n, EDO_n, LCS_n, PD2, CUP, CON, ECSR_n} = v[7:0];
      #1;

      // ---- 74LS244 half: each buffered output tracks its OWN input, and
      // ---- PD2 forces it to 0. A swapped pair fails here on most patterns.
      expect1("BSTP",     BSTP,     PD2 ? 1'b0 : STP);
      expect1("BEMPID_n", BEMPID_n, PD2 ? 1'b0 : EMPID_n);
      expect1("BEDO_n",   BEDO_n,   PD2 ? 1'b0 : EDO_n);
      expect1("BLCS_n",   BLCS_n,   PD2 ? 1'b0 : LCS_n);

      // ---- status word half
      expect1("IDB0_CUP",  IDB_3_0[0], ECSR_n ? 1'b0 : CUP);
      expect1("IDB1_CON",  IDB_3_0[1], ECSR_n ? 1'b0 : CON);
      expect1("IDB2_CONn", IDB_3_0[2], ECSR_n ? 1'b0 : ~CON);
      expect1("IDB3_FIN",  IDB_3_0[3], ECSR_n ? 1'b0 : 1'b1);

      // ---- named property: while SELECTED, IDB1 and IDB2 are complements.
      // ---- If the pair were ever wired from the same source (or swapped
      // ---- onto the same polarity) this fires immediately.
      if (!ECSR_n) begin
        checks = checks + 1;
        if (IDB_3_0[1] === IDB_3_0[2]) begin
          errors = errors + 1;
          $display("FAIL CON_PAIR_NOT_COMPLEMENT: CON=%b IDB1=%b IDB2=%b",
                   CON, IDB_3_0[1], IDB_3_0[2]);
        end
      end
    end

    // ---- named property: not selected means the module contributes
    // ---- EXACTLY ZERO to the IDB, for every data pattern.
    ECSR_n = 1'b1;
    for (v = 0; v < 4; v = v + 1) begin
      {CUP, CON} = v[1:0];
      #1;
      checks = checks + 1;
      if (IDB_3_0 !== 4'b0000) begin
        errors = errors + 1;
        $display("FAIL DESELECTED_NOT_ZERO: IDB_3_0=%b (CUP=%b CON=%b)", IDB_3_0, CUP, CON);
      end
    end

    // ---- named property: PD2 kills all four buffered lines at once.
    PD2 = 1'b1; STP = 1'b1; EMPID_n = 1'b1; EDO_n = 1'b1; LCS_n = 1'b1;
    #1;
    checks = checks + 1;
    if ({BSTP, BEMPID_n, BEDO_n, BLCS_n} !== 4'b0000) begin
      errors = errors + 1;
      $display("FAIL PD2_DOES_NOT_KILL_BUFFERS: %b", {BSTP, BEMPID_n, BEDO_n, BLCS_n});
    end

    // ---- named property: PD2 must NOT affect the IDB status word (the
    // ---- 244 and the status buffer are different chips on the drawing).
    PD2 = 1'b1; ECSR_n = 1'b0; CUP = 1'b1; CON = 1'b1; #1;
    checks = checks + 1;
    if (IDB_3_0 !== 4'b1011) begin
      errors = errors + 1;
      $display("FAIL PD2_LEAKS_INTO_IDB: IDB_3_0=%b expected 1011", IDB_3_0);
    end

    // ---- IDB3 is documented as a constant 1 while selected. Prove it is
    // ---- not accidentally driven from a data bit.
    ECSR_n = 1'b0;
    for (v = 0; v < 4; v = v + 1) begin
      {CUP, CON} = v[1:0]; #1;
      checks = checks + 1;
      if (IDB_3_0[3] !== 1'b1) begin
        errors = errors + 1;
        $display("FAIL IDB3_NOT_CONSTANT_1: CUP=%b CON=%b IDB3=%b", CUP, CON, IDB_3_0[3]);
      end
    end

    $display("-----------------------------------------------------");
    $display(" checks run : %0d", checks);
    $display(" failures   : %0d", errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $display("=====================================================");
    $finish;
  end

endmodule

`default_nettype wire

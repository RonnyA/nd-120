/**************************************************************************
** CPU_MMU_PTIDB_30 - bidirectional bus path testbench                   **
** (sheet 30, PT TO IDB - two 74PCT245 collapsed into one 16-bit path)   **
**                                                                       **
** This module is the ONLY door between the page-table data bus PT and   **
** the CPU's internal data bus IDB, and it is exactly the shape that     **
** has bitten this project before: an enable, a direction, and two       **
** 16-bit ports where a mis-wired bit or an inverted direction is        **
** invisible until a page-table read returns the wrong word.             **
**                                                                       **
** WHAT THIS WOULD CATCH                                                 **
**   - direction inverted (WRITE meaning read)                           **
**   - enable inverted (EPTI~ active high)                               **
**   - either port driving while DISABLED - fatal here, because both     **
**     IDB and PT are OR-ed buses inside the FPGA, so a disabled path    **
**     that does not drive 0 corrupts whatever else is driving           **
**   - BOTH ports driving at once (the transceiver must be one-way)      **
**   - any bit reaching the wrong bit position, or the far-side INPUT    **
**     leaking into the same side's OUTPUT (the structural edge that     **
**     created the TTL_74245 combinational loop on the FIDB bus)         **
**                                                                       **
** COVERAGE: all 4 control states x (16 one-hot + 16 one-cold + rails +  **
** randomised patterns) on both ports, checked against a reference       **
** model, plus five named property checks.                               **
** SPECIFICATION test - the 245 function table is the spec.              **
**                                                                       **
** Run: cd Verilog/CPU-BOARD-3202/sim && make test-ptidb30               **
**                                                                       **
** Last reviewed: 20-AUG-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/
`timescale 1ns / 1ps
`default_nettype none

module CPU_MMU_PTIDB_30_tb;

  reg         WRITE, EPTI_n;
  reg  [15:0] IDB_15_0_IN, PT_15_0_IN;
  wire [15:0] IDB_15_0_OUT, PT_15_0_OUT;

  integer errors = 0;
  integer checks = 0;
  integer i, w, e;
  reg [15:0] want_idb, want_pt, hold;

  CPU_MMU_PTIDB_30 DUT (
      .WRITE(WRITE), .EPTI_n(EPTI_n),
      .IDB_15_0_IN(IDB_15_0_IN), .IDB_15_0_OUT(IDB_15_0_OUT),
      .PT_15_0_IN(PT_15_0_IN),   .PT_15_0_OUT(PT_15_0_OUT)
  );

  // reference model: a 245 with the repo's zero-when-disabled convention.
  // DIR = WRITE: 1 = IDB drives PT ("write to the page table"),
  //              0 = PT drives IDB ("read the page table").
  task compare;
    input [255:0] name;
    begin
      want_idb = (EPTI_n || WRITE)  ? 16'b0 : PT_15_0_IN;
      want_pt  = (EPTI_n || !WRITE) ? 16'b0 : IDB_15_0_IN;
      checks = checks + 2;
      if (IDB_15_0_OUT !== want_idb) begin
        errors = errors + 1;
        if (errors < 15)
          $display("FAIL %0s IDB_OUT: EPTI_n=%b WRITE=%b IDBin=%04h PTin=%04h -> %04h want %04h",
                   name, EPTI_n, WRITE, IDB_15_0_IN, PT_15_0_IN, IDB_15_0_OUT, want_idb);
      end
      if (PT_15_0_OUT !== want_pt) begin
        errors = errors + 1;
        if (errors < 15)
          $display("FAIL %0s PT_OUT: EPTI_n=%b WRITE=%b IDBin=%04h PTin=%04h -> %04h want %04h",
                   name, EPTI_n, WRITE, IDB_15_0_IN, PT_15_0_IN, IDB_15_0_OUT, want_pt);
      end
    end
  endtask

  initial begin
    $dumpfile("CPU_MMU_PTIDB_30_tb.vcd");
    $dumpvars(0, CPU_MMU_PTIDB_30_tb);
    // Keep the committed waveform SHORT and readable: this testbench
    // runs far more stimulus than anyone wants to open in GTKWave, so
    // only the opening 300 ns is recorded. The pass/fail verdict comes
    // from the text output, never from the waveform.
    #300 $dumpoff;
  end

  initial begin
    $display("=====================================================");
    $display(" CPU_MMU_PTIDB_30 (sheet 30) bus path testbench");
    $display("=====================================================");

    for (e = 0; e < 2; e = e + 1) begin
      for (w = 0; w < 2; w = w + 1) begin
        EPTI_n = e[0];
        WRITE  = w[0];

        // one-hot walk on each side - catches a bit landing in the wrong
        // position, which a same-value pattern can never see
        for (i = 0; i < 16; i = i + 1) begin
          IDB_15_0_IN = 16'b1 << i;  PT_15_0_IN = ~(16'b1 << i);
          #1; compare("ONEHOT");
          IDB_15_0_IN = ~(16'b1 << i);  PT_15_0_IN = 16'b1 << i;
          #1; compare("ONECOLD");
        end

        IDB_15_0_IN = 16'h0000; PT_15_0_IN = 16'h0000; #1; compare("ZEROS");
        IDB_15_0_IN = 16'hFFFF; PT_15_0_IN = 16'hFFFF; #1; compare("ONES");
        IDB_15_0_IN = 16'hA5A5; PT_15_0_IN = 16'h5A5A; #1; compare("PATTERN");

        for (i = 0; i < 300; i = i + 1) begin
          IDB_15_0_IN = $random;
          PT_15_0_IN  = $random;
          #1; compare("RANDOM");
        end
      end
    end

    // ---- named property 1: enabled READ (WRITE=0) puts the PT word on the
    // ---- IDB unchanged, and PT_OUT stays at zero - only ONE driver.
    EPTI_n = 1'b0; WRITE = 1'b0; IDB_15_0_IN = 16'hFFFF; PT_15_0_IN = 16'h1234; #1;
    checks = checks + 2;
    if (IDB_15_0_OUT !== 16'h1234) begin
      errors = errors + 1;
      $display("FAIL READ_PATH: IDB_OUT=%04h expected 1234", IDB_15_0_OUT);
    end
    if (PT_15_0_OUT !== 16'h0000) begin
      errors = errors + 1;
      $display("FAIL READ_BACKDRIVE: PT_OUT=%04h must be 0000 during a read", PT_15_0_OUT);
    end

    // ---- named property 2: enabled WRITE mirrors it
    WRITE = 1'b1; IDB_15_0_IN = 16'h4321; PT_15_0_IN = 16'hFFFF; #1;
    checks = checks + 2;
    if (PT_15_0_OUT !== 16'h4321) begin
      errors = errors + 1;
      $display("FAIL WRITE_PATH: PT_OUT=%04h expected 4321", PT_15_0_OUT);
    end
    if (IDB_15_0_OUT !== 16'h0000) begin
      errors = errors + 1;
      $display("FAIL WRITE_BACKDRIVE: IDB_OUT=%04h must be 0000 during a write", IDB_15_0_OUT);
    end

    // ---- named property 3: DISABLED contributes exactly 0 on both ports,
    // ---- whatever the direction and data. This is the OR-ed-bus rule.
    EPTI_n = 1'b1;
    for (w = 0; w < 2; w = w + 1) begin
      WRITE = w[0]; IDB_15_0_IN = 16'hFFFF; PT_15_0_IN = 16'hFFFF; #1;
      checks = checks + 1;
      if (IDB_15_0_OUT !== 16'h0000 || PT_15_0_OUT !== 16'h0000) begin
        errors = errors + 1;
        $display("FAIL DISABLED_NOT_ZERO (WRITE=%b): IDB_OUT=%04h PT_OUT=%04h",
                 WRITE, IDB_15_0_OUT, PT_15_0_OUT);
      end
    end

    // ---- named property 4: the far-side input must NOT reach the same
    // ---- side's output. During a read, changing IDB_IN must not move
    // ---- IDB_OUT - the edge that made the 74245 loop on FIDB.
    EPTI_n = 1'b0; WRITE = 1'b0; PT_15_0_IN = 16'h0F0F;
    IDB_15_0_IN = 16'h0000; #1; hold = IDB_15_0_OUT;
    IDB_15_0_IN = 16'hFFFF; #1;
    checks = checks + 1;
    if (IDB_15_0_OUT !== hold || IDB_15_0_OUT !== 16'h0F0F) begin
      errors = errors + 1;
      $display("FAIL IDB_IN_REACHES_IDB_OUT: %04h -> %04h", hold, IDB_15_0_OUT);
    end
    // mirror on the write direction
    WRITE = 1'b1; IDB_15_0_IN = 16'hF0F0;
    PT_15_0_IN = 16'h0000; #1; hold = PT_15_0_OUT;
    PT_15_0_IN = 16'hFFFF; #1;
    checks = checks + 1;
    if (PT_15_0_OUT !== hold || PT_15_0_OUT !== 16'hF0F0) begin
      errors = errors + 1;
      $display("FAIL PT_IN_REACHES_PT_OUT: %04h -> %04h", hold, PT_15_0_OUT);
    end

    // ---- named property 5: the two ports are never BOTH live at once
    EPTI_n = 1'b0;
    for (w = 0; w < 2; w = w + 1) begin
      WRITE = w[0]; IDB_15_0_IN = 16'hFFFF; PT_15_0_IN = 16'hFFFF; #1;
      checks = checks + 1;
      if ((IDB_15_0_OUT != 0) && (PT_15_0_OUT != 0)) begin
        errors = errors + 1;
        $display("FAIL BOTH_SIDES_DRIVING (WRITE=%b): IDB_OUT=%04h PT_OUT=%04h",
                 WRITE, IDB_15_0_OUT, PT_15_0_OUT);
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

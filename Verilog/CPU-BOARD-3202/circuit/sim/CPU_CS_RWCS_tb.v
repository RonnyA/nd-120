/****************************************************************************
** TESTBENCH: control-store READBACK (the TRA CS / TRA 17 path)             **
**                                                                         **
** WHY THIS EXISTS (07-AUG-2026)                                           **
**                                                                         **
** SINTRAN III refuses to start on this machine with                       **
**   "Micro-code not loaded. CPU revision too low !!"                      **
** Its test is PH-P2-RESTART.NPL:1049-1055:                                **
**   X := 100 ; *150017 ; A =: MICVER ; IF A<<13 THEN <fatal>              **
** i.e. TRA CS (150017) must return the control-store word addressed by X. **
** The ND-120 microcode implements it as (nd-120-delilah-L-from-K.uc,      **
** routine ACS):                                                           **
**   A,X ALUF,ANDAQ  IDBS,ALU  COMM,ADCS      <- latch the CS address      **
**   B,A ALUF,PASSD  IDBS,RCS  COMM,RWCS      <- read the CS word to A     **
** Measured on the full machine: A comes back 000000.                      **
**                                                                         **
** NOTE (08-AUG-2026): an earlier version of this header said "neither     **
** ECSL nor RWCS ever assert". That was WRONG - an artefact of the         **
** value-triggered CSV sampler in sim/nd120_probe.py, which takes one      **
** settled sample per tick and so cannot see a signal that asserts and     **
** clears inside a microcycle. The FST waveform shows both DO assert, and  **
** the correct control-store word does reach the CPU's IDB input. The real **
** fault was the control-store address not being HELD across the read      **
** window; see PAL_44307C.v (MACLK) and CPU_CS_RWCS_CYCLE_tb.v.            **
**                                                                         **
** This bench isolates the HARDWARE half of that path (everything below    **
** the microcode): given a control-store address and a WCS word, does a    **
** COMM=36/MIS=01 (RWCS) cycle put the addressed 16-bit slice on the IDB?  **
** It deliberately drives the module inputs directly - no CPU, no          **
** microcode - so a failure here is RTL, and a PASS here proves the fault  **
** is above this level (the microcode dispatch reaching ACS at all).       **
**                                                                         **
** Checks (all self-verifying, verdict on the last line):                  **
**   1. RWCS command decode: PAL_44408B asserts RWCS_n low for COMM=36     **
**      with MIS1=0, MIS0=1, LCS_n=1 - and for nothing else nearby.        **
**   2. ECSL window: PAL_44305D asserts ECSL_n low during the read cycle   **
**      states its PALASM names (g and h: CC3, and CC2 with CC1 low).      **
**   3. Slice select: with EW selecting word 0..3, the transceiver puts    **
**      exactly CSBITS[15:0] / [31:16] / [47:32] / [63:48] on IDB.         **
**   4. Read direction only: with WCS_n low (write) the transceiver must   **
**      NOT drive IDB.                                                     **
**   5. WCS storage: a word written into the writable control store at a   **
**      defined address reads back byte-exact at that address, and a       **
**      DIFFERENT address is unaffected (addresses 0100, 0777, 3777).      **
**                                                                        **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <n> errors                   **
**                                                                        **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module CPU_CS_RWCS_tb;

  integer errors = 0;

  task ck;
    input        cond;
    input [639:0] what;
    begin
      if (!cond) begin
        $display("FAIL: %0s", what);
        errors = errors + 1;
      end else begin
        $display("[ ok ] %0s", what);
      end
    end
  endtask

  // ---------------------------------------------------------------- clock
  reg clk = 0;
  always #10 clk = ~clk;

  // ============================================================ check 1
  // RWCS command decode (PAL_44408B): COMM 36 octal with MIS = 01.
  reg  c4, c3, c2, c1, c0, m1, m0, lcs_n, oe_n;
  wire rwcs_n_dec, opclcs_dec, vex_dec, ldexm_n_dec;

  PAL_44408B UDEC (
      .CK(clk),
      .C4(c4), .C3(c3), .C2(c2), .C1(c1), .C0(c0),
      .M1(m1), .M0(m0),
      .IDB2(1'b0),
      .LCS_n(lcs_n),
      .OE_n(oe_n),
      .RWCS_n(rwcs_n_dec),
      .OPCLCS(opclcs_dec),
      .VEX(vex_dec),
      .LDEXM_n(ldexm_n_dec)
  );

  task drive_comm;
    input [4:0] comm;
    input [1:0] mis;
    begin
      {c4, c3, c2, c1, c0} = comm;
      {m1, m0} = mis;
      @(posedge clk);
      @(posedge clk);   // registered PAL: one edge to load, one to settle
    end
  endtask

  // ============================================================ check 2/3/4
  // ECSL window (PAL_44305D) and the transceiver slice select.
  reg        rwcs_in, wcs_n_in, cc1, cc2, cc3, term_n;
  wire       ecsl_n, ewca_n, wcstb_n, wica_n, eupp_n, elow_n;

  // PAL_44305D takes ACTIVE-LOW inputs (it inverts them internally).
  PAL_44305D UCTL (
      .FORM_n(1'b1),
      .CC1_n(~cc1), .CC2_n(~cc2), .CC3_n(~cc3),
      .LCS_n(1'b1),
      .RWCS_n(~rwcs_in),
      .WCS_n(wcs_n_in),
      .FETCH(1'b0),
      .BRK_n(1'b1),
      .TERM_n(term_n),
      .WICA_n(wica_n), .WCSTB_n(wcstb_n), .ECSL_n(ecsl_n),
      .EWCA_n(ewca_n), .EUPP_n(eupp_n), .ELOW_n(elow_n),
      .WCA_n(1'b1),
      .LUA12(1'b0)
  );

  reg  [63:0] csbits_in;
  reg  [15:0] idb_in;
  reg  [ 3:0] ew_n;
  wire [15:0] idb_out;
  wire [63:0] csbits_out;

  CPU_CS_TCV_20 UTCV (
      .sysclk(clk),
      .sys_rst_n(1'b1),
      .CSBITS(csbits_in),
      .CSBITS_OUT(csbits_out),
      .IDB_15_0_IN(idb_in),
      .IDB_15_0_OUT(idb_out),
      .ECSL_n(ecsl_n),
      .WCS_n(wcs_n_in),
      .EW_3_0_n(ew_n)
  );

  // ============================================================ check 5
  // Writable control store: write a word at an address, read it back.
  reg  [63:0] wcs_wdata;
  reg  [11:0] lua, uua;
  reg         elow_n_r, eupp_n_r;
  reg  [ 3:0] ww_n, wu_n;
  wire [63:0] wcs_rdata;

  CPU_CS_WCS_21_22 UWCS (
      .sysclk(clk),
      .sys_rst_n(1'b1),
      .CSBITS_63_0(wcs_wdata),
      .CSBITS_63_0_OUT(wcs_rdata),
      .LUA_11_0(lua),
      .ELOW_n(elow_n_r),
      .WW0_n(ww_n[0]), .WW1_n(ww_n[1]), .WW2_n(ww_n[2]), .WW3_n(ww_n[3]),
      .UUA_11_0(uua),
      .EUPP_n(eupp_n_r),
      .WU0_n(wu_n[0]), .WU1_n(wu_n[1]), .WU2_n(wu_n[2]), .WU3_n(wu_n[3])
  );

  // Write one 64-bit word into the store at `addr` (both halves enabled).
  task wcs_write;
    input [11:0] addr;
    input [63:0] data;
    begin
      lua       = addr;
      uua       = addr;
      wcs_wdata = data;
      elow_n_r  = 1'b0;
      eupp_n_r  = 1'b0;
      ww_n      = 4'b0000;   // all four byte strobes active (low)
      wu_n      = 4'b0000;
      @(posedge clk);
      @(posedge clk);
      ww_n      = 4'b1111;
      wu_n      = 4'b1111;
      @(posedge clk);
    end
  endtask

  task wcs_read;
    input [11:0] addr;
    begin
      lua      = addr;
      uua      = addr;
      elow_n_r = 1'b0;
      eupp_n_r = 1'b0;
      @(posedge clk);
      @(posedge clk);
    end
  endtask

  // ---------------------------------------------------------------- test
  localparam [63:0] PATTERN_A = 64'hDEAD_BEEF_1234_5678;
  localparam [63:0] PATTERN_B = 64'h0F1E_2D3C_4B5A_6978;


  // Present a control-store slice and then assert ECSL, which is the order the
  // hardware works in: the 74PCT373 latches on sheet 20 close on ECSL~'s
  // falling edge, so the data must be settled BEFORE ECSL is asserted.
  // States: (cc3,cc2,cc1) = (0,0,0) releases ECSL, (1,0,0) asserts it.
  task slice_read;
    input [3:0] sel_n;
    integer k;
    begin
      cc3 = 1'b0; cc2 = 1'b0; cc1 = 1'b0;   // ECSL released, latch transparent
      ew_n = sel_n;
      for (k = 0; k < 4; k = k + 1) @(posedge clk);
      cc3 = 1'b1; cc2 = 1'b0; cc1 = 1'b0;   // ECSL asserts -> latch closes
      for (k = 0; k < 4; k = k + 1) @(posedge clk);
      #1;
    end
  endtask

  initial begin
    c4 = 0; c3 = 0; c2 = 0; c1 = 0; c0 = 0; m1 = 0; m0 = 0;
    lcs_n = 1'b1; oe_n = 1'b0;
    rwcs_in = 0; wcs_n_in = 1'b1; cc1 = 0; cc2 = 0; cc3 = 0; term_n = 1'b1;
    csbits_in = 64'd0; idb_in = 16'd0; ew_n = 4'b1111;
    wcs_wdata = 64'd0; lua = 12'd0; uua = 12'd0;
    elow_n_r = 1'b1; eupp_n_r = 1'b1; ww_n = 4'b1111; wu_n = 4'b1111;
    repeat (4) @(posedge clk);

    // ---- 1. RWCS command decode ------------------------------------
    drive_comm(5'o36, 2'b01);            // COMM 36, MIS1=0 MIS0=1
    ck(rwcs_n_dec === 1'b0, "COMM=36 MIS=01 decodes RWCS (active low)");

    drive_comm(5'o36, 2'b11);            // wrong MIS: that is LCS, not RWCS
    ck(rwcs_n_dec === 1'b1, "COMM=36 MIS=11 does NOT decode RWCS");

    drive_comm(5'o35, 2'b01);            // neighbouring command
    ck(rwcs_n_dec === 1'b1, "COMM=35 MIS=01 does NOT decode RWCS");

    drive_comm(5'o36, 2'b01);
    lcs_n = 1'b0;                        // during LCS the command is a load
    @(posedge clk); @(posedge clk);
    ck(rwcs_n_dec === 1'b1, "RWCS suppressed while LCS_n is low");
    lcs_n = 1'b1;

    // ---- 2. ECSL window --------------------------------------------
    rwcs_in = 1'b1; wcs_n_in = 1'b1; term_n = 1'b1;
    cc3 = 1'b1; cc2 = 1'b0; cc1 = 1'b0;
    #1;
    ck(ecsl_n === 1'b0, "ECSL asserted in the CC3 read-hold state (g)");

    cc3 = 1'b0; cc2 = 1'b1; cc1 = 1'b0;
    #1;
    ck(ecsl_n === 1'b0, "ECSL asserted in the CC2/!CC1 overlap state (h)");

    cc3 = 1'b0; cc2 = 1'b0; cc1 = 1'b0;
    #1;
    ck(ecsl_n === 1'b1, "ECSL released outside the read window");

    rwcs_in = 1'b0; cc3 = 1'b1;
    #1;
    ck(ecsl_n === 1'b1, "ECSL stays released without the RWCS command");

    // ---- 3. slice select -------------------------------------------
    // CORRECTED 08-AUG-2026. This block used to assert ECSL once and then
    // change the word select underneath it, expecting the IDB to follow
    // combinationally. That encoded a pass-through model of sheet 20 which is
    // wrong: chips 8C and 9C are 74PCT373 latches whose C (pin 11) and /OC
    // (pin 1) are BOTH driven by ECSL~, so while ECSL is asserted the latch is
    // CLOSED and the D inputs are ignored. The word select is stable for the
    // whole microcycle in the real machine, so nothing is lost by driving it
    // the way the hardware does: present the slice FIRST, then assert ECSL.
    // (The "held while the select moves" property is asserted directly in
    // CPU_CS_TCV_20_tb.v check 5.)
    rwcs_in = 1'b1; wcs_n_in = 1'b1;
    csbits_in = PATTERN_A;

    slice_read(4'b1110);
    ck(idb_out === PATTERN_A[15:0],  "EW0 puts CSBITS[15:0] on IDB");
    slice_read(4'b1101);
    ck(idb_out === PATTERN_A[31:16], "EW1 puts CSBITS[31:16] on IDB");
    slice_read(4'b1011);
    ck(idb_out === PATTERN_A[47:32], "EW2 puts CSBITS[47:32] on IDB");
    slice_read(4'b0111);
    ck(idb_out === PATTERN_A[63:48], "EW3 puts CSBITS[63:48] on IDB");

    // ---- 4. read direction only ------------------------------------
    wcs_n_in = 1'b0;   // write direction
    ew_n = 4'b1110; #1;
    ck(idb_out === 16'd0, "no IDB drive while WCS_n is low (write cycle)");
    wcs_n_in = 1'b1;

    // ---- 5. WCS storage at defined addresses ------------------------
    // 0100 is the address SINTRAN itself uses (X := 100 before TRA CS).
    wcs_write(12'o0100, PATTERN_A);
    wcs_write(12'o0777, PATTERN_B);
    wcs_write(12'o3777, ~PATTERN_A);

    wcs_read(12'o0100);
    ck(wcs_rdata === PATTERN_A, "WCS address 0100 reads back what was written");
    wcs_read(12'o0777);
    ck(wcs_rdata === PATTERN_B, "WCS address 0777 reads back what was written");
    wcs_read(12'o3777);
    ck(wcs_rdata === ~PATTERN_A, "WCS address 3777 reads back what was written");
    wcs_read(12'o0100);
    ck(wcs_rdata === PATTERN_A, "WCS address 0100 unaffected by the other writes");

    // ---- 6. the whole hardware path, end to end ---------------------
    // Address 0100 holding a word whose low slice is a plausible microcode
    // revision: an RWCS read cycle must present exactly that on the IDB.
    wcs_write(12'o0100, 64'h0000_0000_0000_8013);   // bit15 set + revision 023
    wcs_read(12'o0100);
    csbits_in = wcs_rdata;
    rwcs_in = 1'b1; wcs_n_in = 1'b1;
    // Same correction as block 3: present the slice, THEN assert ECSL, because
    // the sheet-20 74PCT373 latches capture on ECSL~'s falling edge.
    slice_read(4'b1110);
    ck(idb_out === 16'h8013,
       "end-to-end: WCS word at 0100 reaches the IDB through an RWCS read");
    ck(idb_out[15] === 1'b1 && idb_out[11:0] >= 12'o013,
       "the value SINTRAN reads satisfies its revision test (>= 013, bit15 set)");

    if (errors == 0) $display("TB_RESULT: PASS (control-store readback path)");
    else             $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #200000;
    $display("TB_RESULT: FAIL watchdog");
    $finish;
  end

endmodule

/**************************************************************************
** MEM_ERROR_47_tb - unit testbench for the PES/PEA error-capture sheet    **
**                                                                        **
** Sheet 47 latches, on a LOCAL parity error, the error STATUS (PES) and  **
** error ADDRESS (PEA) so software can read them via TRA PES / TRA PEA.    **
** This TB proves the capture datapath works and encodes the fields the   **
** way the diagnostic (TPE) expects - part of the "memory reads as Mpm5,   **
** not Local" investigation (a Local bank is one whose parity error path   **
** actually latches + reports; see MEM_RAM_49_SIM_PARITY_tb + the PACK16   **
** / LPERR_n|1 / SWDIS->GND blockers upstream that stop the error ever     **
** reaching here on the shipped build).                                    **
**                                                                        **
** Strobes come from PAL_45009B (combinational):                          **
**   SPESL = ~(RDATA_n | BLOCKL25 | EPEAL | EPESL | MR)   (RDATA rising)   **
**   SPEAL = ~(BCGNT50_n | BLOCKL25 | EPEAL | MR)         (BCGNT50 rising) **
**   EPESL_n = ~(PS_n==0 & RERR_n)   EPEAL_n = ~(PA_n==0 & RERR_n)         **
** The 74374 latches capture D on a CK rising edge sampled by sysclk and   **
** drive Q only when their OE_n (EPESL_n / EPEAL_n) is low; IDB = PEA|PES. **
**                                                                        **
** PES[15:8] = {FETCH, CGNT50_n, 1,1,1, CORR_n, HIERR, LOERR}             **
** PES[7:0]  = LBD[23:16]     PEA[15:0] = LBD[15:0]                        **
**                                                                        **
** Ronny Hansen (unit TB)                                                 **
***************************************************************************/
`timescale 1ns / 1ps

module MEM_ERROR_47_tb;

  // clocks
  reg         sysclk = 0, OSC = 0, sys_rst_n = 0;
  always #5  sysclk = ~sysclk;
  always #7  OSC    = ~OSC;      // independent edge for the PAL BLOCKL FF

  // DUT inputs
  reg         BCGNT50 = 0, BLOCKL25 = 1, CGNT50_n = 1, CORR_n = 1;
  reg         FETCH = 0, HIERR = 0, LERR_n = 1, LOERR = 0, MR_n = 1;
  reg         PA_n = 1, PD4 = 0, PS_n = 1, RDATA25 = 0, RERR_n = 1;
  reg  [23:0] LBD_23_0_IN = 24'h000000;

  // DUT outputs
  wire        BLOCKL_n;
  wire [15:0] IDB_15_0_OUT;

  integer errors = 0;

  MEM_ERROR_47 dut (
      .sysclk(sysclk), .OSC(OSC), .sys_rst_n(sys_rst_n),
      .BCGNT50(BCGNT50), .BLOCKL25(BLOCKL25), .CGNT50_n(CGNT50_n),
      .CORR_n(CORR_n), .FETCH(FETCH), .HIERR(HIERR),
      .LBD_23_0_IN(LBD_23_0_IN), .LERR_n(LERR_n), .LOERR(LOERR),
      .MR_n(MR_n), .PA_n(PA_n), .PD4(PD4), .PS_n(PS_n),
      .RDATA25(RDATA25), .RERR_n(RERR_n),
      .BLOCKL_n(BLOCKL_n), .IDB_15_0_OUT(IDB_15_0_OUT)
  );

  task automatic check(input cond, input string name);
    begin
      if (cond) $display("  PASS: %0s", name);
      else begin $display("  FAIL: %0s", name); errors = errors + 1; end
    end
  endtask

  // Hold both output enables OFF (EPESL_n=EPEAL_n=1) so the registers can be
  // clocked without driving IDB: PS_n=1 & PA_n=1 (PS=PA=0) => both enables off.
  task automatic enables_off;
    begin PS_n = 1; PA_n = 1; RERR_n = 1; end
  endtask

  reg [15:0] pes, pea;

  initial begin
    $display("=== MEM_ERROR_47_tb : PES/PEA capture on local parity error ===");

    // ---- power-on reset ----------------------------------------------
    sys_rst_n = 0; MR_n = 0; RDATA25 = 0; BCGNT50 = 0; enables_off();
    repeat (3) @(posedge sysclk);
    sys_rst_n = 1; MR_n = 1;
    @(posedge sysclk);

    // ---- present a LOCAL parity error at a known address --------------
    // low-byte parity error (LOERR), address 0x123456
    LERR_n = 0; LOERR = 1; HIERR = 0; CORR_n = 0; FETCH = 1; CGNT50_n = 1;
    LBD_23_0_IN = 24'h123456;
    BLOCKL25 = 1;            // port BLOCKL25=1 -> PAL BLOCKL25=0 (not blocked)
    enables_off();          // capture with outputs disabled
    @(posedge sysclk);

    // ---- strobe SPESL (RDATA rising) -> capture PES status byte -------
    RDATA25 = 0; @(posedge sysclk);
    RDATA25 = 1; repeat (3) @(posedge sysclk);   // SPESL high across sysclk edge
    RDATA25 = 0; @(posedge sysclk);

    // ---- strobe SPEAL (BCGNT50 rising) -> capture PES_lo + PEA --------
    BCGNT50 = 0; @(posedge sysclk);
    BCGNT50 = 1; repeat (3) @(posedge sysclk);
    BCGNT50 = 0; @(posedge sysclk);

    // ---- BLOCKL should have set on the local error -------------------
    check(BLOCKL_n === 1'b0, "BLOCKL_n asserted (0) on local parity error");

    // ---- read PES: enable PES output (PS_n=0 & RERR_n=1), PEA off -----
    PS_n = 0; PA_n = 1; RERR_n = 1; repeat (2) @(posedge sysclk);
    pes = IDB_15_0_OUT;
    // PES[15:8] = {FETCH=1,CGNT50_n=1,1,1,1,CORR_n=0,HIERR=0,LOERR=1} = 0xF9
    check(pes[15:8] == 8'hF9, "PES status byte == 0xF9 {fetch,cgnt50_n,111,corr_n,hierr,loerr}");
    check(pes[7:0]  == 8'h12, "PES low byte == phys addr [23:16] (0x12)");

    // ---- read PEA: enable PEA output (PA_n=0 & RERR_n=1), PES off -----
    PS_n = 1; PA_n = 0; RERR_n = 1; repeat (2) @(posedge sysclk);
    pea = IDB_15_0_OUT;
    check(pea == 16'h3456, "PEA == phys addr [15:0] (0x3456)");

    // ---- second error at a different address latches the new values --
    // (registers are not locked by this sheet - re-strobe captures fresh)
    LOERR = 0; HIERR = 1; CORR_n = 0; LBD_23_0_IN = 24'h0ABCDE; FETCH = 0; CGNT50_n = 0;
    enables_off();
    RDATA25 = 0; @(posedge sysclk);
    RDATA25 = 1; repeat (3) @(posedge sysclk);
    RDATA25 = 0; @(posedge sysclk);
    BCGNT50 = 1; repeat (3) @(posedge sysclk);
    BCGNT50 = 0; @(posedge sysclk);
    PS_n = 0; PA_n = 1; RERR_n = 1; repeat (2) @(posedge sysclk);
    pes = IDB_15_0_OUT;
    // {FETCH=0,CGNT50_n=0,1,1,1,CORR_n=0,HIERR=1,LOERR=0} = 0b0011_1010 = 0x3A
    check(pes[15:8] == 8'h3A, "T2 PES status byte == 0x3A (HIERR set, FETCH/CGNT50_n clear)");
    check(pes[7:0]  == 8'h0A, "T2 PES low byte == addr[23:16] (0x0A)");
    PS_n = 1; PA_n = 0; repeat (2) @(posedge sysclk);
    check(IDB_15_0_OUT == 16'hBCDE, "T2 PEA == addr[15:0] (0xBCDE)");

    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL (%0d checks failed)", errors);
    $finish;
  end

  // safety timeout
  initial begin #200000; $display("TB_RESULT: FAIL (timeout)"); $finish; end

endmodule

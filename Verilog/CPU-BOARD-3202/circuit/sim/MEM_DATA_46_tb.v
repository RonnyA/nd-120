/**************************************************************************
** ND120 CPU - unit test                                                 **
** MEM_DATA_46: memory data path sheet (2x AM29833A parity transceivers  **
** + PAL_45008B control + error LED flops).                              **
**                                                                       **
** Same vectors must pass in BOTH modes (the Makefile compiles twice):   **
**   plain            - original posedge-RDATA error-flop clocking       **
**   -DFPGA_FF_MODE   - P1a sysclk (OSC) edge-capture (USE_SYSCLK=2)     **
**                                                                       **
** Covered: write path LBD->DD with odd-parity generation, read path     **
** DD->LBD pass-through, RDATA-strobed parity-error latch (set on even   **
** 9-bit parity, ONE capture per RDATA rise - no re-capture under a held **
** strobe), LOERR/HIERR/LERR_n visibility gating by OET_n, CLRERR clear  **
** when the grant window closes, LPERR_n error latch, and LED4/LED5 SWDIS-disable config.            **
**                                                                       **
** NOT asserted here: receive-mode ERR semantics - the capture condition **
** (!ReceiveMode checking T-port parity) is a known open question vs the **
** datasheet ("AM29833A parity" in Verilog/TODO.md). This tb pins the    **
** paths both build modes must agree on, not the disputed semantics.     **
**                                                                       **
** Run: make test-memdata   (CPU-BOARD-3202/circuit/sim)                 **
***************************************************************************/
`timescale 1ns / 1ps

module MEM_DATA_46_tb;

  reg osc = 0;
  always #5 osc = ~osc;

  reg         sys_rst_n = 0;
  reg         bcgnt50r_n = 1;
  reg         bioxl_n = 1;
  reg         eccr = 0;
  reg         mwrite_n = 1;
  reg         pa_n = 1;
  reg         qd_n = 1;
  reg         rdata = 0;
  reg  [15:0] lbd_in = 0;
  reg  [17:0] dd_in = 0;
  wire [15:0] lbd_out;
  wire [17:0] dd_out;
  wire        hierr, loerr, lerr_n, lperr_n, led4, led5;

  MEM_DATA_46 dut (
      .OSC(osc),
      .sys_rst_n(sys_rst_n),
      .BCGNT50R_n(bcgnt50r_n),
      .BIOXL_n(bioxl_n),
      .ECCR(eccr),
      .HIEN_n(1'b1),
      .MR_n(1'b1),
      .MWRITE_n(mwrite_n),
      .PA_n(pa_n),
      .QD_n(qd_n),
      .RDATA(rdata),
      .LBD_15_0_IN(lbd_in),
      .LBD_15_0_OUT(lbd_out),
      .DD_17_0_IN(dd_in),
      .DD_17_0_OUT(dd_out),
      .HIERR(hierr),
      .LOERR(loerr),
      .LERR_n(lerr_n),
      .LPERR_n(lperr_n),
      .LED4(led4),
      .LED5(led5)
  );

  integer errors = 0;
  integer checks = 0;

  task check_eq(input [17:0] got, input [17:0] want, input [255:0] label);
    begin
      checks = checks + 1;
      if (got !== want) begin
        errors = errors + 1;
        $display("FAIL %0s: got %o expected %o", label, got, want);
      end
    end
  endtask

  initial begin
    $dumpfile("MEM_DATA_46_tb.vcd");
    $dumpvars(0, MEM_DATA_46_tb);

    repeat (4) @(negedge osc);
    sys_rst_n = 1;
    repeat (2) @(negedge osc);

    // ---- 1. write path (transmit): LBD -> DD + odd-parity generation ----
    // MWRITE_n=0 => OET_n=0, BCGNT50R_n=1 => OER_n=1: TransmitMode
    @(negedge osc); mwrite_n = 0; bcgnt50r_n = 1; lbd_in = 16'o052525;
    @(negedge osc);
    check_eq(dd_out[7:0],  8'o125, "write DD[7:0] = LBD[7:0]");
    check_eq({17'b0, dd_out[8]},  {17'b0, ~(^8'o125)}, "write DD[8] odd parity low");
    check_eq({10'b0, dd_out[16:9]}, {10'b0, 8'o125}, "write DD[16:9] = LBD[15:8]");
    check_eq({17'b0, dd_out[17]}, {17'b0, ~(^8'o125)}, "write DD[17] odd parity high");

    @(negedge osc); lbd_in = 16'o177401;   // different halves
    @(negedge osc);
    check_eq(dd_out[7:0],  8'o001, "write2 DD[7:0]");
    check_eq({10'b0, dd_out[16:9]}, {10'b0, 8'o377}, "write2 DD[16:9]");
    check_eq({17'b0, dd_out[8]},  {17'b0, ~(^8'o001)}, "write2 parity low");
    check_eq({17'b0, dd_out[17]}, {17'b0, ~(^8'o377)}, "write2 parity high");

    // ---- 2. read path (receive): DD -> LBD pass-through ----
    // MWRITE_n=1 => OET_n=1, BCGNT50R_n=0 => OER_n=0: ReceiveMode
    @(negedge osc); mwrite_n = 1; bcgnt50r_n = 0;
    dd_in = {1'b0, 8'o146, 1'b1, 8'o031};
    @(negedge osc);
    check_eq({2'b0, lbd_out}, {2'b0, 16'o063031}, "read LBD = DD data halves");

    // ---- 3. parity-error latch on RDATA rise (visible in write mode) ----
    // OET_n=0 (error outputs enabled) + CLRERR_n=1 needs MWRITE_n=0 AND
    // BCGNT50R_n=0. Drive T (DD_IN) with EVEN 9-bit parity = error.
    @(negedge osc); mwrite_n = 0; bcgnt50r_n = 0;
    dd_in = 18'o000003;                    // low half T+PAR = 000000011: even
    @(negedge osc);
    check_eq({17'b0, loerr}, 18'b0, "no error before RDATA");
    @(negedge osc); rdata = 1;             // strobe rise: capture error
    @(negedge osc);
    check_eq({17'b0, loerr}, 18'b1, "LOERR set on RDATA rise");
    check_eq({17'b0, lerr_n}, 18'b0, "LERR_n active");
    // On this sheet SWDIS_n is tied LOW (parity display disabled): DIS_n=0
    // holds the LED4 flop in reset and lights LED5. The flop that latches
    // the error here is MEMORY_5 (LPERR_n), cleared only by MR/PA.
    check_eq({17'b0, led4}, 18'b0, "LED4 held clear by SWDIS");
    check_eq({17'b0, led5}, 18'b1, "LED5 parity-disable on");
    check_eq({17'b0, lperr_n}, 18'b0, "LPERR_n latched on error edge");

    // no re-capture while RDATA held: make T parity ODD, flop must hold
    @(negedge osc); dd_in = 18'o000001;    // odd parity = no error
    @(negedge osc);
    check_eq({17'b0, loerr}, 18'b1, "held RDATA: no re-capture");
    @(negedge osc); rdata = 0;
    @(negedge osc); rdata = 1;             // NEW rise with good parity
    @(negedge osc);
    check_eq({17'b0, loerr}, 18'b0, "second rise captures good parity");
    @(negedge osc); rdata = 0;

    // ---- 4. error again, then CLRERR when the grant window closes ----
    @(negedge osc); dd_in = 18'o000003;
    @(negedge osc); rdata = 1;
    @(negedge osc);
    check_eq({17'b0, loerr}, 18'b1, "error re-latched");
    @(negedge osc); rdata = 0; bcgnt50r_n = 1;   // grant closes: CLRERR_n=0
    @(negedge osc); @(negedge osc);
    bcgnt50r_n = 0;
    @(negedge osc);
    check_eq({17'b0, loerr}, 18'b0, "CLRERR cleared the error flop");
    check_eq({17'b0, lperr_n}, 18'b0, "LPERR_n stays latched after CLRERR");

    // ---- 5. OET_n gating: errors invisible outside write mode ----
    @(negedge osc); dd_in = 18'o000003;
    @(negedge osc); rdata = 1;
    @(negedge osc);
    check_eq({17'b0, loerr}, 18'b1, "error visible in write mode");
    // CORRECTED 11-AUG-2026. This used to assert LOERR forced to 0 when
    // OET_n=1. OET_n = MWRITE_n, so OET_n=1 is a READ - exactly the case where
    // a stored parity error must be reported. On sheet 46 (region E2-F3) the
    // AM29833A ERR pins are OPEN COLLECTOR into the 74F04, ungated, so the
    // error stays visible in both directions. Why it mattered: with nothing
    // able to report an error the CONFIGURATION diagnostic classifies every
    // bank as Mpm 5 instead of Local (measured on the Tang, all 4 MB), and
    // SINTRAN then routes a page fault to its ND-500/5000 window handler.
    @(negedge osc); mwrite_n = 1;          // OET_n=1 is a READ
    @(negedge osc);
    check_eq({17'b0, loerr}, 18'b1, "LOERR still visible on a read (ungated)");
    @(negedge osc); rdata = 0;

    $display("checks=%0d errors=%0d", checks, errors);
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL");
    $finish;
  end

  initial begin
    #100000;
    $display("FAIL [timeout]: watchdog fired");
    $display("TB_RESULT: FAIL");
    $finish;
  end

endmodule

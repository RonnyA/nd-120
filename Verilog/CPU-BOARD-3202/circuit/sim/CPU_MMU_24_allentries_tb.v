/***************************************************************************
** ND120 CPU-BOARD 3202D - MMU SHEET 24 - ALL PAGE-TABLE ENTRIES          **
**                                                                       **
** WHY THIS EXISTS. SINTRAN III halts in ERRFATAL on a page fault at      **
** Perror 064544, virtual page 0o32, at PIL 1, with NPIT/APIT = 012/007.  **
** The trap machinery was cleared first (CGA_TRAP_TVGEN proved correct    **
** over all 524288 input states), so the remaining suspect is the page    **
** table itself: an entry that should be mapped reads back ALL ZERO. The  **
** nd100x oracle boots the SAME disc image and takes ZERO page faults in  **
** that window, so on a correct machine the mapping exists.               **
**                                                                       **
** A silent-write failure of exactly this kind has already bitten once:   **
** the PAL_44306A EIPL term (29-JUL-2026) carried an extra DOUBLE, so in  **
** REX mode the PPN MAP BANK was never written while the STATUS bank      **
** looked perfect - every paged access ran in physical page 0. A bench    **
** that only checks status bits would have sailed straight past it.       **
**                                                                       **
** WHAT THE EXISTING BENCHES DO NOT DO. CPU_MMU_24_shadow_tb.v (1374      **
** checks) and CPU_MMU_PT_29_shadow_rmw_tb.v (77) verify the protocol,    **
** the PAL enables, bank isolation and RMW - but between them they touch  **
** on the order of 30 DISTINCT INDEXES out of 2048, with small adjacent   **
** PPN values. This bench sweeps EVERY entry, with physical pages spread  **
** so that reading through the wrong index cannot look plausible.         **
**                                                                       **
** WHAT IT CHECKS, per index (32 page tables x 64 VPNs = 2048):           **
**   1. REX write, then software read-back through the IDB: all 16 bits.  **
**   2. TRANSLATION through the entry: PT_15_9_OUT and PPN_25_10_OUT.     **
**      This is the check that catches a write which never landed - the   **
**      EIPL failure mode. Reading RAM contents alone does not.           **
**   3. SEX pass: status via CA0=0 and a FULL 16-bit PPN via CA0=1, then  **
**      translate. REX masks the PPN to IDB[8:0] (EIPUR_n, sheet 28), so  **
**      only the SEX path exercises the upper PPN bits at all.            **
**   4. Fault-and-fix: leave an entry with no permit bits, confirm the    **
**      translation reports it, write a valid PTE, confirm it now maps    **
**      and returns the right physical page. This is SINTRAN's demand     **
**      paging pattern - a page fault is NORMAL, the crash is not.        **
**                                                                       **
** ANTI-ALIASING. Physical pages are assigned by an odd stride coprime    **
** with the field width, so consecutive indexes get far-apart pages. If   **
** the index is formed wrongly anywhere, the observed PPN is visibly      **
** wrong rather than a neighbouring value that might pass by luck.        **
**                                                                       **
** ON "ALL PIL LEVELS": there is nothing PIL-shaped below the CGA. PCR    **
** bits 6:3 (PIL) are hardwired to 0 (CGA_MAC_SEGPT_PCR.v:53-54) and      **
** PIL_3_0 never reaches CGA_MAC - the per-level PCR copies are kept by   **
** MICROCODE, which reloads the single PCR latch with COMM,LDPCR on a     **
** level switch. What PIL selection ultimately produces is the page-table **
** number in LA_20_10[10:6], so sweeping all 32 tables here is the        **
** faithful equivalent, and strictly stronger: it covers tables no PIL    **
** currently uses.                                                        **
**                                                                       **
** Stimulus on the NEGEDGE, sampled #1 after the posedge - the anti-race  **
** convention of this directory. Two builds required, plain and           **
** -DTMM_ASYNC_READ, because the RAM read latency differs.                **
**                                                                       **
** Run: make test-mmu24-allentries   (CPU-BOARD-3202/circuit/sim)         **
**                                                                       **
** 17-AUG-2026                                                            **
***************************************************************************/
`timescale 1ns / 1ps

module CPU_MMU_24_allentries_tb;

  // Read latency of the compiled RAM model, in posedges from address to data.
`ifdef TMM_ASYNC_READ
  localparam integer RDLAT = 0;
`else
  localparam integer RDLAT = 1;
`endif

  localparam integer NPT   = 32;    // page tables (LA_20_10[10:6])
  localparam integer NVPN  = 64;    // entries per table (LA_20_10[5:0])
  localparam integer NIDX  = NPT * NVPN;

  // 3 checks per index in the REX pass, 1 in the SEX pass, plus 6 directed
  // fault-and-fix checks.
  localparam integer EXPECTED_CHECKS = NIDX*3 + NIDX*1 + 6;

  reg         sysclk, sys_rst_n;
  reg         BRK_n, CC2_n, CCLR_n, CUP, CWR, CYD, DOUBLE, DT_n, DVACC_n;
  reg         ECSR_n, EDO_n, EMCL_n, EMPID_n, EORF_n, ESTOF_n, FMISS;
  reg         LCS_n, LSHADOW, PD2, RT_n, STP, SW1_CONSOLE, UCLK, UCLK_EN;
  reg         WCHIM_n, WRITE;
  reg  [10:0] CA_10_0, LA_20_10;
  reg  [15:0] IDB_15_0_IN, CD_15_0_IN, PPN_25_10_IN;

  wire [15:0] IDB_15_0_OUT, CD_15_0_OUT, PPN_25_10_OUT;
  wire        BEDO_n, BEMPID_n, BLCS_n, BSTP, HIT, LAPA_n, WCA_n, LED1;
  wire [ 6:0] PT_15_9_OUT;

  CPU_MMU_24 DUT (
      .sysclk(sysclk), .sys_rst_n(sys_rst_n),
      .BRK_n(BRK_n), .CA_10_0(CA_10_0), .CC2_n(CC2_n), .CCLR_n(CCLR_n),
      .CUP(CUP), .CWR(CWR), .CYD(CYD), .DOUBLE(DOUBLE), .DT_n(DT_n),
      .DVACC_n(DVACC_n), .ECSR_n(ECSR_n), .EDO_n(EDO_n), .EMCL_n(EMCL_n),
      .EMPID_n(EMPID_n), .EORF_n(EORF_n), .ESTOF_n(ESTOF_n), .FMISS(FMISS),
      .LA_20_10(LA_20_10), .LCS_n(LCS_n), .LSHADOW(LSHADOW), .PD2(PD2),
      .RT_n(RT_n), .STP(STP), .SW1_CONSOLE(SW1_CONSOLE), .UCLK(UCLK),
      .UCLK_EN(UCLK_EN), .WCHIM_n(WCHIM_n), .WRITE(WRITE),
      .IDB_15_0_IN(IDB_15_0_IN), .IDB_15_0_OUT(IDB_15_0_OUT),
      .CD_15_0_IN(CD_15_0_IN), .CD_15_0_OUT(CD_15_0_OUT),
      .PPN_25_10_IN(PPN_25_10_IN), .PPN_25_10_OUT(PPN_25_10_OUT),
      .BEDO_n(BEDO_n), .BEMPID_n(BEMPID_n), .BLCS_n(BLCS_n), .BSTP(BSTP),
      .HIT(HIT), .LAPA_n(LAPA_n), .PT_15_9_OUT(PT_15_9_OUT),
      .WCA_n(WCA_n), .LED1(LED1)
  );

  initial sysclk = 0;
  always #5 sysclk = ~sysclk;

  integer errors, checks, printed;
  localparam integer MAX_PRINT = 25;

  task check_eq(input [15:0] got, input [15:0] exp, input [(8*72):1] msg);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        errors = errors + 1;
        if (printed < MAX_PRINT) begin
          printed = printed + 1;
          $display("FAIL %0s: got %06o expected %06o", msg, got, exp);
        end
      end
    end
  endtask

  // Everything cache-side parked inactive.
  task quiescent;
    begin
      BRK_n=1; CC2_n=1; CCLR_n=1; CUP=0; CWR=0; DT_n=1; ECSR_n=1; EDO_n=1;
      EMPID_n=1; EORF_n=1; FMISS=0; LCS_n=1; PD2=0; RT_n=1; STP=0;
      SW1_CONSOLE=0; UCLK=0; UCLK_EN=0; CD_15_0_IN=0;
    end
  endtask

  // REX shadow write: PT[idx] = IDB[15:0], PPN[idx] = IDB[8:0].
  task rex_write(input [10:0] idx, input [15:0] w);
    begin
      @(negedge sysclk);
      LA_20_10=idx; CA_10_0=0; DOUBLE=0; EMCL_n=1; WCHIM_n=1; DVACC_n=1;
      ESTOF_n=0; PPN_25_10_IN=0; IDB_15_0_IN=w;
      LSHADOW=1; WRITE=1; CYD=1;
      @(posedge sysclk);
      @(negedge sysclk);
      LSHADOW=0; WRITE=0; CYD=0; IDB_15_0_IN=0;
    end
  endtask

  // SEX shadow write: ca0=0 -> PT status bank only; ca0=1 -> PPN bank only,
  // full 16 bits (EIPUR_n high, so no protect-bit masking).
  task sex_write(input [10:0] idx, input [15:0] w, input ca0);
    begin
      @(negedge sysclk);
      LA_20_10=idx; CA_10_0={10'b0, ca0}; DOUBLE=1; EMCL_n=1; WCHIM_n=1;
      DVACC_n=1; ESTOF_n=0; PPN_25_10_IN=0; IDB_15_0_IN=w;
      LSHADOW=1; WRITE=1; CYD=1;
      @(posedge sysclk);
      @(negedge sysclk);
      LSHADOW=0; WRITE=0; CYD=0; IDB_15_0_IN=0; DOUBLE=0; CA_10_0=0;
    end
  endtask

  // Software read of the PT entry onto the IDB (ESTOF_n=1: PPNX not driving).
  task shadow_read_idb(input [10:0] idx, output [15:0] w);
    begin
      @(negedge sysclk);
      LA_20_10=idx; CA_10_0=0; LSHADOW=1; WRITE=0; CYD=0; DOUBLE=0;
      EMCL_n=1; WCHIM_n=1; DVACC_n=1; ESTOF_n=1; PPN_25_10_IN=0;
      IDB_15_0_IN=0;
      repeat (RDLAT) @(posedge sysclk);
      #1 w = IDB_15_0_OUT;
    end
  endtask

  // Translation: both banks selected, no transceiver driving.
  task xlat_read(input [10:0] idx, output [6:0] pt_hi, output [15:0] ppn);
    begin
      @(negedge sysclk);
      LSHADOW=0; WRITE=0; CYD=0; DOUBLE=0; EMCL_n=1; WCHIM_n=1; DVACC_n=1;
      ESTOF_n=0; PPN_25_10_IN=0; LA_20_10=idx; CA_10_0=0; IDB_15_0_IN=0;
      repeat (RDLAT) @(posedge sysclk);
      #1 pt_hi = PT_15_9_OUT;
         ppn   = PPN_25_10_OUT;
    end
  endtask

  // ---- value generators -------------------------------------------------
  // Spread so consecutive indexes get FAR-APART physical pages: an index
  // formed wrongly anywhere yields a visibly wrong PPN instead of a
  // neighbouring value that could pass by luck. 173 and 40503 are odd, hence
  // coprime with 512 and 65536 respectively, so each is a full-period stride.
  function [15:0] rex_word(input [10:0] idx);
    reg [8:0] ppn9;
    reg [6:0] st;
    begin
      ppn9    = (idx * 173) % 512;
      st      = idx[10:4] ^ 7'h55;        // status bits also vary with index
      rex_word = {st, ppn9};
    end
  endfunction

  function [15:0] sex_ppn(input [10:0] idx);
    begin
      sex_ppn = (idx * 40503) % 65536;
    end
  endfunction

  integer pt, vpn, i;
  reg [10:0] idx;
  reg [15:0] w, rb, ppn;
  reg [ 6:0] pth;

  initial begin
`ifdef TMM_ASYNC_READ
    $display("CPU_MMU_24_allentries_tb: TMM2018D ASYNC read (RDLAT=0)");
`else
    $display("CPU_MMU_24_allentries_tb: TMM2018D SYNC read (RDLAT=1)");
`endif
    errors=0; checks=0; printed=0;
    quiescent;
    LSHADOW=0; WRITE=0; CYD=0; DOUBLE=0; EMCL_n=1; WCHIM_n=1; DVACC_n=1;
    ESTOF_n=0; LA_20_10=0; CA_10_0=0; IDB_15_0_IN=0; PPN_25_10_IN=0;
    sys_rst_n=0;
    repeat (4) @(posedge sysclk);
    sys_rst_n=1;
    repeat (2) @(posedge sysclk);

    // ---- PHASE 1+2: REX write, read back, translate - EVERY entry --------
    for (pt = 0; pt < NPT; pt = pt + 1) begin
      for (vpn = 0; vpn < NVPN; vpn = vpn + 1) begin
        idx = (pt << 6) | vpn;
        w   = rex_word(idx);
        rex_write(idx, w);
        shadow_read_idb(idx, rb);
        check_eq(rb, w, "REX read-back");
        xlat_read(idx, pth, ppn);
        check_eq({9'b0, pth}, {9'b0, w[15:9]}, "REX translate: status bits");
        // REX masks the PPN bank to IDB[8:0] via EIPUR_n (sheet 28).
        check_eq(ppn, w & 16'o000777, "REX translate: physical page");
      end
    end

    // ---- PHASE 3: SEX pass - FULL 16-bit PPN through every entry ---------
    for (pt = 0; pt < NPT; pt = pt + 1) begin
      for (vpn = 0; vpn < NVPN; vpn = vpn + 1) begin
        idx = (pt << 6) | vpn;
        sex_write(idx, rex_word(idx), 1'b0);   // status bank
        sex_write(idx, sex_ppn(idx), 1'b1);    // PPN bank, all 16 bits
        xlat_read(idx, pth, ppn);
        check_eq(ppn, sex_ppn(idx), "SEX translate: full 16-bit page");
      end
    end

    // ---- PHASE 4: fault-and-fix, the demand-paging pattern ---------------
    // A page fault is NORMAL - SINTRAN takes one to load a page from disc.
    // What must work is: unmapped entry reads as not-present, then a valid
    // PTE written into it maps and returns the right page.
    idx = (7 << 6) | 6'o32;        // APIT 007, virtual page 0o32 - the entry
                                   // the machine actually dies on.
    sex_write(idx, 16'h0000, 1'b0);   // no permit bits = page not present
    sex_write(idx, 16'h0000, 1'b1);
    xlat_read(idx, pth, ppn);
    check_eq({9'b0, pth}, 16'h0000, "unmapped: status all zero");
    check_eq(ppn, 16'h0000, "unmapped: no physical page");

    sex_write(idx, 16'o162000, 1'b0);  // WPM|RPM|FPM, ring 2 - a real entry
    sex_write(idx, 16'o000463, 1'b1);  // a real physical page
    xlat_read(idx, pth, ppn);
    check_eq({9'b0, pth}, {9'b0, 7'o162 >> 0}, "after fix: status bits");
    check_eq(ppn, 16'o000463, "after fix: physical page");

    // and the neighbours must be undisturbed by that repair
    xlat_read((7 << 6) | 6'o31, pth, ppn);
    check_eq(ppn, sex_ppn((7 << 6) | 6'o31), "neighbour -1 undisturbed");
    xlat_read((7 << 6) | 6'o33, pth, ppn);
    check_eq(ppn, sex_ppn((7 << 6) | 6'o33), "neighbour +1 undisturbed");

    $display("");
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d checks, %0d errors, expected %0d checks)",
               checks, errors, EXPECTED_CHECKS);
    $finish;
  end

  initial begin
    #200000000;
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule

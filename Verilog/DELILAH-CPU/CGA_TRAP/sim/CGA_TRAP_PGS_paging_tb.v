/**************************************************************************************************
** ND120 CGA (DELILAH) - PAGING PROTECTION: trap vector AND paging status (PGS) together          **
**                                                                                                **
** DUTs (two sheets driven as ONE unit, exactly as CGA.v wires them):                             **
**   CGA_TRAP          - DELILAH page 100 (TBUF p.101, TVGEN p.104 sheets 1+2, BRKDET p.102)      **
**                       Verilog/DELILAH-CPU/CGA_TRAP/circuit/CGA_TRAP.v                          **
**   CGA_IDBCTL_PGSREG - DELILAH page 98, the 14-bit PGS register                                 **
**                       Verilog/DELILAH-CPU/CGA_IDBCTL/circuit/CGA_IDBCTL_PGSREG.v               **
** In CGA.v both sheets share FETCHN and VACCN, and CGA_TRAP.PVIOL feeds CGA_IDBCTL.PVIOL. This   **
** bench reproduces exactly that wiring, so every case asserts BOTH the trap vector raised AND    **
** the PGS word the CPU would read back - which no existing bench does.                           **
**                                                                                                **
** WHY THIS BENCH EXISTS                                                                          **
**   A SINTRAN boot dies with "IIC 3 Page Fault" at PIL 1 that the operating system cannot        **
**   resolve, while a reference emulator boots the same disc image to a login. The kernel tells   **
**   "page not in memory" from "mapped but access denied" by the INTERRUPT CODE, and it reads the **
**   faulting page out of PGS. So the pair (vector, PGS) is the whole contract, and it is that    **
**   pair that is asserted here.                                                                  **
**                                                                                                **
** REFERENCE SEMANTICS (the golden model below is written from THESE rules, not from the netlist) **
**   Source: RetroCore Emulated.HW/ND/CPU/ND100/CpuND100.MMS.cs - checkPageProtection()/UpdatePGS()**
**   R1  WPM=RPM=FPM all zero  => page NOT in memory => PAGE FAULT (IIC 3, trap vector 1).        **
**       Cited to ND-110 Functional Description, chapter 3 page 89.                               **
**   R2  page present (>=1 permit bit) but the requested mode not permitted => MEMORY PROTECTION  **
**       VIOLATION (IIC 2, trap vector 2).                                                        **
**   R3  PGS is always updated on these events.                                                   **
**   R4  PGS[11:0] = (pageTable << 6) | VPN.                                                      **
**   R5  PGS[14] (PM) is SET on a not-present page as well as on a permit violation. The C# source**
**       carries a DO-NOT-CHANGE guard: with PM=0 the TPE diagnostic PAGING-C02:TEST test 6 aborts**
**       reporting "Ring violation instead of permit violation".                                  **
**   R6  PGS[15] is set when the fault happened on an instruction FETCH, but NOT on a READ_FETCH  **
**       (the indirect read during effective-address calculation, which happens AFTER the fetch).  **
**   Permitted-access mask per mode, from checkPageProtection(): READ->RPM, WRITE->WPM,           **
**   FETCH->FPM, READ_FETCH(indirect)->RPM|FPM (allowed if EITHER is set).                        **
**                                                                                                **
** READ_FETCH IS DISTINGUISHABLE IN THIS RTL - measured, not assumed. PGS15 is the QN of a scan   **
** flip-flop whose scan input is FETCHN, while the indirect access is signalled on a SEPARATE pin **
** INDN (TBUF: IFETCH=~FETCHN, IIND=~INDN). Driving the indirect read as FETCHN=1 + INDN=0 there- **
** fore yields PGS15=0 while a true fetch yields PGS15=1. Section D asserts that directly.        **
** What this bench CANNOT settle: whether the microcode/decoder (CGA_DCD) really holds FETCHN     **
** high during the indirect read - that is outside both sheets. UNKNOWN here; the experiment that **
** would settle it is a full-CPU run with FETCHN and INDN probed across an indirect-addressing    **
** instruction.                                                                                   **
**                                                                                                **
** PAGE TABLE STATUS WORD bits carried on PT_15_9[6:0]:                                           **
**   [6]=PT15 write-permit  [5]=PT14 read-permit  [4]=PT13 fetch-permit                           **
**   [3]=PT12 WIP           [2]=PT11 PGU          [1:0]=PT10:PT9 ring                             **
**   NOTE the polarity of the two level-2 sources: the WIP trap fires on a WRITE to a write-      **
**   permitted page whose WIP bit is CLEAR, and the PGU trap fires whenever the PGU bit is CLEAR. **
**   Every "no trap expected" case therefore sets PT12 and PT11.                                  **
**                                                                                                **
** VECTOR ENCODING. Level-1 (page fault 1, protect violation 2) is what the reference semantics   **
** above govern and is the point of this bench. The level-2 encodings (ring-down 3, PGU 4, WIP 5) **
** and their priority WIP > PGU > ring-down are NOT in the reference emulator at all - they are   **
** taken from the DELILAH p.104 vector table as already pinned by CGA_TRAP_TVGEN_tb.v, and are    **
** carried here only so the ring cases can be asserted end to end.                                **
**                                                                                                **
** NOT ASSERTED HERE, deliberately: TRAPN/BRKN. CGA_TRAP_BRKDET has its own bench, and its break  **
** detect uses a WIDER, access-mode-independent IPV term (VACC & ~PT14 & ~PT13) that does not     **
** track the trap vector. TRAPN is printed for information only.                                  **
**                                                                                                **
** Teeth: see the comment above the golden model. Proven with a mutated SCRATCH copy of the RTL.  **
**                                                                                                **
** Coverage:                                                                                      **
**   A  page NOT present (all permits 0) x {read, write, fetch, indirect} x 2 entry flavours      **
**      -> page-fault vector 1 and PGS[14] SET in every one of them (R1, R5)                      **
**   B  page present, ONE permit bit set at a time x all 4 access modes (12 combinations)         **
**      -> protect-violation vector 2 where the mode is not permitted, PGS[14] set, and never     **
**         the page-fault vector; no trap where the mode IS permitted (R2)                        **
**   C  page present and access permitted (all permits + WIP + PGU set) -> no trap at all         **
**   D  PGS[15]: set on a fetch fault, CLEAR on a data-read fault, CLEAR on an indirect-read      **
**      fault (READ_FETCH) - the R6 case that crashes the SINTRAN boot if mishandled              **
**   E  PGS[11:0] = pagetable<<6 | VPN swept over page tables 0,1,2,3,31,63 and VPNs 0,1,31,62,63 **
**      including the block boundaries, plus one faulting fetch that carries bits 15 and 14 too   **
**   F  ring bits PT10:9 against the PCR ring, all 16 combinations x {read, fetch}: ring violation**
**      (PCR ring < PT ring) -> vector 2 with PGS[14] CLEAR (it is NOT a permit violation - this  **
**      is exactly the distinction the TPE diagnostic decodes), ring-down (PCR ring > PT ring, on **
**      a fetch of a fetch-permitted page) -> vector 3                                            **
**   G  RECORDED behaviour, not a requirement: this PGS register has no lock - it reloads on every**
**      MCLK while VACC is high, so a later non-faulting access overwrites the faulting PGS.      **
**                                                                                                **
** Stimulus is driven on the NEGEDGE so it is stable at the sampling posedge (the anti-race       **
** convention of the other benches in this tree). Default build = latch/CP mode: the vector flip- **
** flops clock on posedge TCLK and PGS on posedge MCLK (sysclk/*_EN unused).                      **
**                                                                                                **
** Self-checking: prints TB_RESULT: PASS / FAIL (never silent).                                   **
**                                                                                                **
** Run: make test-trap-pgs-paging      (Verilog/DELILAH-CPU/CGA_TRAP/sim)                         **
**                                                                                                **
** 11-AUG-2026                                                                                    **
** Ronny Hansen                                                                                   **
***************************************************************************************************/
`timescale 1ns / 1ps

module CGA_TRAP_PGS_paging_tb;

  // The verdict is gated on this too, so a silently skipped section cannot pass.
  localparam integer EXPECTED_CHECKS = 230;

  // Access modes
  localparam integer M_READ = 0;  // plain data read
  localparam integer M_WRITE = 1;  // data write
  localparam integer M_FETCH = 2;  // instruction fetch
  localparam integer M_IND = 3;  // indirect read (the reference emulator's READ_FETCH)

  // Trap vectors
  localparam [3:0] V_PGF = 4'd1;  // page fault            (IIC 3)
  localparam [3:0] V_PVIOL = 4'd2;  // protection violation  (IIC 2)
  localparam [3:0] V_RINGDOWN = 4'd3;
  localparam [3:0] V_PGU = 4'd4;
  localparam [3:0] V_WIP = 4'd5;
  localparam [3:0] V_NONE = 4'd15;  // no trap

  // Page-table status word bit positions inside PT_15_9[6:0]
  localparam integer B_WPM = 6;  // PT15 write permit
  localparam integer B_RPM = 5;  // PT14 read  permit
  localparam integer B_FPM = 4;  // PT13 fetch permit
  localparam integer B_WIP = 3;  // PT12
  localparam integer B_PGU = 2;  // PT11

  reg sysclk = 1'b0;
  always #5 sysclk = ~sysclk;

  // ---------------- DUT drives ----------------
  reg        TCLK = 1'b0;
  reg        MCLK = 1'b0;
  reg        TCLK_EN = 1'b0;
  reg        MCLK_EN = 1'b0;

  reg        VACCN = 1'b1;
  reg        FETCHN = 1'b1;
  reg        INDN = 1'b1;
  reg        WRITEN = 1'b1;
  reg  [6:0] PT_15_9 = 7'b0;
  reg  [1:0] PCR_1_0 = 2'b11;
  reg [11:0] LA_21_10 = 12'b0;

  // held-inactive trap sources, so only the paging logic can raise a vector
  reg        CBRKN = 1'b1;
  reg        DSTOPN = 1'b1;
  reg        ETRAPN = 1'b0;
  reg        FTRAPN = 1'b1;
  reg        INTRQN = 1'b1;
  reg        PANN = 1'b1;
  reg        PONI = 1'b1;
  reg        VTRAPN = 1'b1;

  wire       BRKN;
  wire       PVIOL;
  wire       RESTR;
  wire       TRAPN;
  wire [3:0] TVEC_3_0;

  wire [11:0] PGS_11_0;
  wire [ 1:0] PGS_15_14;  // [1]=PGS15, [0]=PGS14

  CGA_TRAP TRAP (
      .sysclk  (sysclk),
      .TCLK_EN (TCLK_EN),
      .CBRKN   (CBRKN),
      .DSTOPN  (DSTOPN),
      .ETRAPN  (ETRAPN),
      .FETCHN  (FETCHN),
      .FTRAPN  (FTRAPN),
      .INDN    (INDN),
      .INTRQN  (INTRQN),
      .PANN    (PANN),
      .PCR_1_0 (PCR_1_0),
      .PONI    (PONI),
      .PT_15_9 (PT_15_9),
      .TCLK    (TCLK),
      .VACCN   (VACCN),
      .VTRAPN  (VTRAPN),
      .WRITEN  (WRITEN),
      .BRKN    (BRKN),
      .PVIOL   (PVIOL),
      .RESTR   (RESTR),
      .TRAPN   (TRAPN),
      .TVEC_3_0(TVEC_3_0)
  );

  // Wired exactly as CGA.v does it: same FETCHN, same VACCN, PVIOL straight across.
  CGA_IDBCTL_PGSREG PGSREG (
      .sysclk   (sysclk),
      .MCLK_EN  (MCLK_EN),
      .FETCHN   (FETCHN),
      .LA_21_10 (LA_21_10),
      .MCLK     (MCLK),
      .PVIOL    (PVIOL),
      .VACCN    (VACCN),
      .PGS_11_0 (PGS_11_0),
      .PGS_15_14(PGS_15_14)
  );

  integer errors = 0;
  integer checks = 0;

  task check_eq(input [15:0] got, input [15:0] exp, input string msg);
    begin
      checks = checks + 1;
      if (got !== exp) begin
        $display("  FAIL: %0s  got=%06o expected=%06o", msg, got, exp);
        errors = errors + 1;
      end
    end
  endtask

  /*************************************************************************
   ** Golden model - written from the REFERENCE SEMANTICS in the header,  **
   ** not copied from the gate netlist.                                   **
   **                                                                     **
   ** TEETH (-DTEETH_TEST) mutates the golden PM bit for the not-present  **
   ** case to 0, i.e. the very "bug #002" the C# source warns about, so a **
   ** build with teeth MUST report FAIL. That proves the checks bite on   **
   ** rule R5, the rule the SINTRAN failure hangs on.                     **
   *************************************************************************/

  function present(input [6:0] p);
    begin
      present = p[B_WPM] | p[B_RPM] | p[B_FPM];
    end
  endfunction

  function permitted(input integer mode, input [6:0] p);
    begin
      case (mode)
        M_READ:  permitted = p[B_RPM];
        M_WRITE: permitted = p[B_WPM];
        M_FETCH: permitted = p[B_FPM];
        default: permitted = p[B_RPM] | p[B_FPM];  // READ_FETCH: RPM or FPM
      endcase
    end
  endfunction

  // page fault: no permit bit at all (R1)
  function g_pgf(input integer mode, input [6:0] p);
    begin
      g_pgf = ~present(p);
    end
  endfunction

  // permit violation: present, but this mode is not allowed (R2)
  function g_permit_viol(input integer mode, input [6:0] p);
    begin
      g_permit_viol = present(p) & ~permitted(mode, p);
    end
  endfunction

  // PGS[14] PM: set on BOTH of the above (R5). Ring violations do NOT set it.
  function g_pm(input integer mode, input [6:0] p);
    begin
      g_pm = g_pgf(mode, p) | g_permit_viol(mode, p);
`ifdef TEETH_TEST
      if (g_pgf(mode, p)) g_pm = 1'b0;  // the C# "bug #002" mutation
`endif
    end
  endfunction

  // PGS[15]: fetch yes, indirect read (READ_FETCH) no (R6)
  function g_pgs15(input integer mode);
    begin
      g_pgs15 = (mode == M_FETCH);
    end
  endfunction

  // ring violation: PCR ring must be >= PT ring
  function g_ring_viol(input [1:0] pcr, input [6:0] p);
    begin
      g_ring_viol = (pcr < p[1:0]);
    end
  endfunction

  // ring-down: fetching a fetch-permitted page that sits in a LOWER ring
  function g_ring_down(input integer mode, input [1:0] pcr, input [6:0] p);
    begin
      g_ring_down = (mode == M_FETCH) & p[B_FPM] & (pcr > p[1:0]);
    end
  endfunction

  function g_wip(input integer mode, input [6:0] p);
    begin
      g_wip = (mode == M_WRITE) & p[B_WPM] & ~p[B_WIP];
    end
  endfunction

  function g_pgu(input [6:0] p);
    begin
      g_pgu = ~p[B_PGU];
    end
  endfunction

  function [3:0] g_tvec(input integer mode, input [1:0] pcr, input [6:0] p);
    reg lev1, lev2;
    begin
      lev1 = g_pgf(mode, p) | g_permit_viol(mode, p) | g_ring_viol(pcr, p);
      lev2 = g_wip(mode, p) | g_pgu(p) | g_ring_down(mode, pcr, p);
      if (lev1) g_tvec = g_pgf(mode, p) ? V_PGF : V_PVIOL;
      else if (lev2)
        g_tvec = g_wip(mode, p) ? V_WIP : (g_pgu(p) ? V_PGU : V_RINGDOWN);
      else g_tvec = V_NONE;
    end
  endfunction

  function [15:0] g_pgs(input integer mode, input [6:0] p, input [5:0] ptnum,
                        input [5:0] vpn);
    begin
      g_pgs = {g_pgs15(mode), g_pm(mode, p), 2'b00, ptnum, vpn};  // R4
    end
  endfunction

  /*************************************************************************
   ** Stimulus                                                            **
   *************************************************************************/

  reg  [ 3:0] o_tvec;
  reg  [15:0] o_pgs;
  reg         o_pviol;
  reg         o_trapn;

  // Composed PGS word as the CPU reads it: bits 13:12 are not implemented.
  wire [15:0] pgs_word = {PGS_15_14[1], PGS_15_14[0], 2'b00, PGS_11_0};

  // One complete paged access: present the page-table word + access type,
  // clock the trap vector on TCLK, clock PGS on MCLK, sample while VACC is
  // still asserted (the vector mux select is combinational on VACC).
  task do_access(input integer mode, input [6:0] ptw, input [1:0] pcr,
                 input [5:0] ptnum, input [5:0] vpn);
    begin
      @(negedge sysclk);
      VACCN    = 1'b0;
      WRITEN   = (mode == M_WRITE) ? 1'b0 : 1'b1;
      FETCHN   = (mode == M_FETCH) ? 1'b0 : 1'b1;
      INDN     = (mode == M_IND) ? 1'b0 : 1'b1;
      PT_15_9  = ptw;
      PCR_1_0  = pcr;
      LA_21_10 = {ptnum, vpn};
      @(negedge sysclk);
      TCLK = 1'b1;  // vector flip-flops capture here
      @(negedge sysclk);
      MCLK = 1'b1;  // PGS captures here
      @(negedge sysclk);
      #1;
      o_tvec  = TVEC_3_0;
      o_pgs   = pgs_word;
      o_pviol = PVIOL;
      o_trapn = TRAPN;
      @(negedge sysclk);
      TCLK  = 1'b0;
      MCLK  = 1'b0;
      VACCN = 1'b1;
      @(negedge sysclk);
    end
  endtask

  function [(8*9):1] mname(input integer mode);
    begin
      case (mode)
        M_READ:  mname = "read    ";
        M_WRITE: mname = "write   ";
        M_FETCH: mname = "fetch   ";
        default: mname = "indirect";
      endcase
    end
  endfunction

  // Drive one access and assert BOTH the vector and the whole PGS word.
  task run_case(input string label, input integer mode, input [6:0] ptw,
                input [1:0] pcr, input [5:0] ptnum, input [5:0] vpn);
    reg [15:0] exp_pgs;
    begin
      do_access(mode, ptw, pcr, ptnum, vpn);
      exp_pgs = g_pgs(mode, ptw, ptnum, vpn);
      check_eq({12'b0, o_tvec}, {12'b0, g_tvec(mode, pcr, ptw)},
               $sformatf("%0s [%0s pt=%07b pcr=%0d] TVEC", label, mname(mode),
                         ptw, pcr));
      check_eq(o_pgs, exp_pgs,
               $sformatf("%0s [%0s pt=%07b pcr=%0d] PGS", label, mname(mode),
                         ptw, pcr));
    end
  endtask

  integer m;
  integer i;
  integer j;
  integer pti;
  integer vpi;
  reg [6:0] ptw;
  reg [5:0] pts[0:5];
  reg [5:0] vps[0:4];

  // "present" entries with WIP+PGU already set and PT ring 3, so no level-2
  // trap and no ring trap can fire and the permit logic stands alone.
  localparam [6:0] E_NONE = 7'b0001111;  // no permit bit, WIP+PGU set, ring 3
  localparam [6:0] E_BARE = 7'b0000000;  // an all-zero entry (PGU also clear)
  localparam [6:0] E_W = 7'b1001111;  // write permit only
  localparam [6:0] E_R = 7'b0101111;  // read  permit only
  localparam [6:0] E_F = 7'b0011111;  // fetch permit only
  localparam [6:0] E_ALL = 7'b1111111;  // all permits, WIP+PGU set, ring 3

  initial begin
    repeat (4) @(negedge sysclk);

    // =================================================================== //
    // A. PAGE NOT PRESENT (WPM=RPM=FPM=0) for every access mode.
    //    R1: page-fault vector. R5: PGS[14] SET in every one of them.
    //    Two entry flavours: PGU/WIP set, and a completely bare entry (which
    //    also raises the level-2 PGU condition - the page fault must win).
    // =================================================================== //
    for (m = 0; m < 4; m = m + 1) begin
      run_case("A not-present (WIP+PGU set)", m, E_NONE, 2'd3, 6'o12, 6'o25);
      check_eq({15'b0, o_tvec == V_PGF}, 16'b1,
               $sformatf("A not-present [%0s] raises PAGE FAULT vector 1",
                         mname(m)));
      check_eq({15'b0, o_pgs[14]}, 16'b1,
               $sformatf("A not-present [%0s] PGS14 PM set (R5)", mname(m)));
    end

    for (m = 0; m < 4; m = m + 1) begin
      run_case("A not-present (bare entry)", m, E_BARE, 2'd3, 6'o12, 6'o25);
      check_eq({15'b0, o_tvec == V_PGF}, 16'b1,
               $sformatf("A bare entry [%0s] page fault beats the PGU trap",
                         mname(m)));
      check_eq({15'b0, o_pgs[14]}, 16'b1,
               $sformatf("A bare entry [%0s] PGS14 PM set (R5)", mname(m)));
    end

    // =================================================================== //
    // B. PAGE PRESENT, ONE permit bit set at a time, every access mode.
    //    Where the mode is NOT permitted: protect-violation vector 2, PGS[14]
    //    set, and never the page-fault vector. Where it IS permitted: no trap.
    // =================================================================== //
    for (i = 0; i < 3; i = i + 1) begin
      case (i)
        0: ptw = E_W;
        1: ptw = E_R;
        default: ptw = E_F;
      endcase
      for (m = 0; m < 4; m = m + 1) begin
        run_case("B single-permit", m, ptw, 2'd3, 6'o03, 6'o61);
        if (permitted(m, ptw)) begin
          check_eq({15'b0, o_tvec == V_NONE}, 16'b1,
                   $sformatf("B permitted [%0s pt=%07b] no trap", mname(m),
                             ptw));
          check_eq({15'b0, o_pgs[14]}, 16'b0,
                   $sformatf("B permitted [%0s pt=%07b] PGS14 clear", mname(m),
                             ptw));
        end else begin
          check_eq({15'b0, o_tvec == V_PVIOL}, 16'b1,
                   $sformatf("B denied [%0s pt=%07b] PROTECT VIOLATION vec 2",
                             mname(m), ptw));
          check_eq({15'b0, o_tvec == V_PGF}, 16'b0,
                   $sformatf("B denied [%0s pt=%07b] is NOT a page fault",
                             mname(m), ptw));
          check_eq({15'b0, o_pgs[14]}, 16'b1,
                   $sformatf("B denied [%0s pt=%07b] PGS14 PM set", mname(m),
                             ptw));
        end
      end
    end

    // =================================================================== //
    // C. PAGE PRESENT AND ACCESS PERMITTED - no trap at all.
    // =================================================================== //
    for (m = 0; m < 4; m = m + 1) begin
      run_case("C permitted", m, E_ALL, 2'd3, 6'o07, 6'o00);
      check_eq({15'b0, o_tvec == V_NONE}, 16'b1,
               $sformatf("C all-permits [%0s] no trap", mname(m)));
      check_eq({15'b0, o_pviol}, 16'b0,
               $sformatf("C all-permits [%0s] PVIOL low", mname(m)));
      check_eq({15'b0, o_pgs[14]}, 16'b0,
               $sformatf("C all-permits [%0s] PGS14 clear", mname(m)));
    end

    // =================================================================== //
    // D. PGS[15]. R6: set on a fault taken during an instruction FETCH,
    //    CLEAR on a data-read fault, and CLEAR on the indirect read
    //    (READ_FETCH) - the rare case the reference warns crashes SINTRAN.
    //    This RTL CAN tell them apart: PGS15 follows FETCHN while the
    //    indirect access is signalled on the separate pin INDN.
    // =================================================================== //
    do_access(M_FETCH, E_NONE, 2'd3, 6'o21, 6'o07);
    check_eq({15'b0, o_pgs[15]}, 16'b1, "D fetch fault sets PGS15");
    check_eq({12'b0, o_tvec}, {12'b0, V_PGF}, "D fetch fault vector is 1");

    do_access(M_READ, E_NONE, 2'd3, 6'o21, 6'o07);
    check_eq({15'b0, o_pgs[15]}, 16'b0, "D data-read fault leaves PGS15 clear");
    check_eq({12'b0, o_tvec}, {12'b0, V_PGF}, "D data-read fault vector is 1");

    do_access(M_IND, E_NONE, 2'd3, 6'o21, 6'o07);
    check_eq({15'b0, o_pgs[15]}, 16'b0,
             "D READ_FETCH (indirect) fault leaves PGS15 clear (R6)");
    check_eq({12'b0, o_tvec}, {12'b0, V_PGF}, "D indirect fault vector is 1");

    do_access(M_WRITE, E_NONE, 2'd3, 6'o21, 6'o07);
    check_eq({15'b0, o_pgs[15]}, 16'b0, "D write fault leaves PGS15 clear");

    // a permit violation on a fetch must set PGS15 too, not only a page fault
    do_access(M_FETCH, E_R, 2'd3, 6'o21, 6'o07);
    check_eq({15'b0, o_pgs[15]}, 16'b1, "D fetch permit-violation sets PGS15");
    check_eq({15'b0, o_pgs[14]}, 16'b1, "D fetch permit-violation sets PGS14");
    check_eq({12'b0, o_tvec}, {12'b0, V_PVIOL},
             "D fetch permit-violation vector is 2");

    // an indirect read denied by BOTH read and fetch permit: violation, no PGS15
    do_access(M_IND, E_W, 2'd3, 6'o21, 6'o07);
    check_eq({15'b0, o_pgs[15]}, 16'b0,
             "D indirect permit-violation leaves PGS15 clear");
    check_eq({12'b0, o_tvec}, {12'b0, V_PVIOL},
             "D indirect permit-violation vector is 2");

    // an indirect read on a FETCH-permit-only page is ALLOWED (RPM|FPM)
    do_access(M_IND, E_F, 2'd3, 6'o21, 6'o07);
    check_eq({12'b0, o_tvec}, {12'b0, V_NONE},
             "D indirect read allowed by FETCH permit alone");

    // =================================================================== //
    // E. PGS[11:0] = pagetable<<6 | VPN (R4), swept over several page tables
    //    and several VPNs including the block boundaries.
    // =================================================================== //
    pts[0] = 6'd0;
    pts[1] = 6'd1;
    pts[2] = 6'd2;
    pts[3] = 6'd3;
    pts[4] = 6'd31;
    pts[5] = 6'd63;
    vps[0] = 6'd0;
    vps[1] = 6'd1;
    vps[2] = 6'd31;
    vps[3] = 6'd62;
    vps[4] = 6'd63;

    for (pti = 0; pti < 6; pti = pti + 1) begin
      for (vpi = 0; vpi < 5; vpi = vpi + 1) begin
        do_access(M_READ, E_ALL, 2'd3, pts[pti], vps[vpi]);
        check_eq({4'b0, PGS_11_0}, {4'b0, pts[pti], vps[vpi]},
                 $sformatf("E PGS[11:0] pt=%0d vpn=%0d", pts[pti], vps[vpi]));
      end
    end

    // and the whole word on a faulting fetch, bits 15 and 14 included
    do_access(M_FETCH, E_NONE, 2'd3, 6'd63, 6'd63);
    check_eq(o_pgs, 16'o140000 | 16'o7777,
             "E faulting fetch pt=63 vpn=63 full PGS word");
    do_access(M_FETCH, E_NONE, 2'd3, 6'd0, 6'd0);
    check_eq(o_pgs, 16'o140000, "E faulting fetch pt=0 vpn=0 full PGS word");

    // =================================================================== //
    // F. RING bits PT10:9 against the PCR ring, all 16 combinations, on a
    //    read and on a fetch of a fully-permitted page.
    //      PCR ring <  PT ring -> ring violation, vector 2, PGS[14] CLEAR
    //                             (it is NOT a permit violation)
    //      PCR ring >  PT ring -> ring-down on a fetch, vector 3
    //      PCR ring == PT ring -> no trap
    // =================================================================== //
    for (i = 0; i < 4; i = i + 1) begin  // PT ring
      for (j = 0; j < 4; j = j + 1) begin  // PCR ring
        ptw = {5'b11111, i[1:0]};
        run_case("F ring", M_READ, ptw, j[1:0], 6'o05, 6'o11);
        if (j < i)
          check_eq({15'b0, o_pgs[14]}, 16'b0,
                   $sformatf(
                       "F ring violation PT=%0d PCR=%0d PGS14 CLEAR (not permit)",
                       i, j));
        run_case("F ring", M_FETCH, ptw, j[1:0], 6'o05, 6'o11);
        if (j > i)
          check_eq({12'b0, o_tvec}, {12'b0, V_RINGDOWN},
                   $sformatf("F ring-down PT=%0d PCR=%0d vector 3", i, j));
      end
    end

    // =================================================================== //
    // G. RECORDED, not a requirement: this PGS register has no lock. It
    //    reloads on every MCLK while VACC is high, so a later clean access
    //    overwrites the faulting PGS. Whatever freezes PGS for the trap
    //    handler must therefore live outside CGA_IDBCTL_PGSREG (unknown
    //    where - the experiment is to trace VACCN/MCLK across a live trap).
    // =================================================================== //
    do_access(M_FETCH, E_NONE, 2'd3, 6'o11, 6'o22);
    check_eq(o_pgs, 16'o140000 | (16'o11 << 6) | 16'o22,
             "G faulting access loaded PGS");
    do_access(M_READ, E_ALL, 2'd3, 6'o33, 6'o44);
    check_eq(o_pgs, (16'o33 << 6) | 16'o44,
             "G a later clean access OVERWRITES PGS (no lock in this sheet)");

    $display("[info] TRAPN after the last access = %b (informational only)",
             o_trapn);

    // =================================================================== //
    if (errors == 0 && checks == EXPECTED_CHECKS)
      $display("TB_RESULT: PASS (%0d checks)", checks);
    else
      $display("TB_RESULT: FAIL (%0d errors, %0d of %0d checks)", errors,
               checks, EXPECTED_CHECKS);
    $finish;
  end

  initial begin
    #4000000;
    $display("TB_RESULT: TIMEOUT");
    $finish;
  end

endmodule

/****************************************************************************
** TICK-COST INSTRUMENTATION of the Winchester DMA path (copy of
** nd_winchester_dmapath_tb.v). Counts sysclk ticks from the GO write on +5
** until status bit 2 (ACTIVE) clears, broken down by engine phase.
** Original header follows.
****************************************************************************/
/****************************************************************************
** TESTBENCH: ND_WINCHESTER -> adapter -> nd_storage -> SD card, END TO END **
**                                                                         **
** THE HOLE THIS CLOSES                                                    **
**                                                                         **
** Four Winchester benches existed before this one and not one of them had **
** nd_storage in it:                                                       **
**                                                                         **
**   nd_winchester_iox_tb.v      register protocol, disk_done faked        **
**   nd_winchester_oracle_tb.v   replays the C model's IOX trace, disk     **
**                               chunks completed by a two-cycle stub      **
**   nd_winchester_bus_tb.v      the card behind the real ND_BUS_SLAVE     **
**   nd_winchester_adapter_tb.v  CHS->LBA arithmetic and write refusal,    **
**                               with NO storage behind the adapter        **
**                                                                         **
** So the whole path from "the guest set GO" to "bytes off the FAT volume" **
** was never simulated. On silicon 08-AUG-2026 that path failed in the one **
** way none of those four benches can see: the controller reported status  **
** 060010 - finished (b3), on cylinder (b14), b13 always-1, NO error bits  **
** at all - the memory address register had advanced by exactly 2000 octal **
** (1024 words, a full DMA), and every one of those 1024 words was ZERO.   **
** A backend that answers "done, no error" while handing over a zero block **
** is invisible to every bench that fakes the backend.                     **
**                                                                         **
** WHAT IS EXERCISED                                                       **
**                                                                         **
** The REAL chain, in the wiring the Tang build uses: ND_WINCHESTER ->     **
** nd_storage_devices(INCLUDE_WD=1) -> nd_storage_disc_adapter (client 6, **
** Winchester geometry) -> nd_storage (mount + engine + Phase-4 cache) ->  **
** the behavioral SD card serving the real FAT16 image, with WD0.IMG on    **
** it. Client 6 is a CACHED client, so a cold block-0 read must MISS,      **
** fetch four card sectors, fill the region line, publish the tag and only **
** then serve the controller.                                             **
**                                                                         **
** The IOX sequence is the ORACLE's, captured from the nd100x C model      **
** (see nd_winchester_oracle_tb.v): block address, memory address HI then  **
** LO, word count, then activate+read. Two transfers are run back to back  **
** because the silicon symptom included "sometimes the second one works" - **
** a cold MISS and then a warm HIT of the same block must BOTH deliver the **
** card's bytes, and the second must not quietly serve a line the first    **
** one never filled.                                                       **
**                                                                         **
** Checks                                                                  **
**   1. transfer 1 (cold, cache MISS): finished, no error bits, and every  **
**      DMA word equals WD0.IMG                                            **
**   2. the memory address register advanced by the word count             **
**   3. transfer 2 (same block, cache HIT): same data, still no error      **
**   4. a block further into the file (past the first cluster) also reads  **
**      correctly - a wrong FAT walk shows up here and not at block 0      **
**                                                                         **
** The card image is the shared one built by                               **
** Verilog/SD-FAT/sim/make_storage_image.sh (target test-nds-mount), which **
** carries WD0.IMG.                                                        **
**                                                                         **
** Verdict: TB_RESULT: PASS / TB_RESULT: FAIL <reason>                     **
**                                                                         **
** Ronny Hansen                                                            **
*****************************************************************************/
`timescale 1ns / 1ps

module nd_winchester_ticks_tb;

  // Micropolis 1325 / DISC-74-1, the geometry nd_storage_devices binds.
  localparam [15:0] WD_HEADS = 16'd8;
  localparam [15:0] WD_SPT   = 16'd9;

  // WD0.IMG on the shared card image (make_storage_image.sh).
  localparam integer WD_BYTES = 16384;
  localparam IMG_BYTES = 4 * 1024 * 1024;

  integer errors = 0;

  // WD0.IMG payload pattern - MUST match make_storage_image.sh
  function [7:0] pat_wd(input integer k);
    pat_wd = ((k % 256) + 61 * ((k / 256) % 256) + 83) % 256;
  endfunction

  // ------------------------------------------------------------- clocks
  // clk_cpu carries the controller AND the client side of nd_storage; the
  // card/region side runs on the skewed clk_stor, as on the board.
  reg clk_cpu = 0;
  always #21.7 clk_cpu = ~clk_cpu;    // ~23.04 MHz
  reg clk_stor = 0;
`ifdef WD_TICKS_STOR_EQ_CPU
  // Verilator full-boot wiring: ND120_TOP.v:511 sets s_stor_clk = clk1, i.e.
  // the storage domain IS the CPU clock, 1:1. The bench default (27 MHz vs
  // 23 MHz) is the Tang wiring and makes backend ticks 1.17x cheaper in
  // sysclk terms than the sim sees.
  always @(clk_cpu) clk_stor = clk_cpu;
`else
  always #18.5 clk_stor = ~clk_stor;  // ~27.03 MHz
`endif

  reg rst_n = 0;
  wire sysclk = clk_cpu;

  // ------------------------------------------------------------- IOX port
  reg  [15:0] iox_addr  = 16'd0;
  reg         iox_wr    = 1'b0;
  reg  [15:0] iox_wdata = 16'd0;
  reg         iox_rd    = 1'b0;
  wire [15:0] iox_rdata;
  wire        iox_sel;
  wire [3:0]  int_pending;
  // IDENT daisy chain, driven for real: the captured driver trace shows FSI
  // does NOT poll a transfer to completion - it reads status once while the
  // card is active and then WAITS FOR THE LEVEL-11 INTERRUPT. A completion
  // interrupt that never arrives is indistinguishable, from SINTRAN's side,
  // from a disc error. No Winchester bench had ever checked that the line
  // rises on a real transfer, so these pins were tied off here too.
  reg         ident_strobe   = 1'b0;
  reg  [3:0]  ident_level    = 4'd0;
  reg         ident_grant_in = 1'b0;
  wire        ident_grant_out, ident_hit;
  wire [15:0] ident_code;

  // ------------------------------------------------- REAL DMA PATH
  // The DMA is NOT faked here, and that is the whole point of this bench.
  // Every other Winchester testbench answers dma_req with dma_ack on the next
  // clock and ties dma_busy to 0, so ND_DMA_MASTER - the thing that actually
  // arbitrates for the ND-100 bus - has never been exercised with this card.
  // The SINTRAN boot hangs with the disc side FINISHED (all five reads
  // reported done) and the controller still ACTIVE, which is the signature of
  // the memory side never answering. A bench that always answers cannot
  // reproduce that, so this one runs the real master against a BCU + memory
  // model that implements the bus handshake (BREQ/BAPR/BDAP/BDRY).
  wire        dma_req, dma_wr;
  wire [23:0] dma_addr;
  wire [15:0] dma_wdata;
  wire [15:0] dma_rdata_w;
  wire        dma_ack, dma_err, dma_busy;
  integer     dma_writes = 0;
  integer     dma_reads  = 0;

  wire        m_breq_n;
  reg         grant_head_n = 1'b1;
  reg         bmem_n = 1'b1;
  reg  [23:0] mem_bd_n = 24'hFFFFFF;
  wire [23:0] m_bd_out_n;
  wire [23:0] mbd_bus_n = m_bd_out_n & mem_bd_n;
  wire        m_bapr_n, m_binput_n, m_bdap_n;
  reg         m_bdry_n = 1'b1;

  // MIN_GAP_TICKS: the dmapath bench uses 4 to keep the run short. ND120_CORE.v
  // instantiates every ND_DMA_MASTER WITHOUT overriding it, so the board and
  // the full Verilator boot run the module default of 32
  // (ND_DMA_MASTER.v:88). -DWD_TICKS_GAP=<n> selects it.
`ifdef WD_TICKS_GAP
  localparam [7:0] WD_GAP = `WD_TICKS_GAP;
`else
  localparam [7:0] WD_GAP = 8'd4;
`endif
  ND_DMA_MASTER #(.TIMEOUT_TICKS(16'd0), .MIN_GAP_TICKS(WD_GAP)) u_dma (
      .sysclk(sysclk), .sys_rst_n(rst_n),
      .dma_req(dma_req), .dma_wr(dma_wr), .dma_addr(dma_addr),
      .dma_wdata(dma_wdata), .dma_rdata(dma_rdata_w),
      .dma_ack(dma_ack), .dma_err(dma_err), .dma_busy(dma_busy),
      .BREQ_n(m_breq_n),
      .INGRANT_n(grant_head_n), .OUTGRANT_n(),
      .BMEM_n(bmem_n),
      .BD_23_0_n_OUT(m_bd_out_n), .BD_23_0_n_IN(mbd_bus_n),
      .BAPR_n(m_bapr_n), .BINPUT_n(m_binput_n), .BDAP_n(m_bdap_n),
      .BDRY_n(m_bdry_n)
  );

  // BCU + ND memory model - same protocol as nd_dma_master_tb.v and
  // nd_floppy_dma_tb.v, so the handshake is the proven one.
  reg [15:0] dmamem [0:65535];
  reg [23:0] m_addr;
  reg        m_write;
  reg [3:0]  m_state = 4'd0;
  reg [3:0]  m_cnt = 4'd0;

  always @(posedge sysclk) begin
    if (!rst_n) begin
      m_state <= 4'd0; grant_head_n <= 1'b1; bmem_n <= 1'b1;
      m_bdry_n <= 1'b1; mem_bd_n <= 24'hFFFFFF;
    end else case (m_state)
      4'd0: if (m_breq_n == 1'b0) begin m_cnt <= 4'd2; m_state <= 4'd1; end
      4'd1: begin
        if (m_cnt != 0) m_cnt <= m_cnt - 4'd1;
        else begin bmem_n <= 1'b0; grant_head_n <= 1'b0; m_state <= 4'd2; end
      end
      4'd2: if (m_bapr_n == 1'b0) begin
        m_addr  <= ~mbd_bus_n;
        m_write <= (m_binput_n == 1'b0);
        m_state <= 4'd3;
      end
      4'd3: if (m_bdap_n == 1'b0) begin
        if (m_write) begin
          dmamem[m_addr[15:0]] <= ~mbd_bus_n[15:0];
          dma_writes = dma_writes + 1;
        end else begin
          mem_bd_n <= ~{8'd0, dmamem[m_addr[15:0]]};
          dma_reads = dma_reads + 1;
        end
        m_bdry_n     <= 1'b0;
        grant_head_n <= 1'b1;
        m_state      <= 4'd4;
      end
      4'd4: if (m_bdap_n == 1'b1) begin
        m_bdry_n <= 1'b1;
        mem_bd_n <= 24'hFFFFFF;
        bmem_n   <= 1'b1;
        m_state  <= 4'd5;
      end
      4'd5: m_state <= 4'd0;
      default: m_state <= 4'd0;
    endcase
  end

  // ------------------------------------------------------------- backend seam
  wire        WDISK_START, WDISK_REQ, WDISK_WR;
  wire [15:0] WDISK_BLKADDR1, WDISK_BLKADDR2;
  wire [ 2:0] WDISK_UNIT;
  wire [10:0] WDISK_WORDCOUNT;
  wire        WDISK_DONE, WDISK_ERR;
  wire [ 9:0] WDBUF_ADDR;
  wire [15:0] WDBUF_WDATA;
  wire        WDBUF_WE;
  wire [15:0] WDBUF_RDATA;

  ND_WINCHESTER #(.DELAY_TICKS(WD_DELAY_TICKS)) dut (
      .sysclk         (sysclk),
      .sys_rst_n      (rst_n),
      .iox_addr       (iox_addr),
      .iox_wr         (iox_wr),
      .iox_wdata      (iox_wdata),
      .iox_rd         (iox_rd),
      .iox_rdata      (iox_rdata),
      .iox_sel        (iox_sel),
      .int_pending    (int_pending),
      .ident_strobe   (ident_strobe),
      .ident_level    (ident_level),
      .ident_grant_in (ident_grant_in),
      .ident_grant_out(ident_grant_out),
      .ident_hit      (ident_hit),
      .ident_code     (ident_code),
      .dma_req        (dma_req),
      .dma_wr         (dma_wr),
      .dma_addr       (dma_addr),
      .dma_wdata      (dma_wdata),
      // Served from the DMA memory, not a constant. A WRITE makes the
      // controller READ host memory, so a tied constant makes every write
      // test meaningless - it would store the same word everywhere and a
      // byte-order or address-stepping fault would look perfect.
      .dma_rdata      (dma_rdata_w),
      .dma_ack        (dma_ack),
      .dma_err        (dma_err),
      .dma_busy       (dma_busy),
      .disk_start     (WDISK_START),
      .disk_req       (WDISK_REQ),
      .disk_wr        (WDISK_WR),
      .disk_blkaddr1  (WDISK_BLKADDR1),
      .disk_blkaddr2  (WDISK_BLKADDR2),
      .disk_unit      (WDISK_UNIT),
      .disk_wordcount (WDISK_WORDCOUNT),
      .disk_done      (WDISK_DONE),
      .disk_err_in    (WDISK_ERR),
      .disk_err_code  (WDISK_ERR_CODE),
      .dbuf_addr      (WDBUF_ADDR),
      .dbuf_wdata     (WDBUF_WDATA),
      .dbuf_we        (WDBUF_WE),
      .dbuf_rdata     (WDBUF_RDATA)
  );

  // ------------------------------------------------------------- storage
  wire        sd_clk, sd_cmd_o, sd_cmd_oe, sd_dat0_o, sd_dat0_oe;
  wire        c_cmd_o, c_cmd_oe, c_dat0_o, c_dat0_oe;
  // SD lines resolved by MUX, no tristates: host output-enable wins, then
  // the card, then the bus pullup - the same rule as nd_storage_tb.v.
  wire        sd_cmd  = sd_cmd_oe  ? sd_cmd_o  : (c_cmd_oe  ? c_cmd_o  : 1'b1);
  wire        sd_dat0 = sd_dat0_oe ? sd_dat0_o : (c_dat0_oe ? c_dat0_o : 1'b1);

  wire        mem_start, mem_we, mem_busy, mem_done;
  wire [19:0] mem_addr;
  wire [31:0] mem_wdata, mem_rdata;

  nd_storage_devices #(
      .SIMULATE      (1),
      .INCLUDE_TAPE  (0),
      .INCLUDE_FLOPPY(1),   // as the Tang build: floppy AND Winchester both mount
      .INCLUDE_SMD   (0),
      .INCLUDE_WD    (1)
  ) u_src (
      .clk_stor  (clk_stor),
      .rst_stor_n(rst_n),
      .clk_cpu   (clk_cpu),
      .rst_cpu_n (rst_n),

      .byte_req     (1'b0),
      .byte_valid   (),
      .byte_data    (),
      .source_rewind(1'b0),

      .FDISK_REQ      (1'b0),
      .FDISK_WR       (1'b0),
      .FDISK_LSECT    (16'd0),
      .FDISK_FORMAT   (2'd0),
      .FDISK_DRIVE    (2'd0),
      .FDISK_WORDCOUNT(11'd0),
      .FDISK_DONE     (),
      .FDISK_ERR      (),
      .FDISK_ERR_CODE (),
      .FDISK_MEDIA_FMT(),
      .FDBUF_ADDR     (),
      .FDBUF_WDATA    (),
      .FDBUF_WE       (),
      .FDBUF_RDATA    (16'd0),

      .SDISK_START    (1'b0),
      .SDISK_REQ      (1'b0),
      .SDISK_WR       (1'b0),
      .SDISK_BLKADDR1 (16'd0),
      .SDISK_BLKADDR2 (16'd0),
      .SDISK_UNIT     (3'd0),
      .SDISK_WORDCOUNT(11'd0),
      .SDISK_DONE     (),
      .SDISK_ERR      (),
      .SDBUF_ADDR     (),
      .SDBUF_WDATA    (),
      .SDBUF_WE       (),
      .SDBUF_RDATA    (16'd0),

      .WDISK_START    (WDISK_START),
      .WDISK_REQ      (WDISK_REQ),
      .WDISK_WR       (WDISK_WR),
      .WDISK_BLKADDR1 (WDISK_BLKADDR1),
      .WDISK_BLKADDR2 (WDISK_BLKADDR2),
      .WDISK_UNIT     (WDISK_UNIT),
      .WDISK_WORDCOUNT(WDISK_WORDCOUNT),
      .WDISK_DONE     (WDISK_DONE),
      .WDISK_ERR      (WDISK_ERR),
      .WDBUF_ADDR     (WDBUF_ADDR),
      .WDBUF_WDATA    (WDBUF_WDATA),
      .WDBUF_WE       (WDBUF_WE),
      .WDBUF_RDATA    (WDBUF_RDATA),

      .sd_clk_o  (sd_clk),
      .sd_cmd_i  (sd_cmd),
      .sd_cmd_o  (sd_cmd_o),
      .sd_cmd_oe (sd_cmd_oe),
      .sd_dat0_i (sd_dat0),
      .sd_dat0_o (sd_dat0_o),
      .sd_dat0_oe(sd_dat0_oe),

      .mem_start(mem_start),
      .mem_we   (mem_we),
      .mem_addr (mem_addr),
      .mem_wdata(mem_wdata),
      .mem_rdata(mem_rdata),
      .mem_busy (mem_busy),
      .mem_done (mem_done),

      .sd_status()
  );

  // ---- the region -----------------------------------------------------
  // TWO builds from this one source, because the region is the ONE part of
  // the chain that differs between this bench and the board:
  //
  //   default            nds_mem_model - the abstract mem-port contract
  //   -DWD_TB_REAL_SDRAM the REAL MEM_RAM_49_SDRAM (ND_SDRAM_PACK16 +
  //                      ND_STORAGE_PORT) driving the behavioral SDRAM
  //                      chip, i.e. exactly what the Tang synthesizes
  //
  // Both nd_storage and MEM_RAM_49_SDRAM have their own passing benches, but
  // they had never been COMPOSED: nd_storage's benches all use
  // nds_mem_model, and mem_ram_49_sdram_tb.v drives the device port from a
  // synthetic task. A disagreement between those two mem-port contracts
  // would pass both benches and lose the data on the board - which is what a
  // read that finishes with no error and delivers 1024 zero words looks
  // like. This build is what makes that composition a tested thing.
`ifdef WD_TB_REAL_SDRAM
  // OSC and 2x clock, edge-aligned (same shape as mem_ram_49_sdram_tb.v).
  localparam OSC_PERIOD = 37;  // ~27 MHz
  reg clk2x = 1;
  always #(OSC_PERIOD / 4.0) clk2x = ~clk2x;
  reg osc = 1;
  always @(clk2x) if (clk2x) osc = ~osc;
  wire clk2x_sdram = ~clk2x;

  // Sheet-49 CPU side held idle: the device port is granted in the idle
  // slots, which is the case the board spends most of its time in anyway.
  wire sd_clk_c, sd_cke, sd_cs_n, sd_cas_n, sd_ras_n, sd_wen_n;
  wire [31:0] sd_dq;
  wire [10:0] sd_a;
  wire [ 1:0] sd_ba;
  wire [ 3:0] sd_dqm;

  MEM_RAM_49_SDRAM #(
      .CLK2X_FREQ(54_000_000)
  ) u_mem (
      .sysclk    (osc),
      .sys_rst_n (rst_n),
      .AA_9_0    (10'd0),
      .BANK0     (1'b0),
      .BANK1     (1'b0),
      .BANK2     (1'b0),
      .CAS       (1'b0),
      .RAS       (1'b0),
      .MWRITE50_n(1'b1),
      .DD_17_0_IN(18'd0),
      .DD_17_0_OUT(),
      .CORR_n    (),

      .clk2x      (clk2x),
      .clk2x_sdram(clk2x_sdram),

      .O_sdram_clk  (sd_clk_c),
      .O_sdram_cke  (sd_cke),
      .O_sdram_cs_n (sd_cs_n),
      .O_sdram_cas_n(sd_cas_n),
      .O_sdram_ras_n(sd_ras_n),
      .O_sdram_wen_n(sd_wen_n),
      .IO_sdram_dq  (sd_dq),
      .O_sdram_addr (sd_a),
      .O_sdram_ba   (sd_ba),
      .O_sdram_dqm  (sd_dqm),

      .stor_clk  (clk_stor),
      .stor_rst_n(rst_n),
      .mem_start (mem_start),
      .mem_we    (mem_we),
      .mem_addr  (mem_addr),
      .mem_wdata (mem_wdata),
      .mem_rdata (mem_rdata),
      .mem_busy  (mem_busy),
      .mem_done  (mem_done)
  );

  sdram_model u_sdram (
      .clk  (sd_clk_c),
      .cke  (sd_cke),
      .cs_n (sd_cs_n),
      .ras_n(sd_ras_n),
      .cas_n(sd_cas_n),
      .we_n (sd_wen_n),
      .a    (sd_a),
      .ba   (sd_ba),
      .dqm  (sd_dqm),
      .dq   (sd_dq)
  );
`else
  // Blocks 0 (staging) and 1.. (the cache pool) are all this needs;
  // 64K words covers pool lines 0..127.
  nds_mem_model #(
      .MEM_WORDS(65536)
  ) u_mem (
      .clk  (clk_stor),
      .rst_n(rst_n),
      .start(mem_start),
      .we   (mem_we),
      .addr (mem_addr),
      .wdata(mem_wdata),
      .rdata(mem_rdata),
      .busy (mem_busy),
      .done (mem_done)
  );
`endif

  sd_card_model #(
      .IMAGE           ("../../../SD-FAT/sim/nds_storage.img"),
      .MAX_BYTES       (IMG_BYTES),
      .LEGAL_MIN_SECTOR(0)
  ) card (
      .sd_clk   (sd_clk),
      .sd_cmd_i (sd_cmd),
      .sd_cmd_o (c_cmd_o),
      .sd_cmd_oe(c_cmd_oe),
      .sd_dat0_i(sd_dat0),
      .sd_dat0_o(c_dat0_o),
      .sd_dat0_oe(c_dat0_oe),
      .sd_dat1_i(1'b1), .sd_dat1_o(), .sd_dat1_oe(),
      .sd_dat2_i(1'b1), .sd_dat2_o(), .sd_dat2_oe(),
      .sd_dat3_i(1'b1), .sd_dat3_o(), .sd_dat3_oe()
  );

  // ------------------------------------------------------------- IOX driver
  task iox_write(input [15:0] a, input [15:0] d);
    begin
      @(posedge sysclk);
      iox_addr  <= a;
      iox_wdata <= d;
      iox_wr    <= 1'b1;
      @(posedge sysclk);
      iox_wr <= 1'b0;
      @(posedge sysclk);
    end
  endtask

  reg [15:0] rdlat;
  task iox_read(input [15:0] a);
    begin
      @(posedge sysclk);
      iox_addr <= a;
      iox_rd   <= 1'b1;
      @(posedge sysclk);
      // mirror ND_BUS_SLAVE: sample at the edge the strobe is still up
      rdlat  <= iox_rdata;
      iox_rd <= 1'b0;
      @(posedge sysclk);
    end
  endtask

  // Wait for the controller to report finished (status b3) rather than
  // guessing a cycle count. Reading +4 resets the flip-flops, so read it
  // ONCE per poll and stop as soon as b3 shows.
  reg [15:0] st;
  task wait_finished(input [255:0] what);
    integer guard;
    begin
      st    = 16'd0;
      guard = 0;
      // 40000 was enough only because the CACHED build had already filled
      // the early blocks, so a 4-block read was mostly hits. With the disc
      // clients DIRECT every block is a fresh fetch - 16 card sectors for a
      // 4096-word read - and the poll budget has to cover the slowest case,
      // not the luckiest.
      while (!st[3] && guard < 400000) begin
        iox_read(16'o504);
        st = rdlat;
        guard = guard + 1;
        repeat (20) @(posedge sysclk);
      end
      if (!st[3]) begin
        $display("TB_RESULT: FAIL %0s: never finished (last status %06o)",
                 what, st);
        $finish;
      end
    end
  endtask

  // One full transfer, exactly the oracle's register order.
  task do_transfer(input [15:0] blkaddr, input [15:0] memaddr,
                   input [15:0] wc, input [255:0] what);
    begin
      iox_write(16'o503, blkaddr);      // block address
      iox_write(16'o501, 16'd0);        // memory address, HI first
      iox_write(16'o501, memaddr);      // memory address, LO second
      iox_write(16'o507, wc);           // word count
      iox_write(16'o505, 16'd4);        // activate, M0 = read, no interrupt
      wait_finished(what);
    end
  endtask

  // M1 = WRITE. Op is control-word bits 13:11 (ND_WINCHESTER.v:198-205), so
  // M1 is (1 << 11) = 004000 octal, plus the activate bit 2.
  task do_write(input [15:0] blkaddr, input [15:0] memaddr,
                input [15:0] wc, input [255:0] what);
    begin
      iox_write(16'o503, blkaddr);      // block address
      iox_write(16'o501, 16'd0);        // memory address, HI first
      iox_write(16'o501, memaddr);      // memory address, LO second
      iox_write(16'o507, wc);           // word count
      iox_write(16'o505, 16'o004004);   // activate, M1 = write, no interrupt
      wait_finished(what);
    end
  endtask

  // Every DMA'd word must be the file's bytes. Byte 2w of the block is the
  // HIGH half of client word w (the packing the whole stack uses).
  task check_words(input [15:0] base, input integer fbyte0, input integer nwords,
                   input [255:0] what);
    integer w;
    reg [15:0] got, want;
    begin
      for (w = 0; w < nwords; w = w + 1) begin
        want = {pat_wd(fbyte0 + 2*w), pat_wd(fbyte0 + 2*w + 1)};
        got  = dmamem[base + w[15:0]];
        if (got !== want) begin
          if (errors < 8)
            $display("FAIL: %0s word %0d at %06o: got %06o want %06o",
                     what, w, base + w, got, want);
          errors = errors + 1;
        end
      end
    end
  endtask

  // ------------------------------------------------------------------------
  // DELAY_TICKS override. Bench default 20 (fast). -DWD_TICKS_DELAY=<n>
  // reproduces the full-boot value: Verilator DEV_CLK_HZ=100e6, SMD_DELAY_MS=8
  // => 800000 (ND120_CORE.v:365-379).
`ifdef WD_TICKS_DELAY
  localparam [31:0] WD_DELAY_TICKS = `WD_TICKS_DELAY;
`else
  localparam [31:0] WD_DELAY_TICKS = 32'd20;
`endif

  // -------------------------------------------------- free-running tick count
  integer tick = 0;
  always @(posedge sysclk) tick = tick + 1;

  // Per-phase accumulators, sampled every sysclk while a measured op runs.
  integer meas       = 0;   // 1 while we are inside a measured operation
  integer t_eng_idle = 0;
  integer t_disk_rd  = 0;
  integer t_mem_wr   = 0;
  integer t_mem_rd   = 0;
  integer t_disk_wr  = 0;
  integer t_delay    = 0;
  integer t_mem_cmp  = 0;
  integer t_dmabusy  = 0;   // ticks with the DMA master busy
  integer t_diskreq  = 0;   // ticks with disk_req asserted to the backend
  integer n_dma_ack  = 0;

  always @(posedge sysclk) if (meas) begin
    case (dut.s_eng)
      3'd0: t_eng_idle = t_eng_idle + 1;
      3'd1: t_disk_rd  = t_disk_rd  + 1;
      3'd2: t_mem_wr   = t_mem_wr   + 1;
      3'd3: t_mem_rd   = t_mem_rd   + 1;
      3'd4: t_disk_wr  = t_disk_wr  + 1;
      3'd5: t_delay    = t_delay    + 1;
      3'd6: t_mem_cmp  = t_mem_cmp  + 1;
      default: ;
    endcase
    if (dma_busy) t_dmabusy = t_dmabusy + 1;
    if (dut.disk_req) t_diskreq = t_diskreq + 1;
    if (dma_ack)  n_dma_ack = n_dma_ack + 1;
  end


  // ---- per-chunk backend timing: every stay in E_DISK_RD ----------------
  // disk_req is a ONE-CYCLE pulse (measured: 4 pulses for a 5-chunk read,
  // the first fires inside the +5 write before measurement starts), so the
  // chunk boundary is taken from the engine state, not from the strobe.
  integer chunk_t0   = 0;
  integer chunk_n    = 0;
  reg     chunk_open = 1'b0;
  always @(posedge sysclk) begin
    if (meas && dut.s_eng == 3'd1 && !chunk_open) begin
      chunk_open <= 1'b1;
      chunk_t0    = tick;
    end
    if (meas && chunk_open && dut.s_eng != 3'd1) begin
      chunk_open <= 1'b0;
      chunk_n     = chunk_n + 1;
      $display("    chunk %0d: %0d words, backend ticks = %0d",
               chunk_n, dut.s_chunk_q, tick - chunk_t0);
    end
    if (!meas) chunk_open <= 1'b0;
  end

  task clear_phase;
    begin
      t_eng_idle=0; t_disk_rd=0; t_mem_wr=0; t_mem_rd=0; t_disk_wr=0;
      t_delay=0; t_mem_cmp=0; t_dmabusy=0; t_diskreq=0; n_dma_ack=0;
      chunk_n=0;
    end
  endtask

  // ------------------------------------------------------------------------
  // A MEASURED operation: write GO, then watch dut.s_active (status bit 2)
  // directly instead of polling +4 - polling would charge the IOX reads to
  // the operation and also clear the flip-flops. Ticks are counted from the
  // sysclk edge on which s_active rises to the edge on which it falls.
  integer t0, t1, ticks_op;
  task timed_transfer(input [15:0] blkaddr, input [15:0] memaddr,
                      input [15:0] wc, input [15:0] ctrl,
                      input [255:0] what);
    integer guard;
    begin
      iox_write(16'o503, blkaddr);
      iox_write(16'o501, 16'd0);
      iox_write(16'o501, memaddr);
      iox_write(16'o507, wc);
      clear_phase();
      iox_write(16'o505, ctrl);          // GO
      // s_active is set inside the +5 write; it is already up here.
      if (!dut.s_active) begin
        $display("FAIL %0s: controller never went ACTIVE after GO", what);
        errors = errors + 1;
        disable timed_transfer;
      end
      t0   = tick;
      meas = 1;
      guard = 0;
      while (dut.s_active && guard < 2_000_000_000) begin
        @(posedge sysclk);
        guard = guard + 1;
      end
      meas = 0;
      t1   = tick;
      ticks_op = t1 - t0;
      if (dut.s_active) begin
        $display("FAIL %0s: never left ACTIVE", what);
        errors = errors + 1;
      end
    end
  endtask

  task report(input [255:0] what, input integer words);
    begin
      $display("");
      $display("---- %0s : %0d words ----", what, words);
      $display("  TOTAL ticks GO->ACTIVE-clear : %0d", ticks_op);
      if (words != 0)
        $display("  ticks per 1024-word chunk    : %0d",
                 (ticks_op * 1024) / words);
      $display("  E_DISK_RD (SD-FAT backend)   : %0d", t_disk_rd);
      $display("  E_MEM_WR  (DMA to ND memory) : %0d", t_mem_wr);
      $display("  E_MEM_RD  (DMA from memory)  : %0d", t_mem_rd);
      $display("  E_DISK_WR (SD-FAT write)     : %0d", t_disk_wr);
      $display("  E_MEM_CMP (M3 compare)       : %0d", t_mem_cmp);
      $display("  E_DELAY   (completion delay) : %0d", t_delay);
      $display("  E_IDLE (inside op)           : %0d", t_eng_idle);
      $display("  [overlay] dma_busy ticks     : %0d", t_dmabusy);
      $display("  [overlay] disk_req ticks     : %0d", t_diskreq);
      $display("  [overlay] dma_ack pulses     : %0d", n_dma_ack);
    end
  endtask

  integer i;

  initial begin
    for (i = 0; i < 65536; i = i + 1) dmamem[i] = 16'hFFFF;

    repeat (10) @(posedge clk_stor);
    rst_n = 1;
    repeat (50) @(posedge sysclk);

    for (i = 0; i < 3_000_000 && !u_src.gen_wd.s_wopened; i = i + 1)
      @(posedge clk_cpu);
    if (!u_src.gen_wd.s_wopened) begin
      $display("TB_RESULT: FAIL WD0.IMG never opened (mount did not complete)");
      $finish;
    end
    $display("== Winchester per-operation tick cost ==");
    $display("DELAY_TICKS = %0d", WD_DELAY_TICKS);
    $display("[ ok ] WD0.IMG mounted, size %0d bytes",
             u_src.size_bytes_w[223:192]);

    // Put the drive on cylinder first (M7), exactly as the driver does.
    iox_write(16'o505, 16'o034005);
    while (dut.s_active) @(posedge sysclk);
    iox_read(16'o504);

    // ---- 1. COLD 4608-word read, C/H/S 0/0/0 (5 chunks: 4x1024 + 512) ----
    dma_writes = 0;
    timed_transfer(16'd0, 16'o10000, 16'd4608, 16'o000004, "cold 4608-word read");
    report("COLD 4608-word read (all 5 chunks are cache misses)", 4608);
    if (dma_writes !== 4608) begin
      $display("FAIL: cold 4608 read moved %0d DMA words, want 4608", dma_writes);
      errors = errors + 1;
    end
    check_words(16'o10000, 0, 4608, "cold 4608");

    // ---- 2. WARM repeat of exactly the same read (cache now holds it) ----
    for (i = 0; i < 4608; i = i + 1) dmamem[16'o30000 + i] = 16'hFFFF;
    dma_writes = 0;
    timed_transfer(16'd0, 16'o30000, 16'd4608, 16'o000004, "warm 4608-word read");
    report("WARM 4608-word read (same blocks, cache hits)", 4608);
    if (dma_writes !== 4608) begin
      $display("FAIL: warm 4608 read moved %0d DMA words, want 4608", dma_writes);
      errors = errors + 1;
    end
    check_words(16'o30000, 0, 4608, "warm 4608");

    // ---- 3. single 1024-word chunk, cold and warm, for the per-chunk cost --
    for (i = 0; i < 1024; i = i + 1) dmamem[16'o50000 + i] = 16'hFFFF;
    dma_writes = 0;
    timed_transfer(16'd5, 16'o50000, 16'd1024, 16'o000004, "cold 1024 blk5");
    report("COLD 1024-word read, sector 5 (one cache miss)", 1024);

    for (i = 0; i < 1024; i = i + 1) dmamem[16'o52000 + i] = 16'hFFFF;
    dma_writes = 0;
    timed_transfer(16'd5, 16'o52000, 16'd1024, 16'o000004, "warm 1024 blk5");
    report("WARM 1024-word read, sector 5 (cache hit)", 1024);

    // ---- 4. zero-word operation: the pure fixed overhead ------------------
    timed_transfer(16'd0, 16'o10000, 16'd0, 16'o000004, "zero-word read");
    report("ZERO-word read (fixed overhead only)", 0);

    $display("");
    if (errors == 0) $display("TB_RESULT: PASS");
    else             $display("TB_RESULT: FAIL %0d errors", errors);
    $finish;
  end

  initial begin
    #40_000_000_000;
    $display("TB_RESULT: FAIL global timeout");
    $finish;
  end

endmodule

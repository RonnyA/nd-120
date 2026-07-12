/****************************************************************************
** Verilator wrapper for the nd_storage full stack (step-6 system gate)   **
**                                                                         **
** Wraps THE full nd_storage stack (mount FSM + engine + fatchk + GPL     **
** sd_file_reader + MIT sd_writer + SD pin mux) for the C++ harness       **
** test_nd_storage.cpp, following the proven sd_fat_test_vtop.v pattern:  **
**                                                                         **
**   - The C++ SD card model drives sd_cmd_c_drive/_c_val and             **
**     sd_dat0_c_drive/_c_val; this wrapper resolves each line WITHOUT    **
**     tristates (no 'z' - repo rule): DUT output-enable wins, then the   **
**     card model, then the bus pullup (1). Both sides see *_resolved.    **
**   - The SDRAM device port (mem_*) goes straight out to the C++         **
**     behavioral mem model (same contract as nds_mem_model.v:            **
**     start/we/addr/wdata sampled at start, randomized latency, rdata    **
**     valid at done).                                                    **
**   - Client ports 0..3 are wired out individually (flat, narrow ports - **
**     easy for the C++ side); clients 4..6 are tied off. Client 3 is     **
**     INSIDE PRELOAD_MASK here (unlike the board default) so the harness **
**     can exercise the missing-file open_err path against a real card    **
**     scan (SMD0.IMG is absent from the test image).                     **
**   - clk_stor and clk_cpu are separate inputs; the harness drives them  **
**     at non-integer-ratio frequencies (~27.03 / ~23.04 MHz) to stress   **
**     the CDC, exactly like the iverilog stack testbenches.              **
**                                                                         **
** Simulation parameters are fixed here (SIMULATE=1 short SD init, fast   **
** reader/writer clocks, 5M-cycle watchdog). Never synthesized.           **
**                                                                         **
** Last reviewed: 11-JUL-2026                                              **
** Ronny Hansen                                                            **
*****************************************************************************/

module nd_storage_vtop (
    input wire clk_stor,  // storage clock, 27 MHz class
    input wire clk_cpu,   // client clock (harness runs it at ~23 MHz: CDC stress)
    input wire rst_n,     // one reset for both domains (harness holds it long)

    // ---- SD pads: C++ card model on one side, DUT split pins on the other
    output wire sd_clk,
    input  wire sd_cmd_c_drive,    // C++ card model drives the CMD line
    input  wire sd_cmd_c_val,
    output wire sd_cmd_resolved,   // resolved CMD line (host + card + pullup)
    input  wire sd_dat0_c_drive,   // C++ card model drives DAT0
    input  wire sd_dat0_c_val,
    output wire sd_dat0_resolved,  // resolved DAT0 line

    // ---- SDRAM device port (clk_stor domain, C++ behavioral mem model)
    output wire        mem_start,
    output wire        mem_we,
    output wire [19:0] mem_addr,
    output wire [31:0] mem_wdata,
    input  wire [31:0] mem_rdata,
    input  wire        mem_busy,
    input  wire        mem_done,

    // ---- client ports 0..3 (clk_cpu domain; 4..6 tied off inside)
    input  wire [ 3:0] open_req_i,
    output wire [ 6:0] open_ok_o,
    output wire [ 6:0] open_err_o,
    output wire [31:0] size_bytes0,
    output wire [31:0] size_bytes1,
    output wire [31:0] size_bytes2,
    output wire [31:0] size_bytes3,
    input  wire [ 3:0] req_i,
    input  wire [ 3:0] wr_i,
    input  wire [15:0] block0,
    input  wire [15:0] block1,
    input  wire [15:0] block2,
    input  wire [15:0] block3,
    output wire [ 6:0] busy_o,
    output wire [ 6:0] done_o,
    output wire [ 6:0] err_o,
    output wire [ 9:0] buf_addr0,
    output wire [ 9:0] buf_addr1,
    output wire [ 9:0] buf_addr2,
    output wire [15:0] buf_wdata0,
    output wire [15:0] buf_wdata1,
    output wire [15:0] buf_wdata2,
    output wire [ 2:0] buf_we_o,
    input  wire [15:0] buf_rdata0,
    input  wire [15:0] buf_rdata1,
    input  wire [15:0] buf_rdata2,

    // ---- status
    output wire [1:0] sd_status,
    output wire [1:0] card_type,
    output wire [1:0] fs_type
);

  localparam N = 7;

  // ------------------------------------------------- resolved SD lines, no 'z'
  // Priority: DUT output enable, then the C++ card model, then the pullup.
  // The DUT and the card never drive simultaneously by SD protocol
  // construction (command/response and write-data/status phases alternate).
  wire s_cmd_o, s_cmd_oe, s_dat0_o, s_dat0_oe;

  wire s_cmd_bus  = s_cmd_oe  ? s_cmd_o  : (sd_cmd_c_drive  ? sd_cmd_c_val  : 1'b1);
  wire s_dat0_bus = s_dat0_oe ? s_dat0_o : (sd_dat0_c_drive ? sd_dat0_c_val : 1'b1);

  assign sd_cmd_resolved  = s_cmd_bus;
  assign sd_dat0_resolved = s_dat0_bus;

  // ------------------------------------------------- flattened client buses
  wire [N*32-1:0] s_size;
  wire [N*10-1:0] s_buf_addr;
  wire [N*16-1:0] s_buf_wdata;
  wire [N-1:0]    s_buf_we;

  assign size_bytes0 = s_size[31:0];
  assign size_bytes1 = s_size[63:32];
  assign size_bytes2 = s_size[95:64];
  assign size_bytes3 = s_size[127:96];

  assign buf_addr0 = s_buf_addr[9:0];
  assign buf_addr1 = s_buf_addr[19:10];
  assign buf_addr2 = s_buf_addr[29:20];

  assign buf_wdata0 = s_buf_wdata[15:0];
  assign buf_wdata1 = s_buf_wdata[31:16];
  assign buf_wdata2 = s_buf_wdata[47:32];

  assign buf_we_o = s_buf_we[2:0];

  // ------------------------------------------------- DUT: the full stack
  nd_storage #(
      .N_CLIENTS   (N),
      .RD_CLK_DIV  (3'd1),            // 27 MHz class clock in the sim
      .WR_CLKDIV   (8'd2),            // fast writer bit clock for sim speed
      .WD_MAX      (32'd5_000_000),
      .SIMULATE    (1),
      .PRELOAD_MASK(7'b0001111)       // client 3 mountable: missing-file case
  ) u_dut (
      .clk_stor  (clk_stor),
      .rst_stor_n(rst_n),
      .clk_cpu   (clk_cpu),
      .rst_cpu_n (rst_n),
      .sd_clk_o  (sd_clk),
      .sd_cmd_i  (s_cmd_bus),
      .sd_cmd_o  (s_cmd_o),
      .sd_cmd_oe (s_cmd_oe),
      .sd_dat0_i (s_dat0_bus),
      .sd_dat0_o (s_dat0_o),
      .sd_dat0_oe(s_dat0_oe),
      .mem_start (mem_start),
      .mem_we    (mem_we),
      .mem_addr  (mem_addr),
      .mem_wdata (mem_wdata),
      .mem_rdata (mem_rdata),
      .mem_busy  (mem_busy),
      .mem_done  (mem_done),
      .open_req  ({3'b000, open_req_i}),
      .open_ok   (open_ok_o),
      .open_err  (open_err_o),
      .size_bytes(s_size),
      .req       ({3'b000, req_i}),
      .wr        ({3'b000, wr_i}),
      .block     ({48'd0, block3, block2, block1, block0}),
      .busy      (busy_o),
      .done      (done_o),
      .err       (err_o),
      .buf_addr  (s_buf_addr),
      .buf_wdata (s_buf_wdata),
      .buf_we    (s_buf_we),
      .buf_rdata ({64'd0, buf_rdata2, buf_rdata1, buf_rdata0}),
      .sd_status (sd_status),
      .card_type (card_type),
      .fs_type   (fs_type)
  );

endmodule

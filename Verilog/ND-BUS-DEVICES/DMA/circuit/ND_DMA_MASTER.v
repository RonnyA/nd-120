/**************************************************************************
** ND-100 DMA BUS MASTER                                                 **
**                                                                       **
** The request/grant + memory-reference engine every DMA controller      **
** (floppy DMA, SMD) uses to exchange single words directly with the     **
** NORD-100 memory system. Protocol per ND-06.016.01 chapter V and       **
** docs/nd100-bus-dma.md:                                                **
**                                                                       **
**   1. Assert BREQ (wired-OR bus request) and wait.                     **
**   2. The Bus Control Unit answers with BMEM (leading edge freezes     **
**      request status) and daisy-chains OUTGRANT; the first module      **
**      with a frozen request receives INGRANT and stops the token.      **
**   3. Granted: present the 24-bit physical address on BD with BAPR;    **
**      BINPUT inactive = memory read, active = memory write.            **
**   4. Read: remove the address (no feedback), assert BDAP ("BD free,   **
**      memory may drive"); memory answers data + BDRY; strobe data on   **
**      BDRY. Write: present data combined with BDAP; memory strobes on  **
**      BDAP and answers BDRY = accepted.                                **
**   5. BDRY leading edge ends the grant; trailing edge releases the     **
**      bus. One word per allocation - block transfers re-request.       **
**                                                                       **
** BDAP driver note: the master drives BDAP in BOTH directions -         **
** verified against PAL_44902A ("PAUSE UNTIL BDAP OCCURS"), see          **
** docs/nd100-bus-dma.md section 9 gap 1 resolution.                     **
**                                                                       **
** Daisy chain: INGRANT_n in, OUTGRANT_n out. A module that is not       **
** requesting passes the token through; a claiming module consumes it.   **
**                                                                       **
** All bus signals active low; BD released = all ones. Client side is a  **
** one-word request/ack interface; the device (word counter, core        **
** address register) sits on top and re-requests per word.               **
**                                                                       **
** Last reviewed: 11-JUL-2026                                            **
** Ronny Hansen                                                          **
***************************************************************************/

module ND_DMA_MASTER #(
    // Safety net only: the real timeout guard is the BCU's (memory out
    // of range -> PES bit 14). This local counter stops a hung FSM in
    // sim/tbs; 0 disables it.
    parameter [15:0] TIMEOUT_TICKS = 16'd4096
) (
    input wire sysclk,
    input wire sys_rst_n,

    // Client (device core) side: one word per request
    input  wire        dma_req,       // pulse: start transfer (when !dma_busy)
    input  wire        dma_wr,        // with req: 0 = memory read, 1 = memory write
    input  wire [23:0] dma_addr,      // physical memory address
    input  wire [15:0] dma_wdata,     // write data
    output reg  [15:0] dma_rdata,     // read data, valid with dma_ack
    output reg         dma_ack,       // pulse: transfer complete
    output reg         dma_err,       // with ack: local timeout hit
    output wire        dma_busy,

    // ND-100 bus, master side
    output reg         BREQ_n,        // bus request (wired-OR line)
    input  wire        INGRANT_n,     // grant token in (OUTGRANT of the module before us / the BCU)
    output wire        OUTGRANT_n,    // grant token out (to the next module)
    input  wire        BMEM_n,        // memory cycle enable from the BCU; leading edge freezes requests
    output reg  [23:0] BD_23_0_n_OUT, // we drive the bus (address, write data); FFFFFF when released
    input  wire [23:0] BD_23_0_n_IN,  // bus as driven by others (read data from memory)
    output reg         BAPR_n,        // address present strobe
    output reg         BINPUT_n,      // direction: low = write (input to memory), high = read
    output reg         BDAP_n,        // data present / BD-free strobe (master-driven both ways)
    input  wire        BDRY_n         // data ready from memory
);

  localparam ST_IDLE  = 3'd0;
  localparam ST_REQ   = 3'd1;  // BREQ out, waiting for BMEM+INGRANT
  localparam ST_ADDR  = 3'd2;  // address on BD with BAPR
  localparam ST_DATA  = 3'd3;  // BDAP out, waiting for BDRY
  localparam ST_END   = 3'd4;  // BDRY seen: strobe/complete, wait release

  reg [2:0]  s_state;
  reg        s_wr;
  reg [23:0] s_addr;
  reg [15:0] s_wdata;
  reg        s_prev_bmem_n;
  reg [15:0] s_tick_cnt;
  reg [1:0]  s_phase_cnt;   // small strobe-width counter

  assign dma_busy = (s_state != ST_IDLE);

  wire s_bmem_fall = (BMEM_n == 1'b0) && (s_prev_bmem_n == 1'b1);

  // Request freeze (F.2, Figure V.4.1 "DMA REQ. STATUS IS FROZEN"):
  // only a request asserted BEFORE the leading edge of BMEM takes part
  // in the current grant round. s_req_frozen latches our status at the
  // BMEM edge; s_frozen_eff covers the edge cycle itself (the register
  // updates one clock later).
  reg  s_req_frozen;
  wire s_frozen_eff = s_req_frozen | (s_bmem_fall && (s_state == ST_REQ));

  // Daisy chain: combinational pass-through, like the search chain on
  // the real backplane. We consume the token only when FROZEN-in and
  // waiting (Figure V.5.1: an un-frozen requester must keep connecting
  // INGRANT to OUTGRANT), and for the whole transfer once granted - if
  // the token leaked past a granted master mid-cycle, the next
  // requester downstream would start its own cycle on the occupied bus.
  wire s_claiming = ((s_state == ST_REQ) && s_frozen_eff) ||
                    (s_state == ST_ADDR) || (s_state == ST_DATA) ||
                    (s_state == ST_END);
  assign OUTGRANT_n = INGRANT_n | s_claiming;

  always @(posedge sysclk or negedge sys_rst_n) begin
    if (!sys_rst_n) begin
      s_state       <= ST_IDLE;
      s_wr          <= 1'b0;
      s_addr        <= 24'd0;
      s_wdata       <= 16'd0;
      s_req_frozen  <= 1'b0;
      s_prev_bmem_n <= 1'b1;
      s_tick_cnt    <= 16'd0;
      s_phase_cnt   <= 2'd0;
      dma_rdata     <= 16'd0;
      dma_ack       <= 1'b0;
      dma_err       <= 1'b0;
      BREQ_n        <= 1'b1;
      BD_23_0_n_OUT <= 24'hFFFFFF;
      BAPR_n        <= 1'b1;
      BINPUT_n      <= 1'b1;
      BDAP_n        <= 1'b1;
    end else begin
      dma_ack <= 1'b0;

      // Freeze latch: sampled at the BMEM leading edge, cleared when the
      // round is over (BMEM inactive)
      if (BMEM_n == 1'b1) s_req_frozen <= 1'b0;
      else if (s_bmem_fall) s_req_frozen <= (s_state == ST_REQ);

      case (s_state)
        ST_IDLE: begin
          dma_err <= 1'b0;
          if (dma_req) begin
            s_wr     <= dma_wr;
            s_addr   <= dma_addr;
            s_wdata  <= dma_wdata;
            BREQ_n   <= 1'b0;
            s_state  <= ST_REQ;
            s_tick_cnt <= 16'd0;
          end
        end

        // Wait for the allocation: BMEM active AND our request frozen in
        // at its leading edge AND the grant token reaching us. A request
        // raised after the BMEM edge waits for the next round (F.2).
        ST_REQ: begin
          if ((BMEM_n == 1'b0) && (INGRANT_n == 1'b0) && s_frozen_eff) begin
            // Granted: drop the request, start the address cycle
            BREQ_n        <= 1'b1;
            BD_23_0_n_OUT <= ~s_addr;
            BAPR_n        <= 1'b0;
            BINPUT_n      <= s_wr ? 1'b0 : 1'b1;  // low = write
            s_phase_cnt   <= 2'd2;
            s_state       <= ST_ADDR;
          end
        end

        // Hold address + BAPR for two clocks, then move to the data part
        ST_ADDR: begin
          if (s_phase_cnt != 2'd0) begin
            s_phase_cnt <= s_phase_cnt - 2'd1;
          end else begin
            BAPR_n <= 1'b1;
            if (s_wr) begin
              // Write: data on BD combined with BDAP
              BD_23_0_n_OUT <= ~{8'd0, s_wdata};
            end else begin
              // Read: remove the address, BD free for memory
              BD_23_0_n_OUT <= 24'hFFFFFF;
            end
            BDAP_n  <= 1'b0;
            s_state <= ST_DATA;
          end
        end

        // Wait for memory's BDRY
        ST_DATA: begin
          if (BDRY_n == 1'b0) begin
            if (!s_wr) begin
              dma_rdata <= ~BD_23_0_n_IN[15:0];  // strobe read data on BDRY
            end
            // Leading edge of BDRY terminates the grant: release our
            // strobes and data
            BDAP_n        <= 1'b1;
            BD_23_0_n_OUT <= 24'hFFFFFF;
            BINPUT_n      <= 1'b1;
            s_state       <= ST_END;
          end
        end

        // Trailing edge of BDRY releases the bus; complete toward the client
        ST_END: begin
          if (BDRY_n == 1'b1) begin
            dma_ack <= 1'b1;
            s_state <= ST_IDLE;
          end
        end

        default: s_state <= ST_IDLE;
      endcase

      // Local hang guard (sim safety net; the real guard is the BCU's)
      if (TIMEOUT_TICKS != 16'd0 && s_state != ST_IDLE) begin
        s_tick_cnt <= s_tick_cnt + 16'd1;
        if (s_tick_cnt >= TIMEOUT_TICKS) begin
          BREQ_n        <= 1'b1;
          BAPR_n        <= 1'b1;
          BDAP_n        <= 1'b1;
          BINPUT_n      <= 1'b1;
          BD_23_0_n_OUT <= 24'hFFFFFF;
          dma_err       <= 1'b1;
          dma_ack       <= 1'b1;
          s_state       <= ST_IDLE;
        end
      end

      s_prev_bmem_n <= BMEM_n;
    end
  end

endmodule

/*
  Contributors:
    * Dovydas Liutkus (dovli@dtu.dk)
  Description:
    * Image processing accelerator Student Subsystem
    * APB slave: CSR + indexed input/output frame buffer access
    * FSM copies input buffer to output buffer, applying pixel processing
    * CPU flow:
    *   1. Write pixels via IBUF_ADDR + IBUF_DATA (auto-incrementing)
    *   2. Write DATA_READY=1 to CSR
    *   3. Poll DONE bit in CSR
    *   4. Read pixels via OBUF_ADDR + OBUF_DATA (auto-incrementing)
    *
    * Register map (byte offsets):
    *   0x00  CSR        [0] DATA_READY (W1S, auto-cleared by FSM)
    *                    [1] DONE       (RO,  cleared when DATA_READY set)
    *                    [2] BUSY       (RO,  high while FSM running)
    *   0x04  IBUF_ADDR  input buffer word-address pointer  (RW)
    *   0x08  IBUF_DATA  input buffer write port            (WO, auto-increments IBUF_ADDR)
    *   0x0C  OBUF_ADDR  output buffer word-address pointer (RW)
    *   0x10  OBUF_DATA  output buffer read port            (RO, auto-increments OBUF_ADDR)
    *
    * Buffer layout: each APB word holds (32 / PIXEL_WIDTH) = 4 pixels,
    * packed little-endian (pixel 0 in LSBs).
    *
    * NOTE: do not write to IBUF while BUSY=1; do not read OBUF until DONE=1.
    *
    * Pipeline note (ibuf BRAM has 1-cycle read latency):
    *   cycle 0: FSM_PROCESS entered, ibuf[0] read issued,  no obuf write (pipe_valid=0)
    *   cycle 1: ibuf[1] read issued, obuf[0] <= f(ibuf_rdata), pipe_valid=1
    *   ...
    *   cycle N: ibuf[N] read issued (last), obuf[N-1] written
    *   cycle N+1: FSM_DONE, obuf[N] written (pipeline drain), done
*/

module Student_area_0 #(
    parameter int APB_AW       = 12,
    parameter int PIXEL_WIDTH  = 8,    // bits per pixel
    parameter int FRAME_WIDTH  = 352,  // pixels per row
    parameter int FRAME_HEIGHT = 288   // rows per frame
)(
    // Interface: APB
    input  logic [APB_AW-1:0]   PADDR,
    input  logic                PENABLE,
    input  logic                PSEL,
    input  logic [31:0]         PWDATA,
    input  logic                PWRITE,
    input  logic [3:0]          PSTRB,      // Unused
    output logic [31:0]         PRDATA,
    output logic                PREADY,
    output logic                PSLVERR,

    input  logic                clk_in,
    input  logic                rst,        // Reset active-low

    // Interface: IRQ
    output logic                irq,

    // Unused
    input  logic [7:0]          clk_ctrl,
    input  logic                irq_en,
    input  logic                high_speed_clk,
    input  logic [15:0]         pmod_gpi,
    output logic [15:0]         pmod_gpo,
    output logic [15:0]         pmod_gpio_oe
);

// ============================================================
// Register offsets
// ============================================================
localparam logic [APB_AW-1:0] ADDR_CSR       = 'h00;
localparam logic [APB_AW-1:0] ADDR_IBUF_ADDR = 'h04;
localparam logic [APB_AW-1:0] ADDR_IBUF_DATA = 'h08;
localparam logic [APB_AW-1:0] ADDR_OBUF_ADDR = 'h0C;
localparam logic [APB_AW-1:0] ADDR_OBUF_DATA = 'h10;

// Derived parameters
localparam int PIXELS_PER_WORD = 32 / PIXEL_WIDTH;
localparam int TOTAL_PIXELS    = FRAME_WIDTH * FRAME_HEIGHT;
localparam int BUF_DEPTH       = TOTAL_PIXELS / PIXELS_PER_WORD;
localparam int BUF_AW          = $clog2(BUF_DEPTH);
// BUF_DEPTH words × 4 B = (352×288/4) × 4 = 101 376 B ≈ 99 KB per buffer

// FSM
typedef enum logic [1:0] {
    FSM_IDLE    = 2'b00,
    FSM_PROCESS = 2'b01,  // pipelined read-process-write loop
    FSM_DONE    = 2'b10   // pipeline drain: write last word, assert DONE
} fsm_state_t;

fsm_state_t        fsm_state;
logic [BUF_AW-1:0] proc_addr;    // ibuf read address (current)
logic [BUF_AW-1:0] proc_addr_d;  // ibuf read address delayed 1 cycle = obuf write address
logic              pipe_valid;    // 0 on first FSM_PROCESS cycle (ibuf_rdata not yet valid)

// CSR registers
logic csr_data_ready, csr_done, csr_busy;

// Buffer address pointers
logic [BUF_AW-1:0] ibuf_waddr, obuf_raddr;
logic              obuf_rd_wait;  // one-cycle wait state for obuf BRAM read latency

// BRAM port wires
logic              ibuf_wr_en, obuf_wr_en;
logic [BUF_AW-1:0] ibuf_wr_addr, obuf_wr_addr;
logic [31:0]       ibuf_wr_data, obuf_wr_data;
logic              ibuf_rd_en, obuf_rd_en;
logic [BUF_AW-1:0] ibuf_rd_addr, obuf_rd_addr;
logic [31:0]       ibuf_rd_data, obuf_rd_data;  // registered by bram_sdp, valid 1 cycle after rd_en

// Processed pixel word - student writes this in the always_comb block below
logic [31:0] pixel_out;

// ============================================================
// BRAM instances
// ============================================================
bram_sdp #(.DATA_WIDTH(32), .ADDR_WIDTH(BUF_AW), .DEPTH(BUF_DEPTH)) ibuf (
    .clk     (clk_in),
    .wr_en   (ibuf_wr_en),
    .wr_addr (ibuf_wr_addr),
    .wr_data (ibuf_wr_data),
    .rd_en   (ibuf_rd_en),
    .rd_addr (ibuf_rd_addr),
    .rd_data (ibuf_rd_data)
);

bram_sdp #(.DATA_WIDTH(32), .ADDR_WIDTH(BUF_AW), .DEPTH(BUF_DEPTH)) obuf (
    .clk     (clk_in),
    .wr_en   (obuf_wr_en),
    .wr_addr (obuf_wr_addr),
    .wr_data (obuf_wr_data),
    .rd_en   (obuf_rd_en),
    .rd_addr (obuf_rd_addr),
    .rd_data (obuf_rd_data)
);

// ============================================================
// ibuf BRAM port - write: APB, read: FSM
// ============================================================
assign ibuf_wr_en   = PSEL && !PREADY && PWRITE && (PADDR == ADDR_IBUF_DATA);
assign ibuf_wr_addr = ibuf_waddr;
assign ibuf_wr_data = PWDATA;
assign ibuf_rd_en   = (fsm_state == FSM_PROCESS);
assign ibuf_rd_addr = proc_addr;

// ============================================================
// obuf BRAM port - write: FSM, read: APB
// ============================================================
assign obuf_wr_en   = pipe_valid;   // suppressed on first FSM_PROCESS cycle
assign obuf_wr_addr = proc_addr_d;
assign obuf_wr_data = pixel_out;
assign obuf_rd_en   = PSEL && !PREADY && !PWRITE && (PADDR == ADDR_OBUF_DATA);
assign obuf_rd_addr = obuf_raddr;

// ============================================================
// STUDENT: Implement your pixel processing algorithm below
// ibuf_rd_data contains the pixel word read from ibuf one cycle ago.
// Compute pixel_out from ibuf_rd_data - it will be written to obuf.
// ============================================================
always_comb begin
    pixel_out = ~ibuf_rd_data;  // Invert all pixels (replace with your algorithm)
end

// ============================================================
// APB register file + FSM  (synchronous reset)
// ============================================================
always_ff @(posedge clk_in or negedge rst) begin
    if (~rst) begin
        PREADY         <= 1'b0;
        PSLVERR        <= 1'b0;
        PRDATA         <= '0;
        csr_data_ready <= 1'b0;
        csr_done       <= 1'b0;
        csr_busy       <= 1'b0;
        ibuf_waddr     <= '0;
        obuf_raddr     <= '0;
        obuf_rd_wait   <= 1'b0;
        fsm_state      <= FSM_IDLE;
        proc_addr      <= '0;
        proc_addr_d    <= '0;
        pipe_valid     <= 1'b0;
    end else begin

        // ----------------------------------------------------------
        // APB slave
        // ----------------------------------------------------------
        if (PSEL) begin
            if (PREADY) begin
                PREADY <= 1'b0;
            end else if (!PWRITE && PADDR == ADDR_OBUF_DATA && !obuf_rd_wait) begin
                // BRAM read latency: hold off PREADY for one cycle so obuf_rd_data is valid
                obuf_rd_wait <= 1'b1;
                PREADY       <= 1'b0;
            end else begin
                PSLVERR      <= 1'b0;
                PREADY       <= 1'b1;
                obuf_rd_wait <= 1'b0;

                if (PWRITE) begin    // WRITE
                    case (PADDR)
                        ADDR_CSR: begin
                            if (PWDATA[0] && fsm_state == FSM_IDLE) begin
                                csr_data_ready <= 1'b1;
                                csr_done       <= 1'b0;
                            end
                        end
                        ADDR_IBUF_ADDR: ibuf_waddr <= PWDATA[BUF_AW-1:0];
                        ADDR_IBUF_DATA: begin
                            if (ibuf_waddr < BUF_AW'(BUF_DEPTH - 1))
                                ibuf_waddr <= ibuf_waddr + 1'b1;
                        end
                        ADDR_OBUF_ADDR: obuf_raddr <= PWDATA[BUF_AW-1:0];
                        default:        PSLVERR <= 1'b1;
                    endcase
                end else begin      // READ
                    case (PADDR)
                        ADDR_CSR:       PRDATA <= 32'({csr_busy, csr_done, csr_data_ready});
                        ADDR_IBUF_ADDR: PRDATA <= 32'(ibuf_waddr);
                        ADDR_OBUF_ADDR: PRDATA <= 32'(obuf_raddr);
                        ADDR_OBUF_DATA: begin
                            PRDATA <= obuf_rd_data;  // valid: BRAM read was issued one cycle ago
                            if (obuf_raddr < BUF_AW'(BUF_DEPTH - 1))
                                obuf_raddr <= obuf_raddr + 1'b1;
                        end
                        default: begin
                            PRDATA  <= '0;
                            PSLVERR <= 1'b1;
                        end
                    endcase
                end
            end
        end else begin
            PREADY       <= 1'b0;
            PSLVERR      <= 1'b0;
            obuf_rd_wait <= 1'b0;
        end

        // ----------------------------------------------------------
        // Processing FSM
        // ----------------------------------------------------------
        case (fsm_state)
            FSM_IDLE: begin
                if (csr_data_ready) begin
                    csr_data_ready <= 1'b0;
                    csr_busy       <= 1'b1;
                    proc_addr      <= '0;
                    pipe_valid     <= 1'b0;
                    fsm_state      <= FSM_PROCESS;
                end
            end

            FSM_PROCESS: begin
                pipe_valid  <= 1'b1;
                proc_addr_d <= proc_addr;

                if (proc_addr == BUF_AW'(BUF_DEPTH - 1))
                    fsm_state <= FSM_DONE;
                else
                    proc_addr <= proc_addr + 1'b1;
            end

            FSM_DONE: begin
                // obuf_wr_en is still high (pipe_valid=1), writing the last word
                csr_busy   <= 1'b0;
                csr_done   <= 1'b1;
                pipe_valid <= 1'b0;
                fsm_state  <= FSM_IDLE;
            end

            default: fsm_state <= FSM_IDLE;
        endcase

    end
end

// IRQ fires when DONE is set and interrupts are enabled
assign irq = csr_done & irq_en;

// Tie-off unused GPIO interface
assign pmod_gpo     = 16'h0;
assign pmod_gpio_oe = 16'h0;

endmodule

// ============================================================
// Simple dual-port BRAM (1 write port + 1 read port)
// No reset on memory or read output (required for BRAM inference).
// ============================================================
module bram_sdp #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH      = 1024
) (
    input  logic                  clk,
    // Write port
    input  logic                  wr_en,
    input  logic [ADDR_WIDTH-1:0] wr_addr,
    input  logic [DATA_WIDTH-1:0] wr_data,
    // Read port
    input  logic                  rd_en,
    input  logic [ADDR_WIDTH-1:0] rd_addr,
    output logic [DATA_WIDTH-1:0] rd_data
);

    // (* ram_style = "block" *) logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    always_ff @(posedge clk) begin
        if (wr_en)
            mem[wr_addr] <= wr_data;
    end

    always_ff @(posedge clk) begin
        if (rd_en)
            rd_data <= mem[rd_addr];
    end

endmodule

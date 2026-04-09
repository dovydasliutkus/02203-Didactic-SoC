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
*/

module Student_area_0 #(
    parameter int APB_AW       = 12,
    parameter int PIXEL_WIDTH  = 8,    // bits per pixel
    parameter int FRAME_WIDTH  = 352,  // pixels per row
    parameter int FRAME_HEIGHT = 288   // rows per frame
)(
    // Interface: APB
    input  logic [31:0]         PADDR,
    input  logic                PENABLE,
    input  logic                PSEL,
    input  logic [31:0]         PWDATA,
    input  logic                PWRITE,
    input  logic [3:0]          PSTRB, // Unused
    output logic [31:0]         PRDATA,
    output logic                PREADY,
    output logic                PSLVERR,

    // Interface: IRQ
    output logic                irq,

    // Interface: SS_Ctrl
    input  logic [7:0]          clk_ctrl,
    input  logic                irq_en,

    // Interface: clk
    input  logic                clk_in,

    // Interface: high_speed_clock
    input  logic                high_speed_clk,

    // Interface: reset (active-low)
    input  logic                rst,

    // Interface: GPIO pmod (unused in this design) TODO: maybe remove
    input  logic [15:0]         pmod_gpi,
    output logic [15:0]         pmod_gpo,
    output logic [15:0]         pmod_gpio_oe
);

// Derived parameters
localparam int PIXELS_PER_WORD = 32 / PIXEL_WIDTH;
localparam int TOTAL_PIXELS    = FRAME_WIDTH * FRAME_HEIGHT;
localparam int BUF_DEPTH       = TOTAL_PIXELS / PIXELS_PER_WORD;
localparam int BUF_AW          = $clog2(BUF_DEPTH);

// Buffer size for reference:
// BUF_DEPTH words × 4 B = (352×288/4) × 4 = 101 376 B ≈ 99 KB per buffer

// ============================================================
// Register offsets
// ============================================================
localparam logic [APB_AW-1:0] ADDR_CSR       = 'h00;
localparam logic [APB_AW-1:0] ADDR_IBUF_ADDR = 'h04;
localparam logic [APB_AW-1:0] ADDR_IBUF_DATA = 'h08;
localparam logic [APB_AW-1:0] ADDR_OBUF_ADDR = 'h0C;
localparam logic [APB_AW-1:0] ADDR_OBUF_DATA = 'h10;

// Frame buffers
logic [31:0] ibuf [0:BUF_DEPTH-1];
logic [31:0] obuf [0:BUF_DEPTH-1];

// Internal registers
// CSR bits
logic csr_data_ready;
logic csr_done;
logic csr_busy;

// Buffer address pointers
logic [BUF_AW-1:0] ibuf_waddr;
logic [BUF_AW-1:0] obuf_raddr;

// FSM
typedef enum logic [1:0] {
    FSM_IDLE       = 2'b00,
    FSM_PROCESSING = 2'b01,
    FSM_DONE       = 2'b10
} fsm_state_t;

fsm_state_t        fsm_state;
logic [BUF_AW-1:0] proc_addr;

// ============================================================
// Sequential logic — APB register file + FSM
// ============================================================
always_ff @(posedge clk_in or negedge rst) begin
    if (~rst) begin
        // APB
        PREADY     <= 1'b0;
        PSLVERR    <= 1'b0;
        PRDATA     <= '0;
        // FSM
        csr_data_ready <= 1'b0;
        csr_done       <= 1'b0;
        csr_busy       <= 1'b0;
        ibuf_waddr     <= '0;
        obuf_raddr     <= '0;
        fsm_state      <= FSM_IDLE;
        proc_addr      <= '0;
    end else begin
        // APB Slave
        if (PSEL) begin
            if (PREADY) begin
                // deassert ready after transfer is accepted
                PREADY <= 1'b0;
            end else begin
                PSLVERR <= 1'b0;
                PREADY  <= 1'b1;

                if (PWRITE) begin
                    case (PADDR)
                        ADDR_CSR: begin
                            if (PWDATA[0] && fsm_state == FSM_IDLE) begin // Bit0 in CSR signals data is ready
                                csr_data_ready <= 1'b1;
                                csr_done       <= 1'b0;
                            end
                        end
                        ADDR_IBUF_ADDR: begin 
                            ibuf_waddr <= PWDATA[BUF_AW-1:0];
                        end
                        ADDR_IBUF_DATA: begin
                            ibuf[ibuf_waddr] <= PWDATA;
                            if (ibuf_waddr < BUF_AW'(BUF_DEPTH - 1)) // Auto increment ibuf address
                                ibuf_waddr <= ibuf_waddr + 1'b1;
                        end
                        ADDR_OBUF_ADDR: begin
                            obuf_raddr <= PWDATA[BUF_AW-1:0];
                        end
                        default: PSLVERR <= 1'b1; // ERR if write to RO or unmapped
                    endcase

                end else begin // read
                    case (PADDR)
                        ADDR_CSR: begin
                            PRDATA <= 32'({csr_busy, csr_done, csr_data_ready});
                        end
                        ADDR_IBUF_ADDR: begin
                            PRDATA <= 32'(ibuf_waddr);
                        end
                        ADDR_OBUF_ADDR: begin
                            PRDATA <= 32'(obuf_raddr);
                        end
                        ADDR_OBUF_DATA: begin
                            PRDATA <= obuf[obuf_raddr];
                            if (obuf_raddr < BUF_AW'(BUF_DEPTH - 1))
                                obuf_raddr <= obuf_raddr + 1'b1;
                        end
                        default: begin           // ERR if read from unmapped
                            PRDATA  <= '0;
                            PSLVERR <= 1'b1;
                        end
                    endcase
                end
            end
        end else begin
            PREADY  <= 1'b0;
            PSLVERR <= 1'b0;
        end

        // ----------------------------------------------------
        // Processing FSM
        // csr_data_ready is only set to 1 by APB (when fsm_state==IDLE,
        // so current value is 0), and cleared to 0 here — no conflict.
        // ----------------------------------------------------
        case (fsm_state)
            FSM_IDLE: begin
                if (csr_data_ready) begin
                    csr_data_ready <= 1'b0;
                    csr_busy       <= 1'b1;
                    proc_addr      <= '0;
                    fsm_state      <= FSM_PROCESSING;
                end
            end

            FSM_PROCESSING: begin
                // ============================================================
                // STUDENT: Starting with this state you should add logic to
                // implement the edge detection algorithm.
                obuf[proc_addr] <= ~ibuf[proc_addr];

                if (proc_addr == BUF_AW'(BUF_DEPTH - 1))
                    fsm_state <= FSM_DONE;
                else
                    proc_addr <= proc_addr + 1'b1;
            end

            FSM_DONE: begin
                csr_busy  <= 1'b0;
                csr_done  <= 1'b1;
                fsm_state <= FSM_IDLE;
            end

            default: fsm_state <= FSM_IDLE;
        endcase

    end
end

// IRQ fires when DONE is set and interrupts are enabled. Can be used so CPU doesn't have to poll CSR
assign irq = csr_done & irq_en;

// GPIO not used
assign pmod_gpo     = 16'h0;
assign pmod_gpio_oe = 16'h0;

endmodule

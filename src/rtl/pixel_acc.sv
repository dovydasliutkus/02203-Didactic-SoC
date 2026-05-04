// ============================================================
//  pixel_acc - STUDENT MODULE
//
//  You are given direct read access to ibuf and write access
//  to obuf. Both are synchronous BRAMs with 1-cycle read latency.
//
//  Interface:
//    start  - pulsed high for 1 cycle to begin processing
//    finish - assert high for 1 cycle when all output words
//             have been written to obuf
//
//  ibuf read port:
//    Set ibuf_rd_en=1 and ibuf_rd_addr to the word you want.
//    ibuf_rd_data is valid on the NEXT clock cycle.
//
//  obuf write port:
//    Set obuf_wr_en=1, obuf_wr_addr, obuf_wr_data on the same cycle.
//    The word is written on the rising edge.
//
//  Parameters:
//    BUF_AW    - address width (ibuf/obuf have 2^BUF_AW words)
//    BUF_DEPTH - total number of words in each buffer
//    IMG_WIDTH - frame width in words (= pixels per row / 4)
// ============================================================
module pixel_acc #(
    parameter int BUF_AW    = 15,
    parameter int BUF_DEPTH = 25344,
    parameter int IMG_WIDTH = 88      // 352 pixels / 4 pixels-per-word
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // ibuf read port
    output logic                  ibuf_rd_en,
    output logic [BUF_AW-1:0]     ibuf_rd_addr,
    input  logic [31:0]           ibuf_rd_data,

    // obuf write port
    output logic                  obuf_wr_en,
    output logic [BUF_AW-1:0]     obuf_wr_addr,
    output logic [31:0]           obuf_wr_data,

    // handshake
    input  logic                  start,
    output logic                  finish
);

    // ============================================================
    // BRAM has 1-cycle read latency, so:
    //   cycle 0: read ibuf[0] issued  (rd_data not yet valid)
    //   cycle 1: read ibuf[1] issued, ibuf[0] data valid -> write obuf[0]
    //   ...
    //   cycle N: read ibuf[N] issued (last), write obuf[N-1]
    //   cycle N+1: no new read, write obuf[N], assert finish
    //
    // ============================================================

    typedef enum logic [1:0] {
        IDLE    = 2'b00,
        PROCESS = 2'b01,
        DRAIN   = 2'b10
    } state_t;

    state_t            state;
    logic [BUF_AW-1:0] rd_addr;   // current ibuf read address
    logic [BUF_AW-1:0] wr_addr;   // current obuf write address (= rd_addr delayed 1 cycle)
    logic              pipe_valid; // 0 on first PROCESS cycle (rd_data not yet valid)
    logic [31:0] pixel_out;
    

    // ---- FSM ----
    always_ff @(posedge clk) begin
        if (~rst_n) begin
            state      <= IDLE;
            rd_addr    <= '0;
            wr_addr    <= '0;
            pipe_valid <= 1'b0;
            ibuf_rd_en <= 1'b0;
            obuf_wr_en <= 1'b0;
            finish     <= 1'b0;
        end else begin
            ibuf_rd_en <= 1'b0;
            obuf_wr_en <= 1'b0;
            finish     <= 1'b0;

            case (state)
                IDLE: begin
                    pipe_valid <= 1'b0;
                    if (start) begin
                        rd_addr      <= '0;
                        ibuf_rd_en   <= 1'b1;
                        ibuf_rd_addr <= '0;
                        state        <= PROCESS;
                    end
                end

                PROCESS: begin
                    pipe_valid <= 1'b1;
                    wr_addr    <= rd_addr;  // write address tracks read address with 1 cycle latency

                    // Write result from previous read (suppressed on first cycle)
                    if (pipe_valid) begin
                        obuf_wr_en   <= 1'b1;
                        obuf_wr_addr <= wr_addr;
                        obuf_wr_data <= pixel_out;
                    end

                    if (rd_addr == BUF_AW'(BUF_DEPTH - 1)) begin
                        // Last read issued - drain the pipeline
                        ibuf_rd_en <= 1'b0;
                        state      <= DRAIN;
                    end else begin
                        rd_addr      <= rd_addr + 1'b1;
                        ibuf_rd_en   <= 1'b1;
                        ibuf_rd_addr <= rd_addr + 1'b1;
                    end
                end

                DRAIN: begin
                    // Write the last word (pipeline had one word in flight)
                    obuf_wr_en   <= 1'b1;
                    obuf_wr_addr <= wr_addr;
                    obuf_wr_data <= pixel_out;
                    finish       <= 1'b1;
                    state        <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
    
    always_comb begin
        pixel_out = ~ibuf_rd_data;  // TASK 0: invert all pixels
    end
endmodule
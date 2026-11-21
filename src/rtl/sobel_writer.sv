module sobel_writer #(
    parameter int BUF_AW    = 15,
    parameter int IMG_WIDTH = 88,
    parameter int IMG_HEIGHT = 288
)(
    input  logic               clk,
    input  logic               rst_n,

    input  logic [7:0]         pixel_0,
    input  logic [7:0]         pixel_1,
    input  logic [7:0]         pixel_2,
    input  logic [7:0]         pixel_3,

    input  logic               first,
    input  logic               write,
    input  logic               flush,
//    input  logic               zero_row,

    output logic               obuf_wr_en,
    output logic [BUF_AW-1:0]  obuf_wr_addr,
    output logic [31:0]        obuf_wr_data
);

    typedef enum logic [1:0] {
        IDLE    = 2'd0,
        STORE_2 = 2'd1,
        STORE_4 = 2'd2,
        FLUSH   = 2'd3
//        ZERO    = 3'd4
    } state_t;

    state_t             state_q, state_d;

    logic [23:0]        carry_q, carry_d;
    logic [BUF_AW-1:0]  wa_q, wa_d;

    logic               wr_en;
    logic [31:0]        wr_data;

    localparam logic [BUF_AW-1:0] WA_FIRST = BUF_AW'(IMG_WIDTH);
    localparam logic [BUF_AW-1:0] WA_LAST = BUF_AW'(IMG_WIDTH * (IMG_HEIGHT - 1) - 1);

    always_comb begin : behavior
        wr_en   = 1'b0;
        wr_data = '0;
        carry_d = carry_q;
        wa_d    = wa_q;
        state_d = IDLE;

        case (state_q)
            IDLE: begin
                if (first) begin
                    state_d = STORE_2;
                end else if (write) begin
                    state_d = STORE_4;
                end
                // end else if (zero_row) begin
                //     state_d = ZERO;
                // end
            end
            STORE_2: begin
                carry_d = {pixel_3, pixel_2, 8'b0};
                state_d = IDLE;
            end
            STORE_4: begin
                wr_en   = 1'b1;
                wr_data = {pixel_0, carry_q};
                carry_d = {pixel_3, pixel_2, pixel_1};
                state_d = flush ? FLUSH : IDLE;
            end
            FLUSH: begin
                wr_en   = 1'b1;
                wr_data = {8'b0, carry_q};
                state_d = /*zero_row ? ZERO :*/ IDLE;
            end
            // ZERO: begin
            //     wr_en   = 1'b1;
            //     state_d = zero_row ? ZERO : IDLE;
            // end
            default: state_d = IDLE;
        endcase

        if (wr_en)
            wa_d = (wa_q == WA_LAST) ? WA_FIRST : wa_q + 1'b1;
    end

    always_ff @(posedge clk or negedge rst_n) begin : fsm
        if (!rst_n) begin
            state_q <= IDLE;
            wa_q    <= WA_FIRST;
            carry_q <= '0;
        end else begin
            state_q <= state_d;
            wa_q    <= wa_d;
            carry_q <= carry_d;
        end
    end

    assign obuf_wr_en   = wr_en;
    assign obuf_wr_addr = wa_q;
    assign obuf_wr_data = wr_data;

endmodule

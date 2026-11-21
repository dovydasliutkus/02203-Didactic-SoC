module sobel_controller #(
    parameter int IMG_WIDTH  = 88,
    parameter int IMG_HEIGHT = 288
)(
    input  logic       clk,
    input  logic       rst_n,

    input  logic       start,
    output logic       finish,

    output logic       load_en,
    output logic [1:0] row_sel,
    output logic       init,

    output logic       first,
    output logic       write,
    output logic       flush
    //output logic       zero_row
);

    localparam int K_W = $clog2(IMG_WIDTH);
    localparam int R_W = $clog2(IMG_HEIGHT);

    localparam  logic [K_W-1:0] K_LAST = K_W'(IMG_WIDTH - 1);
    localparam  logic [R_W-1:0] R_LAST = R_W'(IMG_HEIGHT - 3);

    typedef enum logic [3:0] {
        IDLE      = 4'd0,
        LOAD_1    = 4'd1,
        LOAD_2    = 4'd2,
        LOAD_3    = 4'd3,
        _WAIT     = 4'd4,
        COMP_2    = 4'd5,
        COMP_4    = 4'd6,
        NEXT_ROW  = 4'd7,
        DONE      = 4'd8
    } state_t;

    state_t         state_q, state_d;

    logic [K_W-1:0] k_q, k_d;
    logic [R_W-1:0] r_q, r_d;
    
    
    always_comb begin

        state_d = state_q;
        k_d = k_q;
        r_d = r_q;
        finish = 1'b0;
        load_en = 1'b0;
        row_sel = 2'd0;
        init = 1'b0;
        first = 1'b0;
        write = 1'b0;
        flush = 1'b0;
    
        case (state_q)
            IDLE: begin
                r_d = '0;
                k_d = '0;
                state_d = (start) ? LOAD_1 : IDLE;        
            end
            LOAD_1: begin
                load_en = 1;
                row_sel = 2'd0;
                init = (k_q == '0);
                state_d = LOAD_2;
            end
            LOAD_2: begin
                load_en = 1'b1;
                row_sel = 2'd1;
                init = (k_q == '0);
                state_d = LOAD_3;
            end
            LOAD_3: begin
                load_en = 1'b1;
                row_sel = 2'd2;
                init = (k_q == '0);
                state_d = _WAIT;
            end
            _WAIT: begin
                state_d = (k_q == '0) ? COMP_2 : COMP_4;
            end
            COMP_2: begin
                first = 1'b1;
                k_d = k_q + 1'b1;
                state_d = LOAD_1;
            end
            COMP_4: begin
                write = 1'b1;
                k_d = k_q + 1'b1;
                state_d = (k_q == K_LAST) ? NEXT_ROW : LOAD_1;
            end
            NEXT_ROW: begin
                flush = 1'b1;
                k_d = '0;
                r_d = r_q + 1'b1;
                state_d = (r_q == R_LAST) ? DONE : LOAD_1;
            end
            DONE: begin
                finish = 1;
                state_d = IDLE;
            end
            default: state_d = IDLE;
        endcase
    
    end
    
    
    always_ff @(posedge clk or negedge rst_n) begin : fsm
        if (!rst_n) begin
            state_q <= IDLE;
            k_q <= '0;
            r_q <= '0;
        end else begin
            state_q <= state_d;
            k_q <= k_d;
            r_q <= r_d;
        end
    end

endmodule

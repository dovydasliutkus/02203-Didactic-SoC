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
    output logic       flush,
    output logic       zero_row
);

    localparam int K_W = $clog2(IMG_WIDTH);
    localparam int R_W = $clog2(IMG_HEIGHT);

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
    
        case (state_q)
            IDLE: begin
                r_d = 0;
                k_d = 0;
                finish = 0;
                load_en = 0;
                row_sel = 0;
                init = 0;
                first = 0;
                write = 0;
                flush = 0;
                state_d = (start) ? LOAD_1 : IDLE;        
            end
            LOAD_1: begin
                load_en = 1;
                row_sel = 2'd0;
                flush = 0;
                init = (k_q == 0);
                state_d = LOAD_2;
            end
            LOAD_2: begin
                row_sel = 2'd1;
                state_d = LOAD_3;
            end
            LOAD_3: begin
                row_sel = 2'd2;
                state_d = _WAIT;
            end
            _WAIT: begin
                load_en = 0;
                state_d = (k_q == 0) ? COMP_2 : COMP_4;
            end
            COMP_2: begin
                first = 1;
                k_d = k_q + 1;
                state_d = LOAD_1;
            end
            COMP_4: begin
                write = 1;
                k_d = k_q + 1;
                state_d = (k_q == 87) ? NEXT_ROW : LOAD_1;
            end
            NEXT_ROW: begin
                flush = 1;
                r_d = r_q + 1;
                state_d = (r_q == 286) ? DONE : LOAD_1;
            end
            DONE: begin
                finish = 1;
                state_d = IDLE;
            end
        endcase
    
    end
    
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state_q <= IDLE;
        else
            state_q <= state_d;
            k_q <= k_d;
            r_q <= r_d;
    end

endmodule

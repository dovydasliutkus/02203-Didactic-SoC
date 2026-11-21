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

    localparam int IMG_HEIGHT = BUF_DEPTH / IMG_WIDTH;

    logic                 load_en;
    logic [1:0]           row_sel;
    logic                 init;

    logic                 first;
    logic                 write;
    logic                 flush;
    //logic                 zero_row;

    logic [2:0][2:0][7:0] win_0, win_1, win_2, win_3;
    logic [7:0]           pixel_0, pixel_1, pixel_2, pixel_3;

    sobel_controller #(
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT)
    ) u_ctrl (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .finish   (finish),
        .load_en  (load_en),
        .row_sel  (row_sel),
        .init     (init),
        .first    (first),
        .write    (write),
        .flush    (flush)
        //.zero_row (zero_row)
    );

    sobel_loader #(
        .BUF_AW     (BUF_AW),
        .IMG_WIDTH  (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT)
    ) u_ld (
        .clk          (clk),
        .rst_n        (rst_n),
        .load_en      (load_en),
        .row_sel      (row_sel),
        .init         (init),
        .ibuf_rd_en   (ibuf_rd_en),
        .ibuf_rd_addr (ibuf_rd_addr),
        .ibuf_rd_data (ibuf_rd_data),
        .win_0        (win_0),
        .win_1        (win_1),
        .win_2        (win_2),
        .win_3        (win_3)
    );

    sobel_kernel u_sobel_0 (.win(win_0), .pixel(pixel_0));
    sobel_kernel u_sobel_1 (.win(win_1), .pixel(pixel_1));
    sobel_kernel u_sobel_2 (.win(win_2), .pixel(pixel_2));
    sobel_kernel u_sobel_3 (.win(win_3), .pixel(pixel_3));

    sobel_writer #(
        .BUF_AW    (BUF_AW),
        .IMG_WIDTH (IMG_WIDTH),
        .IMG_HEIGHT (IMG_HEIGHT)
    ) u_wr (
        .clk          (clk),
        .rst_n        (rst_n),
        .pixel_0      (pixel_0),
        .pixel_1      (pixel_1),
        .pixel_2      (pixel_2),
        .pixel_3      (pixel_3),
        .first        (first),
        .write        (write),
        .flush        (flush),
        //.zero_row     (zero_row),
        .obuf_wr_en   (obuf_wr_en),
        .obuf_wr_addr (obuf_wr_addr),
        .obuf_wr_data (obuf_wr_data)
    );

endmodule

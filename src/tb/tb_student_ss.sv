`timescale 1ns/1ps

module tb_student_ss;

parameter string src_image = "pattern.pgm";

parameter string src_image_path = "../src/tb/src_images/";
parameter string out_image_path = "../src/tb/out_images/";

// Parameters matching DUT defaults
localparam int PIXEL_WIDTH  = 8;
localparam int FRAME_WIDTH  = 352;
localparam int FRAME_HEIGHT = 288;
localparam int TOTAL_PIXELS = FRAME_WIDTH * FRAME_HEIGHT;
localparam int PIXELS_PER_WORD = 32 / PIXEL_WIDTH;
localparam int BUF_DEPTH    = TOTAL_PIXELS / PIXELS_PER_WORD;

// Clock / reset
logic clk = 0;
always #5 clk = ~clk;  // 100 MHz

logic rst = 0;

// APB signals
logic [31:0] PADDR;
logic        PENABLE, PSEL, PWRITE;
logic [31:0] PWDATA;
logic [3:0]  PSTRB;
logic [31:0] PRDATA;
logic        PREADY, PSLVERR;

// Other DUT ports
logic        irq;
logic [7:0]  clk_ctrl = 8'h01;
logic        irq_en   = 0;

// DUT
Student_area_0 #(
    .PIXEL_WIDTH  (PIXEL_WIDTH),
    .FRAME_WIDTH  (FRAME_WIDTH),
    .FRAME_HEIGHT (FRAME_HEIGHT)
) dut (
    .PADDR          (PADDR),
    .PENABLE        (PENABLE),
    .PSEL           (PSEL),
    .PWDATA         (PWDATA),
    .PWRITE         (PWRITE),
    .PSTRB          (PSTRB),
    .PRDATA         (PRDATA),
    .PREADY         (PREADY),
    .PSLVERR        (PSLVERR),
    .irq            (irq),
    .clk_ctrl       (clk_ctrl),
    .irq_en         (irq_en),
    .clk_in         (clk),
    .high_speed_clk (clk),
    .rst            (rst)
);

// ----------------------------------------------------------------
// APB helper tasks
// ----------------------------------------------------------------
task apb_write(input logic [31:0] addr, input logic [31:0] data);
    @(posedge clk); #1;
    PSEL = 1; PWRITE = 1; PADDR = addr; PWDATA = data; PENABLE = 0;
    @(posedge clk); #1;
    PENABLE = 1;
    @(posedge clk);
    while (!PREADY) @(posedge clk);
    #1;
    PSEL = 0; PENABLE = 0; PWRITE = 0;
endtask

task apb_read(input logic [31:0] addr, output logic [31:0] data);
    @(posedge clk); #1;
    PSEL = 1; PWRITE = 0; PADDR = addr; PWDATA = 0; PENABLE = 0;
    @(posedge clk); #1;
    PENABLE = 1;
    @(posedge clk);
    while (!PREADY) @(posedge clk);
    data = PRDATA;
    #1;
    PSEL = 0; PENABLE = 0;
endtask


// ----------------------------------------------------------------
// Main test
// ----------------------------------------------------------------

// Image buffers
logic [7:0] pixels_in  [0:TOTAL_PIXELS-1];
logic [7:0] pixels_out [0:TOTAL_PIXELS-1];

integer      fd, i;
integer      tmp_val;
string       hdr_str, out_path;
logic [31:0] word, csr;

initial begin
    // Default APB idle state
    PSEL = 0; PENABLE = 0; PWRITE = 0;
    PADDR = 0; PWDATA = 0; PSTRB = 4'hF;

    // Reset
    rst = 0;
    repeat(4) @(posedge clk);
    rst = 1;
    repeat(4) @(posedge clk);

    // ----------------------------------------------------------
    // 1. Read input PGM
    // ----------------------------------------------------------

    fd = $fopen({src_image_path, src_image}, "r");
    if (fd == 0) begin
        $fatal(1, "ERROR: could not open %s%s", src_image_path, src_image);
    end

    // Skip P2 header lines (magic, comment, dimensions, maxval)
    $fgets(hdr_str, fd);  // P2
    $fgets(hdr_str, fd);  // comment
    $fgets(hdr_str, fd);  // width height
    $fgets(hdr_str, fd);  // maxval

    // Read ASCII pixel values
    for (i = 0; i < TOTAL_PIXELS; i++) begin
        $fscanf(fd, "%d", tmp_val);
        pixels_in[i] = tmp_val[7:0];
    end
    $fclose(fd);
    $display("INFO: image loaded (%0d pixels)", TOTAL_PIXELS);

    // ----------------------------------------------------------
    // 2. Write pixels into input buffer via APB
    // ----------------------------------------------------------
    apb_write(32'h04, 32'h0);  // Set IBUF_ADDR to 0

    // Assemble APB word from 4 pixels
    for (i = 0; i < BUF_DEPTH; i++) begin
        word = {pixels_in[i*4+3], pixels_in[i*4+2],
                pixels_in[i*4+1], pixels_in[i*4+0]};
        apb_write(32'h08, word);  // Write to IBUF (auto-increments)
    end

    // ----------------------------------------------------------
    // 3. Trigger processing
    // ----------------------------------------------------------
    apb_write(32'h00, 32'h1);  // CSR DATA_READY = 1

    // ----------------------------------------------------------
    // 4. Poll DONE bit (CSR[1])
    // ----------------------------------------------------------
    csr = 0;
    while (!csr[1]) begin
        apb_read(32'h00, csr);
    end
    $display("INFO: processing done");

    // ----------------------------------------------------------
    // 5. Read output buffer
    // ----------------------------------------------------------
    apb_write(32'h0C, 32'h0);  // Set OBUF_ADDR to 0

    // Read from the Output Buffer
    for (i = 0; i < BUF_DEPTH; i++) begin
        apb_read(32'h10, word);  // OBUF_DATA (auto-increments)
        pixels_out[i*4+0] = word[7:0];
        pixels_out[i*4+1] = word[15:8];
        pixels_out[i*4+2] = word[23:16];
        pixels_out[i*4+3] = word[31:24];
    end

    // ----------------------------------------------------------
    // 6. Write output PGM
    // ----------------------------------------------------------
    out_path = {out_image_path, src_image.substr(0, src_image.len()-5), "_result.pgm"};
    fd = $fopen(out_path, "w");
    $fwrite(fd, "P2\n%0d %0d\n255\n", FRAME_WIDTH, FRAME_HEIGHT);
    for (i = 0; i < TOTAL_PIXELS; i++)
        $fwrite(fd, "%0d\n", pixels_out[i]);
    $fclose(fd);
    $display("INFO: output written to %s", out_path);

    $finish;
end

endmodule

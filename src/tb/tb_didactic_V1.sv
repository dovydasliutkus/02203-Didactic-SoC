`timescale 1ns/1ns

module tb_didactic;

initial
//shall print %t with scaled in ns (-9), with 2 precision digits, and would print the " ns" string
  $timeformat(-9, 2, " ns", 20);

// Parameters
parameter string TESTCASE     = "blink";  // hex loaded from: ../build/sw/<TESTCASE>.hex
parameter string SRC_IMAGE    = "pattern.pgm";
parameter string SRC_IMG_PATH = "../src/tb/src_images/";
parameter string OUT_IMG_PATH = "../src/tb/out_images/";

localparam int FRAME_WIDTH  = 352;
localparam int FRAME_HEIGHT = 288;
localparam int TOTAL_PIXELS = FRAME_WIDTH * FRAME_HEIGHT;

// UART bit period:
//   SIM_UART_MODEL + SIM_FAST_UART: behavioral model, divisor=2, no 16x  → 20 ns/bit
//   SIM_FAST_UART only:             real UART 16750, divisor=2           → 320 ns/bit
//   default:                        real UART 16750, divisor=27          → 4340 ns/bit
`ifdef SIM_UART_MODEL
  `ifdef SIM_FAST_UART
    localparam real UART_BIT_NS = 20.0;   // divisor=2, 1x sampling → 2 clk/bit
  `else
    localparam real UART_BIT_NS = 270.0;  // divisor=27, 1x sampling → 27 clk/bit
  `endif
`elsif SIM_FAST_UART
  localparam real UART_BIT_NS = 320.0;    // real UART, divisor=2, 16x → 32 clk/bit
`else
  localparam real UART_BIT_NS = 4340.0;   // real UART, divisor=27, 16x → 432 clk/bit
`endif

// ----------------------------------------------------------------
// Clock / reset
// ----------------------------------------------------------------
logic clk   = 1'b0;
logic reset = 1'b0;
always #5 clk = ~clk;  // 100 MHz

// ----------------------------------------------------------------
// DUT wiring — inout ports require tri/wire intermediaries
// ----------------------------------------------------------------
logic tb_uart_tx = 1'b1;   // TB → DUT (idle high)

tri0  dut_clk;
tri0  dut_reset;
tri0  dut_uart_rx;
tri0  dut_uart_tx;

assign dut_clk     = clk;
assign dut_reset   = reset;
assign dut_uart_rx = tb_uart_tx;

// SPI / GPIO / JTAG — tied off
tri1  dut_spi_csn0, dut_spi_csn1;
tri0  dut_spi_sck;
tri1  dut_spi_data0, dut_spi_data1, dut_spi_data2, dut_spi_data3;
tri0  dut_gpio [15:0];
tri1  dut_jtag_tck, dut_jtag_tdi, dut_jtag_tms, dut_jtag_trst;
wire  dut_jtag_tdo;

// DUT
Didactic i_didactic (
    .clk_in   (dut_clk),
    .reset    (dut_reset),
    .uart_rx  (dut_uart_rx),
    .uart_tx  (dut_uart_tx),
    .gpio     ({dut_gpio[15],dut_gpio[14],dut_gpio[13],dut_gpio[12],
               dut_gpio[11],dut_gpio[10],dut_gpio[9], dut_gpio[8],
               dut_gpio[7], dut_gpio[6], dut_gpio[5], dut_gpio[4],
               dut_gpio[3], dut_gpio[2], dut_gpio[1], dut_gpio[0]}),
    .spi_csn  ({dut_spi_csn1, dut_spi_csn0}),
    .spi_sck  (dut_spi_sck),
    .spi_data ({dut_spi_data3, dut_spi_data2, dut_spi_data1, dut_spi_data0}),
    .jtag_tck (dut_jtag_tck),
    .jtag_tdi (dut_jtag_tdi),
    .jtag_tdo (dut_jtag_tdo),
    .jtag_tms (dut_jtag_tms),
    .jtag_trst(dut_jtag_trst)
);

// ----------------------------------------------------------------
// UART TX task  (TB -> DUT)
// ----------------------------------------------------------------
task automatic uart_send_byte(input logic [7:0] data);
    tb_uart_tx = 1'b0;               // start bit
    #(UART_BIT_NS * 1ns);
    for (int b = 0; b < 8; b++) begin
        tb_uart_tx = data[b];        // LSB first
        #(UART_BIT_NS * 1ns);
    end
    tb_uart_tx = 1'b1;               // stop bit
    #(UART_BIT_NS * 1ns);
endtask

// ----------------------------------------------------------------
// UART RX task  (DUT -> TB)
// ----------------------------------------------------------------
task automatic uart_recv_byte(output logic [7:0] data);
    @(negedge dut_uart_tx);                  // wait for start bit
    #(UART_BIT_NS * 0.5 * 1ns);             // sample mid-start-bit
    for (int b = 0; b < 8; b++) begin
        #(UART_BIT_NS * 1ns);
        data[b] = dut_uart_tx;               // LSB first
    end
    #(UART_BIT_NS * 1ns);                    // consume stop bit
endtask

// Image buffers
logic [7:0] pixels_in  [0:TOTAL_PIXELS-1];
logic [7:0] pixels_out [0:TOTAL_PIXELS-1];

// ----------------------------------------------------------------
// Main test
// ----------------------------------------------------------------
integer  fd, i;
integer  tmp_val;
string   hdr_str, out_path;
logic [31:0] obuf_word;

initial begin
    // ----------------------------------------------------------
    // Load CPU program into IMEM
    // ----------------------------------------------------------
    $readmemh({"../build/sw/", TESTCASE, ".hex"}, tb_didactic.i_didactic.SystemControl_SS.SysCtrl_SS.i_imem.ram);
    $display("[TB] IMEM loaded from ../build/sw/%s.hex", TESTCASE);

    // ----------------------------------------------------------
    // Read input PGM (P2 ASCII)
    // ----------------------------------------------------------
    fd = $fopen({SRC_IMG_PATH, SRC_IMAGE}, "r");
    if (fd == 0)
        $fatal(1, "[TB] ERROR: could not open %s%s", SRC_IMG_PATH, SRC_IMAGE);

    void'($fgets(hdr_str, fd));  // P2
    void'($fgets(hdr_str, fd));  // comment
    void'($fgets(hdr_str, fd));  // width height
    void'($fgets(hdr_str, fd));  // maxval
    for (i = 0; i < TOTAL_PIXELS; i++) begin
        $fscanf(fd, "%d", tmp_val);
        pixels_in[i] = tmp_val[7:0];
    end
    $fclose(fd);
    $display("[TB] Image loaded (%0d pixels)", TOTAL_PIXELS);

    // ----------------------------------------------------------
    // Reset sequence
    // ----------------------------------------------------------
    reset = 1'b0;
    repeat(10) @(posedge clk);
    reset = 1'b1;
    $display("[TB] Reset released");

`ifdef BYPASS_UART
    // ----------------------------------------------------------
    // BYPASS_UART: pre-load ibuf directly then let the CPU run.
    // The firmware is compiled with -DBYPASS_UART so it skips the
    // UART receive loop and goes straight to writing CSR_DATA_READY.
    // This exercises the full firmware CSR path without the serial link.
    // ----------------------------------------------------------
    $display("[TB] BYPASS_UART: pre-loading ibuf directly...");
    for (i = 0; i < TOTAL_PIXELS /4 + 1; i++) begin
        force tb_didactic.i_didactic.Student_SS_0.Student_area_0.ibuf[i] =
            {pixels_in[i*4+3], pixels_in[i*4+2], pixels_in[i*4+1], pixels_in[i*4+0]};
    end

    #2500;  // wait for CPU boot

    @(posedge clk);
    for (i = 0; i < TOTAL_PIXELS/4 + 1; i++)
        release tb_didactic.i_didactic.Student_SS_0.Student_area_0.ibuf[i];
    $display("[TB] ibuf pre-loaded, waiting for CPU to write CSR_DATA_READY...");
`else
    // ----------------------------------------------------------
    // Normal flow: wait for CPU boot, send image via UART
    // ----------------------------------------------------------
    // Wait for CPU to boot and initialise UART
    #2500;

    $display("[TB] Sending image via UART...");
    for (i = 0; i < TOTAL_PIXELS; i++) begin
        uart_send_byte(pixels_in[i]);
        if (i % 1000 == 0) $display("[TB] Sent %0d / %0d bytes @ %0t", i, TOTAL_PIXELS, $time);
    end
    $display("[TB] Image sent, waiting for result...");
`endif

    // ----------------------------------------------------------
    // Wait for accelerator DONE flag
    // ----------------------------------------------------------
    $display("[TB] Waiting for accelerator DONE...");
    
    wait(tb_didactic.i_didactic.Student_SS_0.Student_area_0.csr_done === 1'b1);
    @(posedge clk);  // one extra cycle so last obuf write is settled
    $display("[TB] Accelerator done @ %0t ns", $time);

    // ----------------------------------------------------------
    // Read output directly from accelerator obuf (no UART TX needed)
    // ----------------------------------------------------------
    for (i = 0; i < TOTAL_PIXELS / 4; i++) begin
        obuf_word = tb_didactic.i_didactic.Student_SS_0.Student_area_0.obuf[i];
        pixels_out[i*4+0] = obuf_word[7:0];
        pixels_out[i*4+1] = obuf_word[15:8];
        pixels_out[i*4+2] = obuf_word[23:16];
        pixels_out[i*4+3] = obuf_word[31:24];
    end
    $display("[TB] Result read from obuf");

    // ----------------------------------------------------------
    // Write output PGM (P2 ASCII)
    // ----------------------------------------------------------
    out_path = {OUT_IMG_PATH, SRC_IMAGE.substr(0, SRC_IMAGE.len()-5), "_result.pgm"};
    fd = $fopen(out_path, "w");
    $fwrite(fd, "P2\n%0d %0d\n255\n", FRAME_WIDTH, FRAME_HEIGHT);
    for (i = 0; i < TOTAL_PIXELS; i++)
        $fwrite(fd, "%0d\n", pixels_out[i]);
    $fclose(fd);
    $display("[TB] Output written to %s", out_path);

    $finish;
end

endmodule

/*
 * apb_uart_sim.sv  —  minimal behavioral UART for fast simulation
 *
 * Drop-in replacement for apb_uart (UART 16750).
 * Implements only what pixel_inversion.c needs:
 *   - uart_init()     : writes to FCR, LCR/DLAB, DLL, IER
 *   - uart_read_byte(): polls LSR[0] (DR), reads RBR
 *
 * RX uses standard mid-bit sampling:
 *   After detecting the start-bit falling edge, wait 1.5 bit periods
 *   to reach the centre of bit 0, then sample every 1 bit period.
 *   Bit period = divisor clock cycles  (1× baud, no 16× oversampling).
 *
 * PADDR[2:0] = byte_address[4:2]  (set by SysCtrl_SS_0 interconnect):
 *   0  RBR(R)/THR(W)/DLL(DLAB=1)
 *   1  IER(RW)     /DLM(DLAB=1)
 *   2  IIR(R) /FCR(W)
 *   3  LCR(RW)                  ← byte offset 0x0C
 *   4  MCR(RW)
 *   5  LSR(R)                   ← byte offset 0x14
 *   6  MSR(R)
 *   7  SCR(RW)
 */

`timescale 1ns/1ps

module apb_uart (
    input  wire        CLK,
    input  wire        RSTN,
    // APB
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire        PWRITE,
    input  wire [2:0]  PADDR,
    input  wire [31:0] PWDATA,
    output logic [31:0] PRDATA,
    output logic       PREADY,
    output logic       PSLVERR,
    // IRQ
    output logic       INT,
    // Serial
    input  wire        SIN,
    output logic       SOUT,
    // Modem (unused)
    input  wire        CTSN,
    input  wire        DSRN,
    input  wire        DCDN,
    input  wire        RIN,
    output logic       DTRN,
    output logic       RTSN,
    output logic       OUT1N,
    output logic       OUT2N
);

// ---------------------------------------------------------------------------
// Configuration registers
// ---------------------------------------------------------------------------
logic [15:0] divisor;   // DLM:DLL  (reset = 27, matches uart_init default)
logic        dlab;      // LCR[7]
logic  [7:0] ier, iir, fcr, lcr, mcr, scr;


// ---------------------------------------------------------------------------
// APB — always ready, no errors (identical to real UART)
// ---------------------------------------------------------------------------
assign PREADY  = 1'b1;
assign PSLVERR = 1'b0;

// Access-phase strobes — match real UART iWrite / iRead
wire iWrite = PSEL & PENABLE &  PWRITE;
wire iRead  = PSEL & PENABLE & !PWRITE;

wire rbr_read  = iRead  & (PADDR == 3'd0) & ~dlab;
wire thr_write = iWrite & (PADDR == 3'd0) & ~dlab;


always_ff @(posedge CLK or negedge RSTN) begin
    if (!RSTN) begin
        divisor <= 16'd27;
        dlab    <= 1'b0;
        ier     <= 8'h00;
        iir     <= 8'h01;
        fcr     <= 8'h00;
        lcr     <= 8'h00;
        mcr     <= 8'h00;
        scr     <= 8'h00;
    end else if (iWrite) begin
        case (PADDR)
            3'd0: if (dlab) divisor[7:0]  <= PWDATA[7:0];   // DLL
            3'd1: if (dlab) divisor[15:8] <= PWDATA[7:0];   // DLM
                  else      ier           <= PWDATA[7:0];    // IER
            3'd2: fcr  <= PWDATA[7:0];
            3'd3: begin lcr <= PWDATA[7:0]; dlab <= PWDATA[7]; end
            3'd4: mcr  <= PWDATA[7:0];
            3'd7: scr  <= PWDATA[7:0];
            default: ;
        endcase
    end
end

// ---------------------------------------------------------------------------
// RX — mid-bit sampling, 1× baud (no 16× oversampling)
//
// Timing with divisor = D, CLK period = T:
//   Bit period = D × T
//   Start bit detected at posedge cycle 0.
//   First sample (bit 0) at cycle  D + D/2  (mid-bit of bit 0).
//   Subsequent samples every D cycles.
//
// Example: D=2, T=10ns → bit period=20ns, TB drives bits at #20ns:
//   Start detected at t≈5ns (cycle 0).
//   rx_cnt loaded with D + D/2 - 1 = 2.
//   Counts: 2→1→0 → sample at cycle 3, t=35ns (bit0 window 20–40ns) ✓
//   Reload rx_cnt = D-1 = 1.
//   Counts: 1→0 → sample at cycle 5, t=55ns (bit1 window 40–60ns)  ✓
//   ...and so on.
// ---------------------------------------------------------------------------
logic [7:0]  rbr;
logic        lsr_dr;

typedef enum logic { RX_IDLE, RX_RECV } rx_state_t;
rx_state_t   rx_state;
logic [15:0] rx_cnt;
logic [2:0]  rx_bit;
logic [7:0]  rx_shift;

always_ff @(posedge CLK or negedge RSTN) begin
    if (!RSTN) begin
        rx_state <= RX_IDLE;
        rx_cnt   <= '0;
        rx_bit   <= '0;
        rx_shift <= '0;
        rbr      <= '0;
        lsr_dr   <= 1'b0;
    end else begin

        case (rx_state)
            RX_IDLE: begin
                if (!SIN) begin
                    // Start bit edge detected.
                    // Wait 1.5 bit periods to land in the middle of bit 0.
                    rx_cnt   <= divisor + (divisor >> 1) - 1;
                    rx_bit   <= 3'd0;
                    rx_state <= RX_RECV;
                end
            end

            RX_RECV: begin
                if (rx_cnt == 0) begin
                    // Sample current bit (shift in from MSB so LSB lands at [0])
                    rx_shift <= {SIN, rx_shift[7:1]};

                    if (rx_bit == 3'd7) begin
                        // All 8 bits done — latch into RBR and signal ready.
                        rbr      <= {SIN, rx_shift[7:1]};
                        lsr_dr   <= 1'b1;
                        rx_state <= RX_IDLE;
                    end else begin
                        rx_bit <= rx_bit + 1'b1;
                        rx_cnt <= divisor - 1;
                    end
                end else begin
                    rx_cnt <= rx_cnt - 1'b1;
                end
            end
        endcase

        // CPU read of RBR clears data-ready
        if (rbr_read)
            lsr_dr <= 1'b0;
    end
end

// ---------------------------------------------------------------------------
// TX — stub: TX is not used by pixel_inversion firmware
// ---------------------------------------------------------------------------
assign SOUT     = 1'b1;   // idle high
assign DTRN     = 1'b1;
assign RTSN     = 1'b1;
assign OUT1N    = 1'b1;
assign OUT2N    = 1'b1;

// LSR THRE/TEMT always 1 (TX always "empty")
wire lsr_thre = 1'b1;

// ---------------------------------------------------------------------------
// APB read — combinatorial (matches real apb_uart.sv always @(...) block)
// ---------------------------------------------------------------------------
always_comb begin
    case (PADDR)
        3'd0: PRDATA = dlab ? {24'h0, divisor[7:0]}  : {24'h0, rbr};
        3'd1: PRDATA = dlab ? {24'h0, divisor[15:8]} : {24'h0, ier};
        3'd2: PRDATA = {24'h0, iir};
        3'd3: PRDATA = {24'h0, lcr};
        3'd4: PRDATA = {24'h0, mcr};
        3'd5: PRDATA = {24'h0,
                        1'b0,       // [7] FIFO error
                        lsr_thre,   // [6] TEMT
                        lsr_thre,   // [5] THRE
                        3'b000,     // [4:2] BI/FE/PE
                        1'b0,       // [1] OE
                        lsr_dr};    // [0] DR
        3'd6: PRDATA = 32'h0;
        3'd7: PRDATA = {24'h0, scr};
        default: PRDATA = '0;
    endcase
end

// ---------------------------------------------------------------------------
// IRQ
// ---------------------------------------------------------------------------
assign INT = lsr_dr & ier[0];

endmodule

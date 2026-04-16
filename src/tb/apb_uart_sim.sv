/*
 * apb_uart_sim.sv - behavioral UART replacement for fast simulation
 *
 * Drop-in replacement for the apb_uart (UART 16750) module.
 * Matches the exact port list and APB register map but skips 16x oversampling:
 * each bit is one baud period (divisor clock cycles) wide, so simulation speed
 * scales with divisor rather than divisor×16.
 *
 * With divisor=2 each bit takes 2 clock cycles instead of 32 → 16× speedup.
 *
 * Register map (PADDR[2:0] = word index, same as real UART):
 *   0 (DLAB=0)  RBR (R) / THR (W) / DLL (DLAB=1 RW)
 *   1 (DLAB=0)  IER (RW)          / DLM (DLAB=1 RW)
 *   2           IIR (R)  / FCR (W)
 *   3           LCR (RW)                       ← byte addr 0x0C from UART base
 *   4           MCR (RW)
 *   5           LSR (R)
 *   6           MSR (R)
 *   7           SCR (RW)
 *
 * Note: PADDR[2:0] received here is bits [4:2] of the byte address, extracted
 * by the SysCtrl_SS_0 interconnect (assign apb_uart_PADDR[2:0] = APB_PADDR[4:2]).
 * So PADDR=3 corresponds to byte offset 0x0C (LCR), PADDR=5 to 0x14 (LSR), etc.
 *
 * LSR bits implemented:
 *   [0] DR   — RX data ready
 *   [5] THRE — TX holding register empty
 *   [6] TEMT — TX shift register empty
 *
 * Contributors:
 *   - Behavioral model for Didactic-SoC fast simulation
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
    // UART serial
    input  wire        SIN,
    output logic       SOUT,
    // Modem (unused, kept for port compatibility)
    input  wire        CTSN,
    input  wire        DSRN,
    input  wire        DCDN,
    input  wire        RIN,
    output logic       DTRN,
    output logic       RTSN,
    output logic       OUT1N,
    output logic       OUT2N
);

// -----------------------------------------------------------------------
// APB: always ready, no errors — same as real UART (assign PREADY = 1'b1)
// -----------------------------------------------------------------------
assign PREADY  = 1'b1;
assign PSLVERR = 1'b0;

// -----------------------------------------------------------------------
// APB access-phase strobes (PSEL && PENABLE, same as real UART iWrite/iRead)
// -----------------------------------------------------------------------
wire iWrite = PSEL & PENABLE &  PWRITE;
wire iRead  = PSEL & PENABLE & !PWRITE;

// -----------------------------------------------------------------------
// Baud divisor registers
// -----------------------------------------------------------------------
logic [15:0] divisor;   // DLM:DLL
logic        dlab;      // LCR[7]

// -----------------------------------------------------------------------
// RBR / THR strobes (byte-lane 0, DLAB=0)
// -----------------------------------------------------------------------
wire rbr_read  = iRead  & (PADDR == 3'd0) & !dlab;
wire thr_write = iWrite & (PADDR == 3'd0) & !dlab;

// -----------------------------------------------------------------------
// Baud clock — fires once every (divisor) CLK cycles (1× baud rate).
// Used only by TX; RX uses its own per-bit counter to sync to start-bit edge.
// -----------------------------------------------------------------------
logic [15:0] baud_cnt;
logic        baud_tick;

always_ff @(posedge CLK or negedge RSTN) begin
    if (!RSTN) begin
        baud_cnt  <= '0;
        baud_tick <= 1'b0;
    end else begin
        baud_tick <= 1'b0;
        if (divisor == 0 || baud_cnt == divisor - 1) begin
            baud_cnt  <= '0;
            baud_tick <= 1'b1;
        end else begin
            baud_cnt <= baud_cnt + 1'b1;
        end
    end
end

// -----------------------------------------------------------------------
// RX — per-bit counter synchronized to the start-bit falling edge.
//
// When the start bit is detected, rx_bit_timer is loaded with (divisor-1)
// so it counts down to 0 after exactly one bit period.  Every subsequent
// bit is sampled at the same phase (end of the bit window), giving correct
// 1x sampling regardless of baud_cnt phase when the start bit arrives.
// -----------------------------------------------------------------------
typedef enum logic [2:0] {
    RX_IDLE, RX_START, RX_DATA, RX_STOP
} rx_state_t;

rx_state_t   rx_state;
logic [2:0]  rx_bit_cnt;
logic [7:0]  rx_shift;
logic [7:0]  rbr;
logic        lsr_dr;
logic [15:0] rx_bit_timer;

always_ff @(posedge CLK or negedge RSTN) begin
    if (!RSTN) begin
        rx_state    <= RX_IDLE;
        rx_bit_cnt  <= '0;
        rx_shift    <= '0;
        rbr         <= '0;
        lsr_dr      <= 1'b0;
        rx_bit_timer <= '0;
    end else begin
        case (rx_state)
            RX_IDLE: begin
                if (!SIN) begin
                    // Load timer for one full bit period; enter start-bit wait.
                    rx_bit_timer <= (divisor == 0) ? '0 : divisor - 1;
                    rx_state     <= RX_START;
                    rx_bit_cnt   <= '0;
                end
            end

            RX_START: begin
                if (rx_bit_timer == 0) begin
                    // Start bit complete; arm timer for first data bit.
                    rx_bit_timer <= (divisor == 0) ? '0 : divisor - 1;
                    rx_state     <= RX_DATA;
                end else begin
                    rx_bit_timer <= rx_bit_timer - 1'b1;
                end
            end

            RX_DATA: begin
                if (rx_bit_timer == 0) begin
                    rx_shift     <= {SIN, rx_shift[7:1]};   // LSB first
                    rx_bit_cnt   <= rx_bit_cnt + 1'b1;
                    rx_bit_timer <= (divisor == 0) ? '0 : divisor - 1;
                    if (rx_bit_cnt == 3'd7)
                        rx_state <= RX_STOP;
                end else begin
                    rx_bit_timer <= rx_bit_timer - 1'b1;
                end
            end

            RX_STOP: begin
                if (rx_bit_timer == 0) begin
                    rbr      <= rx_shift;
                    lsr_dr   <= 1'b1;
                    rx_state <= RX_IDLE;
                end else begin
                    rx_bit_timer <= rx_bit_timer - 1'b1;
                end
            end

            default: rx_state <= RX_IDLE;
        endcase

        // Clear DR when CPU reads RBR (takes effect next cycle after lsr_dr=1)
        if (rbr_read)
            lsr_dr <= 1'b0;
    end
end

// -----------------------------------------------------------------------
// TX — baud_tick-based shift register
// -----------------------------------------------------------------------
typedef enum logic [1:0] {
    TX_IDLE, TX_START, TX_DATA, TX_STOP
} tx_state_t;

tx_state_t   tx_state;
logic [2:0]  tx_bit_cnt;
logic [7:0]  tx_shift;
logic        thr_full;
logic [7:0]  thr;
logic        lsr_thre;

always_ff @(posedge CLK or negedge RSTN) begin
    if (!RSTN) begin
        tx_state   <= TX_IDLE;
        tx_bit_cnt <= '0;
        tx_shift   <= '0;
        thr_full   <= 1'b0;
        thr        <= '0;
        lsr_thre   <= 1'b1;
        SOUT       <= 1'b1;
    end else begin
        if (thr_write) begin
            thr      <= PWDATA[7:0];
            thr_full <= 1'b1;
            lsr_thre <= 1'b0;
        end

        case (tx_state)
            TX_IDLE: begin
                SOUT <= 1'b1;
                if (thr_full) begin
                    tx_shift   <= thr;
                    thr_full   <= 1'b0;
                    lsr_thre   <= 1'b1;
                    tx_state   <= TX_START;
                end
            end

            TX_START: begin
                if (baud_tick) begin
                    SOUT       <= 1'b0;   // start bit
                    tx_bit_cnt <= '0;
                    tx_state   <= TX_DATA;
                end
            end

            TX_DATA: begin
                if (baud_tick) begin
                    SOUT       <= tx_shift[0];
                    tx_shift   <= {1'b1, tx_shift[7:1]};
                    tx_bit_cnt <= tx_bit_cnt + 1'b1;
                    if (tx_bit_cnt == 3'd7)
                        tx_state <= TX_STOP;
                end
            end

            TX_STOP: begin
                if (baud_tick) begin
                    SOUT     <= 1'b1;   // stop bit
                    tx_state <= TX_IDLE;
                end
            end

            default: tx_state <= TX_IDLE;
        endcase
    end
end

// -----------------------------------------------------------------------
// APB register file — writes on access phase (iWrite), reads combinatorial.
// Mirrors the real apb_uart: writes on iWrite, PRDATA driven like
//   always @(PADDR or regs...) in the original.
// -----------------------------------------------------------------------
logic [7:0] ier, iir, fcr, lcr, mcr, scr;

always_ff @(posedge CLK or negedge RSTN) begin
    if (!RSTN) begin
        divisor <= 16'd27;   // matches uart_init() default (100 MHz / (16×27) ≈ 231 kbaud)
        dlab    <= 1'b0;
        ier     <= '0;
        iir     <= 8'h01;
        fcr     <= '0;
        lcr     <= '0;
        mcr     <= '0;
        scr     <= '0;
    end else if (iWrite) begin
        case (PADDR)
            3'd0: if (dlab) divisor[7:0]  <= PWDATA[7:0];  // DLL (THR via thr_write)
            3'd1: if (dlab) divisor[15:8] <= PWDATA[7:0];  // DLM
                  else      ier           <= PWDATA[7:0];   // IER
            3'd2: fcr <= PWDATA[7:0];                       // FCR (IIR read-only)
            3'd3: begin                                      // LCR (byte offset 0x0C)
                      lcr  <= PWDATA[7:0];
                      dlab <= PWDATA[7];
                  end
            3'd4: mcr <= PWDATA[7:0];                       // MCR
            // 3'd5 LSR read-only
            // 3'd6 MSR read-only
            3'd7: scr <= PWDATA[7:0];                       // SCR
            default: ;
        endcase
    end
end

// Combinatorial read — same style as the real apb_uart.sv always @(...) block.
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
        3'd6: PRDATA = 32'h0;       // MSR — no modem signals
        3'd7: PRDATA = {24'h0, scr};
        default: PRDATA = '0;
    endcase
end

// -----------------------------------------------------------------------
// IRQ — RX data ready with IER[0] enabled
// -----------------------------------------------------------------------
assign INT   = lsr_dr & ier[0];

// Modem outputs — inactive (same polarity as real UART after reset)
assign DTRN  = 1'b1;
assign RTSN  = 1'b1;
assign OUT1N = 1'b1;
assign OUT2N = 1'b1;

endmodule

/*
 * apb_uart_sim.sv — behavioral UART replacement for fast simulation
 *
 * Drop-in replacement for the apb_uart (UART 16750) module.
 * Matches the exact port list and APB register map but skips 16x oversampling:
 * bits are sampled once per baud clock edge, so simulation speed scales with
 * the divisor rather than divisor×16.
 *
 * With divisor=2 each bit takes 2 clock cycles instead of 32 → 16× speedup.
 * With divisor=1 it works fine here (unlike the real UART).
 *
 * Register map (PADDR[2:0], word-addressed):
 *   0 (DLAB=0)  RBR (R) / THR (W) / DLL (DLAB=1 RW)
 *   1 (DLAB=0)  IER (RW)          / DLM (DLAB=1 RW)
 *   2           IIR (R)  / FCR (W)
 *   3           LCR (RW)
 *   4           MCR (RW)
 *   5           LSR (R)
 *   6           MSR (R)
 *   7           SCR (RW)
 *
 * LSR bits implemented:
 *   [0] DR   — RX data ready (byte in RBR)
 *   [5] THRE — TX holding register empty (always 1 after reset)
 *   [6] TEMT — TX empty           (always 1 after reset)
 *
 * Contributors:
 *   - Generated for Didactic-SoC fast simulation
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
// Baud divisor registers
// -----------------------------------------------------------------------
logic [15:0] divisor;   // DLM:DLL
logic        dlab;      // LCR[7]

// Declared here so RX/TX blocks below can reference them
logic        rbr_read;
logic        thr_write;

// -----------------------------------------------------------------------
// Baud clock — fires once per (divisor) CLK cycles, 1× baud rate.
// With the real UART the baud gen runs at 16× and the RX samples at mid-bit.
// Here we run at 1× so one tick = one bit period.
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
// RX — simple shift register, 1 sample per bit
// -----------------------------------------------------------------------
typedef enum logic [2:0] {
    RX_IDLE, RX_START, RX_DATA, RX_STOP
} rx_state_t;

rx_state_t   rx_state;
logic [2:0]  rx_bit_cnt;
logic [7:0]  rx_shift;
logic [7:0]  rbr;          // receive buffer register
logic        lsr_dr;        // data ready

always_ff @(posedge CLK or negedge RSTN) begin
    if (!RSTN) begin
        rx_state   <= RX_IDLE;
        rx_bit_cnt <= '0;
        rx_shift   <= '0;
        rbr        <= '0;
        lsr_dr     <= 1'b0;
    end else begin
        case (rx_state)
            RX_IDLE: begin
                if (!SIN) begin           // start bit (low)
                    rx_state   <= RX_START;
                    rx_bit_cnt <= '0;
                end
            end

            RX_START: begin
                // Wait one full baud period (mid-start-bit alignment)
                if (baud_tick) begin
                    rx_state   <= RX_DATA;
                    rx_bit_cnt <= '0;
                end
            end

            RX_DATA: begin
                if (baud_tick) begin
                    rx_shift   <= {SIN, rx_shift[7:1]};  // LSB first
                    rx_bit_cnt <= rx_bit_cnt + 1'b1;
                    if (rx_bit_cnt == 3'd7)
                        rx_state <= RX_STOP;
                end
            end

            RX_STOP: begin
                if (baud_tick) begin
                    rbr      <= rx_shift;
                    lsr_dr   <= 1'b1;
                    rx_state <= RX_IDLE;
                end
            end

            default: rx_state <= RX_IDLE;
        endcase

        // Clear DR when CPU reads RBR
        if (rbr_read)
            lsr_dr <= 1'b0;
    end
end

// -----------------------------------------------------------------------
// TX — simple shift register, 1 bit per baud tick
// -----------------------------------------------------------------------
typedef enum logic [1:0] {
    TX_IDLE, TX_START, TX_DATA, TX_STOP
} tx_state_t;

tx_state_t   tx_state;
logic [2:0]  tx_bit_cnt;
logic [7:0]  tx_shift;
logic        thr_full;     // THR has data waiting
logic [7:0]  thr;          // transmit holding register
logic        lsr_thre;     // THR empty

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
        // CPU writes THR
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
// APB register file
// -----------------------------------------------------------------------
logic [7:0] ier, iir, fcr, lcr, mcr, scr;

assign rbr_read  = PSEL & PENABLE & !PWRITE & (PADDR == 3'd0) & !dlab;
assign thr_write = PSEL & PENABLE &  PWRITE & (PADDR == 3'd0) & !dlab;

always_ff @(posedge CLK or negedge RSTN) begin
    if (!RSTN) begin
        PREADY  <= 1'b0;
        PSLVERR <= 1'b0;
        PRDATA  <= '0;
        divisor <= 16'd27;   // matches uart_init() default
        dlab    <= 1'b0;
        ier     <= '0;
        iir     <= 8'h01;
        fcr     <= '0;
        lcr     <= '0;
        mcr     <= '0;
        scr     <= '0;
    end else begin
        PREADY  <= 1'b0;
        PSLVERR <= 1'b0;

        if (PSEL && !PREADY) begin
            PREADY <= 1'b1;

            if (PWRITE) begin
                case (PADDR)
                    3'd0: begin
                        if (dlab) divisor[7:0] <= PWDATA[7:0];  // DLL
                        // THR handled by thr_write above
                    end
                    3'd1: begin
                        if (dlab) divisor[15:8] <= PWDATA[7:0]; // DLM
                        else      ier           <= PWDATA[7:0];
                    end
                    3'd2: fcr <= PWDATA[7:0];
                    3'd3: begin
                        lcr  <= PWDATA[7:0];
                        dlab <= PWDATA[7];
                    end
                    3'd4: mcr <= PWDATA[7:0];
                    3'd7: scr <= PWDATA[7:0];
                    default: ;
                endcase
            end else begin
                case (PADDR)
                    3'd0: PRDATA <= dlab ? {24'h0, divisor[7:0]}
                                        : {24'h0, rbr};
                    3'd1: PRDATA <= dlab ? {24'h0, divisor[15:8]}
                                        : {24'h0, ier};
                    3'd2: PRDATA <= {24'h0, iir};
                    3'd3: PRDATA <= {24'h0, lcr};
                    3'd4: PRDATA <= {24'h0, mcr};
                    3'd5: PRDATA <= {24'h0,
                                     1'b0,         // [7] FIFO error
                                     lsr_thre,      // [6] TEMT
                                     lsr_thre,      // [5] THRE
                                     3'b000,        // [4:2] BI/FE/PE
                                     1'b0,          // [1] OE
                                     lsr_dr};       // [0] DR
                    3'd6: PRDATA <= 32'h00;         // MSR — no modem
                    3'd7: PRDATA <= {24'h0, scr};
                    default: PRDATA <= '0;
                endcase
            end
        end
    end
end

// -----------------------------------------------------------------------
// IRQ — RX data ready and IER[0] enabled
// -----------------------------------------------------------------------
assign INT  = lsr_dr & ier[0];

// Modem outputs — inactive
assign DTRN  = 1'b1;
assign RTSN  = 1'b1;
assign OUT1N = 1'b1;
assign OUT2N = 1'b1;

endmodule

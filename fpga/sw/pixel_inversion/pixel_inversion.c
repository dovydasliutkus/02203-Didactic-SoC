/*
 * Contributors:
 *   - Dovydas Liutkus (dovli@dtu.dk)
 * Description:
 *   - Drives the Student_area_0 pixel-inversion accelerator.
 *   - Receives image pixels from UART, writes to ibuf, triggers processing,
 *     polls for completion.
 *   - Sends processed pixels back over UART
 */

#include <stdint.h>
#include "soc_ctrl.h"
#include "uart.h"

/* ------------------------------------------------------------------ */
/* Accelerator register addresses (Student_area_0 @ 0x01050000)       */
/* ------------------------------------------------------------------ */
#define ACCEL_BASE      0x01050000u

#define ACCEL_CSR       ((volatile uint32_t *)(ACCEL_BASE + 0x00u))
#define ACCEL_IBUF_ADDR ((volatile uint32_t *)(ACCEL_BASE + 0x04u))
#define ACCEL_IBUF_DATA ((volatile uint32_t *)(ACCEL_BASE + 0x08u))
#define ACCEL_OBUF_ADDR ((volatile uint32_t *)(ACCEL_BASE + 0x0Cu))
#define ACCEL_OBUF_DATA ((volatile uint32_t *)(ACCEL_BASE + 0x10u))

/* CSR bit positions */
#define CSR_DATA_READY  (1u << 0)
#define CSR_DONE        (1u << 1)

/* ------------------------------------------------------------------ */
/* Frame geometry                                                      */
/* ------------------------------------------------------------------ */
#define FRAME_WIDTH     352u
#define FRAME_HEIGHT    288u
#define TOTAL_PIXELS    (FRAME_WIDTH * FRAME_HEIGHT)  // 101376
#define PIXELS_PER_WORD 4u
#define BUF_DEPTH       (TOTAL_PIXELS / PIXELS_PER_WORD)  // 25344

/* ------------------------------------------------------------------ */
/* Receive one byte from UART (polling)                               */
/* ------------------------------------------------------------------ */
static inline uint8_t uart_read_byte(void)
{
    while (!(LSR & 0x1u)) {}        // Wait for RX data ready
    return (uint8_t)(RBR_THR_DLL & 0xFFu);
}

static inline void uart_write_byte(uint8_t b)
{
    while (!(LSR & 0x20u)) {}       // Wait for TX holding register empty
    RBR_THR_DLL = b;
}

int main(void)
{
    ss_init(0);
    uart_init(100000000u, 115200u);
    IIR_FCR = 0x07u; /* FIFO enable + RX reset + TX reset */

#ifdef SIM_FAST_UART
    /* Override baud divisor for fast simulation.
     * divisor=2 → 100 MHz / (16×2) = 3.125 Mbaud (320 ns/bit).
     * Testbench must be compiled with +define+SIM_FAST_UART to match.
     * NOTE: divisor=1 is unusable — iBAUDOUTN gets stuck at 0 and RX never fires. */
    LCR = (1u << 7) | 3u;  /* enable DLAB */
    RBR_THR_DLL = 2u;       /* divisor = 2 → 100 MHz / (16×2) = 3.125 Mbaud (320 ns/bit) */
    LCR = 3u;               /* disable DLAB */
#endif

#ifndef BYPASS_UART
    /* Receive image pixel-by-pixel from UART, pack 4 bytes per word,
     * write directly into ibuf — no DMEM buffering needed. */
    *ACCEL_IBUF_ADDR = 0u;
    for (uint32_t i = 0u; i < BUF_DEPTH; i++) {
         uint32_t word = (uint32_t)uart_read_byte()
                       | ((uint32_t)uart_read_byte() <<  8)
                       | ((uint32_t)uart_read_byte() << 16)
                       | ((uint32_t)uart_read_byte() << 24);
        *ACCEL_IBUF_DATA = word;
    }
#endif /* BYPASS_UART: ibuf pre-loaded by testbench */

    *ACCEL_CSR = CSR_DATA_READY;
    while (!(*ACCEL_CSR & CSR_DONE)) {}

    /* Send processed pixels back over UART, byte by byte. */
    // *ACCEL_OBUF_ADDR = 0u;
    // for (uint32_t i = 0u; i < BUF_DEPTH; i++) {
    //     uint32_t word = *ACCEL_OBUF_DATA;
    //     uart_write_byte((uint8_t)(word        & 0xFFu));
    //     uart_write_byte((uint8_t)((word >>  8) & 0xFFu));
    //     uart_write_byte((uint8_t)((word >> 16) & 0xFFu));
    //     uart_write_byte((uint8_t)((word >> 24) & 0xFFu));
    // }
    
    return 0;
}

# PC Application for Interfacing the Didactic-SoC on FPGA

## Overview

The PC application allows a user to send a grayscale image to the Didactic-SoC running on an FPGA via UART, wait for the accelerator to process it, receive the result, and display both images side by side.

All images are fixed-size: **352 × 288 pixels, 1 byte per pixel (grayscale), 101 376 bytes total**.

---

Python Desktop GUI 


- `pyserial` handles cross-platform serial port access.
- `tkinter` ships with Python on all platforms (zero extra install for basic GUI).
- `Pillow` converts raw byte arrays to displayable images.
- Entire application fits in ~150–200 lines of code.

### Dependencies

| Package    | Purpose                              | Install              |
|------------|--------------------------------------|----------------------|
| pyserial   | Serial port open/read/write          | `pip install pyserial` |
| Pillow     | Raw pixel → displayable image        | `pip install Pillow`  |
| tkinter    | GUI widgets (bundled with Python 3)  | built-in             |

Optional upgrade: replace `tkinter` with **PyQt6** or **CustomTkinter** for a more polished look, but the logic is identical.

### GUI Layout

```
┌──────────────────────────────────────────────────┐
│  Serial Port: [/dev/ttyUSB0 ▼]  Baud: [115200  ] │
│  Image:       [path/to/image.pgm        ] [Browse]│
│  [  Send & Process  ]                             │
│  Progress: [████████░░░░░░░░░░░░] 42 %            │
├────────────────────┬─────────────────────────────┤
│   Original Image   │      Processed Image        │
│   (352 × 288)      │      (352 × 288)            │
│                    │                             │
├────────────────────┴─────────────────────────────┤
│ Log:                                              │
│  [12:01:03] Port opened at 115200 baud            │
│  [12:01:04] Sending 101376 bytes...               │
│  [12:01:09] TX done. Waiting for result...        │
│  [12:01:14] RX complete. Displaying result.       │
└──────────────────────────────────────────────────┘
```

**Required GUI elements:**

1. **Serial port selector** - dropdown populated by `serial.tools.list_ports.comports()`, refreshed on open.
2. **Baud rate field** - editable, default `115200`; must match FPGA firmware divisor setting.
3. **Image file picker** - accepts `.pgm` (P5 binary or P2 ASCII) and raw `.bin`; Browse button opens file dialog.
4. **Send & Process button** - triggers the full TX → wait → RX sequence in a background thread so the GUI stays responsive.
5. **Progress bar** - updated during both TX (0–50 %) and RX (50–100 %) phases.
6. **Before / After image panels** - two `Label` widgets displaying `PIL.ImageTk.PhotoImage`; shown at native 352 × 288 or scaled to fit.
7. **Log / status area** - scrollable `Text` widget; timestamped one-liners; errors in red.

---

## Option B - Web Application

### Architecture

```
Browser (HTML/JS) ←──── HTTP/WebSocket ────→ Python backend (Flask/FastAPI)
                                                      │
                                              pyserial (serial port)
                                                      │
                                                  FPGA UART
```

The browser cannot access a serial port directly (WebSerial API exists but has limited OS support and requires Chrome/Edge).  A Python backend process must own the serial port and expose it over a local HTTP or WebSocket endpoint.

### Why Not Recommended

- Requires writing and maintaining two separate codebases (frontend JS + backend Python).
- Running a local web server adds setup steps for the end user.
- WebSerial API (browser-native serial) is Chrome/Edge-only and has no Linux `/dev/ttyUSB` support in all distros without udev rules.
- For a lab tool used by one person, the added complexity gives no benefit over a native GUI.

**Choose the web option only if:** the tool must be accessible from a browser on a shared lab machine without installing Python packages, or a responsive multi-user dashboard is required.

---

## Communication Protocol (Handshaking)

The FPGA firmware runs in a loop: **ready → receive image → process → send result → ready**. A minimal two-byte handshake synchronises the PC with the firmware state.

### Byte-Level Sequence

```
PC                              FPGA
 |                               |
 |──── 'R' (0x52) ─────────────►|  PC signals it is ready to send
 |                               |  (firmware enters receive loop)
 |◄─── 'A' (0x41) ──────────────|  FPGA acknowledges, ready to receive
 |                               |
 |──── 101 376 bytes ──────────►|  raw pixel stream, MSB-first rows,
 |     (pixel[0,0] … pixel[287,351])  no framing, no CRC
 |                               |
 |     (FPGA processes image)    |
 |                               |
 |◄─── 101 376 bytes ───────────|  processed pixel stream, same layout
 |                               |
```

### Why Simple Handshake Is Sufficient

- Frame size is fixed and known to both sides: no length header needed.
- A simple R/A exchange ensures the firmware has initialised UART and entered the receive loop before the PC floods the line.
- No CRC is needed for a lab tool - a corrupted result is immediately visible as a corrupted image; user can retry.
- If robustness is required later, a CRC-32 appended after the pixel stream and checked on the PC side is a straightforward addition.

### Timeout / Error Handling (PC side)

| Event                            | Action                                        |
|----------------------------------|-----------------------------------------------|
| No 'A' within 2 s of sending 'R' | Log error "FPGA not responding"; allow retry  |
| RX stalls (no byte for 5 s)      | Log error "RX timeout"; close port            |
| Received byte count ≠ 101 376    | Log warning "Short read"; display partial image |
| Serial port error                | Log exception; re-enable controls             |

### FPGA Firmware Requirements

The firmware must be updated (from the current simulation-only version) to:

1. After `uart_init()`, enter a loop:
   a. Poll for byte `'R'` from PC.
   b. Send byte `'A'` to PC.
   c. Receive 101 376 bytes into `ibuf` (same loop as current `#ifndef BYPASS_UART` block).
   d. Write `CSR_DATA_READY`; poll `CSR_DONE`.
   e. Read 101 376 bytes from `obuf`; transmit each byte back via UART.
   f. Return to step (a).

2. Baud rate divisor must match what the PC sends - default `115200` baud requires divisor = `100 000 000 / (16 × 115200)` ≈ `54` (round to nearest integer and tune).


## File Format Notes

- Input:P2 (ASCII) 
- Output: saved as `<input_stem>_result.pgm` same format as input. Alongside the input file; also displayed live in the GUI.
- Both images stored as 8-bit grayscale; no colour conversion required.

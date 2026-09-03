
# Image processing accelerator with CPU data transport

This laboratory exercise extends the existing image processing accelerator lab by integrating it into the Didactic-SoC and introducing data transport between the CPU, accelerator, and UART peripheral. The goal is to expose students to memory-mapped hardware modules, a simple SoC architecture, and hardware-software co-design.

This lab supports Linux and Windows operating systems. For Linux the commands are given and were tested on a Ubuntu 24.04 LTS system.

## Software requirements

| # | Tool | Notes |
|---|------|-------|
| 1 | Make | Flow automation |
| 2 | Questa Starter Edition | Simulation |
| 3 | WSL2 | Windows only |
| 4 | `riscv64-unknown-elf` toolchain | Cross-compiler |
| 5 | Vivado | FPGA synthesis and implementation |
| 6 | Python 3 | For the PC side of the FPGA test. Packages: `pyserial`, `Pillow`, `appJar`, `python3-tk` |
| 7 | OpenOCD (Optional) | JTAG debugging |

Refer to [02203_Software_setup](02203_Software_setup.md) for setting up the required tools.

## Project overview

### What you will build

You will implement an **edge detection accelerator** in RTL and run it as a
hardware module inside the **Didactic-SoC**. 

The SoC receives an image over UART, a RISC-V CPU feeds this image into your accelerator, waits for it to finish processing, and streams the result back out over UART. The edge detection algorithm is described in the pdf, this guide is about its integration in the SoC.

### The Didactic-SoC in one minute

The Didactic-SoC is a small RISC-V system-on-chip, it has two parts:

- a fixed **staff (management) section** — a RISC-V **Ibex** core (RV32IMC),
  16 KiB instruction memory (IMEM) and 16 KiB data memory (DMEM),
  **UART / SPI / GPIO** peripherals, a JTAG debug module and a controller (control register bank).
- five **student subsystem slots (SS0–SS4)** — customisable modules attached to the CPU over an **APB** bus. Your accelerator goes in **SS0**.

Everything is **memory-mapped** into one 32-bit address space, so from C the CPU
reaches memory, peripherals and your accelerator the same way: by reading and
writing `volatile` pointers. The blocks you need:

| Block | Base address |
|-------|--------------|
| Data memory (DMEM) | `0x01010000` |
| UART peripheral | `0x01030100` |
| Controller block | `0x01040000` |
| Student subsystem 0 (your accelerator) | `0x01050000` |

The provided C headers already define these. A full memory map and register
listing is in [the-didactic-soc-platform.md](the-didactic-soc-platform.md).

![Didactic-SoC architecture](figures/didactic_architecture.drawio.svg)

Two things about this SoC differ from a typical microcontroller:

- **There is no bootloader.** Instruction memory is preloaded before the core
  runs - by the testbench in simulation, and by the bitstream (or over JTAG) on the FPGA. Your compiled C lands in IMEM with no boot code in front of it.
- **Subsystems start gated off.** Before SS0 responds on the bus, the CPU must
  enable its clock and release it - and the interconnect - from reset through
  the controller block at `0x01040000`. The example firmware handles this with a
  single call to `ss_init(0)` (see
  [pixel_inversion.c:56](../sw/pixel_inversion/pixel_inversion.c#L56)).

### The accelerator subsystem

SS0 is provided in [Student_area_0.sv](../src/rtl/Student_area_0.sv) as a working example that performs **pixel inversion**. It contains an **input buffer** and **output buffer** (BRAM), a **control/status register (CSR)**, and the APB bus handling. The pixel processing FSM is split into a submodule, [pixel_acc.sv](../src/rtl/pixel_acc.sv) - that is the part you replace with your edge detector (by default does pixel inversion).

**Read the header comment in both .sv files**: they document the CSR
bit layout and the buffer access protocol.

![Student SS with pixel inversion accelerator](figures/student_ss_bd.drawio.svg)

The CPU drives the accelerator through the CSR at the SS0 base address:

1. Receive image data over **UART** and copy it into the accelerator
   **input buffer**.
2. Set the **DATA_READY** bit in the CSR to start processing.
3. Poll the **DONE** bit in the CSR.
4. When **DONE = 1**, read the **output buffer** and send the processed image
   back over **UART**.

### Testing

The **end goal** is a full round trip: a PC sends an image to the Didactic-SoC over UART, the CPU runs it through your accelerator, and the SoC sends the processed image back over UART to the PC, where you view it. On real hardware (Task 3-4) this is done with the board plugged into a USB port and a Python GUI on the PC driving the serial link.

You do not need the FPGA to develop, though. The lab builds up to that round trip in three stages, each with its own simulation:

| Stage | Testbench | What it exercises | What plays the PC |
|-------|-----------|-------------------|---------------------|
| Task 0-1 | `src/tb/tb_student_ss.sv` | Your accelerator alone | The testbench drives the CSR and buffers directly over **APB** and reads/writes `.pgm` files - no CPU, no UART |
| Task 2 | `src/tb/tb_didactic_V1.sv` | The whole SoC running the real CPU firmware | The testbench emulates the PC: it bit-bangs the image in over **UART**, the CPU and your accelerator do the rest |
| Task 3-4 | — (real FPGA) | The taped-out flow on a Nexys A7 | An actual PC running the Python serial GUI |

Both testbenches write the processed image to a `.pgm` in `src/tb/out_images/` for visual inspection. View it with **IrfanView** or any viewer that supports the PGM format.

To keep the system simulation fast, `tb_didactic_V1.sv` takes two shortcuts: it uses a simplified UART model (20 cycles per byte instead of a real baud divider), and it reads the result straight from the accelerator output buffer instead of waiting for the CPU to stream every byte back over UART. The FPGA test does the real thing end to end.

---

## Tasks
### 0.  Test the Didactic-SoC with a Working Example

This task checks that your toolchain is complete and introduces the `make` flow. The two commands below exercise the two independent toolchains you installed: the RISC-V cross-compiler (software) and Questa (simulation). They do **not** depend on each other - `tb_student_ss` drives the accelerator directly and never runs the CPU firmware.

Run all commands from the project root, `02203-Didactic-SoC/`.

> **Windows:** replace `make` with `make -f Makefile.win` for every command in this guide.

#### Step 1 - Build the CPU firmware

```bash
make build_test TEST=pixel_inversion
```

This cross-compiles [sw/pixel_inversion/pixel_inversion.c](../sw/pixel_inversion/pixel_inversion.c) and links it into `build/sw/pixel_inversion.elf`, then produces a `.hex` image used to preload instruction memory. A disassembly is left in `build/sw/pixel_inversion.asm` if you want to inspect it. 

> **Note**: If this step fails, your RISC-V toolchain might not be on `PATH`.

#### Step 2 - Simulate the standalone accelerator

```bash
make test_ss
```

This runs the `src/tb/tb_student_ss.sv` testbench against the standalone `Student_area_0` module in batch mode. The testbench:

1. reads an input image from `src/tb/src_images/` (default `pattern.pgm`, 352x288, 8-bit grayscale),
2. writes the pixels into the accelerator input buffer over [APB](https://developer.arm.com/documentation/ihi0024/latest/),
3. starts the accelerator and waits for `DONE`,
4. reads the output buffer back and writes `src/tb/out_images/pattern_result.pgm`.

The default accelerator inverts pixels, so `pattern_result.pgm` should look like a photographic negative of the input. To try another image, edit the `src_image` parameter at the top of `src/tb/tb_student_ss.sv` (e.g. `"kaleidoscope.pgm"`).

**Success criteria:** the simulation runs to `$finish` with no errors, and the result PGM appears in `src/tb/out_images/` and opens in an image viewer.

#### Step 3 - Simulate with the Questa GUI

```bash
make test_ss_gui
```

Same run, but Questa opens with a preconfigured waveform (`wave_ss.do`). Use this when debugging your own RTL in Task 1. Run `make clean_build` at any time to wipe `build/` and `src/tb/out_images/` and start fresh.

> **Keeping the GUI open:** the testbench ends with `$finish`, which makes Questa pop up *"Are you sure you want to finish?"* - choose **No** to keep the window and waveforms up for inspection. If you iterate a lot in GUI, replace `$finish` with `$stop` at the end of `src/tb/tb_student_ss.sv`: the popup no longer appears in GUI mode, but in batch mode (`make test_ss`) the simulation then halts instead of exiting, so you have to quit Questa manually.

> **Persisting your waveform:** signals you drag into the Wave window are lost on the next `make test_ss_gui` unless you save them. Add the signals you want (right-click -> *Add Wave*), arrange them, then **File -> Save Format...** and overwrite `sim/wave_ss.do`. The GUI run executes `do wave_ss.do` on startup, so your layout comes back on every rerun.

---

### 1.  Develop the Edge Detection Accelerator

#### Architecture consideration

Before writing any RTL. You need to understand the problem and consider possible implementations. You need to think about how much data your HW accelerator will buffer internally, how pixels are accessed from the memory, and how many times the same pixel is read from memory during the processing of an image frame. In this process, you may also try to estimate bounds on the time it takes to process an image. A lower bound can be established by calculating the time it takes your design to read from and write to the memory. You may be able to think of other bounds and estimates that characterize your design. To keep the size of the design manageable, you may ignore the boundary conditions and simply produce an image that is smaller than the original (missing the left and right columns of pixels and the upper and lower rows of pixels).

Draw a block diagram showing the datapath you have designed and develop an ASMD-chart specification of your design.

#### RTL design

Implement your accelerator in [pixel_acc.sv](../src/rtl/pixel_acc.sv) - this is the FSM submodule that currently does pixel inversion. Its interface is a `start` pulse, a 1-cycle-latency read port into the input buffer (`ibuf_rd_en` / `ibuf_rd_addr` -> `ibuf_rd_data`), a write port into the output buffer (`obuf_wr_en` / `obuf_wr_addr` / `obuf_wr_data`), and a `finish` pulse you assert once the last output word is written. Each 32-bit word packs 4 pixels little-endian. Read the header comments in `pixel_acc.sv` and [Student_area_0.sv](../src/rtl/Student_area_0.sv) for the exact timing and buffer layout or run Questa in GUI mode and analyse the waveforms. You should not need to change `Student_area_0.sv` (the APB/CSR wrapper) unless you alter the buffer geometry or module parameters.

Test with the same standalone flow as Task 0:

```bash
make test_ss        # batch
make test_ss_gui    # with waveforms
```

Check the result in `src/tb/out_images/` - it should show bright edges on a dark
background. The testbench does not do strict per-pixel checking, so minor border
differences between implementations are fine. Verify your design here before
moving to system integration.


### 2.  Integrate the Accelerator into the SoC

Once your RTL passes the standalone testbench, run it on the whole system. Your edge detector uses the same CSR / ibuf / obuf protocol as the pixel-inversion example, so the provided CPU firmware drives it unchanged - this task is just re-running the full SoC simulation with your RTL in place. You are not expected to modify any C code here.

The system testbench is `src/tb/tb_didactic_V1.sv`. It replicates the real FPGA test: image data arrives over UART from a "PC", the CPU moves it into the accelerator, the accelerator processes it, and the result comes back. The testbench plays the PC side of the UART link via two tasks, `uart_write_byte` and `uart_receive_byte`.

Two shortcuts keep the run fast: a simplified UART model is used instead of the real peripheral, and the processed image is read straight from the accelerator output buffer instead of being streamed all the way back over UART.

**Task: skim `src/tb/tb_didactic_V1.sv`** so you know what the simulation is doing.

**Task: skim the CPU firmware [pixel_inversion.c](../sw/pixel_inversion/pixel_inversion.c).** Its flow is:

1. initialise student subsystem 0 (`ss_init(0)`) and the UART peripheral,
2. set the ibuf address pointer to 0,
3. read the image from UART four bytes at a time and write each packed word to ibuf,
4. once ibuf is full, set `DATA_READY` in the CSR and poll `DONE`,
5. the UART write-back loop is present but commented out (the testbench reads obuf directly).

Build the firmware into a `.hex` for instruction-memory init, from the project root:
```bash
make build_test TEST=pixel_inversion
```
The assembly dump is in `build/sw/pixel_inversion.asm` if you want to look.

Run the full simulation:
```bash
make test_all TEST=pixel_inversion       # batch
make test_all_gui TEST=pixel_inversion   # with waveforms + memory viewer
```

Expect roughly 18 minutes in batch mode (longer with the GUI). The test transfers 101376 bytes (352x288 pixels) at 20 cycles per byte -> about 2.03e6 cycles, or 20.3 ms of simulated time at 100 MHz.

**Success criteria:** the simulation runs to completion with no errors, and `src/tb/out_images/pattern_result.pgm` appears and matches the result your standalone testbench produced.

**If the simulation seems stuck:** a frozen run almost always means the CPU is spinning in one of two loops. Open the GUI (`make test_all_gui`) and check which:

- **stuck filling ibuf** - the CPU never gets past the UART receive loop, so no bytes are arriving. Look at the UART model and the ibuf write side.
- **stuck polling `DONE`** - all data is in, but your accelerator never asserts `finish`. Debug `pixel_acc`.

Remove build files with:
```bash
make clean_build
```



### 3.  FPGA Implementation

To test the system you will send an image from your computer to the Didactic-SoC and receive the processed image back. The steps are:

1. A computer sends an image to the FPGA via UART.
2. The CPU forwards the pixel data to the accelerator IBUF.
3. The accelerator processes the image.
4. The CPU sends the processed image back to the PC through UART.

Compile the code for FPGA with the following make target from `fpga/`

```bash
make build_test TEST=pixel_inversion
```
Note: There are two CPU programs - one in `sw/` for simulation and another in `fpga/sw/` for the FPGA implementation, which is intended to work with the Python GUI on the PC side.

Synthesize and implement the design using **Vivado**. This can be done by running
```bash
make fpga
```
If synthesis errors occur, check your RTL code for **unsynthesizable constructs**.

To open the Vivado project with the GUI - launch Vivado then choose "Open Project" and select `build/fpga/nexys_a7/didactic-nexys_a7.xpr` file.

You may use the `Hardware Manager` in Vivado GUI for uploading the bitstream. The bitstream also contains memory initialization commands so after bitstream flashing the CPU program will start executing instantly.

### 4. Test with Python GUI

Requires Python 3.12 (newer versions may not be compatible). From `fpga/serial_interface/`:

**Windows (PowerShell):**
```bash
py -3.12 --version
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python serial_interface.py
```

If you don't have Python 3.12, install it with `winget install Python.Python.3.12` or from https://www.python.org/

**Linux:**
```bash
python3.12 --version
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python serial_interface.py
```

If you don't have Python 3.12, install it with your package manager.


### 5. Program and debug over JTAG (Optional)

The main advantage of using JTAG is being able to reprogram the CPU in the Didactic-SoC without having to rebuild the FPGA bitstream.

To upload code to the CPU in the Didactic-SoC, first start an OpenOCD server. OpenOCD acts as a bridge between the GNU Debugger (GDB) and the physical JTAG interface.

#### Linux

```bash
openocd -f fpga/utils/openocd-didactic-nexys.cfg
```

Then from `fpga/`, upload the program with

```bash
make load_elf TEST=pixel_inversion
```

This will start GDB. 

#### Windows

All commands below run inside the **MSYS2 MINGW64** terminal.

**1. Switch the FTDI driver**

Open Zadig after flashing the bitstream onto the FPGA:
1. Options -> List All Devices
2. Select **Digilent USB Device (Interface 0)**
3. Set driver to **WinUSB** -> Install Driver

> **Restoring Vivado's programmer:** Open Device Manager -> Universal Serial Bus devices -> right-click **Digilent USB Device** -> Uninstall device. Unplug and replug the board — Windows will reinstall the default `FTDIBUS` driver automatically.

**2. Start OpenOCD** (leave this terminal open)

From the `fpga/` directory:
```bash
openocd -f utils/openocd-didactic-nexys.cfg
```
Wait for `Ready for Remote Connections`.

**3. Flash the ELF** (second MSYS2 terminal)

```bash
gdb-multiarch ../build/fpga/sw/<test>.elf -x utils/connect-and-load.gdb
```


### Useful commands for gdb

To run a program from gdb:
```bash
continue
# Use Ctrl+C to halt target
```

To create a breakpoint in gdb:
```bash
break *0x1000474
```
When hit the target halts. **Important: Delete breakpoints before continuing**. 
```bash
delete breakpoints
continue
```
If breakpoints remain, the core becomes unresponsive. So breakpoint flow: <br>
break |adr| -> continue -> * CPU breaks* -> delete breakpoints -> continue

### Stepping
Single-step (`step`, `next`) causes the core to hang.

### Reset
The core can be reset from `gdb` using:
```bash
monitor reset
monitor halt
set $pc=0x01000080
```

Then `monitor reset` works without setting pc (hence also no need to halt). This also allows the CPU to start executing an application after hard reset (through physical switch) if the application was uploaded in the same power cycle.
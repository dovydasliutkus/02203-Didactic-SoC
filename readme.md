# 02203 - Image processing accelerator with CPU data transport

This repository holds the hardware, firmware and tool flow for the design lab in
**02203 Design of Digital Systems** at DTU. You implement an edge detection
accelerator in SystemVerilog, integrate it into the **Didactic-SoC** and run the complete image round trip in simulation and
on an FPGA board.

The Didactic-SoC itself comes from the [Edu4Chip](https://edu4chip.eu/) project.
It is licensed under the Solderpad Hardware License v2.1 (see [LICENSE](LICENSE)).

## Start here

Two documents cover everything you need for the lab:

1. **[doc/02203_Software_setup.md](doc/02203_Software_setup.md)** - install and
   verify the tools.
2. **[doc/02203_Lab_Guide.md](doc/02203_Lab_Guide.md)** - the lab itself: the SoC
   in brief, the accelerator interface, and the tasks from first simulation
   through to running on the board.

Everything else in [doc/](doc/) is background reference - useful if you are
curious, not required to finish the lab.
[the-didactic-soc-platform.md](doc/the-didactic-soc-platform.md) is the one worth
knowing about: it holds the full memory map and register listing.

Run all `make` commands from this directory (the project root). On Windows, use
`make -f Makefile.win` instead of `make`.

## Directory structure

```
.
|-- doc/           Documentation. Lab guide, software setup, platform reference
|-- src/
|   |-- rtl/       SoC RTL. Your work goes in pixel_acc.sv (and Student_area_0.sv)
|   |-- tb/        Testbenches, plus src_images/ and out_images/ for .pgm files
|   |-- reuse/     Open-source IP reused as-is
|   |-- generated/ RTL generated from the IP-XACT model (do not edit by hand)
|-- sw/            Baremetal C firmware, one folder per program
|   |-- common/    Shared headers and drivers (UART, subsystem init, startup)
|   |-- pixel_inversion/  The example firmware that drives the accelerator
|-- sim/           Questa simulation flow: Makefiles, file lists, waveform scripts
|-- fpga/          Vivado flow: constraints, scripts, and the Python serial GUI
|-- build/         All tool output. Created by make, not in git
|-- vendor_ips/    Dependencies fetched by `make repository_init`, not in git
|-- Bender.yml     Hardware dependency manifest
|-- Makefile       Top-level flow (Makefile.win for Windows)
```

## Quick reference

Fetch the hardware dependencies once, after cloning:

```bash
make repository_init
```

Then the flows used throughout the lab:

| Command | What it does |
|---------|--------------|
| `make build_test TEST=pixel_inversion` | Cross-compile the firmware to a `.hex` for instruction memory |
| `make test_ss` / `make test_ss_gui` | Simulate the accelerator on its own (no CPU) |
| `make test_all TEST=pixel_inversion` | Simulate the whole SoC running the firmware |
| `make clean_build` | Remove build outputs |

The lab guide explains what each of these does and when you need it.

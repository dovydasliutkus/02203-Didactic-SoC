## Notes
[change] Top-level `DidacticNexys_A7` has no jtag ports. In run_xilinx.tcl with the `nexys_a7` target the VJTAG macro is set which disables ios in `io_cell_frame_sysctrl.sv`.

[risk] testbench was simplified to initialize IMEM with `$readmemh` support for DMEM initialization HAS NOT been added.

[feature] To simulate picture loading from PC `tb_didactic_V1.sv` has two modes for UART. The modes are controlled by `FAST_UART` variable in Makefiles. When the variable is set the minimum clock divisor of 2 is used to maximise simulation speed. `FAST_UART` can also be set to 0 for more realistic 230400 baudrate @ 100MHz sys clk.

[question] Will the students be able to adjust C code for optimizing their accelerator if they didn't have a smaller task with that?

[sw:risk] Setting baudrate for UART need to check if it can be divided in a clean way from the system frequency.

[sw:risk] File lists are generated on linux and added to the repo there shouldn't be a need to regenerated, but if there is it should be done on a Linux machine, because linux paths will still work with Questa and Vivado.

## TODO

- mem init with bitstream (openocd will be hard on windows) but leave jtag as an option
- cleanup Student_area_0.sv
- finalize lab description
- Replace the project README, maybe with DoD_lab_plan.md or just a short version.
  
In the final stages:
-  Delete all redundant code like the BYPASS_UART and FAST_UART ifdef statements (Only leave the real UART as an option)
- If not using bender create files.f for simulation and fpga implementation. Also ship the repo with all dependencies.

## Compatibility plan

### Target platforms
- **Linux** - primary/reference platform, all tools native
- **macOS** - no Vivado, no Questa, FPGA work on lab computers?
- **Windows** - native Questa + Vivado, RISC-V toolchain TBD (see below)

### Dependency elimination (all platforms benefit)
1. **Bender** - pre-generate `files.f` file lists and commit them; ship `.bender/` vendor checkouts in-repo. Students never need to run bender. Only maintainers re-run it when dependencies change. But also makes repo bigger and need a file list for every Makefile. bender ships prebuilt for all OSs so maybe keep it for now.
2. **OpenOCD / JTAG** - use mem init with bitstream as primary flow; keep JTAG as optional advanced path (already noted as TODO).

### Linux (no changes needed)
- Current Makefiles work as-is.
- Minor cleanup: `realpath` -> `abspath`, `sed -r` -> `sed -E`, `wc -w` whitespace strip (for macOS parity).

### macOS
- **Simulator**: Questa not supported on macOS. Migrate to Verilator? 

    Assessment needed: do testbenches use any Verilator-unsupported SystemVerilog?
- **FPGA synthesis**: not supported on macOS - students use lab computers or remote access for Vivado/bitstream steps.
- **RISC-V toolchain**: `brew install riscv-gnu-toolchain` (drop-in, same binary names).
- Makefile fixes above cover remaining incompatibilities.

### Windows
- **Questa**: native Windows install.
- **Vivado**: native Windows install.
- **RISC-V toolchain**: options under evaluation -
  - *Option A*: xPack `riscv-none-elf-gcc` - native Windows binary, no WSL, drop-in for bare-metal; `riscv-none-elf` vs `riscv32-unknown-elf` prefix needs verification.
  - *Option B*: WSL2 only for SW compilation - Windows Makefile calls `wsl make -C sw`; everything else native.
- **Make on Windows**: GNU Make via [Chocolatey](https://chocolatey.org/) (`choco install make`).
- A separate `Makefile.win` may be needed for Windows-native paths (backslash, drive letters). Scope TBD after toolchain decision.

### Open questions
- [ ] Verilator testbench compatibility audit - can it be simulated with Verilator?
- [ ] xPack toolchain flag compatibility with current `sw/Makefile` (`-march=rv32imc -mabi=ilp32`) or go the WSL way
- [ ] Windows Makefile scope - wrapper or full duplication?

---

## 2026-03-23
### Did

- Added support for Nexys A7 and NexysDDR4 FPGAs (same board)

    `nexys_a7.sdc` based on the basys3 project. 

    Only with virtual JTAG. Removed top jtag ports. To make Vivado happy, in `io_cell_frame_sysctrl.sv` used `ifndef VJTAG` to replace `io_cell_wrapper` instantiations with assignments.

- Tested with OpenOCD and blinky example, works on both


### Next
- Generate Didactic 1.1 with the example student subsystems.
- Create the student subsystem block for `Task 0` (see block diagram in DoD_lab_plan.md)
- Write sw to exercise the subsystem
---

## 2026-03-26
### Did
- Generated Didactic 1.1 using scripts/run_kactus2_script.sh.

### Next
- Create the student subsystem block for `Task 0` (see block diagram in DoD_lab_plan.md)

---

## 2026-03-30   
### Did
- Created subsystem block for pixel inversion (`Task 0`)

### Problem 1
We cannot do full buffering in DMEM as we need 100kB of memory then, that shifts the entire address map which is mostly hardcoded and moving it is prone to cause bugs

### Solution 1
We buffer the full image only in the accelerator. The CPU copies the data in chunks from a virtual UART transmitter in the testbench. 

The processed pgm will be generated straight from the accelerator output buffer.

---

## 2026-04-09   
### Did
- Cleaned up `Student_area_0`. Currently it is all in an `always_ff` block. ASK LUCA if I should change it to FSMD.
- Created isolated testbench `src/tb/tb_student_ss.sv` for `Student_area_0`.
- Added `sim_ss` target in `sim/Makefile`

### Next
- ASK LUCA if I should change `Student_area_0` to FSMD (Create always_comb block and move FSM case there).
- WIP Full system example (`Task 0`)
    - pc jumps around for some reason, maybe try blinky for a start to isolate if the problem is from uart or from not using jtag (also could be the memory bug fix)

---

## 2026-04-13
### Did
- blinky works with new - simplified - testbench. 
- The testbench UART write is successfully transfered to `Student_area_0.IBUF`. (Fast and Slow UART both work)
- Replaced UART with a simplified model that doesn't do x16 oversampling which significantly sped up the simulation, enabled by default in Make.
- To debug the ACC implemented UART bypass controled by `UART_BYPASS` variable from Make.

### Next
- Fix of by one error in `UART_BYPASS` mode. 

## 2026-04-16
- `UART_BYPASS` working, an image with inverted pixels is generated.
- Tested `SIM_UART_MODEL` with `FAST_UART` enabled. In batch mode, with Questa Starter took 18mins.


## 2026-04-20
### Did
- Successfully implemented for Nexys 7 with `make fpga PROJECT=nexys_a7 TEST=pixel_inversion` for the bram-ss branch

### Problem 1
BRAM buffers will make it complicated for students because they act as memories. LUT RAM cannot be used because the buffers are too big
```
ERROR: [DRC UTLZ-1] Resource utilization: LUT as Distributed RAM over-utilized in Top Level Design (This design requires more LUT as Distributed RAM cells than are available in the target device. This design requires 43040 of such cell types but only 19000 compatible sites are available in the target device.
```
Also tried to do only `ibuf` as LUT RAM but it was still too big.

### Solution 1
Use BRAM for both `ibuf` and `obuf`

## 2026-04-23
### Did
- hello.c works on FPGA
- pixel_inversion.c works with the python GUI on FPGA.
- Added TODOs in the lab guide.

## 2026-05-04
### Did
- Submodule for `pixel_acc` to give students a minimal working document (not to scare with `Student_area_0.sv`). full system testbenches successfully inverts pixels.
- Work on compatability for windows

## 2026-05-07
### Did
- Chose to switch to `riscv64-unknown-elf` toolchain that is available on Ubuntu package manager (on WSL aswell)
- Fix sw build post-processing because riscv64 outputs binaries where the byte count is not necessarily divisible by 4.
- Generate file list and include list in Linux Makefile to remove bender as a software requirement. (Windows doesn't generate bender correctly) 
- Fix async reset bug in SS. Reset happens before clock is enabled so need async reset (or change the software driver).
- Simplify `sim/Makefile.win` to delegate targets to `sim/Makefile` so we don't have repetitive commands in two Makefiles.

### Next
On Windows:
- Get fpga flow running 

## 2026-05-11
### Did
- (On Win) make build_test works from 'fpga/'
- (On Win) make load_elf works through MSYS2 with gdb-multiarch


### Hardware debugging with Windows and WSL2

**Current state:** Manage to start OpenOCD server after `usbipd attach`. Then `Make load_elf` runs slowly and gets packet errors, blinky doesn't work. Using all the same files through MSYS2 works. Proabably abandon WSL way and require MSYS2 installation.

#### Step 1 — Install usbipd-win (Windows, needs admin)

Open **PowerShell as Administrator** and run:
```powershell
winget install --interactive --exact dorssel.usbipd-win
```
Follow the installer. **Reboot when done.**

#### Step 2 — Bind the Nexys A7 (admin, one-time per machine)

Plug in the Nexys A7. Then in **PowerShell as Administrator**:
```powershell
usbipd list
```
Find the line that says something like `Digilent USB Device` with hardware-id `0403:6010`. Then:
```powershell
usbipd bind --hardware-id 0403:6010
```
You only ever do this once. After this, binding survives reboots.

#### Step 3 — Install tools inside WSL (one-time)

Open your Ubuntu WSL terminal:
```bash
sudo apt update
sudo apt install openocd gdb-multiarch
```

Verify:
```bash
openocd --version
gdb-multiarch --version
```

#### Step 4 — Attach the board to WSL (each session, no admin needed)

From any normal Windows terminal (or `make -f Makefile.win usbipd_attach`):
```
usbipd attach --wsl --hardware-id 0403:6010
```

Verify it landed in WSL:
```bash
lsusb   # should show "Future Technology Devices International" or "Digilent"
```

#### Step 5 — Start OpenOCD

In a Windows terminal, from the `fpga/` directory:
```
make -f Makefile.win start_openocd
```
A new window opens running OpenOCD inside WSL. You should see `JTAG Chain dump` and `Ready for Remote Connections`. **Leave it open.**

#### Step 6 — Flash the ELF

In another terminal (after `build_test` has built your firmware):
```
make -f Makefile.win load_elf TEST=blink
```

#### When done — give USB back to Vivado

```
usbipd detach --hardware-id 0403:6010
```

Vivado can program the board again immediately after this.

### Next
- Initialize software with the bitstream
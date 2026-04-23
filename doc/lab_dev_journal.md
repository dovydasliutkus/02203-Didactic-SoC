## Notes
[change] Top-level `DidacticNexys_A7` has no jtag ports. In run_xilinx.tcl with the `nexys_a7` target the VJTAG macro is set which disables ios in `io_cell_frame_sysctrl.sv`.

[risk] testbench was simplified to initialize IMEM with `$readmemh` support for DMEM initialization HAS NOT been added.

[feature] To simulate picture loading from PC `tb_didactic_V1.sv` has two modes for UART. The modes are controlled by `FAST_UART` variable in Makefiles. When the variable is set the minimum clock divisor of 2 is used to maximise simulation speed. `FAST_UART` can also be set to 0 for more realistic 230400 baudrate @ 100MHz sys clk.

[question] Will the students be able to adjust C code for optimizing their accelerator if they didn't have a smaller task with that?

## TODO
- Try Luca's serial_interface application for uploading to FPGA
- make for sw can be run from sw/ or fpga/sw/ think of a cleaner way maybe. For blinky it makes sense to have seperate sw, maybe for pixel_inversion will be the same.

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
- 
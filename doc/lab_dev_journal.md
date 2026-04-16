## Notes
[change] Top-level `DidacticNexys_A7` has no jtag ports. In run_xilinx.tcl with the `nexys_a7` target the VJTAG macro is set which disables ios in `io_cell_frame_sysctrl.sv`.

[risk] testbench was simplified to initialize IMEM with `$readmemh` support for DMEM initialization HAS NOT been added.

[feature] To simulate picture loading from PC `tb_didactic_V1.sv` has two modes for UART. The modes are controlled by `FAST_UART` variable in Makefiles. When the variable is set the minimum clock divisor of 2 is used to maximise simulation speed. `FAST_UART` can also be set to 0 for more realistic 230400 baudrate @ 100MHz sys clk.

[question] Will the students be able to adjust C code for optimizing their accelerator if they didn't have a smaller task with that?

## TODO
- What simulator will the students use? ModelSim or free questa? Questa Starter Edition runs the scripts


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
- Fix of by one error in `UART_BYPASS` mode. This works - generates images with inverted pixels.
- Tested `SIM_UART_MODEL` with `FAST_UART` enabled. In batch mode.
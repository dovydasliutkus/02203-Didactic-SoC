Top-level `DidacticNexys_A7` has no jtag ports.
In run_xilinx.tcl with the `nexys_a7` target the VJTAG macro is set which disables ios in 


## TODO
- What simulator will the students use? ModelSim or free questa? Supposedly free questa should run the default scripts.
- [ ] Task or issue
- [ ] Task or bug
- [ ] Idea to explore

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


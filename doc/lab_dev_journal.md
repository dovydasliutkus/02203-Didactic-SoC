Top-level `DidacticNexys_A7` has no jtag ports.
In run_xilinx.tcl with the `nexys_a7` target the VJTAG macro is set which disables ios in 


## TODO (short-term)
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
- Create the student subsystem block for `Task 0` (see block diagram in DoD_lab_plan.md)
- Write sw to exercise the subsystem
---

## 2026-03-24
### Did
- 
- 

### Notes
- 

### Next
- 

---
# Using FPGA JTAG for debugging

This guide explains how to reuse the JTAG adapter in the Nexys A7 FPGA, for the Didactic-SoC. This is useful if you want to program and debug the SoC, but don't have a seperate JTAG adapter.

## Linux
1. Run make from project root:
```bash
make all_xilinx_vjtag PROJECT=basys3
```
2. Flash bitstream

3. On Windows I had to reinstall drivers for `Digilent USB Device (Interface 0)` to WinUSB. For OpenOCD to recognize device.

4. Run OpenOCD with vjtag config:
```bash
openocd -f fpga/utils/openocd-didactic-vjtag.cfg
```
5. Run gdb with desired .elf file:
```bash
riscv-none-elf-gdb build/sw/blinky.elf
```
6. Source `fpga/utils/connect-and-load.gdb` to connect to OpenOCD and load program.
```bash
source fpga/utils/connect-and-load.gdb
```
7. To run the application from gdb do:
```
continue
```

## Windows (my run)
1. As I'm running vivado on windows I generate files.f with bender from *WSL*.
2. I ran a modified version of `run_xilinx.tcl` from PowerShell. Tried WSL and MSYS2 for testing unmodified script, but hit too many issues and came back to the modified (windows) version of the script.
3. After writing bitstream must reinstall driver for `Digilent USB Device (Interface 0)` to WinUSB. I used *Zadig* for this.
2. In `basys3.xdc` comment out everything with jtag - jtag connections to pmod, jtag clock generation. Replace clock groups to exclude `jtag_clk`.

<br><br>

# Work Journal

## Sources
The following link describes using fpga jtag adapter to tunnel JTAG to softcore CPU debugger
https://craigjb.com/2024/09/09/vexriscv-jtag-tunnel/

More detailed guide from the same project:
https://zenodo.org/records/4767195?utm_source=chatgpt.com


BSCANE2 component docs:
https://docs.amd.com/r/en-US/ug953-vivado-7series-libraries/Design-Elements

boxlambda project, riscv-dbg documentation for Arty-A7 fpga:
https://boxlambda.readthedocs.io/en/latest/components_riscv_dbg/#openocd-and-riscv-dbg-on-arty-a7-fpga

riscv-dbg documentation: https://github.com/pulp-platform/riscv-dbg/blob/master/doc/debug-system.md

## Monday 02-03-2026

Using `dmi_bscane_tap.sv` instead of `dmi_jtag_tap.sv`

PROBLEM: `io_cell_frame` has physical IO buffers (IBUFs) instantiated for the JTAG pads <br>
SOLUTION: ifdef with a new macro `VJTAG` to tie off these values in `io_cell_frame_sysctrl.sv`
Then in Vivado tcl console:
```tcl
set_property verilog_define "VJTAG" [current_fileset]
```


OpenOCD output:
openocd -f /c/Users/dovyd/dtu_chip/Didactic-SoC_Vjtag/fpga/utils/openocd-didactic-vjtag.cfg
Open On-Chip Debugger 0.12.0
Licensed under GNU GPL v2
For bug reports, read
        http://openocd.org/doc/doxygen/bugs.html
Info : Nested Tap based Bscan Tunnel Selected
init...
Info : clock speed 200 kHz
Info : JTAG tap: riscv.cpu tap/device found: 0x0362d093 (mfg: 0x049 (Xilinx), part: 0x362d, ver: 0x0)
Error: Unsupported DTM version 1. (dtmcontrol=0x1071)
Warn : target riscv.cpu examination failed
Info : starting gdb server for riscv.cpu on 3333
Info : Listening on port 3333 for gdb connections
Error: Target not examined yet

From https://craigjb.com/2024/09/09/vexriscv-jtag-tunnel/
Note: Use a separate reset for the debug clock domain. I spent a long time trying to figure out why OpenOCD would connect, recognize my debug module, and then lose it. Turns out that happens when your debug module is on the same reset line as the CPU.

TRY THE ABOVE, ISOLATE DEBUG RESET

But the reset is not connected directly to CPU. reset is connected to `jtag_db_wrapper_obi.sv`
where Line 188:
``` verilog
   assign core_reset = rstn_i & ~(ndmreset_o);
```
ndreset comes from jtag (asserted when reset from gdb). So core reset is seperate from debug module reset.

## Thursday 05-03-2026
Rewrote openocd config file from scratch mainly refering to 
[riscv-dbg documentation](https://github.com/pulp-platform/riscv-dbg/blob/master/doc/debug-system.md)

IR length, and register locations (IDCODE, DTMCS, DMI)
![From riscv-dbg](figures/xc7a35t_IR_length.png)

**STATUS: Connection to debugger works, uploaded and ran blinky.elf, tested breakpoints, reset - all working.**

Now integrating for automated Makefile flow. TODO:
1. Add rtl with ifdef VJTAG macro from DidacticBasys3.v (top level). ifdef primary jtag ports and tie jtag signals to constant values for io_cell_frame to not throw errors during synthesis.
2. New target in top Makefile
3. new target in fpga/Makefile
4. new script fpga/scripts/run_xilinx_vjtag.tcl
5. Adjust run_xilinx_vjtag.tcl
        1. Define VJTAG
        2. Change .xdc to the vjtag one
        3. Extra bender target - `bscane`, to use `dmi_bscane_tap.sv` instead of `dmi_jtag_tap.sv`.


**PROBLEM**
If we remove the primary jtag ports (because now they are connected internally through BSCAN2 module) Vivado gets upset at the `io_cell_wrapper` instantiations in `io_cell_frame_sysctrl.sv` - they don't have any connections so they become unplaced and get the following errors:
```
[Place 30-69] Instance didactic/SystemControl_SS/i_io_cell_frame/i_io_cell_jtag_trst/gen_i_cell.i_i_iobuf/IBUF (IBUF driven by I/O terminal didactic/SystemControl_SS/i_io_cell_frame/i_io_cell_jtag_trst/gen_i_cell.i_i_iobuf/IO) is unplaced after IO placer
[Place 30-68] Instance didactic/SystemControl_SS/i_io_cell_frame/i_io_cell_jtag_trst/gen_i_cell.i_i_iobuf/IBUF (IBUF) is not placed
```
**SOLUTIONS**
1. Leave the primary jtag ports dangling. The jtag ports are assigned to the PMOD but not internally connected. Then no errors are thrown but the PMOD which the ports are assigned to will not be reusable for other connections (not elegant).

2. Change io_cell_frame_sysctrl.sv
from 
```systemverilog
 // jtag
  io_cell_wrapper#(.CELL_TYPE(2), .IOCELL_CFG_W(IOCELL_CFG_W)) i_io_cell_jtag_tck (.FROM_CORE(1'b0),              .TO_CORE(jtag_tck_internal),  .PAD(jtag_tck),  .io_cell_cfg(IOCELL_CFG_W'('hF)));
  io_cell_wrapper#(.CELL_TYPE(2), .IOCELL_CFG_W(IOCELL_CFG_W)) i_io_cell_jtag_tms (.FROM_CORE(1'b0),              .TO_CORE(jtag_tms_internal),  .PAD(jtag_tms),  .io_cell_cfg(IOCELL_CFG_W'('hF)));
  io_cell_wrapper#(.CELL_TYPE(2), .IOCELL_CFG_W(IOCELL_CFG_W)) i_io_cell_jtag_trst(.FROM_CORE(1'b0),              .TO_CORE(jtag_trst_internal), .PAD(jtag_trst), .io_cell_cfg(IOCELL_CFG_W'('hF)));
  io_cell_wrapper#(.CELL_TYPE(2), .IOCELL_CFG_W(IOCELL_CFG_W)) i_io_cell_jtag_tdi (.FROM_CORE(1'b0),              .TO_CORE(jtag_tdi_internal),  .PAD(jtag_tdi),  .io_cell_cfg(IOCELL_CFG_W'('hF)));
  io_cell_wrapper#(.CELL_TYPE(1), .IOCELL_CFG_W(IOCELL_CFG_W)) i_io_cell_jtag_tdo (.FROM_CORE(jtag_tdo_internal), .TO_CORE(),                   .PAD(jtag_tdo),  .io_cell_cfg(IOCELL_CFG_W'('hE)));
```
to 
```systemverilog
  // jtag
`ifndef VJTAG
  io_cell_wrapper#(.CELL_TYPE(2), .IOCELL_CFG_W(IOCELL_CFG_W)) i_io_cell_jtag_tck (.FROM_CORE(1'b0),              .TO_CORE(jtag_tck_internal),  .PAD(jtag_tck),  .io_cell_cfg(IOCELL_CFG_W'('hF))); 
  io_cell_wrapper#(.CELL_TYPE(2), .IOCELL_CFG_W(IOCELL_CFG_W)) i_io_cell_jtag_tms (.FROM_CORE(1'b0),              .TO_CORE(jtag_tms_internal),  .PAD(jtag_tms),  .io_cell_cfg(IOCELL_CFG_W'('hF)));
  io_cell_wrapper#(.CELL_TYPE(2), .IOCELL_CFG_W(IOCELL_CFG_W)) i_io_cell_jtag_trst(.FROM_CORE(1'b0),              .TO_CORE(jtag_trst_internal), .PAD(jtag_trst), .io_cell_cfg(IOCELL_CFG_W'('hF)));
  io_cell_wrapper#(.CELL_TYPE(2), .IOCELL_CFG_W(IOCELL_CFG_W)) i_io_cell_jtag_tdi (.FROM_CORE(1'b0),              .TO_CORE(jtag_tdi_internal),  .PAD(jtag_tdi),  .io_cell_cfg(IOCELL_CFG_W'('hF)));
  io_cell_wrapper#(.CELL_TYPE(1), .IOCELL_CFG_W(IOCELL_CFG_W)) i_io_cell_jtag_tdo (.FROM_CORE(jtag_tdo_internal), .TO_CORE(),                   .PAD(jtag_tdo),  .io_cell_cfg(IOCELL_CFG_W'('hE)));
`else
  // Tie to fixed values because dmi_bscane_tap.sv provides these internally
  assign jtag_tck_internal  = 1'b0;
  assign jtag_tms_internal  = 1'b1;
  assign jtag_tdi_internal  = 1'b0;
  assign jtag_trst_internal = 1'b1;
  // tdo_internal is an input to this module (output from debug), just leave floating
`endif
```

With the 2nd solution can remove everything to do with jtag from `.xdc` file and remove the primary jtag ports in `DidacticBasys3.v`


# Notes

When I need to reprogram bitstream I do `Uninstall device` from `Device Manager` and check attemt to remove drivers

### Directories
`original/` has the changes pushed to vjtag branch

`original_win_test/` working example similar to the pushed changes, but with files.f and without automation

Didactic-SoC_Vjtag older working version with ifdef in `io_cell_frame_sysctrl.sv`
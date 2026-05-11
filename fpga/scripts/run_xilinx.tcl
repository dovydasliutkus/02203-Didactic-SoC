####
# Didactic SoC 
# FPGA prototyping flow for Xilinx PYNQ-Z1 board.
# Contributor(s):
#   -Matti Käyrä (matti.kayra@tuni.fi)
#   -Thomas Szymkoviak
#   -Dovydas Liutkus (dovli@dtu.dk)
####

# Pass all available cores to Vivado
if {$tcl_platform(platform) eq "windows"} {
  set CPUS $::env(NUMBER_OF_PROCESSORS)
} else {
  catch {set CPUS [exec getconf _NPROCESSORS_ONLN]}
}
if { ![info exists CPUS] || $CPUS eq "" } {
  set CPUS 4
}
#
set PROJECT $::env(PROJECT)
set BUILD_DIR $::env(BUILD_DIR)

if { $PROJECT eq "z1" } {
  set XILINX_PART xc7z020clg400-1
} elseif { $PROJECT eq "vcu118" } {
  set XILINX_PART xvup9p-flga2104-2L-e
  puts "ERROR: VCU118 constraints are empty"
} elseif { $PROJECT eq "basys3" || $PROJECT eq "basys3_vjtag"} {
  set XILINX_PART xc7a35tcpg236-1
} elseif { $PROJECT eq "nexys_a7"} {
  set XILINX_PART xc7a100tcsg324-1
} else {
  puts "PROJECT variable contains unsupported board!"
  break
}

set DIR [file normalize .]

create_project didactic-$PROJECT ../build/fpga/$PROJECT -force -part $XILINX_PART

# Read pre-generated include dirs and file lists (produced by make gen_filelists)
set fp [open "$DIR/includes.f" r]
set INCLUDE_DIRS [split [string trim [read $fp]] "\n"]
close $fp
set_property include_dirs $INCLUDE_DIRS [current_fileset]

# File read - bscane variant for basys3_vjtag / nexys_a7
if { $PROJECT eq "basys3_vjtag" || $PROJECT eq "nexys_a7" } {
  set fp [open "$DIR/flist_bscane.f" r]
} else {
  set fp [open "$DIR/flist.f" r]
}
set src_files [split [string trim [read $fp]] "\n"]
close $fp
add_files -norecurse -scan_for_includes $src_files

if { $PROJECT eq "z1" } {
  add_files -norecurse $DIR/rtl/DidacticZ1.v
}
if { $PROJECT eq "basys3" || $PROJECT eq "basys3_vjtag" } {
  add_files -norecurse $DIR/rtl/DidacticBasys3.v
}
if { $PROJECT eq "nexys_a7" } {
  add_files -norecurse $DIR/rtl/DidacticNexys_A7.v
}

set_property file_type SystemVerilog [get_files *.v]

# 
set_property is_global_include true [get_files prim_assert_dummy_macros.svh]

# Use xilinx specific cg
if { $PROJECT eq "nexys_a7" } {
  set_property verilog_define {VJTAG=1 SYNTHESIS=1 FPGA=1 PRIM_DEFAULT_IMPL=prim_pkg::ImplXilinx} [current_fileset]
} else {          
  set_property verilog_define {SYNTHESIS=1 FPGA=1 PRIM_DEFAULT_IMPL=prim_pkg::ImplXilinx} [current_fileset]
}

set_property source_mgmt_mode None [current_project]
if { $PROJECT eq "z1" } {
  set_property top DidacticZ1 [current_fileset]
} elseif { $PROJECT eq "basys3" || $PROJECT eq "basys3_vjtag" } {
  set_property top DidacticBasys3 [current_fileset]
} elseif { $PROJECT eq "nexys_a7" } {
  set_property top DidacticNexys_A7 [current_fileset]
} else {
  set_property top Didactic [current_fileset]
}

update_compile_order -fileset sources_1

# For the vjtag use the same basys3.xdc
if { $PROJECT eq "basys3_vjtag" } {
  add_files -fileset constrs_1 -norecurse constraints/basys3.xdc
} else {
  add_files -fileset constrs_1 -norecurse constraints/$PROJECT.xdc
}
#Elaborate design
synth_design -rtl -name rtl_1 -sfcu
# sfcu -> run synthesis in single file compilation unit mode

set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value -sfcu -objects [get_runs synth_1]
# Use single file compilation unit mode to prevent issues with import pkg::* statements in the codebase
launch_runs synth_1 -jobs $CPUS
wait_on_run synth_1
open_run synth_1 -name netlist_1
set_property needs_refresh false [get_runs synth_1]

# Launch Implementation
# default strategy creates issues with hold. we trade runtime to get timing correct.

set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

launch_runs impl_1 -jobs $CPUS 
wait_on_run impl_1
launch_runs impl_1 -jobs $CPUS -to_step write_bitstream
wait_on_run impl_1

open_run impl_1

# Generate reports
file mkdir $BUILD_DIR/fpga/logs/

check_timing                                                          -file $BUILD_DIR/fpga/logs/$PROJECT.check_timing.rpt
report_timing -max_paths 50 -nworst 50 -delay_type max -sort_by slack -file $BUILD_DIR/fpga/logs/$PROJECT.timing_WORST_50.rpt
report_timing -nworst 1 -delay_type max -sort_by group                -file $BUILD_DIR/fpga/logs/$PROJECT.timing.rpt
report_utilization -hierarchical                                      -file $BUILD_DIR/fpga/logs/$PROJECT.utilization.rpt
report_utilization                                                    -file $BUILD_DIR/fpga/logs/$PROJECT.utilization_pct.rpt

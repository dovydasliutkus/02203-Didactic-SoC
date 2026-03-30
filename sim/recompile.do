# recompile.do
# Run from the Questa transcript: do recompile.do
# Recompiles the design in-place without closing the simulator.

quietly set BUILD_DIR [file normalize [file join [file dirname [info script]] ../build]]
quietly set SIM_DIR   [file normalize [file dirname [info script]]]

echo "=== Recompiling Didactic SoC ==="

# Re-run vlog with the same flags as the Makefile compile_didactic target.
# Edit the defines below if you change Makefile TB_DEFINES / DUT_DEFINES.
vlog -sv -work didactic_lib \
    +define+RVFI \
    +define+INC_ASSERT \
    +define+USE_UART \
    +define+USE_SPI \
    -svinputport=compat \
    -suppress vlog-2583 \
    -suppress vlog-2244 \
    +incdir+[exec bender path common_cells]/include \
    +incdir+[exec bender path axi]/include \
    +incdir+[exec bender path apb]/include \
    +incdir+[exec bender path register_interface]/include \
    +incdir+[exec bender path obi]/include \
    +incdir+$BUILD_DIR/../vendor_ips/ibex/vendor/lowrisc_ip/dv/sv/dv_utils \
    +incdir+$BUILD_DIR/../vendor_ips/ibex/vendor/lowrisc_ip/ip/prim/rtl \
    +incdir+$BUILD_DIR/../vendor_ips/ibex/rtl \
    -L $BUILD_DIR/didactic_lib \
    [exec bender script flist -t rtl -t vendor -t simulation -t tracer -t didactic_obi]

if {[catch {
    vopt \
        -L $BUILD_DIR/didactic_lib \
        -sv \
        -suppress vopt-2577 \
        +acc=npr \
        -gDM_SANITY_TESTCASES=0 \
        -work $BUILD_DIR/didactic_lib \
        tb_didactic \
        -o tb_didactic_opt
} err]} {
    echo "=== vopt FAILED: $err ==="
} else {
    restart -f
    echo "=== Recompile OK, simulation restarted: ==="
    # echo "    vsim tb_didactic_opt"
    # echo "or simply: restart -f"
}

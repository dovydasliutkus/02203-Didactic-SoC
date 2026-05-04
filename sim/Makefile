############################################
# Sim makefile for questa/modelsim
# Project: Edu4chip
# SoC: Didactic
# Contributors: 
# * Matti Käyrä (Matti.kayra@tuni.fi)
# * Antti Nurmi (Antti.nurmi@tuni.fi)
# Notes:
# * 
###############################################

BUILD_DIR ?= $(realpath $(CURDIR))/../build
START_TIME=`date +%F_%H:%M`
SHELL = bash

DUT = tb_didactic
SS_TB   = tb_student_ss

# By default use fastest available UART
FAST_UART ?= 1
SIM_UART_MODEL ?= 1
BYPASS_UART ?= 0

UART_DEFINE        = $(if $(filter 1,$(FAST_UART)),+define+SIM_FAST_UART,)
UART_MODEL_DEFINE  = $(if $(filter 1,$(SIM_UART_MODEL)),+define+SIM_UART_MODEL,)
BYPASS_UART_DEFINE = $(if $(filter 1,$(BYPASS_UART)),+define+BYPASS_UART,)

TB_DEFINES = \
	+define+USE_UART \
	+define+USE_SPI \
	$(UART_DEFINE) \
	$(UART_MODEL_DEFINE) \
	$(BYPASS_UART_DEFINE)

# Dut defines:
# * RVFi required by tracer
# * Synthesis disables verification assertions within
# pulp / ibex codes
DUT_DEFINES = \
	+define+RVFI \
	+define+INC_ASSERT \
#	+define+SYNTHESIS \

DUT_LIBS = \
	-L $(BUILD_DIR)/didactic_lib \

# vsim-8386: suppress bit-to-reg assignment errors
VSIM_OPTS = \
	-suppress vsim-3009 \
	-suppress vsim-8386 \

VOPT_OPTS = \
	-sv \
	-O5 \
	-suppress vopt-2577 \
	+acc \

# vlog-2244: tracer Variable implicitly static
VLOG_OPTS = \
	-svinputport=compat \
	-suppress vlog-2583 \
	-suppress vlog-2244 \

BENDER ?= bender

COMMON_CELLS_DIR ?= $(shell $(BENDER) path common_cells)
AXI_DIR          ?= $(shell $(BENDER) path axi)
APB_DIR          ?= $(shell $(BENDER) path apb)
REGIF_DIR        ?= $(shell $(BENDER) path register_interface)
OBI_DIR          ?= $(shell $(BENDER) path obi)
IBEX_DIR         ?= $(BUILD_DIR)/../vendor_ips/ibex

SIM_FLIST        ?= $(shell $(BENDER) script flist -t rtl -t vendor -t simulation -t tracer -t didactic_obi)

INCLUDES ?= \
	+incdir+$(COMMON_CELLS_DIR)/include \
	+incdir+$(AXI_DIR)/include \
	+incdir+$(APB_DIR)/include \
	+incdir+$(REGIF_DIR)/include \
	+incdir+$(OBI_DIR)/include \
	+incdir+$(IBEX_DIR)/vendor/lowrisc_ip/dv/sv/dv_utils \
	+incdir+$(IBEX_DIR)/vendor/lowrisc_ip/ip/prim/rtl \
	+incdir+$(IBEX_DIR)/rtl

env:
	mkdir -p $(BUILD_DIR)/logs/compile
	mkdir -p $(BUILD_DIR)/logs/opt
	mkdir -p $(BUILD_DIR)/logs/sim

library_mapping: 
	cd $(BUILD_DIR)
	vmap didactic_lib $(BUILD_DIR)/didactic_lib

compile: env compile_didactic

# SIM_UART_MODEL=1: replace apb_uart with fast behavioral model (no 16x oversampling).
# Can be combined with FAST_UART=1 to also set matching TB bit timing.
SIM_UART_MODEL ?= 0

compile_didactic:
	vlib $(BUILD_DIR)/didactic_lib
	vmap didactic_lib $(BUILD_DIR)/didactic_lib
	vlog -sv -work didactic_lib $(DUT_DEFINES) $(TB_DEFINES) $(INCLUDES) $(DUT_LIBS) \
	$(VLOG_OPTS) $(SIM_FLIST) -l $(BUILD_DIR)/logs/compile/$(START_TIME)_didactic.log
ifeq ($(SIM_UART_MODEL),1)
	@echo "[sim] Compiling fast behavioral UART model (overrides apb_uart)"
	vlog -sv -work didactic_lib $(VLOG_OPTS) \
	../src/tb/apb_uart_sim.sv
endif

SANITY_CHECK ?= 0
TESTCASE ?= blink
GUI ?= -c

# +acc enables full signal visibility for GUI waveforms (adds overhead).
# elaborate uses +acc (needed for $readmemh hierarchy path access).
# elaborate_fast drops +acc for pure batch/regression runs.
VOPT_OPTS_FAST = $(filter-out +acc,$(VOPT_OPTS))

elaborate: library_mapping
	cd $(BUILD_DIR)
	vopt \
	$(DUT_LIBS) $(VOPT_OPTS) \
	-gDM_SANITY_TESTCASES=$(SANITY_CHECK) \
	-gTESTCASE=$(TESTCASE) \
	-work $(BUILD_DIR)/didactic_lib \
	$(DUT) \
	-o $(DUT)_opt \
	-l $(BUILD_DIR)/logs/opt/$(START_TIME)_vopt.log

elaborate_fast: library_mapping
	cd $(BUILD_DIR)
	vopt \
	$(DUT_LIBS) $(VOPT_OPTS_FAST) \
	-gDM_SANITY_TESTCASES=$(SANITY_CHECK) \
	-gTESTCASE=$(TESTCASE) \
	-work $(BUILD_DIR)/didactic_lib \
	$(DUT) \
	-o $(DUT)_opt \
	-l $(BUILD_DIR)/logs/opt/$(START_TIME)_vopt.log

run_sim: library_mapping
	mkdir -p stdout &&	touch stdout/uart
	cd $(BUILD_DIR)
	vsim $(GUI) \
	$(DUT_LIBS) $(VSIM_OPTS) \
	-work $(BUILD_DIR)/didactic_lib \
	$(DUT)_opt \
	$(if $(filter -c,$(GUI)),-do "run -all;",-do "do wave.do; do mem.do; run -all;") \
	-l $(BUILD_DIR)/logs/sim/$(START_TIME)_sim.log

#============================================================
# Isolated test for Student_area_0 with tb_student_ss
#============================================================

SS_TB = tb_student_ss
SS_TB_SRC = ../src/tb/tb_student_ss.sv ../src/rtl/Student_area_0.sv ../src/rtl/pixel_acc.sv

compile_ss: env
	vlib $(BUILD_DIR)/didactic_lib
	vmap didactic_lib $(BUILD_DIR)/didactic_lib
	vlog -sv -work didactic_lib $(VLOG_OPTS) $(SS_TB_SRC) \
	-l $(BUILD_DIR)/logs/compile/$(START_TIME)_ss.log

elaborate_ss: library_mapping
	mkdir -p $(BUILD_DIR)/logs/opt
	vopt \
	$(DUT_LIBS) $(VOPT_OPTS) \
	-work $(BUILD_DIR)/didactic_lib \
	$(SS_TB) \
	-o $(SS_TB)_opt \
	-l $(BUILD_DIR)/logs/opt/$(START_TIME)_ss_vopt.log

run_ss: library_mapping
	mkdir -p $(BUILD_DIR)/logs/sim
	vsim $(GUI) \
	$(DUT_LIBS) $(VSIM_OPTS) \
	-work $(BUILD_DIR)/didactic_lib \
	$(SS_TB)_opt \
	$(if $(filter -c,$(GUI)),-do "run -all;",-do "do wave_ss.do; run -all;") \
	-l $(BUILD_DIR)/logs/sim/$(START_TIME)_ss_sim.log

sim_ss: compile_ss elaborate_ss run_ss

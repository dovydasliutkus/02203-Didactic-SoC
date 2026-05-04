########################################
# Top repository makefile
# Project: Edu4chip
# SoC: Didactic
#
# Description:
# * Top level commands to enable "make <command>"
# -style automated workflows.
#
# Contributors: 
# * Matti Käyrä (Matti.kayra@tuni.fi)
# * Roni Hämäläinen (roni.hamalainen@tuni.fi)
#######################################

# Common shell variables
SHELL=bash
BUILD_DIR ?= $(realpath $(CURDIR))/build/
TEST ?= blink


# Fetch submodule revisions and 
# save work in submodules to stashes - avoid data loss by accidents
repository_init:
	bender update
	bender vendor init
#	git submodule update --init --recursive

check-env:
	mkdir -p $(BUILD_DIR)/logs/compile
	mkdir -p $(BUILD_DIR)/logs/opt
	mkdir -p $(BUILD_DIR)/logs/sim
	mkdir -p src/tb/out_images

clean_build:
	rm -rf $(BUILD_DIR)
	rm -rf  src/tb/out_images

clean_ips:
	rm -fr ./.bender

clean_all: clean_build clean_ips

######################################################################
#
######################################################################
soc-rtl:
	echo "Generating SoC RTL. Check variables from scripts/run_kactus2_script.sh to be able to run Kactus2."
	source scripts/run_kactus2_script.sh -f scripts/kactus2_generate_soc_rtl.py

######################################################################
# hw targets
######################################################################

# compile hw library with chosen tools
compile: check-env
	$(MAKE) -C sim compile BUILD_DIR=$(BUILD_DIR)

# potentionally elaborate hw library with chosen tools
elaborate: check-env
	$(MAKE) -C sim elaborate BUILD_DIR=$(BUILD_DIR) TESTCASE=$(TEST)

# No signal logging for faster simulation without gui
elaborate_fast: check-env
	$(MAKE) -C sim elaborate_fast BUILD_DIR=$(BUILD_DIR) TESTCASE=$(TEST)

# Potentionally split this to multiple subtasks
syn: check-env
	$(MAKE) -C syn synthesize BUILD_DIR=$(BUILD_DIR)

######################################################################
# sim targets
######################################################################

# compile hw library with chosen tools
run_sim: check-env
	$(MAKE) -C sim run_sim BUILD_DIR=$(BUILD_DIR)

######################################################################
# sw targets
######################################################################
#
build_test: check-env
	$(MAKE) -C sw test BUILD_DIR=$(BUILD_DIR) TESTCASE=$(TEST)

######################################################################
# full flow targets
######################################################################

test_all: check-env compile elaborate_fast build_test run_sim

test_all_gui: check-env compile elaborate build_test
	$(MAKE) -C sim run_sim BUILD_DIR=$(BUILD_DIR) GUI=""

test_ss: check-env
	$(MAKE) -C sim sim_ss BUILD_DIR=$(BUILD_DIR)

test_ss_gui: check-env
	$(MAKE) -C sim sim_ss BUILD_DIR=$(BUILD_DIR) GUI=""

######################################################################
# fpga targets
######################################################################

fpga: check-env
	$(MAKE) -C fpga all_xilinx BUILD_DIR=$(BUILD_DIR)

######################################################################
# verilator targets
######################################################################

.PHONY: verilate
verilate:
	@python3 ./verification/verilator/verilate.py

####
# Didactic SoC
# Baremetal controller SW flow makefile
# Contributor(s):
#   -Matti Käyrä (matti.kayra@tuni.fi)
# 	-Dovydas Liutkus (dovli@dtu.dk)
###

TESTCASE ?= blink
START_TIME=`date +%F_%H:%M`
SHELL = bash
BUILD_DIR ?= ../../build/fpga
XLEN ?= 64
PREFIX ?= riscv$(XLEN)-unknown-elf
ARCH_FLAGS ?= -march=rv32imc -mabi=ilp32
CC=$(PREFIX)-gcc
CFLAGS=-O0 -g -ffunction-sections -fdata-sections -Icommon/
OBJDUMP ?= $(PREFIX)-objdump

test: env build_test dump

env:
	mkdir -p $(BUILD_DIR)/sw
	echo "prerequisite: local install of RISCV64 toolchain + elf2hex"

# The following target is exactly the same as in sw/Makefile
build_test:
	$(CC) $(ARCH_FLAGS) -D__riscv__ $(CFLAGS) -c $(TESTCASE)/$(TESTCASE).c -o $(BUILD_DIR)/sw/$(TESTCASE).o
	$(CC) $(ARCH_FLAGS) -D__riscv__ $(CFLAGS) -DLANGUAGE_ASSEBMLY -c common/crt0.S -o $(BUILD_DIR)/sw/crt0.o
	$(CC) $(ARCH_FLAGS) -Tcommon/link.ld $(BUILD_DIR)/sw/$(TESTCASE).o $(BUILD_DIR)/sw/crt0.o -nostartfiles -nostdlib -Wl,--gc-sections -o $(BUILD_DIR)/sw/$(TESTCASE).elf
	
	$(PREFIX)-size $(BUILD_DIR)/sw/$(TESTCASE).elf

dump:
	$(OBJDUMP) $(BUILD_DIR)/sw/$(TESTCASE).elf -d -S -l > $(BUILD_DIR)/sw/$(TESTCASE).asm

#hex_test:
#	$(ELF2HEX_BIN) --bit-width 32 --input $(BUILD_DIR)/sw/$(TESTCASE).elf --output $(BUILD_DIR)/sw/$(TESTCASE).hex
####
# Didactic SoC 
# Baremetal controller SW flow makefile
# Contributor(s):
#   -Matti Käyrä (matti.kayra@tuni.fi)
#   -Antti Nurmi
###

# UART set to FAST by default
FAST_UART ?= 1
UART_FLAG = $(if $(filter 1,$(FAST_UART)),-DSIM_FAST_UART,)

# Set BYPASS_UART=1 to skip the UART receive loop (ibuf pre-loaded by testbench)
BYPASS_UART ?= 0
BYPASS_FLAG = $(if $(filter 1,$(BYPASS_UART)),-DBYPASS_UART,)

TESTCASE ?= blink
START_TIME=`date +%F_%H:%M`
SHELL = bash
BUILD_DIR ?= ../build
XLEN ?= 64
PREFIX ?= riscv$(XLEN)-unknown-elf
ARCH_FLAGS ?= -march=rv32imc -mabi=ilp32
CC=$(PREFIX)-gcc
CFLAGS=-O2 -g -ffunction-sections -fdata-sections -Icommon/ $(UART_FLAG) $(BYPASS_FLAG)
OBJDUMP ?= $(PREFIX)-objdump
OBJCOPY ?= $(PREFIX)-objcopy

env:
	mkdir -p $(BUILD_DIR)/sw
	echo "prerequisite: local install of RISCV32 toolchain + elf2hex"

build_test:
	$(CC) $(ARCH_FLAGS) -D__riscv__ $(CFLAGS) -c $(TESTCASE)/$(TESTCASE).c -o $(BUILD_DIR)/sw/$(TESTCASE).o 
	$(CC) $(ARCH_FLAGS) -D__riscv__ $(CFLAGS) -DLANGUAGE_ASSEBMLY -c common/crt0.S -o $(BUILD_DIR)/sw/crt0.o
	$(CC) $(ARCH_FLAGS) -Tcommon/link.ld $(BUILD_DIR)/sw/$(TESTCASE).o $(BUILD_DIR)/sw/crt0.o -nostartfiles -nostdlib -Wl,--gc-sections -o $(BUILD_DIR)/sw/$(TESTCASE).elf
	$(PREFIX)-size $(BUILD_DIR)/sw/$(TESTCASE).elf

hex_test:
	$(OBJCOPY) $(BUILD_DIR)/sw/$(TESTCASE).elf -O binary $(BUILD_DIR)/tmp.bin
# Pad to 4-byte boundary - without this, a binary with size % 4 != 0 causes the
# byte-swap sed to split the last word across two lines, corrupting the final instruction
	@SIZE=$$(wc -c < $(BUILD_DIR)/tmp.bin); PAD=$$(( (4 - $$SIZE % 4) % 4 )); \
	if [ $$PAD -ne 0 ]; then dd if=/dev/zero bs=1 count=$$PAD >> $(BUILD_DIR)/tmp.bin 2>/dev/null; fi
	xxd -ps $(BUILD_DIR)/tmp.bin $(BUILD_DIR)/tmp.hex
	tr -d '\n' < $(BUILD_DIR)/tmp.hex > $(BUILD_DIR)/tmp_nl.hex	
	sed -r 's/(.{8})/\1\n/g' < $(BUILD_DIR)/tmp_nl.hex > $(BUILD_DIR)/tmp_be.hex
	sed -E 's/(..)(..)(..)(..)/\4\3\2\1/' < $(BUILD_DIR)/tmp_be.hex > $(BUILD_DIR)/tmp_le.hex

trim:
	head -$(shell wc -w < $(BUILD_DIR)/tmp_le.hex) $(BUILD_DIR)/tmp_le.hex > $(BUILD_DIR)/sw/$(TESTCASE).hex

dump:
	$(OBJDUMP) $(BUILD_DIR)/sw/$(TESTCASE).elf -d -S -l > $(BUILD_DIR)/sw/$(TESTCASE).asm

cleanup:
	@rm -fr $(BUILD_DIR)/sw/*.o 
	@rm $(BUILD_DIR)/tmp*

test: env build_test hex_test trim dump cleanup

CC ?= cc
LD ?= ld

CFLAGS := -std=c89 -pedantic -Wall -Wextra -Werror -O2
KERNEL_CFLAGS := -m32 -std=c11 -Wall -Wextra -Wpedantic -Werror \
	-ffreestanding -fno-pie -fno-stack-protector -mno-sse -O2
KERNEL_LDFLAGS := -m elf_i386 -T kernel/linker.ld

.PHONY: all clean check test run

all: pathcheck kernel/kernel.elf

pathcheck: pathcheck.c
	$(CC) $(CFLAGS) $< -o $@

kernel/boot.o: kernel/boot.S
	$(CC) -m32 -ffreestanding -fno-pie -c $< -o $@

kernel/kernel.o: kernel/kernel.c
	$(CC) $(KERNEL_CFLAGS) -c $< -o $@

kernel/kernel.elf: kernel/boot.o kernel/kernel.o kernel/linker.ld
	$(LD) $(KERNEL_LDFLAGS) kernel/boot.o kernel/kernel.o -o $@

test: pathcheck
	sh tests/test.sh

check: all test
	@readelf -h kernel/kernel.elf | grep -q 'Class:.*ELF32'
	@objdump -s -j .text kernel/kernel.elf | grep -q '02b0ad1b 03000000 fb4f52e4'
	@echo "checks passed"

run: kernel/kernel.elf
	qemu-system-x86_64 -kernel $< -debugcon stdio -display none -no-reboot -no-shutdown

clean:
	rm -f pathcheck kernel/*.o kernel/kernel.elf

# pathcheck

`pathcheck` is a C89 project with a long-term destination: a tiny operating
system kernel. The host program and kernel deliberately live together so that
we can compare normal C (with an operating system and standard library) with
freestanding C (where we provide everything ourselves).

## Current milestone

- `pathcheck.c` is the hosted-C apprenticeship project. It parses `PATH`
  without modifying the environment, checks every candidate, and identifies
  the selected executable and any shadowed matches.
- `kernel/boot.S` supplies a Multiboot header, a stack, and the assembly entry
  point needed before C can run.
- `kernel/kernel.c` is freestanding C. It writes a greeting directly to VGA
  text memory and to QEMU's debug port.
- `kernel/linker.ld` controls the kernel's memory layout and entry point.

Build `pathcheck` and run its tests:

```sh
make pathcheck
make test
```

The hosted program is deliberately compiled as strict C89 with no GNU helper
functions. It returns 0 when it finds an executable, 1 when it does not (or
cannot inspect `PATH`), and 2 for incorrect command-line usage.

Build and check both the utility and kernel scaffold with `make check`.

Boot the kernel in QEMU:

```sh
make run
```

You should see `pathcheck kernel: hello from freestanding C` in the terminal.
QEMU will keep running because the kernel intentionally halts; exit with
<kbd>Ctrl</kbd>+<kbd>A</kbd>, then <kbd>X</kbd>.

## Learning roadmap

1. Diagnose `PATH` itself: duplicate, missing, relative, empty, non-directory,
   and unsafe world-writable components; then polish documentation and tests.
2. Strengthen the kernel foundation: serial output, a tiny `printf`, and a
   repeatable boot smoke test.
3. Learn the machine: Global Descriptor Table, Interrupt Descriptor Table,
   exceptions, and keyboard/timer interrupts.
4. Manage memory: parse the bootloader memory map, add a physical-page
   allocator, enable paging, then add a kernel heap.
5. Add kernel services: processes, scheduling, system calls, and a small
   in-memory filesystem.
6. Return to the name: run `pathcheck` as a user program inside our own OS.

This is an educational kernel, not a secure or production operating system.
We will keep each milestone small, observable, and testable before adding the
next subsystem.

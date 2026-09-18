#include <stddef.h>
#include <stdint.h>

enum {
    VGA_WIDTH = 80,
    VGA_HEIGHT = 25,
    VGA_COLOR_LIGHT_GREY_ON_BLACK = 0x07,
    QEMU_DEBUG_PORT = 0xE9
};

static volatile uint16_t *const vga = (uint16_t *)0xB8000;

static void
debug_putc(char character)
{
    __asm__ volatile ("outb %0, %1"
                      :
                      : "a"((uint8_t)character), "Nd"(QEMU_DEBUG_PORT));
}

static void
write_message(const char *message)
{
    size_t index;

    for (index = 0; message[index] != '\0' && index < VGA_WIDTH * VGA_HEIGHT;
         ++index) {
        vga[index] = (uint16_t)VGA_COLOR_LIGHT_GREY_ON_BLACK << 8 |
                     (uint8_t)message[index];
        debug_putc(message[index]);
    }
    debug_putc('\n');
}

void
kernel_main(void)
{
    write_message("pathcheck kernel: hello from freestanding C");
}

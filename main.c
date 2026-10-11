/*
 * Optional bare-metal program concept for the custom RISC-V CPU.
 *
 * This file is NOT a drop-in Vitis A53 application. It must be compiled using
 * a RISC-V ELF toolchain and linked to the custom CPU's memory map/startup code.
 * The current RTL uses an internal instruction memory initialized in RTL/testbench.
 * A later integration step must add a program-loading mechanism or BRAM init image.
 */
#include <stdint.h>

#define GPIO_OUT (*(volatile uint32_t *)0x10000000u)

int main(void)
{
    uint32_t counter = 0;
    while (1) {
        GPIO_OUT = counter++;
    }
    return 0;
}

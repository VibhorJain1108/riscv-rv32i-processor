# Custom RV32I Five-Stage Pipeline for FPGA

An educational Verilog project for learning a five-stage RISC-V integer pipeline and
bringing it up in AMD Vivado on a Zynq UltraScale+ MPSoC.

## Contents
- `rtl/rv32i_pipeline.v`: pipeline CPU, internal instruction/data memories, GPIO store.
- `rtl/riscv_fpga_top.v`: board-neutral top module.
- `tb/tb_rv32i_pipeline.v`: self-checking simulation test.
- `sw/main.c`: software concept only; requires a RISC-V toolchain and custom memory integration.
- `constraints/README_constraints.txt`: board-specific constraint guidance.
- `docs/architecture.md`: supported instructions and limitations.

## First: run the testbench
The testbench is plain Verilog and can be run in Vivado Simulator (XSim).

### Vivado GUI
1. Create a new RTL project.
2. Select the exact Zynq UltraScale+ device/board only when known.
3. Add `rtl/rv32i_pipeline.v` and `rtl/riscv_fpga_top.v` as Design Sources.
4. Add `tb/tb_rv32i_pipeline.v` as a Simulation Source.
5. Set `tb_rv32i_pipeline` as the simulation top.
6. Run Behavioral Simulation.
7. Let the test run; expected final output includes `TEST PASSED`.

The testbench writes a short machine-code program directly into the internal instruction
array. It does not need an external assembler or a `.mem` file.

## Synthesis
1. Set `riscv_fpga_top` as the synthesis top.
2. Add clock/reset constraints only after selecting the exact board and clock source.
3. Run Synthesis, then Implementation.
4. Inspect warnings, inferred memories, utilization and timing summary.
5. Do not claim a clock frequency or resource result until it is measured.

The top-level `clk`, `reset`, and 32-bit `gpio_out` ports are board-neutral. A real board's
pins and available LEDs differ. The bundled constraints README intentionally does not guess
pin assignments.

## Zynq UltraScale+ PS and Vitis: important distinction
The custom RISC-V CPU is a soft processor in PL. It is separate from the hard Arm Cortex-A53
APU/R5 RPU processors in the Zynq UltraScale+ MPSoC.

The normal Vivado -> XSA -> Vitis flow creates software for supported AMD embedded processors
(such as Cortex-A53/R5). It does not automatically make a custom RTL RISC-V CPU a supported
Vitis software target. For C on the custom CPU, you need:
1. a RISC-V bare-metal cross compiler (for example a `riscv64-unknown-elf` toolchain configured
   for `-march=rv32i -mabi=ilp32`, or a suitable RV32 toolchain);
2. a startup file and linker script matching the CPU's memory map;
3. a way to convert the ELF to a memory initialization image, and load that image into
   instruction memory/BRAM;
4. a defined UART/GPIO/memory-mapped bus interface;
5. software runtime/printf support if required.

Vitis can still be used for the Zynq A53 side to load/control the PL design through AXI, but
that is a separate host application. A practical first milestone is simulation and RTL
synthesis; then add BRAM/AXI interfaces and software loading.

## Current GPIO behavior
A store to byte address `0x10000000` updates `gpio_out`. Other data addresses map into the
small internal RAM array. This is a teaching interface, not a full AXI memory map.

## License
MIT-style project license for the original files in this archive. If you reuse third-party code,
preserve its original license and attribution.

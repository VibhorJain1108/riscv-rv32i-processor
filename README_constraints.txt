BOARD-SPECIFIC CONSTRAINTS REQUIRED
-----------------------------------
Do not use a guessed XDC file for a Zynq UltraScale+ MPSoC board.

This project top has ports:
  clk       : clock input
  reset     : active-high reset input
  gpio_out  : 32-bit output bus

For a physical board:
1. Confirm the exact board model and FPGA part number.
2. Use the board vendor's master XDC or board files for the correct clock pin,
   reset source, and any LEDs/connectors.
3. Assign only pins that exist on your board and set correct I/O standards.
4. Add a create_clock constraint matching the board oscillator.
5. Prefer an AXI GPIO IP or a registered output interface for external I/O.
6. Do not connect all 32 gpio_out bits to pins unless the board exposes them.

For Zynq UltraScale+ MPSoC designs using the PS, the board clock may instead be
provided by a PL clock output from the PS block design. In that case, wire the
CPU clock from the PL clock and constrain the actual clock port accordingly.

`timescale 1ns/1ps
// Board-neutral top. Connect gpio_out to board LEDs or an ILA in Vivado.
// Reset is active-high. Add a reset synchronizer for a physical board design.
module riscv_fpga_top (
    input  wire        clk,
    input  wire        reset,
    output wire [31:0] gpio_out
);
    rv32i_pipeline #(.IMEM_WORDS(256), .DMEM_WORDS(256)) cpu (
        .clk(clk),
        .reset(reset),
        .gpio_out(gpio_out)
    );
endmodule

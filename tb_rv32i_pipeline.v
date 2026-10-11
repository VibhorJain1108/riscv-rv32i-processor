`timescale 1ns/1ps
module tb_rv32i_pipeline;
    reg clk = 0;
    reg reset = 1;
    wire [31:0] gpio_out;
    integer cycles;

    always #5 clk = ~clk;

    riscv_fpga_top dut (.clk(clk), .reset(reset), .gpio_out(gpio_out));

    initial begin
        // Program:
        // x1=5; x2=7; x3=x1+x2; sw x3,0(x0); lw x4,0(x0);
        // addi x5,x4,1 (load-use stall); loop forever.
        dut.cpu.imem[0] = 32'h00500093;
        dut.cpu.imem[1] = 32'h00700113;
        dut.cpu.imem[2] = 32'h002081B3;
        dut.cpu.imem[3] = 32'h00302023;
        dut.cpu.imem[4] = 32'h00002203;
        dut.cpu.imem[5] = 32'h00120293;
        dut.cpu.imem[6] = 32'h0000006F;

        repeat (4) @(posedge clk);
        reset = 0;
        for (cycles = 0; cycles < 60; cycles = cycles + 1)
            @(posedge clk);
        #1;
        $display("x1=%0d x2=%0d x3=%0d x4=%0d x5=%0d dmem[0]=%0d",
            dut.cpu.regs[1], dut.cpu.regs[2], dut.cpu.regs[3],
            dut.cpu.regs[4], dut.cpu.regs[5], dut.cpu.dmem[0]);

        if (dut.cpu.regs[1] !== 5 ||
            dut.cpu.regs[2] !== 7 ||
            dut.cpu.regs[3] !== 12 ||
            dut.cpu.regs[4] !== 12 ||
            dut.cpu.regs[5] !== 13 ||
            dut.cpu.dmem[0] !== 12) begin
            $display("TEST FAILED");
            $fatal(1);
        end
        $display("TEST PASSED");
        $finish;
    end
endmodule

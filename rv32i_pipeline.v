`timescale 1ns/1ps
// Educational five-stage RV32I pipeline.
// Supported: RV32I integer arithmetic/logical/shift, loads/stores,
// conditional branches, JAL/JALR, LUI/AUIPC.
// No CSRs, traps, interrupts, privilege modes, or compressed instructions.
// Instruction and data memories are small on-chip arrays for bring-up.
// Adapt memory sizes/latency before using external DDR or BRAM IP.

module rv32i_pipeline #(
    parameter IMEM_WORDS = 256,
    parameter DMEM_WORDS = 256
) (
    input  wire        clk,
    input  wire        reset,
    output reg  [31:0] gpio_out
);
    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem [0:DMEM_WORDS-1];
    reg [31:0] regs [0:31];

    integer i;
    initial begin
        for (i = 0; i < IMEM_WORDS; i = i + 1) imem[i] = 32'h00000013; // NOP
        for (i = 0; i < DMEM_WORDS; i = i + 1) dmem[i] = 32'b0;
    end

    // ---------------- IF ----------------
    reg [31:0] pc;
    wire [31:0] if_instr = imem[pc[31:2] % IMEM_WORDS];

    // ---------------- IF/ID ----------------
    reg [31:0] ifid_pc, ifid_instr;
    reg ifid_valid;

    // ---------------- ID decode ----------------
    wire [6:0] id_opcode = ifid_instr[6:0];
    wire [4:0] id_rs1 = ifid_instr[19:15];
    wire [4:0] id_rs2 = ifid_instr[24:20];
    wire [4:0] id_rd  = ifid_instr[11:7];
    wire [2:0] id_funct3 = ifid_instr[14:12];

    reg [31:0] id_imm;
    always @* begin
        case (id_opcode)
            7'b0010011, 7'b0000011, 7'b1100111:
                id_imm = {{20{ifid_instr[31]}}, ifid_instr[31:20]};
            7'b0100011:
                id_imm = {{20{ifid_instr[31]}}, ifid_instr[31:25], ifid_instr[11:7]};
            7'b1100011:
                id_imm = {{19{ifid_instr[31]}}, ifid_instr[31], ifid_instr[7],
                          ifid_instr[30:25], ifid_instr[11:8], 1'b0};
            7'b0110111:
                id_imm = {ifid_instr[31:12], 12'b0}; // LUI
            7'b0010111:
                id_imm = {ifid_instr[31:12], 12'b0}; // AUIPC
            7'b1101111:
                id_imm = {{11{ifid_instr[31]}}, ifid_instr[31], ifid_instr[19:12],
                          ifid_instr[20], ifid_instr[30:21], 1'b0};
            default: id_imm = 32'b0;
        endcase
    end

    wire id_uses_rs1 = (id_opcode == 7'b0110011) || (id_opcode == 7'b0010011) ||
                       (id_opcode == 7'b0000011) || (id_opcode == 7'b0100011) ||
                       (id_opcode == 7'b1100011) || (id_opcode == 7'b1100111);
    wire id_uses_rs2 = (id_opcode == 7'b0110011) || (id_opcode == 7'b0100011) ||
                       (id_opcode == 7'b1100011);

    wire [31:0] id_rdata1 = (id_rs1 == 0) ? 32'b0 : regs[id_rs1];
    wire [31:0] id_rdata2 = (id_rs2 == 0) ? 32'b0 : regs[id_rs2];

    // ---------------- ID/EX ----------------
    reg [31:0] idex_pc, idex_rdata1, idex_rdata2, idex_imm;
    reg [4:0] idex_rs1, idex_rs2, idex_rd;
    reg [2:0] idex_funct3;
    reg [6:0] idex_opcode;
    reg [6:0] idex_funct7;
    reg idex_valid;

    // ---------------- EX/MEM ----------------
    reg [31:0] exmem_pc4, exmem_alu, exmem_store_data;
    reg [4:0] exmem_rd;
    reg [2:0] exmem_funct3;
    reg [6:0] exmem_opcode;
    reg exmem_regwrite, exmem_memread, exmem_memwrite, exmem_memtoreg;
    reg exmem_valid;

    // ---------------- MEM/WB ----------------
    reg [31:0] memwb_pc4, memwb_alu, memwb_load;
    reg [4:0] memwb_rd;
    reg memwb_regwrite, memwb_memtoreg, memwb_valid;

    wire [31:0] wb_data = memwb_memtoreg ? memwb_load : memwb_alu;

    // ---------------- EX forwarding ----------------
    reg [31:0] ex_src1, ex_src2;
    always @* begin
        ex_src1 = idex_rdata1;
        ex_src2 = idex_rdata2;
        if (exmem_valid && exmem_regwrite && (exmem_rd != 0) &&
            !exmem_memtoreg && (exmem_rd == idex_rs1))
            ex_src1 = exmem_alu;
        else if (memwb_valid && memwb_regwrite && (memwb_rd != 0) &&
                 (memwb_rd == idex_rs1))
            ex_src1 = wb_data;

        if (exmem_valid && exmem_regwrite && (exmem_rd != 0) &&
            !exmem_memtoreg && (exmem_rd == idex_rs2))
            ex_src2 = exmem_alu;
        else if (memwb_valid && memwb_regwrite && (memwb_rd != 0) &&
                 (memwb_rd == idex_rs2))
            ex_src2 = wb_data;
    end

    wire [6:0] ex_opcode = idex_opcode;
    wire [2:0] ex_f3 = idex_funct3;
    wire [6:0] ex_f7 = idex_funct7;
    wire ex_is_op_imm = (ex_opcode == 7'b0010011);
    wire ex_is_op = (ex_opcode == 7'b0110011);
    wire ex_is_load = (ex_opcode == 7'b0000011);
    wire ex_is_store = (ex_opcode == 7'b0100011);
    wire ex_is_branch = (ex_opcode == 7'b1100011);
    wire ex_is_jal = (ex_opcode == 7'b1101111);
    wire ex_is_jalr = (ex_opcode == 7'b1100111);
    wire ex_is_lui = (ex_opcode == 7'b0110111);
    wire ex_is_auipc = (ex_opcode == 7'b0010111);

    wire [31:0] ex_alu_b = (ex_is_op_imm || ex_is_load || ex_is_store ||
                            ex_is_jalr) ? idex_imm : ex_src2;
    reg [31:0] ex_alu_result;
    always @* begin
        ex_alu_result = 32'b0;
        if (ex_is_lui) ex_alu_result = idex_imm;
        else if (ex_is_auipc) ex_alu_result = idex_pc + idex_imm;
        else if (ex_is_jal || ex_is_jalr) ex_alu_result = idex_pc + 4;
        else begin
            case (ex_f3)
                3'b000: ex_alu_result = (ex_is_op && ex_f7[5]) ?
                                         (ex_src1 - ex_alu_b) : (ex_src1 + ex_alu_b);
                3'b001: ex_alu_result = ex_src1 << ex_alu_b[4:0];
                3'b010: ex_alu_result = ($signed(ex_src1) < $signed(ex_alu_b)) ? 1 : 0;
                3'b011: ex_alu_result = (ex_src1 < ex_alu_b) ? 1 : 0;
                3'b100: ex_alu_result = ex_src1 ^ ex_alu_b;
                3'b101: ex_alu_result = ex_f7[5] ?
                                         ($signed(ex_src1) >>> ex_alu_b[4:0]) :
                                         (ex_src1 >> ex_alu_b[4:0]);
                3'b110: ex_alu_result = ex_src1 | ex_alu_b;
                3'b111: ex_alu_result = ex_src1 & ex_alu_b;
                default: ex_alu_result = 32'b0;
            endcase
        end
    end

    reg ex_branch_taken;
    always @* begin
        ex_branch_taken = 1'b0;
        if (ex_is_branch) begin
            case (ex_f3)
                3'b000: ex_branch_taken = (ex_src1 == ex_src2); // BEQ
                3'b001: ex_branch_taken = (ex_src1 != ex_src2); // BNE
                3'b100: ex_branch_taken = ($signed(ex_src1) < $signed(ex_src2));
                3'b101: ex_branch_taken = ($signed(ex_src1) >= $signed(ex_src2));
                3'b110: ex_branch_taken = (ex_src1 < ex_src2);
                3'b111: ex_branch_taken = (ex_src1 >= ex_src2);
                default: ex_branch_taken = 1'b0;
            endcase
        end
    end

    wire ex_redirect = idex_valid && (ex_branch_taken || ex_is_jal || ex_is_jalr);
    wire [31:0] ex_redirect_target = ex_is_jalr ?
                                    ((ex_src1 + idex_imm) & 32'hFFFFFFFE) :
                                    (idex_pc + idex_imm);

    // Load-use interlock. JAL/JALR don't consume rs2.
    wire idex_is_load = idex_valid && (idex_opcode == 7'b0000011);
    wire load_use_stall = idex_is_load && (idex_rd != 0) && ifid_valid &&
                          ((id_uses_rs1 && (id_rs1 == idex_rd)) ||
                           (id_uses_rs2 && (id_rs2 == idex_rd)));

    // ---------------- MEM stage ----------------
    wire [31:0] dmem_word_addr = exmem_alu[31:2] % DMEM_WORDS;
    wire [31:0] raw_load = dmem[dmem_word_addr];
    reg [31:0] load_value;
    always @* begin
        case (exmem_funct3)
            3'b000: begin // LB
                case (exmem_alu[1:0])
                    0: load_value = {{24{raw_load[7]}}, raw_load[7:0]};
                    1: load_value = {{24{raw_load[15]}}, raw_load[15:8]};
                    2: load_value = {{24{raw_load[23]}}, raw_load[23:16]};
                    default: load_value = {{24{raw_load[31]}}, raw_load[31:24]};
                endcase
            end
            3'b100: begin // LBU
                case (exmem_alu[1:0])
                    0: load_value = {24'b0, raw_load[7:0]};
                    1: load_value = {24'b0, raw_load[15:8]};
                    2: load_value = {24'b0, raw_load[23:16]};
                    default: load_value = {24'b0, raw_load[31:24]};
                endcase
            end
            3'b001: load_value = exmem_alu[1] ?
                                 {{16{raw_load[31]}}, raw_load[31:16]} :
                                 {{16{raw_load[15]}}, raw_load[15:0]}; // LH
            3'b101: load_value = exmem_alu[1] ?
                                 {16'b0, raw_load[31:16]} :
                                 {16'b0, raw_load[15:0]}; // LHU
            default: load_value = raw_load; // LW
        endcase
    end

    // GPIO at byte address 0x1000_0000. Other addresses wrap into small data RAM.
    wire exmem_gpio_write = exmem_valid && exmem_memwrite &&
                            (exmem_alu == 32'h10000000);
    always @(posedge clk) begin
        if (reset) begin
            gpio_out <= 32'b0;
        end else if (exmem_gpio_write) begin
            case (exmem_funct3)
                3'b000: begin
                    case (exmem_alu[1:0])
                        0: gpio_out[7:0] <= exmem_store_data[7:0];
                        1: gpio_out[15:8] <= exmem_store_data[7:0];
                        2: gpio_out[23:16] <= exmem_store_data[7:0];
                        3: gpio_out[31:24] <= exmem_store_data[7:0];
                    endcase
                end
                3'b001: begin
                    if (exmem_alu[1]) gpio_out[31:16] <= exmem_store_data[15:0];
                    else gpio_out[15:0] <= exmem_store_data[15:0];
                end
                default: gpio_out <= exmem_store_data;
            endcase
        end
    end

    integer lane;
    always @(posedge clk) begin
        if (!reset && exmem_valid && exmem_memwrite &&
            (exmem_alu != 32'h10000000)) begin
            case (exmem_funct3)
                3'b000: begin
                    case (exmem_alu[1:0])
                        0: dmem[dmem_word_addr][7:0] <= exmem_store_data[7:0];
                        1: dmem[dmem_word_addr][15:8] <= exmem_store_data[7:0];
                        2: dmem[dmem_word_addr][23:16] <= exmem_store_data[7:0];
                        3: dmem[dmem_word_addr][31:24] <= exmem_store_data[7:0];
                    endcase
                end
                3'b001: begin
                    if (exmem_alu[1]) dmem[dmem_word_addr][31:16] <= exmem_store_data[15:0];
                    else dmem[dmem_word_addr][15:0] <= exmem_store_data[15:0];
                end
                default: dmem[dmem_word_addr] <= exmem_store_data;
            endcase
        end
    end

    // ---------------- Pipeline sequential state ----------------
    always @(posedge clk) begin
        if (reset) begin
            pc <= 32'b0;
            ifid_pc <= 0; ifid_instr <= 32'h00000013; ifid_valid <= 0;
            idex_pc <= 0; idex_rdata1 <= 0; idex_rdata2 <= 0; idex_imm <= 0;
            idex_rs1 <= 0; idex_rs2 <= 0; idex_rd <= 0; idex_funct3 <= 0;
            idex_opcode <= 0; idex_funct7 <= 0; idex_valid <= 0;
            exmem_pc4 <= 0; exmem_alu <= 0; exmem_store_data <= 0;
            exmem_rd <= 0; exmem_funct3 <= 0; exmem_opcode <= 0;
            exmem_regwrite <= 0; exmem_memread <= 0; exmem_memwrite <= 0;
            exmem_memtoreg <= 0; exmem_valid <= 0;
            memwb_pc4 <= 0; memwb_alu <= 0; memwb_load <= 0; memwb_rd <= 0;
            memwb_regwrite <= 0; memwb_memtoreg <= 0; memwb_valid <= 0;
            for (i = 0; i < 32; i = i + 1) regs[i] <= 0;
        end else begin
            // WB
            if (memwb_valid && memwb_regwrite && (memwb_rd != 0))
                regs[memwb_rd] <= wb_data;
            regs[0] <= 0;

            // MEM/WB captures current MEM output
            memwb_valid <= exmem_valid;
            memwb_rd <= exmem_rd;
            memwb_regwrite <= exmem_regwrite;
            memwb_memtoreg <= exmem_memtoreg;
            memwb_pc4 <= exmem_pc4;
            memwb_alu <= exmem_alu;
            memwb_load <= load_value;

            // EX/MEM
            exmem_valid <= idex_valid;
            exmem_pc4 <= idex_pc + 4;
            exmem_alu <= ex_alu_result;
            exmem_store_data <= ex_src2;
            exmem_rd <= idex_rd;
            exmem_funct3 <= idex_funct3;
            exmem_opcode <= idex_opcode;
            exmem_regwrite <= idex_valid &&
                ((ex_is_op || ex_is_op_imm || ex_is_load || ex_is_jal ||
                  ex_is_jalr || ex_is_lui || ex_is_auipc));
            exmem_memread <= idex_valid && ex_is_load;
            exmem_memwrite <= idex_valid && ex_is_store;
            exmem_memtoreg <= idex_valid && ex_is_load;

            // Redirect flushes younger instructions.
            if (ex_redirect) begin
                pc <= ex_redirect_target;
                ifid_pc <= 0; ifid_instr <= 32'h00000013; ifid_valid <= 0;
                idex_pc <= 0; idex_rdata1 <= 0; idex_rdata2 <= 0; idex_imm <= 0;
                idex_rs1 <= 0; idex_rs2 <= 0; idex_rd <= 0; idex_funct3 <= 0;
                idex_opcode <= 0; idex_funct7 <= 0; idex_valid <= 0;
            end else if (load_use_stall) begin
                // Hold PC and IF/ID; insert bubble into ID/EX.
                pc <= pc;
                ifid_pc <= ifid_pc; ifid_instr <= ifid_instr; ifid_valid <= ifid_valid;
                idex_pc <= 0; idex_rdata1 <= 0; idex_rdata2 <= 0; idex_imm <= 0;
                idex_rs1 <= 0; idex_rs2 <= 0; idex_rd <= 0; idex_funct3 <= 0;
                idex_opcode <= 0; idex_funct7 <= 0; idex_valid <= 0;
            end else begin
                pc <= pc + 4;
                ifid_pc <= pc;
                ifid_instr <= if_instr;
                ifid_valid <= 1'b1;

                idex_pc <= ifid_pc;
                idex_rdata1 <= id_rdata1;
                idex_rdata2 <= id_rdata2;
                idex_imm <= id_imm;
                idex_rs1 <= id_rs1;
                idex_rs2 <= id_rs2;
                idex_rd <= id_rd;
                idex_funct3 <= id_funct3;
                idex_opcode <= id_opcode;
                idex_funct7 <= ifid_instr[31:25];
                idex_valid <= ifid_valid;
            end
        end
    end
endmodule

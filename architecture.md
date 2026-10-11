# Architecture and limitations

## Pipeline
- IF: program counter and instruction fetch from internal instruction array.
- ID: register reads and immediate generation.
- EX: ALU, branch comparison, forwarding and redirect calculation.
- MEM: data RAM access and byte/halfword selection.
- WB: register-file writeback.

## Hazard handling
- EX/MEM and MEM/WB forwarding for ALU operands.
- One-cycle load-use interlock.
- Taken branches and jumps redirect the PC and flush younger instructions.

## Implemented instruction groups
- R-type: ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND.
- I-type ALU: ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI.
- Loads: LB, LH, LW, LBU, LHU.
- Stores: SB, SH, SW.
- Branches: BEQ, BNE, BLT, BGE, BLTU, BGEU.
- Jumps: JAL, JALR.
- Upper immediates: LUI, AUIPC.

## Important limitations
This is an educational bring-up core, not a verified production CPU.
- No machine-mode CSRs, traps/exceptions, interrupts, debug module, or privilege modes.
- No misaligned-access traps; misaligned loads/stores are not fully specified.
- Internal asynchronous-read memories are intended for simulation and first bring-up.
  Their implementation may map to distributed logic rather than BRAM.
- Memory addressing wraps into a small array for addresses other than the GPIO address.
  This is not a general physical memory map.
- The RTL has not been certified against the RISC-V architectural test suite.
- Synthesis/timing/resource figures must be measured on the selected FPGA and tool version.
- For a robust implementation, add assertions, architectural tests, a proper bus interface,
  BRAM-friendly synchronous memories, and reset synchronization.

// Verilog implementation of Y86-64 Sequential Processor
// Generated from seq-full.hcl
// Includes iaddq instruction support

`timescale 1ns / 1ps

// Instruction Codes
`define INOP    4'h0
`define IHALT   4'h1
`define IRRMOVQ 4'h2
`define IIRMOVQ 4'h3
`define IRMMOVQ 4'h4
`define IMRMOVQ 4'h5
`define IOPQ    4'h6
`define IJXX    4'h7
`define ICALL   4'h8
`define IRET    4'h9
`define IPUSHQ  4'hA
`define IPOPQ   4'hB
`define IIADDQ  4'hC

// Function Codes
`define FNONE   4'h0

// ALU Functions
`define ALUADD  4'h0
`define ALUSUB  4'h1
`define ALUAND  4'h2
`define ALUXOR  4'h3

// Register IDs
`define RRSP    4'h4
`define RNONE   4'hF

// Status Codes
`define SAOK    4'h1
`define SHLT    4'h2
`define SADR    4'h3
`define SINS    4'h4

module seq_full (
    input wire clk,
    input wire reset,
    output reg [63:0] pc,
    output wire [3:0] stat
);

    // Internal signals
    // Fetch stage
    wire [3:0] imem_icode;
    wire [3:0] imem_ifun;
    wire [3:0] icode;
    wire [3:0] ifun;
    wire [3:0] rA;
    wire [3:0] rB;
    wire [63:0] valC;
    wire [63:0] valP;
    wire imem_error;
    wire instr_valid;
    wire need_regids;
    wire need_valC;

    // Decode stage
    wire [3:0] srcA;
    wire [3:0] srcB;
    wire [3:0] dstE;
    wire [3:0] dstM;
    wire [63:0] valA;
    wire [63:0] valB;

    // Execute stage
    wire [63:0] aluA;
    wire [63:0] aluB;
    wire [3:0] alufun;
    wire set_cc;
    wire [63:0] valE;
    wire Cnd;
    reg ZF, SF, OF;

    // Memory stage
    wire mem_read;
    wire mem_write;
    wire [63:0] mem_addr;
    wire [63:0] mem_data;
    wire [63:0] valM;
    wire dmem_error;

    // PC update
    wire [63:0] new_pc;

    // Instruction Memory (simplified - would be external in real design)
    reg [7:0] imem [0:4095];
    wire [79:0] instr_bytes;
    
    assign instr_bytes = {imem[pc+9], imem[pc+8], imem[pc+7], imem[pc+6],
                          imem[pc+5], imem[pc+4], imem[pc+3], imem[pc+2],
                          imem[pc+1], imem[pc]};
    
    assign imem_icode = imem[pc][7:4];
    assign imem_ifun = imem[pc][3:0];
    assign imem_error = (pc > 4095);

    // Register File
    reg [63:0] registers [0:14];
    
    assign valA = (srcA == `RNONE) ? 64'h0 : registers[srcA];
    assign valB = (srcB == `RNONE) ? 64'h0 : registers[srcB];

    // Data Memory (simplified)
    reg [7:0] dmem [0:4095];
    assign dmem_error = (mem_addr > 4095) && (mem_read || mem_write);

    //=========================================================================
    // Fetch Stage
    //=========================================================================
    
    // Determine instruction code
    assign icode = imem_error ? `INOP : imem_icode;
    
    // Determine instruction function
    assign ifun = imem_error ? `FNONE : imem_ifun;
    
    // Is instruction valid?
    assign instr_valid = (icode == `INOP) || (icode == `IHALT) ||
                         (icode == `IRRMOVQ) || (icode == `IIRMOVQ) ||
                         (icode == `IRMMOVQ) || (icode == `IMRMOVQ) ||
                         (icode == `IOPQ) || (icode == `IJXX) ||
                         (icode == `ICALL) || (icode == `IRET) ||
                         (icode == `IPUSHQ) || (icode == `IPOPQ) ||
                         (icode == `IIADDQ);
    
    // Does fetched instruction require a regid byte?
    assign need_regids = (icode == `IRRMOVQ) || (icode == `IOPQ) ||
                         (icode == `IPUSHQ) || (icode == `IPOPQ) ||
                         (icode == `IIRMOVQ) || (icode == `IRMMOVQ) ||
                         (icode == `IMRMOVQ) || (icode == `IIADDQ);
    
    // Does fetched instruction require a constant word?
    assign need_valC = (icode == `IIRMOVQ) || (icode == `IRMMOVQ) ||
                       (icode == `IMRMOVQ) || (icode == `IJXX) ||
                       (icode == `ICALL) || (icode == `IIADDQ);
    
    // Extract register specifiers
    assign rA = need_regids ? imem[pc+1][7:4] : `RNONE;
    assign rB = need_regids ? imem[pc+1][3:0] : `RNONE;
    
    // Extract constant value (little-endian)
    assign valC = need_valC ? (need_regids ? 
                  {imem[pc+9], imem[pc+8], imem[pc+7], imem[pc+6],
                   imem[pc+5], imem[pc+4], imem[pc+3], imem[pc+2]} :
                  {imem[pc+8], imem[pc+7], imem[pc+6], imem[pc+5],
                   imem[pc+4], imem[pc+3], imem[pc+2], imem[pc+1]}) : 64'h0;
    
    // Compute next PC value
    assign valP = pc + 1 + (need_regids ? 1 : 0) + (need_valC ? 8 : 0);

    //=========================================================================
    // Decode Stage
    //=========================================================================
    
    // What register should be used as the A source?
    assign srcA = ((icode == `IRRMOVQ) || (icode == `IRMMOVQ) ||
                   (icode == `IOPQ) || (icode == `IPUSHQ)) ? rA :
                  ((icode == `IPOPQ) || (icode == `IRET)) ? `RRSP : `RNONE;
    
    // What register should be used as the B source?
    assign srcB = ((icode == `IOPQ) || (icode == `IRMMOVQ) ||
                   (icode == `IMRMOVQ) || (icode == `IIADDQ)) ? rB :
                  ((icode == `IPUSHQ) || (icode == `IPOPQ) ||
                   (icode == `ICALL) || (icode == `IRET)) ? `RRSP : `RNONE;
    
    // What register should be used as the E destination?
    assign dstE = ((icode == `IRRMOVQ) && Cnd) ? rB :
                  ((icode == `IIRMOVQ) || (icode == `IOPQ) ||
                   (icode == `IIADDQ)) ? rB :
                  ((icode == `IPUSHQ) || (icode == `IPOPQ) ||
                   (icode == `ICALL) || (icode == `IRET)) ? `RRSP : `RNONE;
    
    // What register should be used as the M destination?
    assign dstM = ((icode == `IMRMOVQ) || (icode == `IPOPQ)) ? rA : `RNONE;

    //=========================================================================
    // Execute Stage
    //=========================================================================
    
    // Select input A to ALU
    assign aluA = ((icode == `IRRMOVQ) || (icode == `IOPQ)) ? valA :
                  ((icode == `IIRMOVQ) || (icode == `IRMMOVQ) ||
                   (icode == `IMRMOVQ) || (icode == `IIADDQ)) ? valC :
                  ((icode == `ICALL) || (icode == `IPUSHQ)) ? -64'd8 :
                  ((icode == `IRET) || (icode == `IPOPQ)) ? 64'd8 : 64'h0;
    
    // Select input B to ALU
    assign aluB = ((icode == `IRMMOVQ) || (icode == `IMRMOVQ) ||
                   (icode == `IOPQ) || (icode == `ICALL) ||
                   (icode == `IPUSHQ) || (icode == `IRET) ||
                   (icode == `IPOPQ) || (icode == `IIADDQ)) ? valB :
                  ((icode == `IRRMOVQ) || (icode == `IIRMOVQ)) ? 64'h0 : 64'h0;
    
    // Set the ALU function
    assign alufun = (icode == `IOPQ) ? ifun : `ALUADD;
    
    // Should the condition codes be updated?
    assign set_cc = (icode == `IOPQ) || (icode == `IIADDQ);
    
    // ALU computation
    reg [63:0] alu_result;
    reg alu_overflow;
    
    always @(*) begin
        case (alufun)
            `ALUADD: begin
                alu_result = aluA + aluB;
                alu_overflow = (aluA[63] == aluB[63]) && (alu_result[63] != aluA[63]);
            end
            `ALUSUB: begin
                alu_result = aluB - aluA;
                alu_overflow = (aluA[63] != aluB[63]) && (alu_result[63] != aluB[63]);
            end
            `ALUAND: begin
                alu_result = aluA & aluB;
                alu_overflow = 1'b0;
            end
            `ALUXOR: begin
                alu_result = aluA ^ aluB;
                alu_overflow = 1'b0;
            end
            default: begin
                alu_result = aluA + aluB;
                alu_overflow = 1'b0;
            end
        endcase
    end
    
    assign valE = alu_result;
    
    // Condition code evaluation for conditional moves/jumps
    reg cond_result;
    always @(*) begin
        case (ifun)
            4'h0: cond_result = 1'b1;                          // unconditional
            4'h1: cond_result = (SF ^ OF) | ZF;                // le
            4'h2: cond_result = SF ^ OF;                       // l
            4'h3: cond_result = ZF;                            // e
            4'h4: cond_result = ~ZF;                           // ne
            4'h5: cond_result = ~(SF ^ OF);                    // ge
            4'h6: cond_result = ~(SF ^ OF) & ~ZF;              // g
            default: cond_result = 1'b1;
        endcase
    end
    
    assign Cnd = cond_result;

    //=========================================================================
    // Memory Stage
    //=========================================================================
    
    // Set read control signal
    assign mem_read = (icode == `IMRMOVQ) || (icode == `IPOPQ) || (icode == `IRET);
    
    // Set write control signal
    assign mem_write = (icode == `IRMMOVQ) || (icode == `IPUSHQ) || (icode == `ICALL);
    
    // Select memory address
    assign mem_addr = ((icode == `IRMMOVQ) || (icode == `IPUSHQ) ||
                       (icode == `ICALL) || (icode == `IMRMOVQ)) ? valE :
                      ((icode == `IPOPQ) || (icode == `IRET)) ? valA : 64'h0;
    
    // Select memory input data
    assign mem_data = ((icode == `IRMMOVQ) || (icode == `IPUSHQ)) ? valA :
                      (icode == `ICALL) ? valP : 64'h0;
    
    // Memory read (little-endian)
    assign valM = mem_read ? {dmem[mem_addr+7], dmem[mem_addr+6],
                              dmem[mem_addr+5], dmem[mem_addr+4],
                              dmem[mem_addr+3], dmem[mem_addr+2],
                              dmem[mem_addr+1], dmem[mem_addr]} : 64'h0;

    //=========================================================================
    // Status
    //=========================================================================
    
    assign stat = (imem_error || dmem_error) ? `SADR :
                  (!instr_valid) ? `SINS :
                  (icode == `IHALT) ? `SHLT : `SAOK;

    //=========================================================================
    // PC Update
    //=========================================================================
    
    assign new_pc = (icode == `ICALL) ? valC :
                    ((icode == `IJXX) && Cnd) ? valC :
                    (icode == `IRET) ? valM : valP;

    //=========================================================================
    // Sequential Logic - Clock Edge Updates
    //=========================================================================
    
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 64'h0;
            ZF <= 1'b1;
            SF <= 1'b0;
            OF <= 1'b0;
        end else if (stat == `SAOK) begin
            // Update PC
            pc <= new_pc;
            
            // Update condition codes
            if (set_cc) begin
                ZF <= (alu_result == 64'h0);
                SF <= alu_result[63];
                OF <= alu_overflow;
            end
            
            // Write to register file (E destination)
            if (dstE != `RNONE) begin
                registers[dstE] <= valE;
            end
            
            // Write to register file (M destination)
            if (dstM != `RNONE) begin
                registers[dstM] <= valM;
            end
            
            // Write to data memory (little-endian)
            if (mem_write && !dmem_error) begin
                dmem[mem_addr]   <= mem_data[7:0];
                dmem[mem_addr+1] <= mem_data[15:8];
                dmem[mem_addr+2] <= mem_data[23:16];
                dmem[mem_addr+3] <= mem_data[31:24];
                dmem[mem_addr+4] <= mem_data[39:32];
                dmem[mem_addr+5] <= mem_data[47:40];
                dmem[mem_addr+6] <= mem_data[55:48];
                dmem[mem_addr+7] <= mem_data[63:56];
            end
        end
    end

endmodule

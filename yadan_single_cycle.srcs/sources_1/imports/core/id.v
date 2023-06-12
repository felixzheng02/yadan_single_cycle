/******************************************************************************
MIT License

Copyright (c) 2020 BH6BAO

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

******************************************************************************/

`ifdef  SPYGLASS
`include "../../module/core/yadan_defs.v"
`else
`include "yadan_defs.v"
`endif


module id(
    input   wire                    rst,
    input   wire[`InstAddrBus]      pc_i,
    input   wire[`InstBus]          inst_i,

    // read regs form regfile
    input   wire[`RegBus]           reg1_data_i,
    input   wire[`RegBus]           reg2_data_i,

    // from ex
    input   wire                    ex_wreg_i,
    input   wire[`RegBus]           ex_wdata_i,
    input   wire[`RegAddrBus]       ex_wd_i,
    input   wire                    ex_branch_flag_i,
// load ���
    input   wire[`AluOpBus]         ex_aluop_i,

    // from wd mem
    input   wire                    mem_wreg_i,
    input   wire[`RegBus]           mem_wdata_i,
    input   wire[`RegAddrBus]       mem_wd_i,

    // from csr
    input   wire[`RegBus]           csr_reg_data_i,

    // to csr reg
    output  reg[`DataAddrBus]       csr_reg_addr_o,

    // output to regfile
    output  reg                     reg1_read_o,
    output  reg                     reg2_read_o,
    output  reg[`RegAddrBus]        reg1_addr_o,
    output  reg[`RegAddrBus]        reg2_addr_o,

    // output execution
    output  wire                    stallreq,

    output  wire[`InstAddrBus]       pc_o,
    output  reg[`InstBus]           inst_o,
    output  reg[`AluOpBus]          aluop_o,
    output  reg[`AluSelBus]         alusel_o,
    output  reg[`RegBus]            reg1_o,
    output  reg[`RegBus]            reg2_o,
    output  reg[`RegAddrBus]        reg_wd_o,
    output  reg                     wreg_o,
    
    output  reg                     wcsr_reg_o,
    output  reg[`RegBus]            csr_reg_o,
    output  reg[`DataAddrBus]       wd_csr_reg_o
);

    // ȡ��ָ���ָ���룬������
    // ���� RISC-V ISA �ֲ����ǿ���֪��
    // [6:0] Ϊ opcode; [11:7] Ϊ rd; [14:12] Ϊ funct3; [19:15] Ϊ rs1; [24:20] Ϊ rs2; [31:25] Ϊ funct7;
    wire[6:0]   opcode  = inst_i[6:0];
    wire[4:0]   rd      = inst_i[11:7];
    wire[2:0]   funct3  = inst_i[14:12];
    wire[4:0]   rs1     = inst_i[19:15];
    wire[4:0]   rs2     = inst_i[24:20];
    // wire[6:0]   funct7  = inst_i[31:25];

    // ����ָ��ִ����Ҫ��������
    reg[`RegBus]    imm_1;
    reg[`RegBus]    imm_2;

    // ָʾָ���Ƿ���Ч
    reg     instvalid;

    // load ���
    reg     reg1_loadralate;
    reg     reg2_loadralate;
    wire    pre_inst_is_load;
    assign  stallreq = reg1_loadralate | reg2_loadralate;
    assign pre_inst_is_load = ( (ex_aluop_i == `EXE_LB) ||
                                (ex_aluop_i == `EXE_LH) ||
                                (ex_aluop_i == `EXE_LW) ||
                                (ex_aluop_i == `EXE_LBU)||
                                (ex_aluop_i == `EXE_LHU)||
                                (ex_aluop_i == `EXE_SB) ||
                                (ex_aluop_i == `EXE_SH) ||
                                (ex_aluop_i == `EXE_SW)) ? 1'b1 : 1'b0;
    
    assign pc_o = pc_i;//202167 �޸ģ���pc_o ԭ������ת�����


    //*******   ��ָ������    *******//
    always @ (*) begin
        if (rst == `RstEnable || (ex_branch_flag_i == `BranchEnable && inst_i != `ZeroWord)) begin
            aluop_o         = `EXE_NONE;
            alusel_o        = `EXE_RES_NONE;
            reg_wd_o        = `NOPRegAddr;
            wreg_o          = `WriteDisable;
            instvalid       = `InstValid;
            reg1_read_o     = `ReadDisable;
            reg2_read_o     = `ReadDisable;
            reg1_addr_o     = `NOPRegAddr;
            reg2_addr_o     = `NOPRegAddr;
            imm_1           = `ZeroWord;
            imm_2           = `ZeroWord;
            inst_o          = `ZeroWord;
            // pc_o            = `ZeroWord; 
            csr_reg_addr_o  = `ZeroWord;
            csr_reg_o       = `ZeroWord;
            wd_csr_reg_o    = `ZeroWord;
            wcsr_reg_o      = `WriteDisable;

        end else begin
            aluop_o         = `EXE_NONE;
            alusel_o        = `EXE_RES_NONE;
            reg_wd_o        =  rd;
            wreg_o          = `WriteDisable;

            reg1_read_o     = `ReadDisable;
            reg2_read_o     = `ReadDisable;
            reg1_addr_o     = rs1;
            reg2_addr_o     = rs2;
            imm_1           = `ZeroWord;
            imm_2           = `ZeroWord;
            inst_o          = inst_i;
            // pc_o            = pc_i;
            csr_reg_addr_o  = `ZeroWord;
            csr_reg_o       = csr_reg_data_i;
            wd_csr_reg_o    = `ZeroWord;
            wcsr_reg_o      = `WriteDisable;

            case (opcode)
                `INST_NONE  : begin
                    aluop_o         = `EXE_NONE;
                    alusel_o        = `EXE_RES_NONE;
                    reg_wd_o        = `NOPRegAddr;
                    wreg_o          = `WriteDisable;
                    instvalid       = `InstValid;
                    reg1_read_o     = `ReadDisable;
                    reg2_read_o     = `ReadDisable;
                    reg1_addr_o     = `NOPRegAddr;
                    reg2_addr_o     = `NOPRegAddr;
                    imm_1           = `ZeroWord;
                    imm_2           = `ZeroWord;
                    // inst_o          = `ZeroWord;
                    // pc_o            = `ZeroWord; 
                    // csr_reg_addr_o  = `ZeroWord;
                    // csr_reg_o       = `ZeroWord;
                    // wd_csr_reg_o    = `ZeroWord;
                    // wcsr_reg_o      = `WriteDisable;
                end
                `INST_LUI   : begin     // lui
                    wreg_o          = `WriteEnable;
                    aluop_o         = `EXE_LUI;
                    alusel_o        = `EXE_RES_SHIFT;
                    imm_2           = {inst_i[31:12], 12'b0};
                    reg_wd_o        = rd;
                    instvalid       = `InstValid;

                end
                `INST_AUIPC : begin     // auipc
                    wreg_o          = `WriteEnable;
                    aluop_o         = `EXE_ADD;
                    alusel_o        = `EXE_RES_ARITH;
                    imm_1           = pc_i;
                    imm_2           = {inst_i[31:12], 12'b0};
                    reg_wd_o        = rd;
                    instvalid       = `InstValid;
  
                end

                `INST_B_TYPE: begin
                    case (funct3)
                        `INST_BEQ: begin        // beq
                            aluop_o         = `EXE_BEQ;
                            reg1_read_o     = `ReadEnable;
                            reg2_read_o     = `ReadEnable;
                            instvalid       = `InstValid;
                    
                        end
                        `INST_BNE: begin        // bne
                            aluop_o         = `EXE_BNE;
                            reg1_read_o     = `ReadEnable;
                            reg2_read_o     = `ReadEnable;
                            instvalid       = `InstValid;
                            
                        end
                        `INST_BLT: begin       // blt
                            aluop_o         = `EXE_BLT;
                            reg1_read_o     = `ReadEnable;
                            reg2_read_o     = `ReadEnable;
                            instvalid       = `InstValid;
                           
                        end
                        `INST_BGE: begin        // bge
                            aluop_o         = `EXE_BGE;
                            reg1_read_o     = `ReadEnable;
                            reg2_read_o     = `ReadEnable;
                            instvalid       = `InstValid;

                        end
                        `INST_BLTU: begin      // bltu
                            aluop_o         = `EXE_BLTU;
                            reg1_read_o     = `ReadEnable;
                            reg2_read_o     = `ReadEnable;
                            instvalid       = `InstValid;
 
                        end
                        `INST_BGEU: begin      // bgeu
                            aluop_o         = `EXE_BGEU;
                            reg1_read_o     = `ReadEnable;
                            reg2_read_o     = `ReadEnable;
                            instvalid       = `InstValid;

                        end
                        default: begin
                            
                            instvalid       = `InstValid;
                        end 
                    endcase
                end

                `INST_JAL:  begin       // jal
                    wreg_o          = `WriteEnable;
                    aluop_o         = `EXE_JAL;
                    alusel_o        = `EXE_RES_BRANCH;
                    reg_wd_o        = rd;
                    instvalid       = `InstValid;

                end

                `INST_JALR: begin      // jalr
                    wreg_o          = `WriteEnable;
                    aluop_o         = `EXE_JALR;
                    alusel_o        = `EXE_RES_BRANCH;
                    reg1_read_o     = `ReadEnable;
                    reg2_read_o     = `ReadDisable;
                    reg_wd_o        = rd;
                    instvalid       = `InstValid;

                end

                `INST_L_TYPE:   begin
                    case (funct3)
                        `INST_LB: begin         // lb
                            wreg_o          = `WriteEnable; 
                            aluop_o         = `EXE_LB;   
                            alusel_o        = `EXE_RES_LOAD; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadDisable;  
                            reg_wd_o        = rd; 
                            instvalid       = `InstValid;

                        end 
                        `INST_LH: begin        // lh
                            wreg_o          = `WriteEnable; 
                            aluop_o         = `EXE_LH;   
                            alusel_o        = `EXE_RES_LOAD; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadDisable;  
                            reg_wd_o        = rd; 
                            instvalid       = `InstValid;

                        end
                        `INST_LW: begin        // lw
                            wreg_o          = `WriteEnable; 
                            aluop_o         = `EXE_LW;   
                            alusel_o        = `EXE_RES_LOAD; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadDisable;  
                            reg_wd_o        = rd; 
                            instvalid       = `InstValid;

                        end
                        `INST_LBU: begin       // lbu
                            wreg_o          = `WriteEnable; 
                            aluop_o         = `EXE_LBU;   
                            alusel_o        = `EXE_RES_LOAD; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadDisable;  
                            reg_wd_o        = rd; 
                            instvalid       = `InstValid;

                        end
                        `INST_LHU: begin       // lhu
                            wreg_o          = `WriteEnable; 
                            aluop_o         = `EXE_LHU;   
                            alusel_o        = `EXE_RES_LOAD; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadDisable;  
                            reg_wd_o        = rd; 
                            instvalid       = `InstValid;
                           
                        end

                        default: begin
                            instvalid       = `InstInvalid;
                        end 
                    endcase
                end

                `INST_S_TYPE: begin
                    case (funct3)
                        `INST_SB: begin         // sb
                            wreg_o          = `WriteDisable; 
                            aluop_o         = `EXE_SB;   
                            alusel_o        = `EXE_RES_STORE; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadEnable;  
                            instvalid       = `InstValid;

                        end
                        `INST_SH: begin        // sh
                            wreg_o          = `WriteDisable; 
                            aluop_o         = `EXE_SH;   
                            alusel_o        = `EXE_RES_STORE; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadEnable;  
                            instvalid       = `InstValid;

                        end
                        `INST_SW: begin        // sw
                            wreg_o          = `WriteDisable; 
                            aluop_o         = `EXE_SW;   
                            alusel_o        = `EXE_RES_STORE; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadEnable;  
                            instvalid       = `InstValid;

                        end
                        default: begin
                            instvalid       =  `InstInvalid;
                        end
                    endcase
                end

                `INST_I_TYPE:   begin
                    case (funct3)
                        `INST_ADDI: begin       // addi
                            wreg_o          = `WriteEnable;                      
                            aluop_o         = `EXE_ADD;                           
                            alusel_o        = `EXE_RES_ARITH;                    
                            reg1_read_o     = `ReadEnable;                         
                            reg2_read_o     = `ReadDisable;                       
                            imm_2           = {{20{inst_i[31]}}, inst_i[31:20]}; 
                            reg_wd_o        = rd;                                  
                            instvalid       = `InstValid;  

                        end
                        `INST_SLTI: begin      // slti
                            wreg_o          = `WriteEnable;                      
                            aluop_o         = `EXE_SLT;                           
                            alusel_o        = `EXE_RES_COMPARE;                    
                            reg1_read_o     = `ReadEnable;                         
                            reg2_read_o     = `ReadDisable;                       
                            imm_2           = {{20{inst_i[31]}}, inst_i[31:20]}; 
                            reg_wd_o        = rd;                                  
                            instvalid       = `InstValid; 

                        end
                        `INST_SLTIU: begin     // sltiu
                            wreg_o          = `WriteEnable;                      
                            aluop_o         = `EXE_SLTU;                           
                            alusel_o        = `EXE_RES_COMPARE;                    
                            reg1_read_o     = `ReadEnable;                         
                            reg2_read_o     = `ReadDisable;                       
                            imm_2           = {{20{inst_i[31]}}, inst_i[31:20]}; 
                            reg_wd_o        = rd;                                  
                            instvalid       = `InstValid;

                        end
                        `INST_XORI: begin      // xori
                            wreg_o          = `WriteEnable;                      
                            aluop_o         = `EXE_XOR;                           
                            alusel_o        = `EXE_RES_LOGIC;                    
                            reg1_read_o     = `ReadEnable;                         
                            reg2_read_o     = `ReadDisable;                       
                            imm_2           = {{20{inst_i[31]}}, inst_i[31:20]}; 
                            reg_wd_o        = rd;                                  
                            instvalid       = `InstValid;

                        end
                        `INST_ORI:  begin      // ori                          // ���� opcode �� funct3 �ж� ori ָ��
                            wreg_o          = `WriteEnable;                        // ori ָ����Ҫ�����д��Ŀ�ļĴ���
                            aluop_o         = `EXE_OR;                             // �������������߼���������
                            alusel_o        = `EXE_RES_LOGIC;                      // �����������߼�����
                            reg1_read_o     = `ReadEnable;                         // ���˿� 1 ��ȡ�Ĵ���
                            reg2_read_o     = `ReadDisable;                        // ���ö�
                            imm_2           = {{20{inst_i[31]}}, inst_i[31:20]};   // ָ��ִ����Ҫ������,�з�����չ
                            reg_wd_o        = rd;                                  // Ŀ�ļĴ�����ַ
                            instvalid       = `InstValid;                          // ori ָ����Чָ��

                        end 
                        `INST_ANDI: begin      // andi
                            wreg_o          = `WriteEnable;                      
                            aluop_o         = `EXE_AND;                           
                            alusel_o        = `EXE_RES_LOGIC;                    
                            reg1_read_o     = `ReadEnable;                         
                            reg2_read_o     = `ReadDisable;                       
                            imm_2           = {{20{inst_i[31]}}, inst_i[31:20]}; 
                            reg_wd_o        = rd;                                  
                            instvalid       = `InstValid;

                        end
                        `INST_SLLI: begin      // slli
                            wreg_o          = `WriteEnable; 
                            aluop_o         = `EXE_SLL;   
                            alusel_o        = `EXE_RES_SHIFT; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadDisable;    
                            imm_2           = {27'b0, inst_i[24:20]}; 
                            reg_wd_o        = rd;                 
                            instvalid       = `InstValid;

                        end
                        `INST_SRI: begin       // srli , srai
                            wreg_o          = `WriteEnable;
                            if (inst_i[30] == 1'b0) begin
                                aluop_o     = `EXE_SRL; 
                            end else begin
                                aluop_o     = `EXE_SRA;
                            end                      
                            alusel_o        = `EXE_RES_SHIFT;                    
                            reg1_read_o     = `ReadEnable;                         
                            reg2_read_o     = `ReadDisable;                       
                            imm_2           = {27'b0, inst_i[24:20]}; 
                            reg_wd_o        = rd;                                  
                            instvalid       = `InstValid;

                        end
                        default:  begin
                            instvalid       = `InstInvalid;
                        end
                    endcase 
                end 
                
                `INST_R_TYPE: begin
                    if(inst_i[25] == 1'b0) begin
                        case (funct3)
                        `INST_ADD: begin        // add , sub
                            wreg_o          = `WriteEnable;
                            if (inst_i[30] == 1'b0) begin
                                aluop_o     = `EXE_ADD; 
                            end else begin
                                aluop_o     = `EXE_SUB;
                            end                      
                            alusel_o        = `EXE_RES_ARITH; 
                            reg1_read_o     = `ReadEnable; 
                            reg2_read_o     = `ReadEnable;
                            reg_wd_o        = rd; 
                            instvalid       = `InstValid;

                        end 
                        `INST_SLL: begin       // sll
                            wreg_o          = `WriteEnable; 
                            aluop_o         = `EXE_SLL;   
                            alusel_o        = `EXE_RES_SHIFT; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadEnable;
                            reg_wd_o        = rd;  
                            instvalid       = `InstValid;

                        end
                        `INST_SLT: begin       // slt
                            wreg_o          = `WriteEnable; 
                            aluop_o         = `EXE_SLT;   
                            alusel_o        = `EXE_RES_COMPARE; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadEnable;
                            reg_wd_o        = rd;                    
                            instvalid       = `InstValid;

                        end
                        `INST_SLTU: begin      // sltu
                            wreg_o          = `WriteEnable; 
                            aluop_o         = `EXE_SLTU;   
                            alusel_o        = `EXE_RES_COMPARE; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadEnable;
                            reg_wd_o        = rd;  
                            instvalid       = `InstValid;

                        end
                        `INST_XOR : begin      // xor
                            wreg_o          = `WriteEnable; 
                            aluop_o         = `EXE_XOR;   
                            alusel_o        = `EXE_RES_LOGIC; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadEnable;
                            reg_wd_o        = rd;  
                            instvalid       = `InstValid;

                        end
                        `INST_SRL : begin       // srl ,sra 
                            if (inst_i[30] == 1'b0) begin
                                aluop_o     = `EXE_SRL; 
                            end else begin
                                aluop_o     = `EXE_SRA;
                            end                      
                            wreg_o          = `WriteEnable;
                            alusel_o        = `EXE_RES_SHIFT; 
                            reg1_read_o     = `ReadEnable; 
                            reg2_read_o     = `ReadEnable;
                            reg_wd_o        = rd; 
                            instvalid       = `InstValid;

                        end
                        `INST_OR : begin        // or
                            wreg_o          = `WriteEnable; 
                            aluop_o         = `EXE_OR;   
                            alusel_o        = `EXE_RES_LOGIC; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadEnable;
                            reg_wd_o        = rd;  
                            instvalid       = `InstValid;

                        end
                        `INST_AND: begin        // and
                            wreg_o          = `WriteEnable; 
                            aluop_o         = `EXE_AND;   
                            alusel_o        = `EXE_RES_LOGIC; 
                            reg1_read_o     = `ReadEnable;  
                            reg2_read_o     = `ReadEnable;
                            reg_wd_o        = rd;  
                            instvalid       = `InstValid;

                        end
                        default: begin
                            instvalid       = `InstInvalid;
                        end
                        endcase
                    end
                    else if(inst_i[25] == 1'b1) begin
                        case (funct3)
                            `INST_MUL: begin
                                aluop_o         = `EXE_MUL; 
                                alusel_o        = `EXE_RES_ARITH;
                                wreg_o          = `WriteEnable;
                                reg_wd_o        =  rd; 
                                reg1_read_o     = `ReadEnable;  
                                reg2_read_o     = `ReadEnable;
                                instvalid       = `InstValid;

                            end
                            `INST_MULHU: begin
                                aluop_o         = `EXE_MULHU; 
                                alusel_o        = `EXE_RES_ARITH;
                                wreg_o          = `WriteEnable;
                                reg_wd_o        =  rd; 
                                reg1_read_o     = `ReadEnable;  
                                reg2_read_o     = `ReadEnable;
                                instvalid       = `InstValid;

                            end
                            `INST_MULH: begin
                                aluop_o         = `EXE_MULH; 
                                alusel_o        = `EXE_RES_ARITH;
                                wreg_o          = `WriteEnable;
                                reg_wd_o        =  rd; 
                                reg1_read_o     = `ReadEnable;  
                                reg2_read_o     = `ReadEnable;
                                instvalid       = `InstValid;

                            end
                            `INST_MULHSU: begin
                                aluop_o         = `EXE_MULHSU; 
                                alusel_o        = `EXE_RES_ARITH;
                                wreg_o          = `WriteEnable;
                                reg_wd_o        =  rd; 
                                reg1_read_o     = `ReadEnable;  
                                reg2_read_o     = `ReadEnable;
                                instvalid       = `InstValid;

                            end
                            `INST_DIV: begin
                                aluop_o         = `EXE_DIV; 
                                alusel_o        = `EXE_RES_ARITH;
                                wreg_o          = `WriteEnable;
                                reg_wd_o        =  rd; 
                                reg1_read_o     = `ReadEnable;  
                                reg2_read_o     = `ReadEnable;
                                instvalid       = `InstValid;

                            end
                            `INST_DIVU: begin
                                aluop_o         = `EXE_DIVU; 
                                alusel_o        = `EXE_RES_ARITH;
                                wreg_o          = `WriteEnable;
                                reg_wd_o        =  rd; 
                                reg1_read_o     = `ReadEnable;  
                                reg2_read_o     = `ReadEnable;
                                instvalid       = `InstValid;

                            end
                            `INST_REM: begin
                                aluop_o         = `EXE_REM; 
                                alusel_o        = `EXE_RES_ARITH;
                                wreg_o          = `WriteEnable;
                                reg_wd_o        =  rd; 
                                reg1_read_o     = `ReadEnable;  
                                reg2_read_o     = `ReadEnable;
                                instvalid       = `InstValid;

                            end
                            `INST_REMU: begin
                                aluop_o         = `EXE_REMU; 
                                alusel_o        = `EXE_RES_ARITH;
                                wreg_o          = `WriteEnable;
                                reg_wd_o        =  rd; 
                                reg1_read_o     = `ReadEnable;  
                                reg2_read_o     = `ReadEnable;
                                instvalid       = `InstValid;

                            end
                            default: begin
                                instvalid       = `InstInvalid;
                            end
                        endcase
                    end
                    else begin
                        instvalid       = `InstInvalid;
                    end
                    
                end
                `INST_F_TYPE: begin
                    wreg_o          = `WriteDisable;
                    reg_wd_o        = `NOPRegAddr;
                    reg1_addr_o     = `NOPRegAddr;
                    reg2_addr_o     = `NOPRegAddr;

                end
                
                `INST_CSR_TYPE: begin
                    case (funct3) 
                        `INST_CSRRW: begin
                            aluop_o         = `EXE_CSRRW;
                            alusel_o        = `EXE_RES_CSR;
                            wreg_o          = `WriteEnable;
                            reg_wd_o        = rd;
                            reg1_read_o     = `ReadEnable;
                            reg2_read_o     = `ReadDisable;
                            wcsr_reg_o      = `WriteEnable;
                            csr_reg_addr_o  = {20'h0, inst_i[31:20]};
                            wd_csr_reg_o    = {20'h0, inst_i[31:20]};
                            instvalid       = `InstValid;

                        end
                        `INST_CSRRS: begin
                            aluop_o         = `EXE_CSRRS;
                            alusel_o        = `EXE_RES_CSR;
                            wreg_o          = `WriteEnable;
                            reg_wd_o        = rd;
                            reg1_read_o     = `ReadEnable;
                            reg2_read_o     = `ReadDisable;
                            wcsr_reg_o      = `WriteEnable;
                            csr_reg_addr_o  = {20'h0, inst_i[31:20]};
                            wd_csr_reg_o    = {20'h0, inst_i[31:20]};
                            instvalid       = `InstValid;

                        end
                        `INST_CSRRC: begin
                            aluop_o         = `EXE_CSRRC;
                            alusel_o        = `EXE_RES_CSR;
                            wreg_o          = `WriteEnable;
                            reg_wd_o        = rd;
                            reg1_read_o     = `ReadEnable;
                            reg2_read_o     = `ReadDisable;
                            wcsr_reg_o      = `WriteEnable;
                            csr_reg_addr_o  = {20'h0, inst_i[31:20]};
                            wd_csr_reg_o    = {20'h0, inst_i[31:20]};
                            instvalid       = `InstValid;

                        end
                        `INST_CSRRWI: begin
                            aluop_o         = `EXE_CSRRW;
                            alusel_o        = `EXE_RES_CSR;
                            wreg_o          = `WriteEnable;
                            reg_wd_o        = rd;
                            reg1_read_o     = `ReadDisable;
                            reg2_read_o     = `ReadDisable;
                            wcsr_reg_o      = `WriteEnable;
                            csr_reg_addr_o  = {20'h0, inst_i[31:20]};
                            wd_csr_reg_o    = {20'h0, inst_i[31:20]};
                            imm_1           = {27'h0, inst_i[19:15]};
                            instvalid       = `InstValid;

                        end
                        `INST_CSRRSI: begin
                            aluop_o         = `EXE_CSRRS;
                            alusel_o        = `EXE_RES_CSR;
                            wreg_o          = `WriteEnable;
                            reg_wd_o        = rd;
                            reg1_read_o     = `ReadDisable;
                            reg2_read_o     = `ReadDisable;
                            wcsr_reg_o      = `WriteEnable;
                            csr_reg_addr_o  = {20'h0, inst_i[31:20]};
                            wd_csr_reg_o    = {20'h0, inst_i[31:20]};
                            imm_1           = {27'h0, inst_i[19:15]};
                            instvalid       = `InstValid;

                        end
                        `INST_CSRRCI: begin
                            aluop_o         = `EXE_CSRRC;
                            alusel_o        = `EXE_RES_CSR;
                            wreg_o          = `WriteEnable;
                            reg_wd_o        = rd;
                            reg1_read_o     = `ReadDisable;
                            reg2_read_o     = `ReadDisable;
                            wcsr_reg_o      = `WriteEnable;
                            csr_reg_addr_o  = {20'h0, inst_i[31:20]};
                            wd_csr_reg_o    = {20'h0, inst_i[31:20]};
                            imm_1           = {27'h0, inst_i[19:15]};
                            instvalid       = `InstValid;

                        end
                        default: begin
                            instvalid       = `InstInvalid;
                        end
                    endcase     // case csr funct3
                end

                default: begin
                    instvalid       = `InstInvalid;
                end
            endcase     // case op

        end     // if
    end // always


    // �� reg1_o ��ֵ�Ĺ������������������
    // 1. ��� Regfile ģ����˿� 1 Ҫ��ȡ�ļĴ�������ִ�н׶�Ҫд��Ŀ�ļĴ�������ôֱ�Ӱ�ִ�н׶εĽ�� ex_wdata_i ��Ϊ reg1_o ��ֵ
    // 2. ��� Regfile ģ����˿� 1 Ҫ��ȡ�ļĴ������Ƿô�׶�Ҫд��Ŀ�ļĴ�������ôֱ�Ӱѷô�׶εĽ�� mem_wdata_i ��Ϊ reg1_o ��ֵ

    // ȷ�������Դ������ 1
    always @ (*) begin
            
        if (rst == `RstEnable) begin
            reg1_o  = `ZeroWord;
            reg1_loadralate = `NoStop;
        end else if (pre_inst_is_load == 1'b1 && ex_wd_i == reg1_addr_o && reg1_read_o == 1'b1) begin
            reg1_loadralate = `Stop;  
            reg1_o  = `ZeroWord;        
        end else if ((reg1_read_o == 1'b1) && (reg1_addr_o == 5'b00000)) begin
            reg1_o  = `ZeroWord;
            reg1_loadralate = `NoStop;
        end else if ((reg1_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg1_addr_o)) begin
            reg1_o  = ex_wdata_i;
            reg1_loadralate = `NoStop;
        end else if ((reg1_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg1_addr_o)) begin
            reg1_o  = mem_wdata_i;
            reg1_loadralate = `NoStop;
        end else if (reg1_read_o == 1'b1) begin
            reg1_o  = reg1_data_i; 
            reg1_loadralate = `NoStop;        // regfile port 1 output data
        end else if (reg1_read_o == 1'b0) begin
            reg1_o  = imm_1;                 // ������
            reg1_loadralate = `NoStop;
        end else begin
            reg1_o  = `ZeroWord;
            reg1_loadralate = `NoStop; 
        end
        
    end

    // �� reg2_o ��ֵ�Ĺ������������������
    // 1. ��� Regfile ģ����˿� 2 Ҫ��ȡ�ļĴ�������ִ�н׶�Ҫд��Ŀ�ļĴ�������ôֱ�Ӱ�ִ�н׶εĽ�� ex_wdata_i ��Ϊ reg2_o ��ֵ
    // 2. ��� Regfile ģ����˿� 2 Ҫ��ȡ�ļĴ������Ƿô�׶�Ҫд��Ŀ�ļĴ�������ôֱ�Ӱѷô�׶εĽ�� mem_wdata_i ��Ϊ reg2_o ��ֵ

    // ȷ�������Դ������ 2
    always @ (*) begin
        
        if (rst == `RstEnable) begin
            reg2_o  = `ZeroWord;
            reg2_loadralate = `NoStop;
        end else if (pre_inst_is_load == 1'b1 && ex_wd_i == reg2_addr_o && reg2_read_o == 1'b1) begin
            reg2_loadralate = `Stop; 
            reg2_o  = `ZeroWord; 
        end else if ((reg2_read_o == 1'b1) && (reg2_addr_o == 5'b00000)) begin
            reg2_o  = `ZeroWord;
            reg2_loadralate = `NoStop;
        end else if ((reg2_read_o == 1'b1) && (ex_wreg_i == 1'b1) && (ex_wd_i == reg2_addr_o)) begin
            reg2_o  = ex_wdata_i;
            reg2_loadralate = `NoStop;
        end else if ((reg2_read_o == 1'b1) && (mem_wreg_i == 1'b1) && (mem_wd_i == reg2_addr_o)) begin
            reg2_o  = mem_wdata_i;
            reg2_loadralate = `NoStop;
        end else if (reg2_read_o == 1'b1) begin
            reg2_o  = reg2_data_i;
            reg2_loadralate = `NoStop;
        end else if (reg2_read_o == 1'b0) begin
            reg2_o  = imm_2;
            reg2_loadralate = `NoStop;
        end else begin
            reg2_o  = `ZeroWord;
            reg2_loadralate = `NoStop;
        end
    end


endmodule // id


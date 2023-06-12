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


module csr_reg(
    input   wire                clk,
    input   wire                rst,

    // write from ex
    input   wire                we_i,
    input   wire[`DataAddrBus]  waddr_i,
    input   wire[`RegBus]       wdata_i,
    // read from ex
    input   wire[`DataAddrBus]  raddr_i,

    //from interrupt
    input wire interrupt_we_i,
    input wire[`DataAddrBus]    interrupt_raddr_i,
    input wire[`DataAddrBus]    interrupt_waddr_i,
    input wire[`RegBus]         interrupt_data_i,

    // to interrupt
    output wire[`RegBus] interrupt_data_o,       // interruptģ����Ĵ�������
    output wire[`RegBus] interrupt_csr_mtvec,   // mtvec
    output wire[`RegBus] interrupt_csr_mepc,    // mepc
    output wire[`RegBus] interrupt_csr_mstatus, // mstatus

    output wire global_int_en_o,            // ȫ���ж�ʹ�ܱ�־

    // to ex
    output  wire[`RegBus]        rdata_o    // exģ����Ĵ�������
);

    // CSR - Machine
    reg[`RegBus]                csr_mstatus;   	//״̬�Ĵ���
    reg[`RegBus]                csr_misa;			//
    reg[`RegBus]                csr_mie;			//���Ʋ�ͬ�����жϵľֲ�ʹ��
    reg[`RegBus]                csr_mtvec;		//�����쳣�ĳ�����ڵ�ַ
    reg[`RegBus]                csr_mscratch;	//
    reg[`RegBus]                csr_mepc;			//�����쳣�ķ���ֵ
    reg[`RegBus]                csr_mcause;		//�����쳣��ԭ��
    reg[`RegBus]                csr_mtval;		//�����쳣����Ϣ
    reg[`RegBus]                csr_mip;			//��ͬ���͵��жϵĵȴ�״̬
    reg[`DoubleRegBus]          csr_mcycle;       // �������ڼ�������32λ
//    reg[`RegBus]                csr_mcycleh;	//�������ڼ�������32λ
    reg[`RegBus]                csr_mhartid;		//Ӳ���̱߳�ʶ

    // CSR - Supervisor
    reg [`RegBus]                  csr_sscratch;

    reg[`RegBus]                rdata;

    assign global_int_en_o = (csr_mstatus[3] == 1'b1)? 1'b1: 1'b0;   

    assign interrupt_csr_mtvec = csr_mtvec;
    assign interrupt_csr_mepc = csr_mepc;
    assign interrupt_csr_mstatus = csr_mstatus;

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            csr_mcycle  <= {`ZeroWord, `ZeroWord};
        end 
        else if (we_i == `WriteEnable) begin
            case (waddr_i[11:0])
                `CSR_MCYCLE: begin
                    csr_mcycle[31:0]<= wdata_i;
                end
                `CSR_MCYCLEH: begin
                    csr_mcycle[63:32]<= wdata_i;
                end 
                default: begin
                   csr_mcycle  <= csr_mcycle + 1'b1; 
                end
            endcase
            end else begin
                csr_mcycle  <= csr_mcycle + 1'b1;
            end
    end

    // write  regs
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            csr_mstatus     <= `ZeroWord;
            csr_misa        <= (`MISA_RV32 | `MISA_RVI);
            csr_mie         <= `ZeroWord;
            csr_mtvec       <= `ZeroWord;
            csr_mscratch    <= `ZeroWord;
            csr_mepc        <= `ZeroWord;
            csr_mcause      <= `ZeroWord;
            csr_mtval       <= `ZeroWord;
            csr_mip         <= `ZeroWord;
            csr_mhartid     <= `ZeroWord;
        end else begin
            if (we_i == `WriteEnable) begin
                case (waddr_i[11:0])
                    `CSR_MSTATUS: begin
                        csr_mstatus <= wdata_i ;//& `CSR_MSTATUS_MASK;
                    end
                    `CSR_MIE: begin
                        csr_mie <= wdata_i ;
                    end
                    `CSR_MTVEC: begin
                        csr_mtvec <= wdata_i ;//& `CSR_MTVEC_MASK;
                    end
                    `CSR_MSCRATCH: begin
                        csr_mscratch <= wdata_i ;//& `CSR_MSCRATCH_MASK;
                    end
                    `CSR_MEPC: begin
                        csr_mepc    <= wdata_i ;//& `CSR_MEPC_MASK;
                    end
                    `CSR_MCAUSE: begin
                        csr_mcause <= wdata_i ;//& `CSR_MCAUSE_MASK;
                    end
                    `CSR_MTVAL: begin
                        csr_mtval <= wdata_i ;//& `CSR_MTVAL_MASK;
                    end
                    `CSR_MIP: begin
                        csr_mip <= wdata_i;
                    end
                    `CSR_SSCRATCH: begin
                       csr_sscratch <= wdata_i ;//& `CSR_SSCRATCH_MASK;
                    end
                    default: begin
                        
                    end
                endcase
            end else if (interrupt_we_i == `WriteEnable) begin
                case (interrupt_waddr_i[11:0])
                    `CSR_MSTATUS: begin
                        csr_mstatus <= interrupt_data_i ;//& `CSR_MSTATUS_MASK;
                    end
                    `CSR_MEPC: begin
                        csr_mepc    <= interrupt_data_i ;//& `CSR_MEPC_MASK;
                    end
                    `CSR_MCAUSE: begin
                        csr_mcause <= interrupt_data_i ;//& `CSR_MCAUSE_MASK;
                    end
                    default: begin
                        
                    end
                endcase
            end
        end
    end

    


    // read regs
    always @ (*) begin
        if (rst == `RstEnable) begin
            rdata <= `ZeroWord;
        end else begin
            case (raddr_i[11:0])
                `CSR_MSTATUS: begin
                    rdata <= csr_mstatus ;//& `CSR_MSTATUS_MASK;
                end 
                `CSR_MSCRATCH: begin
                    rdata <= csr_mscratch ;//& `CSR_MSCRATCH_MASK;
                end
                `CSR_MEPC: begin
                    rdata <= csr_mepc ;//& `CSR_MEPC_MASK;
                end
                `CSR_MTVEC: begin
                    rdata <= csr_mtvec ;//& `CSR_MTVEC_MASK;
                end
                `CSR_MTVAL: begin
                    rdata <= csr_mtval ;//& `CSR_MTVAL_MASK;
                end
                `CSR_MCAUSE: begin
                    rdata <= csr_mcause ;//& `CSR_MCAUSE_MASK;
                end
                `CSR_MIP: begin
                    rdata <= csr_mip ;
                end
                `CSR_MIE: begin
                    rdata <= csr_mie;
                end
                `CSR_MCYCLE: begin
                    rdata <= csr_mcycle[31:0];
                end
                `CSR_MCYCLEH: begin
                    rdata <= csr_mcycle[63:32];
                end
                `CSR_MHARTID: begin
                    rdata <= csr_mhartid;
                end
                `CSR_SSCRATCH: begin
                    rdata <= csr_sscratch ;//& `CSR_SSCRATCH_MASK; 
                end
                default: begin
                    rdata <= `ZeroWord;
                end
            endcase
        end
    end
    assign rdata_o = ((raddr_i[11:0] == waddr_i[11:0]) && (we_i == `WriteEnable))?wdata_i:rdata;  //������أ����ļĴ�������д�ļĴ����򷵻�д��ֵ��
   

    assign interrupt_data_o = ((interrupt_raddr_i[11:0] == interrupt_waddr_i[11:0]) && (interrupt_we_i == `WriteEnable))?interrupt_data_i:'h0;


endmodule // csr_reg

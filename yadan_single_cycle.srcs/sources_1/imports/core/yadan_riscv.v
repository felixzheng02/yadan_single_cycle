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


module yadan_riscv(
        input   wire            clk
        ,input   wire            rst
);

    wire[`RegBus]   rom_data_i ;
    wire[`RegBus]   rom_addr_o ;
    wire            rom_ce_o   ;

    wire[`RegBus]   ram_data_i ;
    wire[`RegBus]   ram_addr_o ;
    wire[`RegBus]   ram_data_o ;
    wire            ram_we_o   ;
    wire[2:0]       ram_sel_o  ;
    wire            ram_ce_o   ;

    // ���� IF/ID ģ��������׶� ID ģ��ı���
    wire[`InstAddrBus]      pc_pc_o;
    wire[`InstAddrBus]      if_id_pc_o;
    wire[`InstBus]          if_id_inst_o;


    // ��������׶� ID ģ������� ID/EX ģ�������ı���
    wire[`InstAddrBus]      id_pc_o;
    wire[`InstBus]          id_inst_o;
    wire[`AluOpBus]         id_aluop_o;
    wire[`AluSelBus]        id_alusel_o;
    wire[`RegBus]           id_reg1_o;
    wire[`RegBus]           id_reg2_o;
    wire                    id_wreg_o;
    wire[`RegAddrBus]       id_wd_o;
    wire                    id_wcsr_reg_o;
    wire[`RegBus]           id_csr_reg_o;
    wire[`DataAddrBus]      id_wd_csr_reg_o;

    // ���� ID/EX ģ�������ִ�н׶� EX ģ����������
    wire[`InstAddrBus]      ex_pc_i;
    wire[`InstBus]          ex_inst_i;
    wire[`AluOpBus]         ex_aluop_i;
    wire[`AluSelBus]        ex_alusel_i;
    wire[`RegBus]           ex_reg1_i;
    wire[`RegBus]           ex_reg2_i;
    wire                    ex_wreg_i;
    wire[`RegAddrBus]       ex_wd_i;
    wire                    ex_wcsr_reg_i;
    wire[`RegBus]           ex_csr_reg_i;
    wire[`DataAddrBus]      ex_wd_csr_reg_i;

    // ����ִ�н׶� EX ģ�������� EX/MEM ģ����������
    wire                    ex_wreg_o;
    wire[`RegAddrBus]       ex_wd_o;
    wire[`RegBus]           ex_wdata_o;

    wire[`AluOpBus]         ex_mem_aluop_o;
    wire[`DataAddrBus]      ex_addr_o;
    wire[`RegBus]           ex_mem_reg2_o;

    //from mul_div
    wire[`DoubleRegBus] muldiv_result_i;
    wire                muldiv_done;

    // mul_div_32 Inputs      
    wire   [31 : 0]  dividend;        
    wire   [31 : 0]  divisor;        
    wire   mul0_div1;
    wire   x_signed0_unsigned1;
    wire   y_signed0_unsigned1;

    // mul_div_32 Outputs
    wire  enable_out;    

    // csr_reg
    wire[`RegBus]           csr_reg_data_o;
    wire[`RegBus]           csr_interrupt_data_o;

    wire[`RegBus]         csr_mtvec;    
    wire[`RegBus]         csr_mepc;     
    wire[`RegBus]         csr_mstatus; 
    
    // id to csr
    wire[`DataAddrBus]      id_csr_reg_addr_o;
    // ex to csr 
    wire                    ex_wcsr_reg_o;
    wire[`DataAddrBus]      ex_wd_csr_reg_o;
    wire[`RegBus]           ex_wcsr_data_o;

    // ���� EX/MEM ģ��������ô�׶� MEM ģ�������ı���
    wire                    mem_wreg_i;
    wire[`RegAddrBus]       mem_wd_i;
    wire[`RegBus]           mem_wdata_i;

    wire[`AluOpBus]         mem_aluop_i;
    wire[`DataAddrBus]      mem_mem_addr_i;
    wire[`RegBus]           mem_reg2_i;

    // ���ӷô�׶� MEM ģ�������� MEM/WB ģ����������
    wire                    mem_wreg_o;
    wire[`RegAddrBus]       mem_wd_o;
    wire[`RegBus]           mem_wdata_o;


    // ���� MEM/WB ģ���������д�׶��������
    wire                    wb_wreg_i;
    wire[`RegAddrBus]       wb_wd_i;
    wire[`RegBus]           wb_wdata_i;

    // ��������׶� ID ģ����ͨ�üĴ��� Regfile ģ��ı���
    wire                    id_reg1_read_o;
    wire                    id_reg2_read_o;
    wire[`RegAddrBus]       id_reg1_addr_o;
    wire[`RegAddrBus]       id_reg2_addr_o;
    wire[`RegBus]           reg1_data_o;
    wire[`RegBus]           reg2_data_o;
    
    // pc_reg ����
    pc_reg  u_pc_reg(
        .clk(clk),
        .rst(rst),
        .PCchange_enable(~ram_ce_o),
        .pc_o(pc_id_pc),
        .ce_o(rom_ce_o)
    );

    assign  rom_addr_o  =  pc_pc_o;  // ָ��洢���������ַ���� pc ��ֵ

    // ID ����
    id  u_id(
        .rst(rst),
        .pc_i(pc_pc_o),
        .inst_i(rom_data_i),
        
        // from regfile ģ�������
        .reg1_data_i(reg1_data_o),
        .reg2_data_i(reg2_data_o),

        // from ex
        .ex_wreg_i(ex_wreg_o),
        .ex_wdata_i(ex_wdata_o),
        .ex_wd_i(ex_wd_o),
//        .ex_branch_flag_i(ex_branch_flag_o),

        .ex_aluop_i(ex_aluop_o),

        // from wd mem
        .mem_wreg_i     (mem_wreg_o),
        .mem_wdata_i    (mem_wdata_o),
        .mem_wd_i       (mem_wd_o),

        // from csr_reg
        .csr_reg_data_i(csr_reg_data_o),
        .csr_reg_addr_o(id_csr_reg_addr_o),

        // ���� regfile ����Ϣ
        .reg1_read_o(id_reg1_read_o),
        .reg2_read_o(id_reg2_read_o),
        .reg1_addr_o(id_reg1_addr_o),
        .reg2_addr_o(id_reg2_addr_o),

//        .stallreq(stallreq_from_id),

        .pc_o(id_pc_o),
        .inst_o(id_inst_o),
        .aluop_o(id_aluop_o),
        .alusel_o(id_alusel_o),
        .reg1_o(id_reg1_o),
        .reg2_o(id_reg2_o),
        .reg_wd_o(id_wd_o),
        .wreg_o(id_wreg_o),

         // �͵� ID/EX ����Ϣ
        .wcsr_reg_o(id_wcsr_reg_o),
        .csr_reg_o(id_csr_reg_o),
        .wd_csr_reg_o(id_wd_csr_reg_o)
    );

    // ͨ�üĴ��� regfile ����
    regsfile u_regsfile
    (
        .clk(clk),
        .rst(rst),
        //.int_assert_i(interrupt_int_assert_o),
        .we_i(mem_wreg_o),
        .waddr_i(mem_wd_o),
        .wdata_i(mem_wdata_o),

        .re1_i(id_reg1_read_o),
        .raddr1_i(id_reg1_addr_o),
        .rdata1_o(reg1_data_o),

        .re2_i(id_reg2_read_o),
        .raddr2_i(id_reg2_addr_o),
        .rdata2_o(reg2_data_o)
    );

    // EX ģ������
    ex  u_ex(
        .rst(rst),

        // �� ID/EX ģ��������Ϣ
        .ex_pc(id_pc_o),
        .ex_inst(id_inst_o),
        .aluop_i(id_aluop_o),
        .alusel_i(id_alusel_o),
        .reg1_i(id_reg1_o),
        .reg2_i(id_reg2_o),
        .wd_i(id_wd_o),
        .wreg_i(id_wreg_o),
        .wcsr_reg_i(id_wcsr_reg_o),
        .csr_reg_i(id_csr_reg_o),
        .wd_csr_reg_i(id_wd_csr_reg_o),
        
        //from mul_div
        .muldiv_result_i(muldiv_result_i),
        .muldiv_done(muldiv_done),

        //to mul_div

//        .muldiv_start_o(enable_in),
        .muldiv_dividend_o(dividend),
        .muldiv_divisor_o(divisor),
        .mul_or_div(mul0_div1),
        .muldiv_reg1_signed0_unsigned1(x_signed0_unsigned1),
        .muldiv_reg2_signed0_unsigned1(y_signed0_unsigned1),

        // ����� ID/MEM ģ�����Ϣ
        .wd_o(ex_wd_o),
        .wreg_o(ex_wreg_o),
        .wdata_o(ex_wdata_o),

        .ex_aluop_o(ex_aluop_o),
        .ex_mem_addr_o(ex_addr_o),
        .ex_reg2_o(ex_reg2_o),

        // to csr reg
        .wcsr_reg_o(ex_wcsr_reg_o),
        .wd_csr_reg_o(ex_wd_csr_reg_o),
        .wcsr_data_o(ex_wcsr_data_o)
    );

    mul_div_32  u_mul_div_32 (
        .clk                     ( clk                   ),
        .reset_n                 ( rst                  ),
//        .enable_in               ( enable_in             ),
        .x                       ( dividend              ),
        .y                       ( divisor               ),
        .mul0_div1               ( mul0_div1             ),
        .x_signed0_unsigned1     ( x_signed0_unsigned1   ),
        .y_signed0_unsigned1     ( y_signed0_unsigned1   ),

        .enable_out              ( muldiv_done           ),
        .z                       ( muldiv_result_i       )
    );

    // MEM ����
    mem u_mem(
        .rst(rst),

        // ���� EX/MEM ģ�����Ϣ
        .wd_i(ex_wd_o),
        .wreg_i(ex_wreg_o),
        .wdata_i(ex_wdata_o),

        .mem_aluop_i(ex_aluop_o),
        .mem_mem_addr_i(ex_addr_o),
        .mem_reg2_i(ex_reg2_o),

        //.int_assert_i(interrupt_int_assert_o),
        // �͵� MEM/WB ����Ϣ
        .wd_o(mem_wd_o),
        .wreg_o(mem_wreg_o),
        .wdata_o(mem_wdata_o),

        // from ram
        .mem_data_i(ram_data_i),
        
        // to ram
        .mem_addr_o(ram_addr_o),
        .mem_we_o(ram_we_o),
        .mem_data_o(ram_data_o),
        .mem_sel_o(ram_sel_o),
        .mem_ce_o(ram_ce_o)
    );

    // csr_reg
    csr_reg     u_csr_reg(
        .clk(clk),
        .rst(rst),

        .we_i(ex_wcsr_reg_o),
        .waddr_i(ex_wd_csr_reg_o),
        .wdata_i(ex_wcsr_data_o),

        .raddr_i(id_csr_reg_addr_o),
        
        .rdata_o(csr_reg_data_o)
    );

endmodule // bitty_riscv

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

      , input  wire         jtag_we_i
      , input  wire  [4:0]  jtag_addr_i
      , input  wire  [31:0] jtag_wdata_i
      , output wire  [31:0] jtag_rdata_o
      , input  wire         jtag_reset_i   
);

    wire[`RegBus]           rom_id_instr ;
    wire[`InstAddrBus]      pc_id_pc;
    wire[`InstAddrBus]      id_rom_pc;
    wire[`RegBus]           reg_id_data_1;
    wire[`RegBus]           reg_id_data_2;
    wire                    ctrl_pc_branchflag;
    wire[`RegBus]           ctrl_pc_branchaddr;
    
    // pc_reg 例化
    pc_reg  u_pc_reg(
        .clk(clk),
        .rst(rst),
        .branch_flag_i(ctrl_pc_branchflag),
        .branch_addr_i(ctrl_pc_branchaddr),
        .pc_o(pc)
    );
    
    // id/csr
    wire[`DataAddrBus]      id_csr_addr;
    wire[`RegBus]           csr_id_data;
    // id/reg
    wire id_reg_read_1;
    wire id_reg_read_2;
    wire[`RegAddrBus]       id_reg_addr_1;
    wire[`RegAddrBus]       id_reg_addr_2;
    // id/ex
    wire[`InstAddrBus]      id_ex_pc;
    wire[`InstBus]          id_ex_inst;
    wire[`AluOpBus]         id_ex_aluop;
    wire[`AluSelBus]        id_ex_alusel;
    wire[`RegBus]           id_ex_regdata_1;
    wire[`RegBus]           id_ex_regdata_2;
    wire                    id_ex_regwrite;
    wire[`RegAddrBus]       id_ex_regwritedata;
    wire                    id_ex_csrwrite;
    wire[`RegBus]           id_ex_csrreg;
    wire[`DataAddrBus]      id_ex_csrwritedata;

    // ID 例化
    id  u_id(
        .rst(rst),
        .pc_i(pc_id_pc),
        .inst_i(rom_id_instr),
        
        // from regfile 模块的输入
        .reg1_data_i(reg_id_data_1),
        .reg2_data_i(reg_id_data_2),

        // from csr_reg
        .csr_reg_data_i(csr_id_data),
        .csr_reg_addr_o(id_csr_addr),

        // 送入 regfile 的信息
        .reg1_read_o(id_reg_read_1),
        .reg2_read_o(id_reg_read_2),
        .reg1_addr_o(id_reg_addr_1),
        .reg2_addr_o(id_reg_addr_2),
        
        // to execution
        .pc_o(id_ex_pc),
        .inst_o(id_ex_inst),
        .aluop_o(id_ex_aluop),
        .alusel_o(id_ex_alusel),
        .reg1_o(id_ex_regdata_1),
        .reg2_o(id_ex_regdata_2),
        .reg_wd_o(id_ex_regwritedata),
        .wreg_o(id_ex_regwrite),
        .wcsr_reg_o(id_ex_csrwrite),
        .csr_reg_o(id_ex_csrreg),
        .wd_csr_reg_o(id_ex_csrwritedata)
    );

    // mem/reg
    wire                    mem_reg_write;
    wire[`RegAddrBus]       mem_reg_addr;
    wire[`RegBus]           mem_reg_data;
    
    // 通用寄存器 regfile 例化
    regsfile u_regsfile
    (
        .clk(clk),
        .rst(rst),
        // from wb
        .we_i(mem_reg_write),
        .waddr_i(mem_reg_addr),
        .wdata_i(mem_reg_data),
        // from id
        .re1_i(id_reg_read_1),
        .raddr1_i(id_reg_addr_1),
        .rdata1_o(reg_id_data_1),
        .re2_i(id_reg_read_2),
        .raddr2_i(id_reg_addr_2),
        .rdata2_o(reg_id_data_2)
    );

    // mul_div to ex
    wire[`DoubleRegBus] md_ex_result;
    wire                md_ex_done;
    // ex to mul_div   
    wire   ex_md_enable;
    wire   [31 : 0]  ex_md_dividend;        
    wire   [31 : 0]  ex_md_divisor;        
    wire   ex_md_mul0_div_1;
    wire   ex_md_x_signed0_unsigned1;
    wire   ex_md_y_signed0_unsigned1;
    // ex/mem
    wire                    ex_mem_regwrite;
    wire[`RegAddrBus]       ex_mem_regwriteaddr;
    wire[`RegBus]           ex_mem_regwritedata;
    wire[`AluOpBus]         ex_mem_aluop;
    wire[`DataAddrBus]      ex_mem_dataaddr;
    wire[`RegBus]           ex_mem_reg2;
    // ex/csr
    wire                    ex_csr_write;
    wire[`DataAddrBus]      ex_csr_addr;
    wire[`RegBus]           ex_csr_data;
    // ex/ctrl
    wire                    ex_ctrl_branchflag;
    wire[`RegBus]           ex_ctrl_branchaddr;

    // EX 模块例化
    ex  u_ex(
        .rst(rst),
        // from id
        .ex_pc(id_ex_pc),
        .ex_inst(id_ex_inst),
        .aluop_i(id_ex_aluop),
        .alusel_i(id_ex_alusel),
        .reg1_i(id_ex_regdata_1),
        .reg2_i(id_ex_regdata_2),
        .wd_i(id_ex_regwritedata),
        .wreg_i(id_ex_regwrite),
        .wcsr_reg_i(id_ex_csrwrite),
        .csr_reg_i(id_ex_csrreg),
        .wd_csr_reg_i(id_ex_csrwritedata),
        //from mul_div
        .muldiv_result_i(md_ex_result),
        .muldiv_done(md_ex_done),
        //to mul_div
        .muldiv_start_o(ex_md_enable),
        .muldiv_dividend_o(ex_md_dividend),
        .muldiv_divisor_o(ex_md_divisor),
        .mul_or_div(ex_md_mul0_div1),
        .muldiv_reg1_signed0_unsigned1(ex_md_x_signed0_unsigned1),
        .muldiv_reg2_signed0_unsigned1(ex_md_y_signed0_unsigned1),
        // to mem
        .wd_o(ex_mem_regwriteaddr),
        .wreg_o(ex_mem_regwrite),
        .wdata_o(ex_mem_regwritedata),
        .ex_aluop_o(ex_mem_aluop),
        .ex_mem_addr_o(ex_mem_dataaddr),
        .ex_reg2_o(ex_mem_reg2),
        // to csr reg
        .wcsr_reg_o(ex_csr_write),
        .wd_csr_reg_o(ex_csr_addr),
        .wcsr_data_o(ex_csr_data),
        // to ctrl
        .branch_flag_o(ex_ctrl_branchflag),
        .branch_addr_o(ex_ctrl_branchaddr)
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
    
    // mem/ram
    wire[`RegBus]   ram_mem_data ;
    wire[`RegBus]   mem_ram_addr ;
    wire[`RegBus]   mem_ram_data ;
    wire            mem_ram_write   ;
    wire[2:0]       mem_ram_sel  ;
    
    // MEM 例化
    mem u_mem(
        .rst(rst),
        // from ex
        .wd_i(ex_mem_regwriteaddr),
        .wreg_i(ex_mem_regwrite),
        .wdata_i(ex_mem_regwritedata),
        .mem_aluop_i(ex_mem_aluop),
        .mem_mem_addr_i(ex_mem_dataaddr),
        .mem_reg2_i(ex_mem_reg2),

        // write back
        .wd_o(mem_reg_addr),
        .wreg_o(mem_reg_write),
        .wdata_o(mem_reg_data),

        // from ram
        .mem_data_i(ram_mem_data),
        
        // to ram
        .mem_addr_o(mem_ram_addr),
        .mem_we_o(mem_ram_write),
        .mem_data_o(mem_ram_data),
        .mem_sel_o(mem_ram_sel)
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
    
    ctrl u_ctrl(
        .rst(rst),
        .branch_flag_i(ex_ctrl_branchflag),
        .branch_addr_i(ex_ctrl_branchaddr),
        // ctrl to pc_reg
        .branch_flag_o(ctrl_pc_branchflag),
        .branch_addr_o(ctrl_pc_branchaddr)
    );
    
    rom instr_mem(
        .addr(id_rom_pc),
        .dout(rom_id_instr)
    );
    
    // needs modification
    ram data_mem(
        // from ram
        .mem_data_i(ram_mem_data),
        
        // to ram
        .mem_addr_o(mem_ram_addr),
        .mem_we_o(mem_ram_write),
        .mem_data_o(mem_ram_data),
        .mem_sel_o(mem_ram_sel)
    );


endmodule // bitty_riscv

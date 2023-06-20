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

    wire[`RegBus]   rom_id_instr ;
    wire[`InstAddrBus]      pc_id_pc;
    wire[`InstAddrBus]      id_rom_pc;
    wire[`RegBus]           reg_id_data_1;
    wire[`RegBus]           reg_id_data_2;
    
    // pc_reg 例化
    pc_reg  u_pc_reg(
        .clk(clk),
        .rst(rst),
        .branch_flag_i(ctrl_branch_flag_o),
        .branch_addr_i(ctrl_branch_addr_o),
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

    // 通用寄存器 regfile 例化
    regsfile u_regsfile
    (
        .clk(clk),
        .rst(rst),

        // from wb (needs modification)
        .we_i(mem_wreg_o),
        .waddr_i(mem_wd_o),
        .wdata_i(mem_wdata_o),
        
        // from id
        .re1_i(id_reg_read_1),
        .raddr1_i(id_reg_addr_1),
        .rdata1_o(reg_id_data_1),
        .re2_i(id_reg_read_2),
        .raddr2_i(id_reg_addr_2),
        .rdata2_o(reg_id_data_2)
    );

    // EX 模块例化
    ex  u_ex(
        .rst(rst),

        // 从 ID/EX 模块来的信息
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

        // 输出到 ID/MEM 模块的信息
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

    // MEM 例化
    mem u_mem(
        .rst(rst),

        // 来自 EX/MEM 模块的信息
        .wd_i(ex_wd_o),
        .wreg_i(ex_wreg_o),
        .wdata_i(ex_wdata_o),

        .mem_aluop_i(ex_aluop_o),
        .mem_mem_addr_i(ex_addr_o),
        .mem_reg2_i(ex_reg2_o),

        //.int_assert_i(interrupt_int_assert_o),
        // 送到 MEM/WB 的信息
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

    rom instr_mem(
        .addr(id_rom_pc),
        .dout(rom_id_instr)
    );
    
    // needs modification
    ram data_mem(
        .addr(pc),
        .dout(instr)
    );


endmodule // bitty_riscv

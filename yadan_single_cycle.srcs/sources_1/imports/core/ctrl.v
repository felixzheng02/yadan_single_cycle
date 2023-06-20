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


module ctrl(
    input   wire                rst,
    input   wire                branch_flag_i,
    input   wire[`InstAddrBus]  branch_addr_i,
    output  reg                 branch_flag_o,
    output  reg[`InstAddrBus]   branch_addr_o
);

    always @ (*) begin
        if (rst == `RstEnable) begin
            branch_flag_o   = `BranchDisable;
            branch_addr_o   = `ZeroWord;
        end else begin
            branch_flag_o   = branch_flag_i;
            branch_addr_o   = branch_addr_i;
        end
    end

endmodule // ctrl

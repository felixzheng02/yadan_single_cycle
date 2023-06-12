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


module mem_wb(
    input   wire            clk,
    input   wire            rst,

    // 访存阶段的结�?
    input   wire[`RegAddrBus]   mem_wd,
    input   wire                mem_wreg,
    input   wire[`RegBus]       mem_wdata,

    input   wire[5:0]           stalled,

    // 送到回写阶段的信�?
    output  reg[`RegAddrBus]    wb_wd,
    output  reg                 wb_wreg,
    output  reg[`RegBus]        wb_wdata
);

    always  @ (posedge clk) begin
        if (rst == `RstEnable) begin
            wb_wd       <= `NOPRegAddr;
            wb_wreg     <= `WriteDisable;
            wb_wdata    <= `ZeroWord;
        end 
        else if (stalled[4] == `Stop && stalled[5] == `NoStop) begin
            wb_wd       <= `NOPRegAddr;
            wb_wreg     <= `WriteDisable;
            wb_wdata    <= `ZeroWord;
        end
        else if (stalled[4] == `NoStop) begin
            wb_wd       <= mem_wd;
            wb_wreg     <= mem_wreg;
            wb_wdata    <= mem_wdata;
        end
    end

endmodule // mem_wb

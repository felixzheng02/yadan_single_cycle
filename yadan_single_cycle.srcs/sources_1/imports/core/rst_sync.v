`ifdef  SPYGLASS
`include "../../module/core/yadan_defs.v"
`else
`include "yadan_defs.v"
`endif


module rst_sync (
    input   wire                    clk,
    input   wire                    rst_i,

    output  wire                    rst_o
);

    reg   [1:0]  reg_rst_sync;

    always @(posedge clk or negedge rst_i) begin
        if (rst_i == `RstEnable)
            reg_rst_sync <= 2'b00;
        else
            reg_rst_sync <= {reg_rst_sync[0], 1'b1};
    end

    assign     rst_o = reg_rst_sync[1];
    
endmodule //rst_sync

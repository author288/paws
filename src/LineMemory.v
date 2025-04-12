// `timescale 1ns / 1ps
`include "src/wasm_defines.vh"
`include "src/sram_sp_16384x64.v"
`define SRAM_ADDR_WIDTH 15
module LineMemory(  
    input clk,
    input en,
    input we,
    input [7:0] EMA_EMAW,
    input [`SRAM_ADDR_WIDTH-1:0] addr,
    input [63:0] wdata,
    output [63:0] rdata

    // ,
    // output [63:0] rdata_0,
    // output [63:0] rdata_1
    
    );
    //2^14 * 4B = 2 * (2^13 * 4B)
    wire [63:0] rdata_0;
    wire [63:0] rdata_1;
    wire en_0;
    wire en_1;
    assign rdata = addr[`SRAM_ADDR_WIDTH-1] ? rdata_1 : rdata_0;
    assign en_0 = en&(~addr[`SRAM_ADDR_WIDTH-1]);
    assign en_1 = en&(addr[`SRAM_ADDR_WIDTH-1]);

    sram_sp_16384x64 u_sram_sp_16384x64_0 ( 
        .Q(rdata_0), 
        .CLK(clk), 
        .CEN(~en_0), 
        .GWEN(~we), 
        .A(addr[`SRAM_ADDR_WIDTH-2:0]),
        .D(wdata),
        .STOV(1'b0),
        .EMA(EMA_EMAW[6:4]),
        .EMAW(EMA_EMAW[1:0]),
        .EMAS(1'b0),
        .RET1N(1'b1)
        );   

    sram_sp_16384x64 u_sram_sp_16384x64_1 (
        .Q(rdata_1), 
        .CLK(clk), 
        .CEN(~en_1), 
        .GWEN(~we), 
        .A(addr[`SRAM_ADDR_WIDTH-2:0]), 
        .D(wdata),
        .STOV(1'b0),
        .EMA(EMA_EMAW[6:4]),
        .EMAW(EMA_EMAW[1:0]),
        .EMAS(1'b0),
        .RET1N(1'b1)
        );    

endmodule
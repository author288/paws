// `timescale 1ns / 1ps
`include "src/wasm_defines.vh"
`include "src/ALU_32bit.v"
module ALU(
input [`st_width-1:0] A,
input [`st_width-1:0] B,
input [`st_width-1:0] C,
input [4:0] ALUControl,
input length_mode, // 0: 32-bit, 1: 64-bit
output [`WIDTH-1:0] ALUResult
);
wire [31:0] A_32b = A[31:0];
wire [31:0] B_32b = B[31:0];
wire [31:0] C_32b = C[31:0];
wire [31:0] ALUResult_32b;
reg [63:0] ALUResult_64b;
assign ALUResult = (length_mode)? ALUResult_64b:{32'd0,ALUResult_32b};
ALU_32bit ALU_32bit(
    .A(A_32b),
    .B(B_32b),
    .C(C_32b),
    .ALUControl(ALUControl),
    .ALUResult(ALUResult_32b)
);
reg C_out;
reg [64:0] sum;
wire [63:0] eqz = {63'd0, (A==64'd0)};
wire [63:0] eq = {63'd0, (A==B)};
wire [63:0] ne = {63'd0, ~(A==B)};
wire [63:0] lt_u = {63'd0, (B<A)};
wire [63:0] gt_u = {63'd0, (B>A)};
wire [63:0] lt_s = {63'd0, ($signed(B)<$signed(A))};
wire [63:0] gt_s = {63'd0, ($signed(B)>$signed(A))};
always@* begin
{C_out,sum} = (ALUControl[0])? (B+(~A)+1'b1):(A+B);
case(ALUControl)
    5'b00000, 5'b0001: ALUResult_64b = sum;
    5'b00010: ALUResult_64b = A&B;
    5'b00011: ALUResult_64b = A|B;
    5'b00100: ALUResult_64b = eqz[0]? B:C;
    5'b00101: ALUResult_64b = eqz;
    5'b00110: ALUResult_64b = eq;
    5'b00111: ALUResult_64b = lt_u;//unsigned lt
    5'b01000: ALUResult_64b = gt_u;//unsigned gt
    5'b01001: ALUResult_64b = lt_u|eq;//unsigned le
    5'b01010: ALUResult_64b = gt_u|eq;//unsigned ge
    5'b01011: ALUResult_64b = lt_s;//signed lt
    5'b01100: ALUResult_64b = gt_s;//signed gt
    5'b01101: ALUResult_64b = lt_s|eq;//signed le
    5'b01110: ALUResult_64b = gt_s|eq;//signed ge
    5'b01111: ALUResult_64b = ne;
    // B shift left A bits 0x74
    5'b10000: ALUResult_64b = B << A;
    // signed B shift right A bits 0x75
    5'b10001: ALUResult_64b = $signed(B) >>> A;
    // unsigned B shift right A bits 0x76
    5'b10010: ALUResult_64b = B >> A;
    // i32 B rotate left A bits 0x77
    5'b10011: ALUResult_64b = B << A | B >>> (64 - A);
    // i32 B rotate right A bits 0x78
    5'b10100: ALUResult_64b = B >>> A | B << (64 - A);
    //i32.mul
    5'b10101: ALUResult_64b = A * B;
    //i32.div_s
    5'b10110: ALUResult_64b = $signed(B) / $signed(A);
    //i32.div_u
    5'b10111: ALUResult_64b = B / A;
    5'b11000: ALUResult_64b = A ^ B;
    5'b11001: ALUResult_64b = $signed(B) % $signed(A);
    5'b11010: ALUResult_64b = B % A;

    default: ALUResult_64b = 64'd0;
endcase
end

//assign ALUFlags[3] = ALUResult[31];
//assign ALUFlags[2] = ~(| ALUResult[31:0]);
//assign ALUFlags[1] = (~ALUControl[1]) & C_out;
//assign ALUFlags[0] = (~ALUControl[1])&(A[31]^sum[31])&(~(ALUControl[0]^A[31]^B[31]));

endmodule

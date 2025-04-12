module sram_sp_16384x64 (Q, CLK, CEN, GWEN, A, D, STOV, EMA, EMAW, EMAS, RET1N
// , WABL,WABLM
);



  output [63:0] Q; //read data
  input  CLK;
  input  CEN; //low enable
  input  GWEN; //low write enable
  input [13:0] A; //addr
  input [63:0] D; //write data

  // useless for github version
  input  STOV;
  input [2:0] EMA;
  input [1:0] EMAW;
  input  EMAS;
  input  RET1N;
  // input  WABL;
  // input [1:0] WABLM;  

//   wire read_en;
//   wire write_en;
  reg [63:0] read_data;
  wire [63:0] write_data;
  wire [63:0] global_pointer;
  reg [63:0] fake_sram [16384:0]; 
  assign global_pointer = fake_sram[16128];
  assign Q = read_data;
  assign write_data = D;
//   assign read_en = (~CEN) & GWEN;
//   assign write_en = (~CEN) & (~GWEN);

  always@(posedge CLK)begin
    if(~CEN)begin
        if(GWEN)begin //read enable
            read_data <= fake_sram[A];
        end else begin //write enable
            fake_sram[A] <= write_data;
        end
    end 
  end

integer i;
initial begin
    for(i=0;i<16384;i=i+1)begin
        fake_sram[i] = 64'h0000000000000000;
    end
end

endmodule
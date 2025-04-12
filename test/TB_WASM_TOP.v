`timescale 1ns / 1ps
`include "src/wasm_defines.vh"
`include "src/WASM_TOP.v"
// `include "src/WASM_TOP_pipeline1.v"
`include "src/i2c_master.v"
`define T 2
module TB_WASM_TOP;

    // clk & rst
    reg clk=1;
    always #(`T/2) clk = ~clk; // Generate clock signal    
    reg rst_n;
    initial begin
    rst_n = 0;
    # 3;
    rst_n = 1;
    end

    //outputs
    wire [2:0] o_ERROR;
    wire [1:0] o_work_state;
    reg [1:0] pipe1_work_state;
    reg [1:0] pipe2_work_state;
    wire o_instr_mem_wr_rdy;
    // wire o_line_mem_rd_vld;
    wire [31:0] o_line_mem_rd_data;
    // signed wire [31:0] output_line_mem = o_line_mem_rd_data;
    //inputs
    reg i_instr_mem_wr_vld;
    reg [14:0] i_instr_mem_wr_addr;
    reg [`instr_read_width-1:0] i_instr_mem_wr_data;
    reg i_instr_mem_write_finish;

    reg i_line_mem_rd_rdy;
    reg [8:0] i_line_mem_rd_addr;

    reg [`instr_bram_width-1:0] bram [0:22941];
    reg [31:0] cnt;
    wire [31:0] cnttt;
    reg [31:0] cnt_max;
    assign cnttt = cnt*11;
    reg i_debug_enable;

/*--------------------i2c signals----------------------*/
    reg i2cclk;
    wire sda, scl;
    wire	sda_m;
    wire	o_sda;
    reg err_flag;

    reg	[6:0]	dev_adr;
    reg	[7:0]	reg_adr;
    reg	[7:0]	wr_data;
    reg	[7:0]	rd_data;

    initial begin
    i2cclk = 0;
    err_flag = 0;
    wr_data = $random;
    forever #60 i2cclk <= !i2cclk;
    end

    initial begin
        i_debug_enable = 1'b0;
        dev_adr = 7'h6C;
        reg_adr = 8'h02;
        // # 1260 i_debug_enable = 1'b1;
        // repeat (17) begin
        //     i2cm.i2creg_read (dev_adr, reg_adr, rd_data);
        //     #100;
        //     $display ("Addr %0h, Data %0h",reg_adr,rd_data);
        //     reg_adr = reg_adr + 8'h01;
        // end
        //     reg_adr = 8'h30;
        //     i2cm.i2creg_read (dev_adr, reg_adr, rd_data);
        //     #100;
        //     $display ("Addr %0h, Data %0h",reg_adr,rd_data);
        //     reg_adr = 8'h31;
        //     i2cm.i2creg_read (dev_adr, reg_adr, rd_data);
        //     #100;
        //     $display ("Addr %0h, Data %0h",reg_adr,rd_data);
        // i_debug_enable = 1'b0;
    end

    pullup	( sda );		// Enternal Pull-high in SDA
    bufif0  ( sda, 1'b0, o_sda );	// Slave's SDA IO
    bufif0  ( sda, 1'b0, sda_m );	// Master's SDA IO

    i2c_master i2cm (
        .rstn	( rst_n ),
        .clk	( i2cclk ),
        .scl	( scl ),
        .sda	( sda_m ),
        .isda	( sda ),
        .cont	( 1'b0 )
        );
/*------------------------------------------------------*/   

    initial begin
        $display("Loading test data");
        // $readmemh("./test/hex_files/br_table_hex.txt", bram);
        // $readmemh("./test/hex_files/br_table_wat_hex.txt", bram);
        // $readmemh("./test/hex_files/mem_if_global_hex.txt", bram);
        // $readmemh("./test/hex_files/ifelse_nest2_hex.txt", bram);
        // $readmemh("./test/hex_files/factorial_hex.txt", bram);
        // $readmemh("./test/hex_files/sign_shift_hex.txt", bram);
        // $readmemh("./test/hex_files/sign_shift2_hex.txt", bram);
        // $readmemh("./test/hex_files/vmv3_hex.txt", bram);
        // $readmemh("./test/hex_files/vmv10_hex.txt", bram);
        // $readmemh("./test/hex_files/vmm10_s_hex.txt", bram);
        // $readmemh("./test/hex_files/vmm_20_hex.txt", bram);
        // $readmemh("./test/hex_files/vmm_30_hex.txt", bram);
        // $readmemh("./test/hex_files/vmm_40_hex.txt", bram);
        // $readmemh("./test/hex_files/vmm_100_hex.txt", bram);
        // $readmemh("./test/hex_files/vmm_10000_hex.txt", bram);
        // $readmemh("./factor/factor_152.hex", bram);
        // $readmemh("./factor/factor_inserted_stack_64_t64.hex", bram);
        // $readmemh("./factor/factor_inserted_stack_6_t32.hex", bram);
        // $readmemh("./factor/factor_inserted_stack_122_t128.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/3mm_inserted_stack_38_t32.hex", bram);
           $readmemh("./forhardware_exp/forhardware_exp/3mm_46_t64.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/atax_42_t64.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/2mm_43_t64.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/2mm_inserted_stack_36_t32.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/symm_44_t64.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/2mm_inserted_stack_36_t32.hex", bram);
        // $readmemh("./new_stack_file/gcd_max_82.hex", bram);
        // $readmemh("./new_stack_file/gcd_inserted_stack_23_t32.hex", bram);
        // $readmemh("./new_stack_file/gcd_inserted_stack_61_t64.hex", bram);
        // $readmemh("./new_stack_file/gcd_inserted_stack_61_t64.hex", bram);
        // $readmemh("./new_stack_file/fib_inserted_stack_37_t64.hex", bram);
        // $readmemh("./new_stack_file/fib_inserted_stack_9_t32.hex", bram);
        // $readmemh("./new_stack_file/fib_max_94.hex", bram);
        // $readmemh("./forhardware_exp/forhardware_exp/atax_inserted_stack_34_t32.hex", bram);
        // $readmemh("./test/wat_files/gemm.hex", bram);
        // $readmemh("./test/wat_files/covariance.hex", bram);
        // $readmemh("./test/hex_files/br_if_hex.txt", bram);
        $display("Test data loaded: %0h %0h %0h %0h", bram[0], bram[1], bram[2], bram[3]);
    end



    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            pipe1_work_state <= #2 'd0;
            pipe2_work_state <= #2 'd0;
        end else begin
            pipe1_work_state <= #2 o_work_state;
            pipe2_work_state <= #2 pipe1_work_state;
        end
    end

    always @ (posedge clk or negedge rst_n) begin
        if(~rst_n)begin
            i_instr_mem_write_finish <= #2 'd0;
            i_instr_mem_wr_data <= #2 'd0;
            i_instr_mem_wr_addr <= #2 'd0;
            i_instr_mem_wr_vld <= #2 'd1;
            i_line_mem_rd_rdy <= #2 'd0;
            i_line_mem_rd_addr <= #2 'd0;

            cnt <= #2 'd0;
            cnt_max <= #2 32'd3000;
        end
        else begin
            if(cnt == cnt_max)begin
                i_instr_mem_write_finish <= #2 'd1;
                i_instr_mem_wr_vld <= #2 'd0;
            end else begin
                if(i_instr_mem_wr_vld)begin
                    i_instr_mem_wr_data <= #2 {bram[cnttt+'d10],bram[cnttt+'d9],bram[cnttt+'d8], bram[cnttt+'d7], bram[cnttt+'d6], bram[cnttt+'d5], bram[cnttt+'d4], bram[cnttt+'d3], bram[cnttt+'d2], bram[cnttt+'d1], bram[cnttt]};
                    i_instr_mem_wr_addr <= #2 i_instr_mem_wr_addr + 'd1;
                    cnt <= #2 cnt + 'd1;
                end
            end
            // if (i_instr_mem_write_finish) i_instr_mem_write_finish <= #2 'd0;
            if(o_work_state == 2'b11) begin
                i_line_mem_rd_rdy <= #2 'd1;
            end
        end
    end




    //generate .vcd

        initial begin
            $dumpfile("wave111.vcd"); 
            $dumpvars(0);
        end
        // initial begin
        //     $fsdbDumpfile("TB_WASM_TOP.fsdb");
        //     $fsdbDumpvars(0, "+mda");   // mda = multiple dimension array
        // end
    
    // initial begin
        //     $dumpfile("wave.vcd"); 
        //     $dumpvars(0);
        // end
        // initial begin
        //     $fsdbDumpfile("TB_WASM_TOP.fsdb");
        //     $fsdbDumpvars(0, "+mda");   // mda = multiple dimension array
        // end
    `ifdef POST_LAYOUT_SIM
        initial $sdf_annotate("../../../APR/WASM_TOP/Results/Final/WASM_TOP.max.sdf", u_WASM_TOP, , , "MAXIMUM");
    `else
        `ifdef POST_SYN_SIM
            initial $sdf_annotate("../../../Syn/WASM_TOP/Results/Mapped/WASM_TOP.sdf", u_WASM_TOP, , , "MAXIMUM");
        `endif
    `endif

    wire[`st_log2_depth:0] o_stack_depth;
    wire [1:0] pre_read_state;
    // Instantiate the Unit Under Test (UUT)
    WASM_TOP u_WASM_TOP (
        .i_clk(clk), 
        .i_rst_n(rst_n), 
        .o_ERROR(o_ERROR), 
        .o_work_state(o_work_state), 
        .i_line_mem_rd_rdy(i_line_mem_rd_rdy),    //or you can call it request
        // o_line_mem_rd_vld,
        .i_line_mem_rd_addr(i_line_mem_rd_addr), 
        .o_line_mem_rd_data(o_line_mem_rd_data),
        .o_instr_mem_wr_rdy(o_instr_mem_wr_rdy), 
        .i_instr_mem_wr_vld(i_instr_mem_wr_vld),
        .i_instr_mem_wr_addr((i_instr_mem_wr_addr-1'b1)), 
        .i_instr_mem_wr_data(i_instr_mem_wr_data), 
        .i_instr_mem_wr_finish(i_instr_mem_write_finish),
        .i_scl(scl),
        .i_sda(sda),
        .o_sda(o_sda),
        .i_debug_ena(i_debug_enable),
        .operand_stack_top_pointer(o_stack_depth),
        .pre_read_state(pre_read_state)
        );

   
   // write the o_stack_depth into a xls file every clk
    integer fd;
    initial begin
        fd = $fopen("stack_depth.txt", "w");
        if (fd == 0) begin
            $display("Error opening file");
            $finish;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (rst_n&o_work_state == 2'b01&pre_read_state==2'b00) begin
            $fwrite(fd, "%0d\n", o_stack_depth);
        end
    end

    reg [31:0] clk_cnt;
    reg [31:0] read_line_cnt;

//    count clk from reset to instr_finish==1
    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            clk_cnt <= 0;
        end else begin
            clk_cnt <= clk_cnt + 1;
        end
    end



    always @(*) begin
        if (pipe1_work_state == 2'b11) begin
            $display("clk_cnt = %0d", clk_cnt);
            #5 i_line_mem_rd_addr = 9'h100;
            #2 $display("global[0] = %0d, %b", $signed(o_line_mem_rd_data), o_line_mem_rd_data);
                i_line_mem_rd_addr = 9'h101;
            #2 $display("global[1] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h102;     
            #2 $display("global[2] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h103;     
            #2 $display("global[3] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h104;     
            #2 $display("global[4] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h105;     
            #2 $display("global[5] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h106;     
            #2 $display("global[6] = %0d", $signed(o_line_mem_rd_data));
                i_line_mem_rd_addr = 9'h107;     
            #2 $display("global[7] = %0d", $signed(o_line_mem_rd_data));   
                i_line_mem_rd_addr = 9'h108;     
            #2 $display("global[8] = %0d", $signed(o_line_mem_rd_data));   
                i_line_mem_rd_addr = 9'h109;     
            #2 $display("global[9] = %0d", $signed(o_line_mem_rd_data));        
                i_line_mem_rd_addr = 9'h000;     
            #2 $display("out_mem[0] = %0d, %b", $signed(o_line_mem_rd_data), o_line_mem_rd_data);      
                i_line_mem_rd_addr = 9'h001;     
            #2 $display("out_mem[1] = %0d, %b", $signed(o_line_mem_rd_data), o_line_mem_rd_data);         
                i_line_mem_rd_addr = 9'h002;     
            #2 $display("out_mem[2] = %0d, %b", $signed(o_line_mem_rd_data), o_line_mem_rd_data);  
                i_line_mem_rd_addr = 9'h003;     
            #2 $display("out_mem[3] = %0d", $signed(o_line_mem_rd_data));      
                i_line_mem_rd_addr = 9'h004;     
            #2 $display("out_mem[4] = %0d", $signed(o_line_mem_rd_data));        
                i_line_mem_rd_addr = 9'h005;     
            #2 $display("out_mem[5] = %0d", $signed(o_line_mem_rd_data));    
                i_line_mem_rd_addr = 9'h006;     
            #2 $display("out_mem[6] = %0d", $signed(o_line_mem_rd_data));     
                i_line_mem_rd_addr = 9'h007;     
            #2 $display("out_mem[7] = %0d", $signed(o_line_mem_rd_data));   
                i_line_mem_rd_addr = 9'h008;     
            #2 $display("out_mem[8] = %0d", $signed(o_line_mem_rd_data));         
                i_line_mem_rd_addr = 9'h009;     
            #2 $display("out_mem[9] = %0d", $signed(o_line_mem_rd_data));        
                i_line_mem_rd_addr = 9'h00a;     
            #2 $display("out_mem[a] = %0d", $signed(o_line_mem_rd_data));       
            #10 $finish;
        end
    end        
    initial begin 
    #1000000000
    $display("Time expired, 1000000000");
        $finish;
    end
            
endmodule



// #20 $display("memory read out = %d", o_line_mem_rd_data);
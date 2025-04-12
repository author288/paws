// `timescale 1ns / 1ps
`include "src/wasm_defines.vh"
`include "src/LEB128_uint_decode_64bit.v"

module CtrlUnit(
        input clk,
        input rst_n,
        input cu_working,
        //connect instr_mem_ctrl
        input [(`instr_log2_bram_depth-1):0] read_pointer,
        input [`instr_read_width-1:0] Instr,
        // input Instr_vld,
        output reg [7:0] read_pointer_shift_minusone,
        output reg INSTR_ERROR,
        output jump_en_out,
        output reg [(`instr_log2_bram_depth-1):0] jump_addr,
        
        //to stack
        output push_num_out, //0 or 1
        output [3:0] pop_num_out, //0~15
        //push_select: 0~from ALU; 1~from memory; 2~from instr;
        output reg [1:0] push_select,
         
        //to ALU     
        output reg [4:0] ALUControl,
        input ALUResult_0,
        output reg length_mode,
        
        //to Memory
        output store_en,
        output load_en,

        //to global memory
        output global_set,
        output global_get,
        output global_init,
        output [31:0] vector_cnt,
        
        //to local memory
        output local_set,
        output local_get,
        
        //instants
        output [`WIDTH-1:0] constant,
        output reg instr_finish,

        //mvm
        output mvm_start,

        //to call stack (control stack)
        input [`instr_log2_bram_depth-1:0] return_addr_tag,
        input control_stack_left_one,
        output function_call,
        output block_instr,
        output loop_instr,
        output if_instr,
        output br_table_instr,
        output end_instr,
        output return_instr,
        output operand_stack_tag_pop,
        input read_retu_num,
        input read_control_endjump,
        output function_retu_num,  //0 or 1
        output [(`log_pa_re_num_max-1):0] function_para_num,
        output [7:0] allocate_local_memory_size,
        output [3:0] LEB128_byte_cnt,
        output [(`instr_log2_bram_depth-1):0] pre_calu_return_addr,
        input [(`instr_bram_width-1):0] br_table_depth,
        output break_depth_is_zero,
        input [`instr_log2_bram_depth-1:0] function_addr_tag

        
        //debug signal
        , output [1:0] instr_pointer_state_out
        , output reg block_hold
        , output [7:0] section_type_out
        ,output [1:0] pre_read_state
    );

    reg push_num;
    reg [3:0] pop_num;
    reg jump_en;

    // reg un_hlt;
    // reg jump_hlt;
    // assign hlt = jump_hlt;
    //section head
    reg [7:0] section_type;
    assign section_type_out = section_type;
    reg [31:0] section_length;//(bytes)
    wire code_content_running;
    wire LEB128_signed_decode;
    wire unreachable_instr;

    reg [1:0] instr_pointer_state;
    assign instr_pointer_state_out = instr_pointer_state;
    parameter   module_head = 2'b00,
                section_head = 2'b01,
                vector_head = 2'b10,
                vector_content = 2'b11;
    //variables
    reg [`bram_in_width-1:0]global_variables[`bram_depth_in-1:0];
    reg [`instr_bram_width-1:0] global_var_type [`bram_depth_in-1:0];

    //byte count decode
    wire [72:0] LEB128_in;
    wire [`WIDTH-1:0] LEB128_decode;
    // wire [2:0] LEB128_byte_cnt;
    
    //vector head
    reg [31:0] vector_num;
    
    //code section vector content
    reg [31:0] vector_cnt;

    // type section decode
    reg type_decode; //0~decode parameter; 1~decode return

    //break control         
    reg [31:0] break_depth;
    // reg block_hold;
    wire break_depth_is_zero;
    wire block_vaild;   //when block vaild==0, operand stack and memory stop, no jump.
    wire br_if_true;
    wire block_hold_up;
    wire block_hold_down;

    // function
    wire function_content_start;
    reg [1:0] code_pre_read_state;
    assign pre_read_state = code_pre_read_state;
    reg [7:0] local_memory_sizes_list [(`func_num_max-1):0]; //local memory size list
    reg [(`log_pa_re_num_max-1):0] para_num_reg [(`func_num_max-1):0];   //parameter number of the function
    reg [(`func_num_max-1):0] retu_num_reg;   //return number of the function, 0 or 1.
    reg [(`log_func_num_max-1):0] function_num_reg ;     //function number
    wire [7:0] type_list_addr;
    wire [(`log_func_num_max-1):0] function_num_left;
    reg [7:0] function_type_list [127:0]; //function type list
    reg [(`instr_log2_bram_depth-1):0] function_addr_list [(`func_num_max-1):0]; //这个list可能不够大
    reg [(`log_func_num_max-1):0] start_function_idx;
    // wire [`instr_log2_bram_depth-1:0] pre_calu_return_addr;
    wire function_num_flag;
    reg [5:0] local_decl_num;
    reg [5:0] local_decl_count;
    reg [3:0] function_store_addr;

    //function
    assign type_list_addr = function_type_list[Instr[15:8]];
    assign allocate_local_memory_size =  function_content_start?  local_memory_sizes_list[start_function_idx] : local_memory_sizes_list[Instr[15:8]];
    assign pre_calu_return_addr = function_content_start? 'd0 : read_pointer+LEB128_byte_cnt+1'd1;
    assign function_content_start = (instr_pointer_state == vector_content)&(section_type==8'h0a)&(code_pre_read_state==2'b11)&(local_decl_count==local_decl_num)&(vector_cnt==(vector_num-1));
    assign LEB128_in = (load_en|store_en)?{1'd0, Instr[87:16]}:(((instr_pointer_state==vector_head)|(|code_pre_read_state))? Instr[72:0]:Instr[80:8]);
    //f32 and f64 const is direct
    assign constant = (code_content_running&(Instr[7:0]==8'h43|Instr[7:0]==8'h44))? Instr[(7+`WIDTH):8]:LEB128_decode;
    assign function_num_left = function_num_reg - `read_window_size*function_store_addr;
    assign function_num_flag = (function_num_left < `read_window_size);
    
    
    //to control stack
    assign function_call = (code_content_running&(Instr[7:0]==8'h10)&block_vaild)|function_content_start;
    assign end_instr = code_content_running&(Instr[7:0]==8'h0b);
    assign return_instr = code_content_running&(Instr[7:0]==8'h0f)&block_vaild;
    assign block_instr = code_content_running&(Instr[7:0]==8'h02);
    assign loop_instr = code_content_running&(Instr[7:0]==8'h03);
    assign if_instr = code_content_running&(Instr[7:0]==8'h04);
    wire else_instr = code_content_running&(Instr[7:0]==8'h05);
    assign function_retu_num = function_content_start? 'b0:retu_num_reg[type_list_addr];
    assign function_para_num = function_content_start? 'b0:para_num_reg[type_list_addr];
    wire control_stack_push = function_call|block_instr|loop_instr|if_instr;


    //break control
    assign break_depth_is_zero = break_depth==32'd0;
    assign br_if_true = (Instr[7:0]==8'h0d)&(~ALUResult_0);
    assign br_table_instr = code_content_running&block_vaild&(Instr[7:0]==8'h0e);
    assign block_hold_up = code_content_running&block_vaild&((Instr[7:0]==8'h0c)|(Instr[7:0]==8'h0e)|br_if_true);
    assign block_hold_down = end_instr&break_depth_is_zero;
    assign push_num_out = push_num & block_vaild;
    assign pop_num_out = block_vaild? pop_num : 4'd0;
    assign jump_en_out = jump_en & block_vaild;
    assign operand_stack_tag_pop = block_vaild&(end_instr|return_instr);
    assign code_content_running = (section_type==8'h0a)&(instr_pointer_state==vector_content)&(~(|code_pre_read_state));

    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            break_depth <= 32'd0;
            block_hold <= 1'b0;
        end
        else if(cu_working) begin
            if(block_hold_up)begin
                break_depth <= (br_table_instr)?br_table_depth:LEB128_decode;
                block_hold <= 1'b1;
            end else if(block_hold_down)begin
                block_hold <= 1'b0;
            end else if(end_instr)begin
                break_depth <= break_depth - 1'd1;
            end else if (block_hold&(block_instr|loop_instr|if_instr))begin
                break_depth <= break_depth + 1'd1;
            end
        end
    end

    //if else control
    reg if_hold;
    reg [31:0] if_hold_depth;
    wire if_hold_depth_is_zero = if_hold_depth==32'd0;
    wire if_unhold = (~if_hold)|(if_hold&if_hold_depth_is_zero&end_instr);
    assign block_vaild = (block_hold_down|(~block_hold))&if_unhold;    
    always@(posedge clk or negedge rst_n)begin
        if(~rst_n)begin
            if_hold <= 1'b0;
            if_hold_depth <= 8'd0;
        end
        else if(cu_working) begin
            if(if_hold)begin
                if(control_stack_push)begin
                    if_hold_depth <= if_hold_depth + 1'd1;
                end else if(if_hold_depth_is_zero)begin
                    if(end_instr|else_instr)begin
                        if_hold <= 1'b0;
                    end
                end else if(end_instr)begin
                    if_hold_depth <= if_hold_depth - 1'd1;
                end
            end else begin
                if(else_instr|(if_instr&ALUResult_0))begin
                    if_hold <= 1'b1;
                end
            end
        end
    end

    //global
    assign global_set = ((Instr[7:0]==8'h24)&code_content_running&block_vaild);  
    assign global_init = ((section_type==8'h06)&(instr_pointer_state==vector_content));
    assign global_get = (Instr[7:0]==8'h23)&code_content_running&block_vaild;    
    // assign global_cnt = vector_cnt;

    //memory
    assign load_en = (Instr[7:0]==8'h28|Instr[7:0]==8'h29|Instr[7:0]==8'h2a|Instr[7:0]==8'h2b|Instr[7:0]==8'h2c|Instr[7:0]==8'h2d|Instr[7:0]==8'h2e|
                     Instr[7:0]==8'h2f|Instr[7:0]== 8'h30|Instr[7:0]==8'h31|Instr[7:0]==8'h32|Instr[7:0]==8'h33|Instr[7:0]==8'h34|Instr[7:0]==8'h35
    )&code_content_running&block_vaild;
    assign store_en = (Instr[7:0]==8'h36|Instr[7:0]==8'h37|Instr[7:0]==8'h38|Instr[7:0]==8'h39
    |Instr[7:0]==8'h3a|Instr[7:0]==8'h3b|Instr[7:0]==8'h3c|Instr[7:0]==8'h3d|Instr[7:0]==8'h3e)&code_content_running&block_vaild;

    //local
    assign local_set = ((Instr[7:0]==8'h21)|(Instr[7:0]==8'h22))&code_content_running&block_vaild;
    assign local_get = (Instr[7:0]==8'h20)&code_content_running&block_vaild;

    //else
    assign unreachable_instr = ((Instr[7:0]==8'h00)&code_content_running&block_vaild);

    //mvm
    assign mvm_start = (Instr[7:0]==8'hD1)&code_content_running&block_vaild;

    /*four states of code section: 
     01 ~ read length; 
     10 ~ read local decl count; 
     11 ~ read local type count;
     00 ~ normal-read;
     */

    assign LEB128_signed_decode = (code_content_running&(~(load_en|store_en|global_get|global_set)))|global_init;
    LEB128_uint_decode u_decode(
            .LEB128_in(LEB128_in),
            .uint_out(LEB128_decode),
            .byte_cnt(LEB128_byte_cnt),
            .LEB128_signed_decode(LEB128_signed_decode)
    );

    //read_pointer_shift logic          
    always@(*) begin
        case (instr_pointer_state)
            module_head: begin
                    read_pointer_shift_minusone = 8'd7;
                    pop_num = 4'd0;
                    push_num = 1'b0;
                    push_select = 2'b00;
                    ALUControl = 5'b00000;     
                    length_mode = 1'b0;                  
                    end
            section_head: begin
                    read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};
                    pop_num = 4'd0;
                    push_num = 1'b0; 
                    push_select = 2'b00;
                    ALUControl = 5'b00000;   
                    length_mode = 1'b0;                                       
            end
            vector_head: begin
                case (section_type)
                    8'h0a, 8'h01, 8'h03:begin
                    // 8'h0a, 8'h01:begin
                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt} - 'd1;
                        pop_num = 4'd0;
                        push_num = 1'b0;
                        push_select = 2'b00;
                        ALUControl = 5'b00000;   
                        length_mode = 1'b0;                          
                    end    
                    8'h06:begin
                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt} + 'd1;
                        pop_num = 4'd0;
                        push_num = 1'b0;
                        push_select = 2'b00;
                        ALUControl = 5'b00000;  
                        length_mode = 1'b0;                               
                    end               
                    default:begin
                        read_pointer_shift_minusone = {section_length - 32'd1};
                        //Warning-WIDTHTRUNC: Operator ASSIGN expects 4 bits on the Assign RHS, but Assign RHS's SUB generates 32 bits.
                        pop_num = 4'd0;
                        push_num = 1'b0;
                        push_select = 2'b00;                        
                        ALUControl = 5'b00000;   
                        length_mode = 1'b0;                         
                    end
                endcase
            end
            vector_content: begin
                    case (section_type)
                        8'h01:begin
                            if(type_decode) begin
                                // read_pointer_shift_minusone = Instr[(`log_read_window_size-1):0] + 'd0;
                                read_pointer_shift_minusone = Instr[7:0] + 'd0;
                                pop_num = 4'd0;
                                push_num = 1'b0;
                                push_select = 2'b00;                            
                                ALUControl = 5'b00000;  
                                length_mode = 1'b0;                              
                            end
                            else begin
                                // read_pointer_shift_minusone = Instr[(`log_read_window_size+7):8]+ 'd1;
                                read_pointer_shift_minusone = Instr[15:8]+ 'd1;
                                pop_num = 4'd0;
                                push_num = 1'b0;
                                push_select = 2'b00;                            
                                ALUControl = 5'b00000;  
                                length_mode = 1'b0;                              
                            end                        
                        end
                        8'h03:begin
                            read_pointer_shift_minusone = (function_num_flag? function_num_left: `read_window_size) - 1'd1;
                            pop_num = 4'd0;
                            push_num = 1'b0;
                            push_select = 2'b00;                            
                            ALUControl = 5'b00000;   
                            length_mode = 1'b0;                             
                        end  
                        8'h06:begin
                            if(vector_cnt==(vector_num-1'd1))begin
                                read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt} + 'd1;
                                pop_num = 4'd0;
                                push_num = 1'b0;
                                push_select = 2'b00;                            
                                ALUControl = 5'b00000;
                                length_mode = 1'b0;    
                            end else begin
                                read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt} + 'd3;
                                pop_num = 4'd0;
                                push_num = 1'b0;
                                push_select = 2'b00;                            
                                ALUControl = 5'b00000;
                                length_mode = 1'b0;    
                            end
                        end                   
                        8'h0a:begin //Code section
                            if(code_pre_read_state==2'b01)begin
                                read_pointer_shift_minusone = LEB128_byte_cnt - 'd1;
                                pop_num = 4'd0;
                                push_num = 1'b0;
                                push_select = 2'b00;
                                ALUControl = 5'b00000;   
                                length_mode = 1'b0;   
                            end else if(code_pre_read_state==2'b10)begin
                                read_pointer_shift_minusone = LEB128_byte_cnt - 'd1;
                                pop_num = 4'd0;
                                push_num = 1'b0;
                                push_select = 2'b00;
                                ALUControl = 5'b00000;   
                                length_mode = 1'b0;   
                            end else if(code_pre_read_state==2'b11)begin
                                // read_pointer_shift_minusone = LEB128_byte_cnt + LEB128_decode - 'd1;
                                read_pointer_shift_minusone = LEB128_byte_cnt;
                                pop_num = 4'd0;
                                push_num = 1'b0;
                                push_select = 2'b00;
                                ALUControl = 5'b00000;    
                                length_mode = 1'b0;                                                                                                                               
                            end else begin
                                case (Instr[7:0]) 
                                    8'h01, 8'ha7, 8'hac:begin //nop, wrap
                                        read_pointer_shift_minusone = `log_read_window_size'd0;
                                        pop_num = 4'd0;
                                        ALUControl = 5'b00000;                                     
                                        push_num = 1'b0;
                                        push_select = 2'b00;       
                                        length_mode = 1'b0;                                
                                    end
                                    8'h02, 8'h03:begin //block, loop
                                        // $display("here in loop");
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00;                                      
                                        ALUControl = 5'b00000;                                    
                                        read_pointer_shift_minusone = `log_read_window_size'd1;
                                        length_mode = 1'b0;   
                                    end
                                    8'h04:begin //if
                                        pop_num = 4'd1;
                                        push_num = 1'b0;
                                        push_select = 2'b00;                                      
                                        ALUControl = 5'b00101;     //eqz                               
                                        read_pointer_shift_minusone = `log_read_window_size'd1;
                                        length_mode = 1'b0;   
                                    end                                    
                                    8'h0b:begin //end, temp for function end
                                        pop_num = 4'd0;
                                        push_num = read_retu_num;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00000;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0; 
                                        length_mode = 1'b0;                                          
                                    end    
                                    8'h0c:begin //br
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00;                                   
                                        ALUControl = 5'b00000;                                   
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};
                                        length_mode = 1'b0;   
                                    end        
                                    8'h0d:begin //br_if
                                        pop_num = 4'd1;
                                        push_num = 1'b0;
                                        push_select = 2'b00;                                      
                                        ALUControl = 5'b00101;      //eqz                                
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};
                                        length_mode = 1'b0;   
                                    end                   
                                    8'h0e:begin //br_table
                                        pop_num = 4'd1;
                                        push_num = 1'b0;
                                        push_select = 2'b00;                                      
                                        ALUControl = 5'b00000;                                   
                                        read_pointer_shift_minusone = (LEB128_byte_cnt + LEB128_decode + 'd1);
                                        length_mode = 1'b0;   
                                    end
                                    8'h0f:begin //return
                                        pop_num = 4'd0;
                                        push_num = read_retu_num;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00000;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;               
                                        length_mode = 1'b0;                            
                                    end
                                    8'h10:begin //call
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00000;                                      
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};
                                        length_mode = 1'b0;   
                                        // $display("call, addr=%h, pop_num=%d", read_pointer, pop_num);
                                    end
                                    8'h1a:begin //drop
                                        pop_num = 4'd1;
                                        push_num = 1'b0;
                                        push_select = 2'b00;                                      
                                        ALUControl = 5'b00000;                                    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;
                                        length_mode = 1'b0;   
                                    end
                                    8'h1b:begin //select
                                        pop_num = 4'd3;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00100;
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b1;                              
                                    end
                                    8'h20:begin //local.get
                                        pop_num = 4'd0;
                                        push_num = 1'b1;
                                        push_select = 2'b11; //local mem
                                        ALUControl = 5'b00000; //add
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};    
                                        length_mode = 1'b0;                                        
                                    end                                
                                    8'h21:begin //local.set
                                        pop_num = 4'd1;
                                        push_num = 1'b0;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00000; //add
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};       
                                        length_mode = 1'b0;                                     
                                    end                                               
                                    8'h22:begin //local.tee
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00000; //add
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};   
                                        length_mode = 1'b0;                                         
                                    end               
                                    8'h23:begin //global.get
                                        pop_num = 4'd0;
                                        push_num = 1'b1;
                                        push_select = 2'b01; //global memory
                                        ALUControl = 5'b00000; //add
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};   
                                        length_mode = 1'b0;                                         
                                    end    
                                    8'h24:begin //global.set
                                        pop_num = 4'd1;
                                        push_num = 1'b0;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00000; //add
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};   
                                        length_mode = 1'b0;                                         
                                    end                                                     
                                    8'h28, 8'h29, 8'h2a, 8'h2b, 8'h2d, 8'h2c, 8'h2e, 8'h2f, 8'h30, 8'h31, 8'h32, 8'h33, 8'h34, 8'h35:begin //i32.load or i64.load or f32.load or f64.load
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b01; //Memory
                                        ALUControl = 5'b00000; //add
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt} + 'd1;   
                                        length_mode = 1'b0;                                         
                                    end                                
                                    8'h36, 8'h37, 8'h38, 8'h39, 8'h3a, 8'h3b, 8'h3c, 8'h3d, 8'h3e: begin //i32.store or i64.store or f32.store or f64.store
                                        pop_num = 4'd2;
                                        push_num = 1'b0;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00000; //add
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt} + 'd1;      
                                        length_mode = 1'b0;                                      
                                    end   
                                    8'h3F:begin //memory.size
                                        pop_num = 4'd0;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00000; //add
                                        read_pointer_shift_minusone = `log_read_window_size'd1;   
                                        length_mode = 1'b0;                                         
                                    end
                                    8'h40:begin //memory.grow
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00000; //add
                                        read_pointer_shift_minusone = `log_read_window_size'd1;   
                                        length_mode = 1'b0;                                         
                                    end
                                    8'h41:begin //i32.const; 
                                        pop_num = 4'd0;
                                        push_num = 1'b1; 
                                        push_select = 2'b10;//Instance_number
                                        ALUControl = 5'b00000;   
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};
                                        length_mode = 1'b0;   
                                    end
                                    8'h42:begin //i64.const;
                                        pop_num = 4'd0;
                                        push_num = 1'b1; 
                                        push_select = 2'b10;//Instance_number
                                        ALUControl = 5'b00000;   
                                        read_pointer_shift_minusone = {`shift_fill_zero'b0, LEB128_byte_cnt};
                                        length_mode = 1'b1;   
                                    end
                                    8'h43:begin //f32.const
                                        pop_num = 4'd0;
                                        push_num = 1'b1; 
                                        push_select = 2'b10;//Instance_number
                                        ALUControl = 5'b00000;   
                                        read_pointer_shift_minusone = 8'd4;
                                        length_mode = 1'b1;   
                                    end
                                    8'h44:begin //f64.const
                                        pop_num = 4'd0;
                                        push_num = 1'b1; 
                                        push_select = 2'b10;//Instance_number
                                        ALUControl = 5'b00000;   
                                        read_pointer_shift_minusone = 8'd8;
                                        length_mode = 1'b1;   
                                    end
                                    8'h45:begin //i32.eqz
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00101;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;          
                                        length_mode = 1'b0;                                                     
                                    end
                                    8'h46:begin //i32.eq
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00110;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;          
                                        length_mode = 1'b0;                           
                                    end
                                    8'h47:begin //i32.ne
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01111;  
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b0;   
                                    end   
                                    8'h48:begin //i32.lt_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01011;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;      
                                        length_mode = 1'b0;                               
                                    end        
                                    8'h49:begin //i32.lt_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00111;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b0;                                
                                    end  
                                    8'h4a:begin //i32.gt_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01100;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b0;                                
                                    end        
                                    8'h4b:begin //i32.gt_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01000;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b0;                                  
                                    end
                                    8'h4c:begin //i32.le_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01101;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;      
                                        length_mode = 1'b0;                               
                                    end
                                    8'h4d:begin //i32.le_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01001;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b0;                                  
                                    end
                                    8'h4e:begin //i32.ge_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01110;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;  
                                        length_mode = 1'b0;                                   
                                    end
                                    8'h4f:begin //i32.ge_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01011;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b0;                                
                                    end    
                                    8'h50:begin //i64.eqz
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00101;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;          
                                        length_mode = 1'b1;          
                                    end
                                    8'h51:begin //i64.eq
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00110;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;          
                                        length_mode = 1'b1;                           
                                    end
                                    8'h52:begin //i64.ne
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01111;  
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b1;   
                                    end  
                                    8'h53:begin //i64.lt_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01011;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;      
                                        length_mode = 1'b1;                               
                                    end    
                                    8'h54:begin //i64.lt_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00111;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b1;                                
                                    end  
                                    8'h55:begin //i64.gt_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01100;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b1;                                
                                    end        
                                    8'h56:begin //i64.gt_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01000;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b1;                                  
                                    end
                                    8'h57:begin //i64.le_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01101;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;      
                                        length_mode = 1'b1;                               
                                    end
                                    8'h58:begin //i64.le_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01001;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b1;                                  
                                    end
                                    8'h59:begin //i64.ge_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01110;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;  
                                        length_mode = 1'b1;                                   
                                    end
                                    8'h60:begin //i64.ge_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b01011;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b1;                                
                                    end    
                                    8'h69:begin //i32.popcnt
                                        pop_num = 4'd1;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        // $display("push_select=%b", push_select);
                                        ALUControl = 5'b11011;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b0;   
                                    end        
                                    8'h6a:begin //i32.add
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        // $display("push_select=%b", push_select);
                                        ALUControl = 5'b00000;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b0;   
                                    end   
                                    8'h6b:begin //i32.sub
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00001;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0; 
                                        length_mode = 1'b0;   
                                    end    
                                    8'h6c:begin //i32.mul
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10101;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0; 
                                        length_mode = 1'b0;   
                                    end
                                    8'h6d:begin //i32.div_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10110;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0; 
                                        length_mode = 1'b0;   
                                    end
                                    8'h6e:begin //i32.div_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10111;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0; 
                                        length_mode = 1'b0;   
                                    end
                                    8'h6f:begin //i32.rem_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11001;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0; 
                                        length_mode = 1'b0;   
                                    end
                                    8'h70:begin //i32.rem_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11010;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b0;                                       
                                    end
                                    8'h71:begin //i32.and
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00010;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b0;                                       
                                    end                 
                                    8'h72:begin //i32.or
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00011;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;  
                                        length_mode = 1'b0;                                          
                                    end
                                    8'h73:begin //i32.xor
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11000;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;  
                                        length_mode = 1'b0;                                          
                                    end                                    
                                    8'h74:begin //i32.shl
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10000;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b0;                                       
                                    end
                                    8'h75:begin //i32.shr_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10001;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;    
                                        length_mode = 1'b0;                                        
                                    end
                                    8'h76:begin //i32.shr_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10010;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;    
                                        length_mode = 1'b0;                                        
                                    end
                                    8'h77:begin //i32.rotl
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10011;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b0;                                         
                                    end
                                    8'h78:begin //i32.rotr
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10100;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;    
                                        length_mode = 1'b0;                                        
                                    end   
                                    8'h7c:begin //i64.add
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        // $display("push_select=%b", push_select);
                                        ALUControl = 5'b00000;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b1;   
                                    end   
                                    8'h7d:begin //i64.sub
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00001;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0; 
                                        length_mode = 1'b1;   
                                    end    
                                    8'h7e:begin //i64.mul
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10101;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0; 
                                        length_mode = 1'b1;   
                                    end
                                    8'h7f:begin //i64.div_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10110;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0; 
                                        length_mode = 1'b1;   
                                    end
                                    8'h80:begin //i64.div_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10111;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0; 
                                        length_mode = 1'b1;   
                                    end
                                    8'h81:begin //i64.rem_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11001;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0; 
                                        length_mode = 1'b1;   
                                    end
                                    8'h82:begin //i64.rem_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11010;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b1;                                       
                                    end
                                    8'h83:begin //i64.and
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00010;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b1;                                       
                                    end                 
                                    8'h84:begin //i64.or
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00011;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;  
                                        length_mode = 1'b1;                                          
                                    end
                                    8'h85:begin //i64.xor
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11000;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;  
                                        length_mode = 1'b1;                                          
                                    end                                    
                                    8'h86:begin //i64.shl
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10000;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;     
                                        length_mode = 1'b1;                                       
                                    end
                                    8'h87:begin //i64.shr_s
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10001;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;    
                                        length_mode = 1'b1;                                        
                                    end
                                    8'h88:begin //i64.shr_u
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10010;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;    
                                        length_mode = 1'b1;                                        
                                    end
                                    8'h89:begin //i64.rotl
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10011;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b1;                                         
                                    end
                                    8'h8a:begin //i64.rotr
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b10100;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;    
                                        length_mode = 1'b1;                                        
                                    end   
                                    8'h92:begin //f32.add
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11100;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b0;   
                                    end
                                    8'h93:begin //f32.sub
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11101;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b0;   
                                    end
                                    8'h94:begin //f32.mul
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11110;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b0;   
                                    end
                                    8'h95:begin //f32.div
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11111;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b0;   
                                    end
                                    8'ha1:begin //f64.sub
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11101;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b1;   
                                    end
                                    8'ha2:begin //f64.mul
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11110;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b1;   
                                    end
                                    8'ha3:begin //f64.div
                                        pop_num = 4'd2;
                                        push_num = 1'b1;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b11111;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;   
                                        length_mode = 1'b1;   
                                    end
                                    8'hD1:begin //i32.mvm
                                        pop_num = 4'd3;
                                        push_num = 1'b0;
                                        push_select = 2'b00; //ALU
                                        ALUControl = 5'b00000;    
                                        read_pointer_shift_minusone = `log_read_window_size'd0;
                                        length_mode = 1'b0;   
                                    end                                          
                                    default:begin
                                        read_pointer_shift_minusone = `log_read_window_size'd0;  
                                        pop_num = 4'd0;
                                        push_num = 1'b0;
                                        push_select = 2'b00;
                                        ALUControl = 5'b00000;
                                        length_mode = 1'b0;   
                                    end                           
                                endcase
                            end
                        end
                        default:begin
                            read_pointer_shift_minusone = `log_read_window_size'b0;
                            pop_num = 4'd0;
                            push_num = 1'b0;
                            push_select = 2'b00;
                            ALUControl = 5'b00000;
                            length_mode = 1'b0;   
                        end
                    endcase
            end
        endcase
    end

    always@(*)begin
        if((instr_pointer_state==vector_content)&(section_type==8'h0a)&(code_pre_read_state==2'b11)&(local_decl_count==local_decl_num))
        begin
            jump_en = 1'b1;
            if(vector_cnt==(vector_num-1))begin
                if (start_function_idx == vector_cnt) begin
                    jump_addr = read_pointer;
                end else begin
                    jump_addr = function_addr_list[start_function_idx];
                end
            end else begin
                jump_addr = function_addr_list[vector_cnt + 1'b1];
            end    
        end else if((instr_pointer_state==vector_content)&(section_type==8'h0a)&(code_pre_read_state==2'b00))
        begin
            if (Instr[7:0] == 8'h10) begin
                jump_en = 1'b1;
                jump_addr = function_addr_list[Instr[15:8]];
            end else if ((Instr[7:0] == 8'h0b)&(read_control_endjump)) begin
                jump_en = 1'b1;
                jump_addr = return_addr_tag;
            end else if (return_instr) begin
                jump_en = 1'b1;
                jump_addr = function_addr_tag;
            end else begin
                jump_en = 1'b0;
                jump_addr = 'd0;
            end
        end else begin
            jump_en = 1'b0;    
            jump_addr = 'd0;
        end
    end


    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            instr_pointer_state <= module_head;
            INSTR_ERROR <= 1'd0;
            section_length <= 32'd0;
            section_type <= 8'd0;
            type_decode <= 1'b0;
            vector_cnt <= 'd0;
            instr_finish <= 1'b0;
            function_store_addr <= 4'd0;
            code_pre_read_state <= 2'd0;
            // jump_en <= 1'b0;
            // jump_addr <= 'd0;
            start_function_idx <= 8'd0;
            // jump_hlt <= 1'b0;
            local_decl_count <= 6'd0;
            local_decl_num <= 6'd0;            
            // un_hlt <= 1'b0;
        end else if (cu_working) begin
            case(instr_pointer_state)
                module_head: begin
                    if(Instr[63:0] == `WASM_MAGIC_VERSION) instr_pointer_state <= section_head;
                    else INSTR_ERROR <= 'd1;
                end
                section_head: begin
                    section_type <= Instr[7:0];
                    section_length <= LEB128_decode;
                    instr_pointer_state <= vector_head;
                end
                vector_head: begin
                    vector_num <= LEB128_decode;
                    if(section_type==8'h01|section_type==8'h06)begin 
                        instr_pointer_state <= vector_content;
                    end else if (section_type==8'h03) begin 
                        instr_pointer_state <= vector_content;
                        function_num_reg <= Instr[7:0];
                    end else if (section_type==8'h08) begin
                        start_function_idx <= Instr[7:0];
                        instr_pointer_state <= section_head;                        
                    end else if (section_type==8'h0a) begin
                        instr_pointer_state <= vector_content;
                        code_pre_read_state <= 2'b01;
                    end else begin
                        instr_pointer_state <= section_head;
                    end
                end
                vector_content: begin
                    case (section_type)
                        8'h0a:begin //; section "Code" (10)
                            if(code_pre_read_state==2'b01)begin
                                function_addr_list[vector_cnt + 1'b1] <= read_pointer + LEB128_byte_cnt + LEB128_decode;
                                code_pre_read_state <= 2'b10;
                                local_memory_sizes_list[vector_cnt] <= 'd0;
                                // jump_en <= 1'b0;
                            end else if(code_pre_read_state==2'b10)begin
                                local_decl_num <= Instr[5:0];
                                code_pre_read_state <= 2'b11;
                            end else if(code_pre_read_state==2'b11)begin
                                if(local_decl_count==local_decl_num)begin
                                    function_addr_list[vector_cnt] <= read_pointer;
                                    // jump_en <= 1'b1;      
                                    local_decl_count <= 6'd0;                                  
                                    if(vector_cnt==(vector_num-1))begin
                                        vector_cnt <= 'd0;
                                        code_pre_read_state <= 2'b00;
                                        // function_content_start <= 1'b1;
                                        // if(start_function_idx == vector_cnt) begin
                                        //     jump_addr <= read_pointer;
                                        // end else begin
                                        //     jump_addr <= function_addr_list[start_function_idx];
                                        // end
                                    end else begin
                                        vector_cnt <= vector_cnt + 1'b1;
                                        code_pre_read_state <= 2'b01;
                                        // jump_addr <= function_addr_list[vector_cnt + 1'b1];
                                    end
                                end else begin
                                    local_decl_count <= local_decl_count + 1'b1;
                                    local_memory_sizes_list[vector_cnt] <= local_memory_sizes_list[vector_cnt]+LEB128_decode;
                                end
                            end else begin //if (code_pre_read_state==2'b00)
                                // function_content_start <= 1'b0;
                                if(unreachable_instr) begin //unreachable
                                    INSTR_ERROR <= 1'b1;
                                    instr_finish <= 1'b1;
                                // end else if(Instr[7:0] == 8'h10) begin //call, jump to function index
                                //     jump_en <= 1'b1;
                                //     jump_addr <= function_addr_list[Instr[15:8]];
                                end else if(Instr[7:0] == 8'h0b) begin //end, temp for function end
                                    if(control_stack_left_one)begin
                                        instr_finish <= 1'b1;
                                    // end else if (read_control_endjump) begin 
                                    //     jump_en <= 1'b1;
                                    //     jump_addr <= return_addr_tag;
                                    end //else if(jump_en) jump_en <= 1'b0;
                                end // else if(jump_en) jump_en <= 1'b0;
                            end
                        end
                        8'h01:begin //; section "Type" (1)
                            if(type_decode) begin
                                type_decode <= 1'b0;
                                retu_num_reg[vector_cnt] <= Instr[0];
                                if(vector_cnt==(vector_num-1)) begin
                                    vector_cnt <= 'd0;
                                    instr_pointer_state <= section_head;
                                end
                                else vector_cnt <= vector_cnt + 'd1;
                            end
                            else begin
                                type_decode <= 1'b1;
                                para_num_reg[vector_cnt] <= Instr[15:8];                                    
                            end
                        end
                        8'h03:begin //; section "Function" (3)
                            {function_type_list[function_store_addr*`read_window_size+10]
                            ,function_type_list[function_store_addr*`read_window_size+9]
                            ,function_type_list[function_store_addr*`read_window_size+8]
                            ,function_type_list[function_store_addr*`read_window_size+7]
                            ,function_type_list[function_store_addr*`read_window_size+6]
                            ,function_type_list[function_store_addr*`read_window_size+5]
                            ,function_type_list[function_store_addr*`read_window_size+4]
                            ,function_type_list[function_store_addr*`read_window_size+3]
                            ,function_type_list[function_store_addr*`read_window_size+2]
                            ,function_type_list[function_store_addr*`read_window_size+1]
                            ,function_type_list[function_store_addr*`read_window_size]} <= Instr;
                            if(~((vector_cnt+`read_window_size)<(vector_num-1))) begin
                                vector_cnt <= 'd0;
                                instr_pointer_state <= section_head;
                                function_store_addr <= 4'd0;
                            end
                            else begin
                                vector_cnt <= vector_cnt + `read_window_size;
                                function_store_addr <= function_store_addr + 'd1;
                            end
                        end
                        8'h06:begin //; section "Global" (6)
                            if(vector_cnt==(vector_num-1'd1)) begin
                                vector_cnt <= 'd0;
                                instr_pointer_state <= section_head;
                            end
                            else begin
                                vector_cnt <= vector_cnt + 'd1;
                            end
                        end
                        default:begin
                            instr_pointer_state <= section_head;
                        end
                    endcase                
                end
            endcase
        end
    end
    
    
endmodule


                                    // 8'h67:begin //i32.clz 统计前置0比特数
                                    //     pop_num = 4'd1;
                                    //     push_num = 1'b1;
                                    //     push_select = 2'b00; //ALU
                                    //     ALUControl = 5'b11000;    
                                    //     read_pointer_shift_minusone = `log_read_window_size'd0;                                  
                                    // end   
                                    // 8'h68:begin //i32.ctz 统计后置0比特数
                                    //     pop_num = 4'd1;
                                    //     push_num = 1'b1;
                                    //     push_select = 2'b00; //ALU
                                    //     ALUControl = 5'b11001;    
                                    //     read_pointer_shift_minusone = `log_read_window_size'd0;                                  
                                    // end     
                                    // 8'h69:begin //i32.popcnt 统计1比特数
                                    //     pop_num = 4'd1;
                                    //     push_num = 1'b1;
                                    //     push_select = 2'b00; //ALU
                                    //     ALUControl = 5'b11001;    
                                    //     read_pointer_shift_minusone = `log_read_window_size'd0;                                  
                                    // end  
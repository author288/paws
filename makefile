tb_name = TB_WASM_TOP.v

iverilog:
	iverilog -o wave ./test/$(tb_name)
	vvp -n wave -lxt2

wave_iverilog:
	iverilog -o wave ./test/$(tb_name)
	vvp -n wave -lxt2
	gtkwave ./wave111.vcd &

generate_instructions:
	python3 arrange_instr_format.py

clean:
	rm -f ./wave 
	rm -f ./*.vcd 
	rm -f ./test/temp.txt
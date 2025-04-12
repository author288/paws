# wasm_cpu_flow

### 1. Preparation

Please install iverilog and gtkwave first: \
iverilog: `sudo apt-get install iverilog` \
gtkwave: `sudo apt-get install gtkwave`
### 2. Settings
Before running the flow, set
``` bash
gedit ./test/TB_WASM_TOP.v
```
On the line 98, set the corresponding hex file.

### 3. running:

without wave:

```bash
make iverilog
```

with wave:
``` bash
make wave_iverilog
```

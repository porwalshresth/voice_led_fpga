# Toolchain
IVERILOG   = iverilog
VVP        = vvp
GTKWAVE    = gtkwave
YOSYS      = yosys
NETLISTSVG = netlistsvg

# Files
RTL_SRCS   = rtl/top_voice_led.v rtl/baud_gen.v rtl/uart_rx.v rtl/packet_fsm.v rtl/led_driver.v
TB_SRC     = tb/tb_top_voice_led.v
SIM_OUT    = voice_led_sim.vvp
WAVE_FST   = voice_led_sim.fst

.PHONY: all sim wave rtl clean

all: sim

# Compile and run self-checking simulation (outputs compressed FST waveform)
sim:
	$(IVERILOG) -o $(SIM_OUT) $(RTL_SRCS) $(TB_SRC)
	$(VVP) $(SIM_OUT) -fst
	@if [ -f voice_led_sim.vcd ]; then mv voice_led_sim.vcd $(WAVE_FST); fi

# Launch GTKWave
wave: sim
	$(GTKWAVE) $(WAVE_FST) &

# Generate RTL schematics using Yosys and netlistsvg
rtl:
	mkdir -p docs/schematics
	$(YOSYS) -p "prep -top top_voice_led; write_json top.json" $(RTL_SRCS)
	$(NETLISTSVG) top.json -o docs/schematics/rtl_top_voice_led.svg
	rm -f top.json

clean:
	rm -f *.vvp *.vcd *.fst *.json
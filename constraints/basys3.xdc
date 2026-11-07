## Clock Signal (100 MHz Onboard CMOS Oscillator)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## Center Pushbutton (Active-High System Reset)
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports rst]

## PMOD Header JA Pin 1 (3.3V Level-Shifted UART RX from Elechouse V3 LV1)
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports uart_rx_pin]

## Output LEDs ([2]=Red/LD2, [1]=Green/LD1, [0]=Blue/LD0)
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {led_out[0]}]
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {led_out[1]}]
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {led_out[2]}]

## Configuration Voltage Settings
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
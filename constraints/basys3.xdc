## ============================================================================
## Basys 3 Master Constraints File for top_voice_led.v
## Target FPGA: Xilinx Artix-7 XC7A35T-1CPG236C
## ============================================================================

## 1. 100 MHz Onboard System Clock (Fixed at Pin W5 on all Basys 3 boards)
set_property -dict { PACKAGE_PIN W5   IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk]

## 2. System Reset Pushbutton (Mapped to Center Pushbutton 'BTNC' -> Pin U18)
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports rst]

## 3. UART Serial Input from Level Shifter LV1 (Mapped to Header JA, Pin 1 -> Pin J1)
set_property -dict { PACKAGE_PIN J1   IOSTANDARD LVCMOS33 } [get_ports uart_rx_pin]

## ============================================================================
## 4. LED Outputs: OPTION A (Using Onboard Basys 3 LEDs LD0, LD1, LD2)
## ============================================================================
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports {led_out[0]}] ;# LD0 ("Blue" channel)
set_property -dict { PACKAGE_PIN E19  IOSTANDARD LVCMOS33 } [get_ports {led_out[1]}] ;# LD1 ("Green" channel)
set_property -dict { PACKAGE_PIN U19  IOSTANDARD LVCMOS33 } [get_ports {led_out[2]}] ;# LD2 ("Red" channel)

## ============================================================================
## 4. LED Outputs: OPTION B (If plugging external R, G, B LEDs into Header JA)
## (To use external LEDs on Header JA Pins 2, 3, 4 instead of onboard LEDs,
##  comment out Option A above with '#' and uncomment the 3 lines below!)
## ============================================================================
# set_property -dict { PACKAGE_PIN L2   IOSTANDARD LVCMOS33 } [get_ports {led_out[0]}] ;# JA Pin 2 (Blue LED)
# set_property -dict { PACKAGE_PIN J2   IOSTANDARD LVCMOS33 } [get_ports {led_out[1]}] ;# JA Pin 3 (Green LED)
# set_property -dict { PACKAGE_PIN G2   IOSTANDARD LVCMOS33 } [get_ports {led_out[2]}] ;# JA Pin 4 (Red LED)

## Configuration Voltage Settings (Prevents Vivado DRC CFGBVS Warning)
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## ----------------------------------------------------------------------------
## Nexys Video XDC Constraints — SD Card Duplicator
## Part: xc7a200tsbg484-1
## Board: Digilent Nexys Video Rev. C
## ----------------------------------------------------------------------------

## Configuration voltage
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]

## ----------------------------------------------------------------------------
## 100 MHz System Clock
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN R4    IOSTANDARD LVCMOS33 } [get_ports { clk_100mhz }]
create_clock -name sys_clk -period 10.000 [get_ports { clk_100mhz }]

## ----------------------------------------------------------------------------
## CPU Reset Button (active-low)
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN G4    IOSTANDARD LVCMOS15 } [get_ports { reset_n }]

## ----------------------------------------------------------------------------
## Center Button (BTNC) — Start duplication
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN B22   IOSTANDARD LVCMOS12 } [get_ports { btn_start }]



## ----------------------------------------------------------------------------
## LEDs LED[7:0] — Status display
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN T14   IOSTANDARD LVCMOS25 } [get_ports { led[0] }]
set_property -dict { PACKAGE_PIN T15   IOSTANDARD LVCMOS25 } [get_ports { led[1] }]
set_property -dict { PACKAGE_PIN T16   IOSTANDARD LVCMOS25 } [get_ports { led[2] }]
set_property -dict { PACKAGE_PIN U16   IOSTANDARD LVCMOS25 } [get_ports { led[3] }]
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS25 } [get_ports { led[4] }]
set_property -dict { PACKAGE_PIN W16   IOSTANDARD LVCMOS25 } [get_ports { led[5] }]
set_property -dict { PACKAGE_PIN W15   IOSTANDARD LVCMOS25 } [get_ports { led[6] }]
set_property -dict { PACKAGE_PIN Y13   IOSTANDARD LVCMOS25 } [get_ports { led[7] }]

## ----------------------------------------------------------------------------
## Onboard microSD Card Slot (Source SD — SPI mode)
##   sd_cclk  → SPI SCLK
##   sd_cmd   → SPI MOSI
##   sd_dat0  → SPI MISO
##   sd_dat3  → SPI CS_N
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN W19   IOSTANDARD LVCMOS33 } [get_ports { src_sd_sclk }]
set_property -dict { PACKAGE_PIN W20   IOSTANDARD LVCMOS33 } [get_ports { src_sd_mosi }]
set_property -dict { PACKAGE_PIN V18   IOSTANDARD LVCMOS33 } [get_ports { src_sd_miso }]
set_property -dict { PACKAGE_PIN T20   IOSTANDARD LVCMOS33 } [get_ports { src_sd_cs_n }]
## Pull-up on MISO: SD card tri-states this line when CS is high
set_property PULLUP TRUE [get_ports { src_sd_miso }]

## ----------------------------------------------------------------------------
## PMOD JA — Destination SD (VKLSVAN SD card module via SPI)
##   JA Pin 1 (AB22) → CS_N
##   JA Pin 2 (AB21) → MOSI
##   JA Pin 3 (AB20) → MISO
##   JA Pin 4 (AB18) → SCLK
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN AB22  IOSTANDARD LVCMOS33 } [get_ports { dst_sd_cs_n }]
set_property -dict { PACKAGE_PIN AB21  IOSTANDARD LVCMOS33 } [get_ports { dst_sd_mosi }]
set_property -dict { PACKAGE_PIN AB20  IOSTANDARD LVCMOS33 } [get_ports { dst_sd_miso }]
set_property -dict { PACKAGE_PIN AB18  IOSTANDARD LVCMOS33 } [get_ports { dst_sd_sclk }]
## Pull-up on MISO: SD card tri-states this line when CS is high
set_property PULLUP TRUE [get_ports { dst_sd_miso }]

## ----------------------------------------------------------------------------
## Timing constraints for SPI outputs
## Max SPI clock is 25 MHz (40 ns period). Allow generous output delay.
## ----------------------------------------------------------------------------
set_output_delay -clock sys_clk -max 5.000 [get_ports { src_sd_sclk src_sd_mosi src_sd_cs_n }]
set_output_delay -clock sys_clk -min 0.000 [get_ports { src_sd_sclk src_sd_mosi src_sd_cs_n }]
set_input_delay  -clock sys_clk -max 5.000 [get_ports { src_sd_miso }]
set_input_delay  -clock sys_clk -min 0.000 [get_ports { src_sd_miso }]

set_output_delay -clock sys_clk -max 5.000 [get_ports { dst_sd_sclk dst_sd_mosi dst_sd_cs_n }]
set_output_delay -clock sys_clk -min 0.000 [get_ports { dst_sd_sclk dst_sd_mosi dst_sd_cs_n }]
set_input_delay  -clock sys_clk -max 5.000 [get_ports { dst_sd_miso }]
set_input_delay  -clock sys_clk -min 0.000 [get_ports { dst_sd_miso }]

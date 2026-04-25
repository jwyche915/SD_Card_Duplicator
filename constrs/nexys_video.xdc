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
set_property -dict {PACKAGE_PIN R4 IOSTANDARD LVCMOS33} [get_ports clk_100mhz]
create_clock -period 10.000 -name sys_clk [get_ports clk_100mhz]

##-----------------------------------------------------------------------------
## 25 MHz SPI Clock created by clock divider
##-----------------------------------------------------------------------------
# destination SD card SPI clock config...multi-path signal updated every 4 sys_clk cycles
create_generated_clock -name dst_spi_clk -source [get_ports clk_100mhz] -divide_by 4 [get_pins dst_spi/sclk_reg/Q]
set_multicycle_path -setup -start -from [get_clocks sys_clk] -to [get_clocks dst_spi_clk] 4
set_multicycle_path -hold -start -from [get_clocks sys_clk] -to [get_clocks dst_spi_clk] 3

# source SD card SPI clock config...multi-path signal updated every 4 sys_clk cycles
create_generated_clock -name src_spi_clk -source [get_ports clk_100mhz] -divide_by 4 [get_pins src_spi/sclk_reg/Q]
set_multicycle_path -setup -start -from [get_clocks sys_clk] -to [get_clocks src_spi_clk] 4
set_multicycle_path -hold -start -from [get_clocks sys_clk] -to [get_clocks src_spi_clk] 3

## ----------------------------------------------------------------------------
## CPU Reset Button (active-low)
## ----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN G4 IOSTANDARD LVCMOS15} [get_ports reset_n]

## ----------------------------------------------------------------------------
## Center Button (BTNC) — Start duplication
## ----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN B22 IOSTANDARD LVCMOS12} [get_ports btn_start]



## ----------------------------------------------------------------------------
## LEDs LED[7:0] — Status display
## ----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN T14 IOSTANDARD LVCMOS25} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN T15 IOSTANDARD LVCMOS25} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS25} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN U16 IOSTANDARD LVCMOS25} [get_ports {led[3]}]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS25} [get_ports {led[4]}]
set_property -dict {PACKAGE_PIN W16 IOSTANDARD LVCMOS25} [get_ports {led[5]}]
set_property -dict {PACKAGE_PIN W15 IOSTANDARD LVCMOS25} [get_ports {led[6]}]
set_property -dict {PACKAGE_PIN Y13 IOSTANDARD LVCMOS25} [get_ports {led[7]}]

## ----------------------------------------------------------------------------
## Onboard microSD Card Slot (Source SD — SPI mode)
##   sd_cclk  → SPI SCLK
##   sd_cmd   → SPI MOSI
##   sd_dat0  → SPI MISO
##   sd_dat3  → SPI CS_N
## ----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports src_sd_sclk]
set_property -dict {PACKAGE_PIN W20 IOSTANDARD LVCMOS33} [get_ports src_sd_mosi]
set_property -dict {PACKAGE_PIN V19 IOSTANDARD LVCMOS33} [get_ports src_sd_miso]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports src_sd_cs_n]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS33} [get_ports src_sd_reset_n]
## Pull-up on MISO: SD card tri-states this line when CS is high
set_property PULLTYPE PULLUP [get_ports src_sd_reset_n]

## ----------------------------------------------------------------------------
## PMOD JA — Destination SD (VKLSVAN SD card module via SPI)
##   JA Pin 1 (AB22) → CS_N
##   JA Pin 2 (AB21) → SCLK
##   JA Pin 3 (AB20) → MOSI
##   JA Pin 4 (AB18) → MISO
## ----------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN AB22 IOSTANDARD LVCMOS33} [get_ports dst_sd_cs_n]
set_property -dict {PACKAGE_PIN AB21 IOSTANDARD LVCMOS33} [get_ports dst_sd_sclk]
set_property -dict {PACKAGE_PIN AB20 IOSTANDARD LVCMOS33} [get_ports dst_sd_mosi]
set_property -dict {PACKAGE_PIN AB18 IOSTANDARD LVCMOS33} [get_ports dst_sd_miso]
## Pull-up on MISO: SD card tri-states this line when CS is high
set_property PULLTYPE PULLUP [get_ports dst_sd_miso]
set_property PULLTYPE PULLUP [get_ports dst_sd_mosi]

## ----------------------------------------------------------------------------
## Timing constraints for SPI outputs
## Max SPI clock is 25 MHz (40 ns period). Allow generous output delay.
## ----------------------------------------------------------------------------
## Output delays for the source SD card
set_output_delay -clock src_spi_clk -max 5.000 [get_ports {src_sd_mosi src_sd_cs_n}]
set_output_delay -clock src_spi_clk -min 0.000 [get_ports {src_sd_mosi src_sd_cs_n}]
set_input_delay -clock src_spi_clk -max 5.000 [get_ports src_sd_miso]
set_input_delay -clock src_spi_clk -min 0.000 [get_ports src_sd_miso]

## Output delays for the destination SD card
set_output_delay -clock dst_spi_clk -max 5.000 [get_ports {dst_sd_mosi dst_sd_cs_n}]
set_output_delay -clock dst_spi_clk -min 0.000 [get_ports {dst_sd_mosi dst_sd_cs_n}]
set_input_delay -clock dst_spi_clk -max 5.000 [get_ports dst_sd_miso]
set_input_delay -clock dst_spi_clk -min 0.000 [get_ports dst_sd_miso]

set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[1]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[3]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[5]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[6]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[8]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[10]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[13]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[0]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[2]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[4]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[7]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[9]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[11]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[12]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[0]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[1]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[2]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[3]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[4]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[5]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[6]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[1]_i_1__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[18]_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[29]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[9]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_5__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_16__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_11__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_19__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_23__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[19]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[35]_2}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[34]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_15__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_9__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[27]_i_1__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_3__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[8]_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[13]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[8]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[11]_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[35]_1}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[10]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[8]_i_2__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_24__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_6__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_21__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[0]_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[8]_1}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[2]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[8]_i_1__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[18]_i_1__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_2__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_4__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[35]_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[31]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[3]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[5]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_10__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_14__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_18__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_22__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[0]_1}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[0]_2}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[7]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[8]_i_4__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_1__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_7__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state[35]_i_12__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg[35]_3}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[12]}]
set_property MARK_DEBUG true [get_nets dst_sd_miso_IBUF]
set_property MARK_DEBUG true [get_nets dst_sd_mosi_OBUF]
set_property MARK_DEBUG true [get_nets dst_sd_sclk_OBUF]
set_property MARK_DEBUG true [get_nets dst_sd_cs_n_OBUF]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf[13]_i_1__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf[14]_i_1__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[1]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[6]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[43]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf[9]_i_1__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf[11]_i_1__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf[15]_i_1__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[3]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[4]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[46]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf[16]_i_1__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[7]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[40]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[42]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf[46]_i_1__0_n_0}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[5]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[41]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[44]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg_n_0_[45]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf0_in[7]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf0_in[41]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg[38]_0[3]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg[38]_0[6]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg[38]_0[9]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf0_in[3]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf0_in[4]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf0_in[6]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf0_in[44]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg[38]_0[2]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg[38]_0[7]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg[38]_0[8]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf0_in[5]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf0_in[43]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg[38]_0[0]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg[38]_0[4]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg[38]_0[5]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf0_in[1]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf0_in[38]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf0_in[40]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf0_in[45]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg[38]_0[1]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/cmd_buf_reg[38]_0[10]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/send_byte_reg_n_0_[0]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/send_byte_reg_n_0_[1]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/send_byte_reg_n_0_[2]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/send_byte_reg_n_0_[3]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/send_byte_reg_n_0_[4]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/send_byte_reg_n_0_[5]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/send_byte_reg_n_0_[6]}]
set_property MARK_DEBUG true [get_nets {dst_sd_ctrl/send_byte_reg_n_0_[7]}]
create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 8192 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_100mhz_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 11 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {dst_sd_ctrl/cmd_buf_reg[38]_0[0]} {dst_sd_ctrl/cmd_buf_reg[38]_0[1]} {dst_sd_ctrl/cmd_buf_reg[38]_0[2]} {dst_sd_ctrl/cmd_buf_reg[38]_0[3]} {dst_sd_ctrl/cmd_buf_reg[38]_0[4]} {dst_sd_ctrl/cmd_buf_reg[38]_0[5]} {dst_sd_ctrl/cmd_buf_reg[38]_0[6]} {dst_sd_ctrl/cmd_buf_reg[38]_0[7]} {dst_sd_ctrl/cmd_buf_reg[38]_0[8]} {dst_sd_ctrl/cmd_buf_reg[38]_0[9]} {dst_sd_ctrl/cmd_buf_reg[38]_0[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 12 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {dst_sd_ctrl/cmd_buf0_in[1]} {dst_sd_ctrl/cmd_buf0_in[3]} {dst_sd_ctrl/cmd_buf0_in[4]} {dst_sd_ctrl/cmd_buf0_in[5]} {dst_sd_ctrl/cmd_buf0_in[6]} {dst_sd_ctrl/cmd_buf0_in[7]} {dst_sd_ctrl/cmd_buf0_in[38]} {dst_sd_ctrl/cmd_buf0_in[40]} {dst_sd_ctrl/cmd_buf0_in[41]} {dst_sd_ctrl/cmd_buf0_in[43]} {dst_sd_ctrl/cmd_buf0_in[44]} {dst_sd_ctrl/cmd_buf0_in[45]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 14 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[0]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[1]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[2]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[3]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[4]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[5]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[6]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[7]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[8]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[9]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[10]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[11]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[12]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_0[13]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 7 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[0]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[1]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[2]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[3]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[4]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[5]} {dst_sd_ctrl/FSM_onehot_state_reg[33]_1[6]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {dst_sd_ctrl/cmd_buf[9]_i_1__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {dst_sd_ctrl/cmd_buf[11]_i_1__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list {dst_sd_ctrl/cmd_buf[13]_i_1__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list {dst_sd_ctrl/cmd_buf[14]_i_1__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list {dst_sd_ctrl/cmd_buf[15]_i_1__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list {dst_sd_ctrl/cmd_buf[16]_i_1__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list {dst_sd_ctrl/cmd_buf[46]_i_1__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[6]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe16]
set_property port_width 1 [get_debug_ports u_ila_0/probe16]
connect_debug_port u_ila_0/probe16 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe17]
set_property port_width 1 [get_debug_ports u_ila_0/probe17]
connect_debug_port u_ila_0/probe17 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[40]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe18]
set_property port_width 1 [get_debug_ports u_ila_0/probe18]
connect_debug_port u_ila_0/probe18 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[41]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe19]
set_property port_width 1 [get_debug_ports u_ila_0/probe19]
connect_debug_port u_ila_0/probe19 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[42]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe20]
set_property port_width 1 [get_debug_ports u_ila_0/probe20]
connect_debug_port u_ila_0/probe20 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[43]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe21]
set_property port_width 1 [get_debug_ports u_ila_0/probe21]
connect_debug_port u_ila_0/probe21 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[44]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe22]
set_property port_width 1 [get_debug_ports u_ila_0/probe22]
connect_debug_port u_ila_0/probe22 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[45]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe23]
set_property port_width 1 [get_debug_ports u_ila_0/probe23]
connect_debug_port u_ila_0/probe23 [get_nets [list {dst_sd_ctrl/cmd_buf_reg_n_0_[46]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe24]
set_property port_width 1 [get_debug_ports u_ila_0/probe24]
connect_debug_port u_ila_0/probe24 [get_nets [list dst_sd_cs_n_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe25]
set_property port_width 1 [get_debug_ports u_ila_0/probe25]
connect_debug_port u_ila_0/probe25 [get_nets [list dst_sd_miso_IBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe26]
set_property port_width 1 [get_debug_ports u_ila_0/probe26]
connect_debug_port u_ila_0/probe26 [get_nets [list dst_sd_mosi_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe27]
set_property port_width 1 [get_debug_ports u_ila_0/probe27]
connect_debug_port u_ila_0/probe27 [get_nets [list dst_sd_sclk_OBUF]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe28]
set_property port_width 1 [get_debug_ports u_ila_0/probe28]
connect_debug_port u_ila_0/probe28 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[1]_i_1__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe29]
set_property port_width 1 [get_debug_ports u_ila_0/probe29]
connect_debug_port u_ila_0/probe29 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[8]_i_1__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe30]
set_property port_width 1 [get_debug_ports u_ila_0/probe30]
connect_debug_port u_ila_0/probe30 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[8]_i_2__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe31]
set_property port_width 1 [get_debug_ports u_ila_0/probe31]
connect_debug_port u_ila_0/probe31 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[8]_i_4__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe32]
set_property port_width 1 [get_debug_ports u_ila_0/probe32]
connect_debug_port u_ila_0/probe32 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[18]_i_1__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe33]
set_property port_width 1 [get_debug_ports u_ila_0/probe33]
connect_debug_port u_ila_0/probe33 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[27]_i_1__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe34]
set_property port_width 1 [get_debug_ports u_ila_0/probe34]
connect_debug_port u_ila_0/probe34 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_1__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe35]
set_property port_width 1 [get_debug_ports u_ila_0/probe35]
connect_debug_port u_ila_0/probe35 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_2__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe36]
set_property port_width 1 [get_debug_ports u_ila_0/probe36]
connect_debug_port u_ila_0/probe36 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_3__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe37]
set_property port_width 1 [get_debug_ports u_ila_0/probe37]
connect_debug_port u_ila_0/probe37 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_4__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe38]
set_property port_width 1 [get_debug_ports u_ila_0/probe38]
connect_debug_port u_ila_0/probe38 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_5__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe39]
set_property port_width 1 [get_debug_ports u_ila_0/probe39]
connect_debug_port u_ila_0/probe39 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_6__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe40]
set_property port_width 1 [get_debug_ports u_ila_0/probe40]
connect_debug_port u_ila_0/probe40 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_7__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe41]
set_property port_width 1 [get_debug_ports u_ila_0/probe41]
connect_debug_port u_ila_0/probe41 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_9__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe42]
set_property port_width 1 [get_debug_ports u_ila_0/probe42]
connect_debug_port u_ila_0/probe42 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_10__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe43]
set_property port_width 1 [get_debug_ports u_ila_0/probe43]
connect_debug_port u_ila_0/probe43 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_11__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe44]
set_property port_width 1 [get_debug_ports u_ila_0/probe44]
connect_debug_port u_ila_0/probe44 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_12__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe45]
set_property port_width 1 [get_debug_ports u_ila_0/probe45]
connect_debug_port u_ila_0/probe45 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_14__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe46]
set_property port_width 1 [get_debug_ports u_ila_0/probe46]
connect_debug_port u_ila_0/probe46 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_15__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe47]
set_property port_width 1 [get_debug_ports u_ila_0/probe47]
connect_debug_port u_ila_0/probe47 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_16__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe48]
set_property port_width 1 [get_debug_ports u_ila_0/probe48]
connect_debug_port u_ila_0/probe48 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_18__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe49]
set_property port_width 1 [get_debug_ports u_ila_0/probe49]
connect_debug_port u_ila_0/probe49 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_19__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe50]
set_property port_width 1 [get_debug_ports u_ila_0/probe50]
connect_debug_port u_ila_0/probe50 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_21__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe51]
set_property port_width 1 [get_debug_ports u_ila_0/probe51]
connect_debug_port u_ila_0/probe51 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_22__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe52]
set_property port_width 1 [get_debug_ports u_ila_0/probe52]
connect_debug_port u_ila_0/probe52 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_23__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe53]
set_property port_width 1 [get_debug_ports u_ila_0/probe53]
connect_debug_port u_ila_0/probe53 [get_nets [list {dst_sd_ctrl/FSM_onehot_state[35]_i_24__0_n_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe54]
set_property port_width 1 [get_debug_ports u_ila_0/probe54]
connect_debug_port u_ila_0/probe54 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[0]_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe55]
set_property port_width 1 [get_debug_ports u_ila_0/probe55]
connect_debug_port u_ila_0/probe55 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[0]_1}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe56]
set_property port_width 1 [get_debug_ports u_ila_0/probe56]
connect_debug_port u_ila_0/probe56 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[0]_2}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe57]
set_property port_width 1 [get_debug_ports u_ila_0/probe57]
connect_debug_port u_ila_0/probe57 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[8]_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe58]
set_property port_width 1 [get_debug_ports u_ila_0/probe58]
connect_debug_port u_ila_0/probe58 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[8]_1}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe59]
set_property port_width 1 [get_debug_ports u_ila_0/probe59]
connect_debug_port u_ila_0/probe59 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[11]_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe60]
set_property port_width 1 [get_debug_ports u_ila_0/probe60]
connect_debug_port u_ila_0/probe60 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[18]_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe61]
set_property port_width 1 [get_debug_ports u_ila_0/probe61]
connect_debug_port u_ila_0/probe61 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[35]_0}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe62]
set_property port_width 1 [get_debug_ports u_ila_0/probe62]
connect_debug_port u_ila_0/probe62 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[35]_1}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe63]
set_property port_width 1 [get_debug_ports u_ila_0/probe63]
connect_debug_port u_ila_0/probe63 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[35]_2}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe64]
set_property port_width 1 [get_debug_ports u_ila_0/probe64]
connect_debug_port u_ila_0/probe64 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg[35]_3}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe65]
set_property port_width 1 [get_debug_ports u_ila_0/probe65]
connect_debug_port u_ila_0/probe65 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe66]
set_property port_width 1 [get_debug_ports u_ila_0/probe66]
connect_debug_port u_ila_0/probe66 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe67]
set_property port_width 1 [get_debug_ports u_ila_0/probe67]
connect_debug_port u_ila_0/probe67 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe68]
set_property port_width 1 [get_debug_ports u_ila_0/probe68]
connect_debug_port u_ila_0/probe68 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe69]
set_property port_width 1 [get_debug_ports u_ila_0/probe69]
connect_debug_port u_ila_0/probe69 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[8]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe70]
set_property port_width 1 [get_debug_ports u_ila_0/probe70]
connect_debug_port u_ila_0/probe70 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[9]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe71]
set_property port_width 1 [get_debug_ports u_ila_0/probe71]
connect_debug_port u_ila_0/probe71 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[10]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe72]
set_property port_width 1 [get_debug_ports u_ila_0/probe72]
connect_debug_port u_ila_0/probe72 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[12]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe73]
set_property port_width 1 [get_debug_ports u_ila_0/probe73]
connect_debug_port u_ila_0/probe73 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[13]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe74]
set_property port_width 1 [get_debug_ports u_ila_0/probe74]
connect_debug_port u_ila_0/probe74 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[19]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe75]
set_property port_width 1 [get_debug_ports u_ila_0/probe75]
connect_debug_port u_ila_0/probe75 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[29]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe76]
set_property port_width 1 [get_debug_ports u_ila_0/probe76]
connect_debug_port u_ila_0/probe76 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[31]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe77]
set_property port_width 1 [get_debug_ports u_ila_0/probe77]
connect_debug_port u_ila_0/probe77 [get_nets [list {dst_sd_ctrl/FSM_onehot_state_reg_n_0_[34]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe78]
set_property port_width 1 [get_debug_ports u_ila_0/probe78]
connect_debug_port u_ila_0/probe78 [get_nets [list {dst_sd_ctrl/send_byte_reg_n_0_[0]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe79]
set_property port_width 1 [get_debug_ports u_ila_0/probe79]
connect_debug_port u_ila_0/probe79 [get_nets [list {dst_sd_ctrl/send_byte_reg_n_0_[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe80]
set_property port_width 1 [get_debug_ports u_ila_0/probe80]
connect_debug_port u_ila_0/probe80 [get_nets [list {dst_sd_ctrl/send_byte_reg_n_0_[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe81]
set_property port_width 1 [get_debug_ports u_ila_0/probe81]
connect_debug_port u_ila_0/probe81 [get_nets [list {dst_sd_ctrl/send_byte_reg_n_0_[3]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe82]
set_property port_width 1 [get_debug_ports u_ila_0/probe82]
connect_debug_port u_ila_0/probe82 [get_nets [list {dst_sd_ctrl/send_byte_reg_n_0_[4]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe83]
set_property port_width 1 [get_debug_ports u_ila_0/probe83]
connect_debug_port u_ila_0/probe83 [get_nets [list {dst_sd_ctrl/send_byte_reg_n_0_[5]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe84]
set_property port_width 1 [get_debug_ports u_ila_0/probe84]
connect_debug_port u_ila_0/probe84 [get_nets [list {dst_sd_ctrl/send_byte_reg_n_0_[6]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe85]
set_property port_width 1 [get_debug_ports u_ila_0/probe85]
connect_debug_port u_ila_0/probe85 [get_nets [list {dst_sd_ctrl/send_byte_reg_n_0_[7]}]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_100mhz_IBUF_BUFG]

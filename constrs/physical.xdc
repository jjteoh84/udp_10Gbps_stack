# =============================================
# Physical Pin Constraints - Using -dict format
# =============================================

# Configure system clock differential pair (300MHz)
# - Positive pin of differential clock at bank AW14
# - LVDS I/O standard for high-speed differential signaling
set_property -dict {IOSTANDARD LVDS PACKAGE_PIN AK17} [get_ports sys_clk_300Mhz_p]
set_property -dict {IOSTANDARD LVDS PACKAGE_PIN AK16} [get_ports sys_clk_300Mhz_n]

# Configure GT reference clock input
# - GT reference clock pin at Y11 location
# - Used for Gigabit Transceiver reference clock (typically 156.25MHz)
#set_property -dict {
#    PACKAGE_PIN P6
#} [get_ports gt_refclk_in_p]
set_property PACKAGE_PIN P5 [get_ports gt_refclk_in_n]
set_property PACKAGE_PIN P6 [get_ports gt_refclk_in_p]
set_property IOSTANDARD LVDS_25 [get_ports {gt_refclk_in_p gt_refclk_in_n}]


# Ensure MMCM clk unconstrained for debug
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets sys_clk_100MHz]
create_clock -period 10.000 -name sys_clk_100MHz [get_nets sys_clk_100MHz]

# Mux SEL (drive low for Si570)
set_property PACKAGE_PIN F12 [get_ports si570_sel]
set_property IOSTANDARD LVCMOS18 [get_ports si570_sel]
set_property PULLTYPE PULLDOWN [get_ports si570_sel]

# Add Si5328 reset drive (high = enabled, optional for now)
set_property PACKAGE_PIN K23 [get_ports si5328_rst]
set_property IOSTANDARD LVCMOS18 [get_ports si5328_rst]

# Configure GT transmit output differential pair
# - Positive pin of GT transmitter at AA9 location
# - High-speed serial output for Ethernet data transmission
#set_property -dict {
#    PACKAGE_PIN AA9
#} [get_ports gt_tx_out_p]


# SFP+ TX Differential Pairs (Bank 66, no IOSTANDARD needed for GT)
#set_property PACKAGE_PIN W4 [get_ports sfp1_txp]
#set_property PACKAGE_PIN W3 [get_ports sfp1_txn]

# TX Control output (LVCMOS18, Bank 65/66)
set_property PACKAGE_PIN AL8 [get_ports sfp0_tx_disable]
# set_property PACKAGE_PIN D28 [get_ports sfp1_tx_disable]
set_property IOSTANDARD LVCMOS18 [get_ports sfp0_tx_disable]


# SFP+ RX Differential Pairs (Bank 66, no IOSTANDARD needed for GT)
set_property LOC GTHE3_CHANNEL_X0Y10 [get_cells {eth_10gmphy/inst/i_eth_10G_mphy_gt/inst/gen_gtwizard_gthe3_top.eth_10G_mphy_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[2].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X0Y10 [get_cells {eth_10G/inst/i_eth_10G_gt/inst/gen_gtwizard_gthe3_top.eth_10G_gt_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[2].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}]
set_property PACKAGE_PIN T2 [get_ports gt_rx_in_p]
set_property PACKAGE_PIN T1 [get_ports gt_rx_in_n]
set_property PACKAGE_PIN U4 [get_ports gt_tx_out_p]
set_property PACKAGE_PIN U3 [get_ports gt_tx_out_n]
#set_property PACKAGE_PIN V2 [get_ports sfp1_rxp]
#set_property PACKAGE_PIN V1 [get_ports sfp1_rxn]




# Configure system reset signal
# - Reset button/input at AY22 location
# - LVCMOS18 I/O standard for 1.8V logic level
# - Used for global system reset functionality
#set_property -dict {
#    PACKAGE_PIN AY22
#    IOSTANDARD LVCMOS18
#} [get_ports sys_reset]

set_property PACKAGE_PIN AN8 [get_ports sys_reset]
set_property IOSTANDARD LVCMOS18 [get_ports sys_reset]
set_property PULLTYPE PULLDOWN [get_ports sys_reset]




set_property PACKAGE_PIN AP8 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[0]}]

set_property PACKAGE_PIN H23 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[1]}]

set_property PACKAGE_PIN P20 [get_ports {led[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[2]}]

set_property PACKAGE_PIN P21 [get_ports {led[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[3]}]

set_property PACKAGE_PIN N22 [get_ports {led[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {led[4]}]



#Adaptor board's LPC pins

#set_property PACKAGE_PIN G9 [get_ports clk_720m_p] # H PC LA01_CC
#set_property PACKAGE_PIN F9 [get_ports clk_720m_n]
set_property PACKAGE_PIN W23 [get_ports clk_720m_p] #LPC LA00_CC
set_property PACKAGE_PIN W24 [get_ports clk_720m_n]
#set_property PACKAGE_PIN W25 [get_ports clk_720m_p] #LPC LA01_CC
#set_property PACKAGE_PIN Y25 [get_ports clk_720m_n]
#set_property PACKAGE_PIN T6 [get_ports clk_720m_p] #GBTCLK0_M2C
#set_property PACKAGE_PIN T5 [get_ports clk_720m_n]
#set_property PACKAGE_PIN D23 [get_ports clk_720m_p] #USER_SMA_CLOCK
#set_property PACKAGE_PIN C23 [get_ports clk_720m_n]
#set_property PACKAGE_PIN AA24 [get_ports clk_720m_p] #LPC CLK0_M2C
#set_property PACKAGE_PIN AA25 [get_ports clk_720m_n]
#set_property PACKAGE_PIN AC31 [get_ports clk_720m_p] #LPC CLK1_M2C
#set_property PACKAGE_PIN AC32 [get_ports clk_720m_n]
set_property IOSTANDARD LVDS [get_ports clk_720m_p]
set_property IOSTANDARD LVDS [get_ports clk_720m_n]
set_property DIFF_TERM_ADV TERM_100 [get_ports clk_720m_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports clk_720m_n]
#set_property DIFF_TERM_ADV TERM_100 [get_ports clk_720m_p]
#set_property DIFF_TERM_ADV TERM_100 [get_ports clk_720m_n]



#set_property PACKAGE_PIN W25 [get_ports data_p] #LPC LA01_CC
#set_property PACKAGE_PIN Y25 [get_ports data_n]
#set_property PACKAGE_PIN AB25 [get_ports data_p] #LPC LA15
#set_property PACKAGE_PIN AB26 [get_ports data_n]
set_property PACKAGE_PIN U21 [get_ports data_p] #LPC LA14
set_property PACKAGE_PIN U22 [get_ports data_n]
#set_property PACKAGE_PIN W33 [get_ports data_p] #LPC LA33  SMA2
#set_property PACKAGE_PIN Y33 [get_ports data_n]

#set_property PACKAGE_PIN V21 [get_ports data_p] #LPC LA11
#set_property PACKAGE_PIN W21 [get_ports data_n]

set_property IOSTANDARD LVDS [get_ports data_p]
set_property IOSTANDARD LVDS [get_ports data_n]
set_property DIFF_TERM_ADV TERM_100 [get_ports data_p]
set_property DIFF_TERM_ADV TERM_100 [get_ports data_n]
#set_property DIFF_TERM_ADV TERM_100 [get_ports data_p]
#set_property DIFF_TERM_ADV TERM_100 [get_ports data_n]
#set_property DIFF_TERM TRUE [get_ports data_n]


set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]

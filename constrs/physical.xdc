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
set_property PACKAGE_PIN U4 [get_ports gt_tx_out_p]
set_property PACKAGE_PIN U3 [get_ports gt_tx_out_n]
#set_property PACKAGE_PIN W4 [get_ports sfp1_txp]
#set_property PACKAGE_PIN W3 [get_ports sfp1_txn]

# TX Control output (LVCMOS18, Bank 65/66)
set_property PACKAGE_PIN AL8 [get_ports sfp0_tx_disable]
# set_property PACKAGE_PIN D28 [get_ports sfp1_tx_disable]
set_property IOSTANDARD LVCMOS18 [get_ports {sfp0_tx_disable}]


# SFP+ RX Differential Pairs (Bank 66, no IOSTANDARD needed for GT)
set_property PACKAGE_PIN T2 [get_ports gt_rx_in_p]
set_property PACKAGE_PIN T1 [get_ports gt_rx_in_n]
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
set_property IOSTANDARD  LVCMOS18 [get_ports {led[0]}]

set_property PACKAGE_PIN H23 [get_ports {led[1]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {led[1]}]

set_property PACKAGE_PIN P20 [get_ports {led[2]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {led[2]}]

set_property PACKAGE_PIN P21 [get_ports {led[3]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {led[3]}]

set_property PACKAGE_PIN N22 [get_ports {led[4]}]
set_property IOSTANDARD  LVCMOS18 [get_ports {led[4]}]


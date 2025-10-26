# =============================================
# Physical Pin Constraints - Using -dict format
# =============================================

# Configure system clock differential pair (300MHz)
# - Positive pin of differential clock at bank AW14
# - LVDS I/O standard for high-speed differential signaling
set_property -dict { 
    IOSTANDARD LVDS 
    PACKAGE_PIN AW14 
} [get_ports sys_clk_300Mhz_p]

# Configure GT reference clock input
# - GT reference clock pin at Y11 location
# - Used for Gigabit Transceiver reference clock (typically 156.25MHz)
set_property -dict {
    PACKAGE_PIN Y11
} [get_ports gt_refclk_in_p]

# Configure GT transmit output differential pair
# - Positive pin of GT transmitter at AA9 location
# - High-speed serial output for Ethernet data transmission
set_property -dict {
    PACKAGE_PIN AA9
} [get_ports gt_tx_out_p]

# Configure system reset signal
# - Reset button/input at AY22 location  
# - LVCMOS18 I/O standard for 1.8V logic level
# - Used for global system reset functionality
set_property -dict {
    PACKAGE_PIN AY22
    IOSTANDARD LVCMOS18
} [get_ports sys_reset]
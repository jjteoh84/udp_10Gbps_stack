# =============================================
# FPGA UDP Project Creation and Configuration Script
# =============================================

# Get current working directory path
set DIR [pwd]

# Create new project
# - Project name: fpga_udp
# - Project path: $DIR/fpga_udp
# - FPGA part: xcvu5p-flvb2104-2-i (UltraScale+ family)
# - force: overwrite if project already exists
create_project fpga_udp $DIR/fpga_udp -part xcvu5p-flvb2104-2-i -force

# =============================================
# Add design source files (RTL code)
# =============================================
add_files -fileset [get_filesets sources_1] {
    ../../rtl/mac_rx_mode.v       
    ../../rtl/eth_axis_fifo.v     
    ../../rtl/xpm_sync_fifo.v        
    ../../rtl/us_ip_tx_mode.v        
    ../../rtl/udp_stack_top.v      
    ../../rtl/us_ip_rx_mode.v  
    ../../rtl/us_arp_rx.v         
    ../../rtl/us_ip_rx.v             
    ../../rtl/us_mac_rx.v              
    ../../rtl/us_arp_table.v          
    ../../rtl/us_ip_tx.v              
    ../../rtl/eth_frame_tx.v         
    ../../rtl/us_udp_tx_v1.v      
    ../../rtl/mac_tx_mode.v       
    ../../rtl/axis_counter.v        
    ../../rtl/eth_frame_rx.v      
    ../../rtl/us_mac_tx.v            
    ../../rtl/us_arp_tx.v          
    ../../rtl/us_udp_rx.v            
    ../../rtl/us_udp_tx.v              
    ../rtl/top_udp.sv                   
    ../../rtl/us_icmp_reply.v          
}

# Set top module for synthesis and implementation
set_property top top_udp [current_fileset]

# Update compilation order for source files
update_compile_order -fileset sources_1

# =============================================
# Add simulation testbenches
# =============================================
# Set source set for simulation
set_property SOURCE_SET sources_1 [get_filesets sim_1]

# Add testbench files to simulation fileset
add_files -fileset sim_1 {
    ../../tb/tb_mac_rx.v               
    ../../tb/tb_udp_tx.v              
    ../../tb/tb_mac_tx.v              
    ../../tb/tb_arp_tx.v              
    ../../tb/tb_icmp_reply.v           
    ../../tb/tb_udp_rx.v                
    ../../tb/tb_xpm_sync_fifo.v         
    ../../tb/tb_eth_frame_tx.v          
    ../../tb/tb_axis_count.v            
    ../../tb/tb_udp_stack_top.sv       
    ../../tb/tb_us_ip_rx.v              
    ../../tb/tb_us_ip_tx.v            
}

# Update compilation order for simulation files
update_compile_order -fileset sim_1

# =============================================
# Add constraint files
# =============================================
add_files -fileset constrs_1 {
    constrs/physical.xdc             
    constrs/timing.xdc                 
}

# =============================================
# Configure simulation settings
# =============================================
# Set top module for simulation
set_property top tb_udp_stack_top [get_filesets sim_1]

# Set default library for simulation
set_property top_lib xil_defaultlib [get_filesets sim_1]

# Update compilation order for simulation
update_compile_order -fileset sim_1

# =============================================
# Create 10G Ethernet IP core
# =============================================
# Create XXV Ethernet IP for 10G Ethernet
create_ip -name xxv_ethernet -vendor xilinx.com -library ip -module_name eth_10G_mphy
set_property -dict [list \
  CONFIG.Component_Name {eth_10G_mphy} \
  CONFIG.GT_GROUP_SELECT {Quad_X1Y4} \
  CONFIG.LINE_RATE {10} \
] [get_ips eth_10G_mphy]

update_compile_order -fileset sources_1

launch_runs synth_1 -jobs 8
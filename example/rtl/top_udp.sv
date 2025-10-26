/****************************************************************************
 * @file    top_udp.v
 * @brief  
 * @author  weslie (zzhi4832@gmail.com)
 * @version 1.0
 * @date    2025-01-22
 * 
 * @par :
 * ___________________________________________________________________________
 * |    Date       |  Version    |       Author     |       Description      |
 * |---------------|-------------|------------------|------------------------|
 * |               |   v1.0      |    weslie        |                        |
 * |---------------|-------------|------------------|------------------------|
 * 
 * @copyright Copyright (c) 2025 welie
 * ***************************************************************************/
`default_nettype none
`timescale 1ns/1ps

module top_udp(
    input   wire    gt_refclk_in_p,
    input   wire    gt_refclk_in_n,

    input   wire    sys_reset,

    input   wire    sys_clk_300Mhz_p,
    input   wire    sys_clk_300Mhz_n,

    input   wire    gt_rx_in_p,
    input   wire    gt_rx_in_n,
    output  wire    gt_tx_out_n,
    output  wire    gt_tx_out_p
);


/****************************************************************
 * 10Gbps eth mac and phy interface signals
 *   for xxv_ethernet
 ***************************************************************/
wire [0:0]      rx_core_clk                 ;
wire [0:0]      rx_clk_out                  ;
wire [0:0]      tx_clk_out                  ;

wire [0:0]      gtpowergood                 ;
wire [2:0]      gt_loopback_in              ;

// RX  Control Signals
wire            ctl_rx_test_pattern         ;
wire            ctl_rx_test_pattern_enable  ;
wire            ctl_rx_data_pattern_select  ;
wire            ctl_rx_enable               ;
wire            ctl_rx_delete_fcs           ;
wire            ctl_rx_ignore_fcs           ;
wire [14:0]     ctl_rx_max_packet_len       ;
wire [7:0]      ctl_rx_min_packet_len       ;
wire            ctl_rx_custom_preamble_enable;
wire            ctl_rx_check_sfd            ;
wire            ctl_rx_check_preamble       ;
wire            ctl_rx_process_lfi          ;
wire            ctl_rx_force_resync         ;
//// TX_0 Control Signals
wire            ctl_tx_test_pattern         ;
wire            ctl_tx_test_pattern_enable  ;
wire            ctl_tx_test_pattern_select  ;
wire            ctl_tx_data_pattern_select  ;
wire [57:0]     ctl_tx_test_pattern_seed_a  ;
wire [57:0]     ctl_tx_test_pattern_seed_b  ;
wire            ctl_tx_enable               ;
wire            ctl_tx_fcs_ins_enable       ;
wire [3:0]      ctl_tx_ipg_value            ;
wire            ctl_tx_send_lfi             ;
wire            ctl_tx_send_rfi             ;
wire            ctl_tx_send_idle            ;
wire            ctl_tx_custom_preamble_enable;
wire            ctl_tx_ignore_fcs           ;

wire [3:0]      gtwiz_reset_tx_datapath     ;
wire [3:0]      gtwiz_reset_rx_datapath     ;

wire [2:0]      txoutclksel_in              ;
wire [2:0]      rxoutclksel_in              ;

wire            user_tx_reset               ;
wire            user_rx_reset               ;
wire            gt_refclk_out               ;

/****************************************************************
 * udp stack signals
 *   for 10Gbps stack
 ***************************************************************/
wire            tx_axis_aclk = tx_clk_out;
wire            rx_axis_aclk = rx_clk_out;

wire            tx_axis_aresetn = ~user_tx_reset;
wire            rx_axis_aresetn = ~user_rx_reset;

wire    [31:0]  src_ip_addr = {8'd192,8'd168,8'd1,8'd123};
wire    [31:0]  dst_ip_addr = {8'd192,8'd168,8'd1,8'd129};

wire    [15:0]  udp_src_port=  16'h8080;
wire    [15:0]  udp_dst_port=  16'h4562;

wire    [47:0]  local_mac_addr = {8'hac, 8'h14, 8'h74, 8'h45, 8'hbc, 8'hf4};

wire            udp_enable          ;

wire    [63:0]  udp_tx_axis_tdata   ;
wire    [7:0]   udp_tx_axis_tkeep   ;
wire            udp_tx_axis_tvalid  ;  
wire            udp_tx_axis_tlast   ;
wire            udp_tx_axis_tready  ;

wire [63:0]     udp_rx_axis_tdata   ;
wire [7:0]     	udp_rx_axis_tkeep   ;
wire            udp_rx_axis_tvalid  ; 		 
wire            udp_rx_axis_tlast   ;
wire            udp_rx_axis_tuser   ;

wire [63:0]     mac_tx_axis_tdata   ;
wire [7:0]      mac_tx_axis_tkeep   ;
wire            mac_tx_axis_tvalid  ;
wire            mac_tx_axis_tlast   ;
wire            mac_tx_axis_tready  ;

wire[63:0]      mac_rx_axis_tdata   ;
wire[7:0]       mac_rx_axis_tkeep   ;
wire            mac_rx_axis_tvalid  ;
wire            mac_rx_axis_tuser   ;
wire            mac_rx_axis_tlast   ;

wire            empty               ;
/****************************************************************
 * Convert the 300MHz differential clock to a 300MHz single-ended 
 * clock, which is used for mmcm frequency division
 ***************************************************************/
wire    sys_clk_300Mhz;
    
IBUFGDS #(
    .DIFF_TERM("FALSE"),    // Differential Termination (Virtex-4/5, Spartan-3E/3A)
    .IBUF_DELAY_VALUE("0"), // Specify the amount of added input delay for 
    .IOSTANDARD("DEFAULT")  // Specify the input I/O standard
) IBUFGDS_inst (
    .O  (sys_clk_300Mhz),  // Clock buffer output
    .I  (sys_clk_300Mhz_p),  // Diff_p clock buffer input (connect directly to top-level port)
    .IB (sys_clk_300Mhz_n) // Diff_n clock buffer input (connect directly to top-level port)
);


/****************************************************************
 * The mmcm module is used to divide the 300MHz single-ended 
 * clock into 100MHz single-ended clocks
 *
 * computational formula:
 *   Fout = (Fin * MULT_F) / (DIVCLK_DIVIDE * CLKOUTn_DIVIDE)
 *   fout = 100MHz ; fin = 300MHz ; MMULT_F = 1;
 *   DIVCLK_DIVIDE = 3; CLKOUTn_DIVIDE = 1;
 ***************************************************************/

wire    sys_clk_100MHz_ibufg;
wire    sys_clk_fb;
wire    sys_clk_100MHz;

MMCME3_BASE #(
   .BANDWIDTH("OPTIMIZED"),    // Jitter programming (HIGH, LOW, OPTIMIZED)
   .CLKFBOUT_MULT_F(10),      // Multiply value for all CLKOUT (2.000-64.000)
   .CLKFBOUT_PHASE(0.0),       // Phase offset in degrees of CLKFB (-360.000-360.000)
   .CLKIN1_PERIOD(3.333),        // Input clock period in ns units, ps resolution (i.e., 33.333 is 30 MHz).
   .CLKOUT0_DIVIDE_F(10),     // Divide amount for CLKOUT0 (1.000-128.000)
   // CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.001-0.999).
   .CLKOUT0_DUTY_CYCLE(0.5),
   .CLKOUT1_DUTY_CYCLE(0.5),
   .CLKOUT2_DUTY_CYCLE(0.5),
   .CLKOUT3_DUTY_CYCLE(0.5),
   .CLKOUT4_DUTY_CYCLE(0.5),
   .CLKOUT5_DUTY_CYCLE(0.5),
   .CLKOUT6_DUTY_CYCLE(0.5),
   // CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
   .CLKOUT0_PHASE(0.0),
   .CLKOUT1_PHASE(0.0),
   .CLKOUT2_PHASE(0.0),
   .CLKOUT3_PHASE(0.0),
   .CLKOUT4_PHASE(0.0),
   .CLKOUT5_PHASE(0.0),
   .CLKOUT6_PHASE(0.0),
   // CLKOUT1_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
   .CLKOUT1_DIVIDE(1),
   .CLKOUT2_DIVIDE(1),
   .CLKOUT3_DIVIDE(1),
   .CLKOUT4_DIVIDE(1),
   .CLKOUT5_DIVIDE(1),
   .CLKOUT6_DIVIDE(1),
   .CLKOUT4_CASCADE("FALSE"),  // Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
   .DIVCLK_DIVIDE(3),          // Master division value (1-106)
   // Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
   .IS_CLKFBIN_INVERTED(1'b0), // Optional inversion for CLKFBIN
   .IS_CLKIN1_INVERTED(1'b0),  // Optional inversion for CLKIN1
   .IS_PWRDWN_INVERTED(1'b0),  // Optional inversion for PWRDWN
   .IS_RST_INVERTED(1'b0),     // Optional inversion for RST
   .REF_JITTER1(0.0),          // Reference input jitter in UI (0.000-0.999)
   .STARTUP_WAIT("FALSE")      // Delays DONE until MMCM is locked (FALSE, TRUE)
)
MMCME3_BASE_inst (
   // Clock Outputs outputs: User configurable clock outputs
   .CLKOUT0 (sys_clk_100MHz_ibufg),     // 1-bit output: CLKOUT0
   .CLKOUT0B(),   // 1-bit output: Inverted CLKOUT0
   .CLKOUT1 (),     // 1-bit output: CLKOUT1
   .CLKOUT1B(),   // 1-bit output: Inverted CLKOUT1
   .CLKOUT2 (),     // 1-bit output: CLKOUT2
   .CLKOUT2B(),   // 1-bit output: Inverted CLKOUT2
   .CLKOUT3 (),     // 1-bit output: CLKOUT3
   .CLKOUT3B(),   // 1-bit output: Inverted CLKOUT3
   .CLKOUT4 (),     // 1-bit output: CLKOUT4
   .CLKOUT5 (),     // 1-bit output: CLKOUT5
   .CLKOUT6 (),     // 1-bit output: CLKOUT6
   // Feedback outputs: Clock feedback ports
   .CLKFBOUT(sys_clk_fb),   // 1-bit output: Feedback clock
   .CLKFBOUTB(), // 1-bit output: Inverted CLKFBOUT
   // Status Ports outputs: MMCM status ports
   .LOCKED  (),       // 1-bit output: LOCK
   // Clock Inputs inputs: Clock input
   .CLKIN1  (sys_clk_300Mhz),       // 1-bit input: Clock
   // Control Ports inputs: MMCM control ports
   .PWRDWN  (),       // 1-bit input: Power-down
   .RST     (sys_reset),             // 1-bit input: Reset
   // Feedback inputs: Clock feedback ports
   .CLKFBIN (sys_clk_fb)      // 1-bit input: Feedback clock
);

BUFG BUFG_inst (
    .O(sys_clk_100MHz),     // Clock buffer output
    .I(sys_clk_100MHz_ibufg)      // Clock buffer input
);


xpm_fifo_axis #(
    .CASCADE_HEIGHT(0),             // DECIMAL
    .CDC_SYNC_STAGES(2),            // DECIMAL
    .CLOCKING_MODE("common_clock"), // String
    .ECC_MODE("no_ecc"),            // String
    .FIFO_DEPTH(2048),              // DECIMAL
    .FIFO_MEMORY_TYPE("auto"),      // String
    .PACKET_FIFO("false"),          // String
    .PROG_EMPTY_THRESH(10),         // DECIMAL
    .PROG_FULL_THRESH(10),          // DECIMAL
    .RD_DATA_COUNT_WIDTH(12),        // DECIMAL
    .RELATED_CLOCKS(0),             // DECIMAL
    .SIM_ASSERT_CHK(1),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .TDATA_WIDTH(64),               // DECIMAL
    .TDEST_WIDTH(1),                // DECIMAL
    .TID_WIDTH(1),                  // DECIMAL
    .TUSER_WIDTH(1),                // DECIMAL
    .USE_ADV_FEATURES("1000"),      // String
    .WR_DATA_COUNT_WIDTH(12)         // DECIMAL
)
xpm_fifo_udp_data_echo (
    .almost_empty_axis  (empty),   
    .almost_full_axis   (),     
    .dbiterr_axis       (),             
    .m_axis_tdata       (udp_tx_axis_tdata),             
    .m_axis_tdest       (),             
    .m_axis_tid         (),                 
    .m_axis_tkeep       (udp_tx_axis_tkeep),             
    .m_axis_tlast       (udp_tx_axis_tlast),             
    .m_axis_tstrb       (),             
    .m_axis_tuser       (),             
    .m_axis_tvalid      (udp_tx_axis_tvalid),           
    .prog_empty_axis    (),       
    .prog_full_axis     (),         
    .rd_data_count_axis (), 
    .s_axis_tready      (1'b1),           
    .sbiterr_axis       (),             
    .wr_data_count_axis (), 
    .injectdbiterr_axis (), 
    .injectsbiterr_axis (), 
    .m_aclk             (tx_axis_aclk),                         
    .m_axis_tready      (udp_tx_axis_tready),           
    .s_aclk             (rx_axis_aclk),                         
    .s_aresetn          (rx_axis_aresetn),                   
    .s_axis_tdata       (udp_rx_axis_tdata),            
    .s_axis_tdest       (),            
    .s_axis_tid         (),                
    .s_axis_tkeep       (udp_rx_axis_tkeep),             
    .s_axis_tlast       (udp_rx_axis_tlast),             
    .s_axis_tstrb       (),             
    .s_axis_tuser       (),             
    .s_axis_tvalid      (udp_rx_axis_tvalid)            
);


udp_stack_top u_udp_stack_top(
    .tx_axis_aclk       	(tx_axis_aclk        ),
    .tx_axis_aresetn    	(tx_axis_aresetn     ),
    .rx_axis_aclk       	(rx_axis_aclk        ),
    .rx_axis_aresetn    	(rx_axis_aresetn     ),
    .src_ip_addr        	(src_ip_addr         ),
    .dst_ip_addr        	(dst_ip_addr         ),
    .src_mac_addr       	(local_mac_addr      ),
    .udp_src_port       	(udp_src_port        ),
    .udp_dst_port       	(udp_dst_port        ),
    .udp_enable         	(udp_enable          ),
    .udp_tx_axis_tdata  	(udp_tx_axis_tdata   ),
    .udp_tx_axis_tkeep  	(udp_tx_axis_tkeep   ),
    .udp_tx_axis_tvalid 	(udp_tx_axis_tvalid  ),
    .udp_tx_axis_tlast  	(udp_tx_axis_tlast   ),
    .udp_tx_axis_tready 	(udp_tx_axis_tready  ),
    .udp_rx_axis_tdata  	(udp_rx_axis_tdata   ),
    .udp_rx_axis_tkeep  	(udp_rx_axis_tkeep   ),
    .udp_rx_axis_tvalid 	(udp_rx_axis_tvalid  ),
    .udp_rx_axis_tlast  	(udp_rx_axis_tlast   ),
    .udp_rx_axis_tuser  	(udp_rx_axis_tuser   ),
    .mac_tx_axis_tdata  	(mac_tx_axis_tdata   ),
    .mac_tx_axis_tkeep  	(mac_tx_axis_tkeep   ),
    .mac_tx_axis_tvalid 	(mac_tx_axis_tvalid  ),
    .mac_tx_axis_tlast  	(mac_tx_axis_tlast   ),
    .mac_tx_axis_tready 	(mac_tx_axis_tready  ),
    .mac_rx_axis_tdata  	(mac_rx_axis_tdata   ),
    .mac_rx_axis_tkeep  	(mac_rx_axis_tkeep   ),
    .mac_rx_axis_tvalid 	(mac_rx_axis_tvalid  ),
    .mac_rx_axis_tuser  	(mac_rx_axis_tuser   ),
    .mac_rx_axis_tlast  	(mac_rx_axis_tlast   )
);

assign rx_core_clk                = tx_clk_out;
assign gt_loopback_in             = 2'h00;
assign ctl_rx_enable              = 1'b1;
assign ctl_rx_check_preamble      = 1'b1;
assign ctl_rx_check_sfd           = 1'b1;
assign ctl_rx_force_resync        = 1'b0;
assign ctl_rx_delete_fcs          = 1'b1;
assign ctl_rx_ignore_fcs          = 1'b0;
assign ctl_rx_process_lfi         = 1'b0;
assign ctl_rx_test_pattern        = 1'b0;
assign ctl_rx_test_pattern_enable = 1'b0;
assign ctl_rx_data_pattern_select = 1'b0;
assign ctl_rx_max_packet_len      = 15'd1536;
assign ctl_rx_min_packet_len      = 15'd42;
assign ctl_rx_custom_preamble_enable = 1'b0;


assign ctl_tx_enable              = 1'b1;
assign ctl_tx_send_rfi            = 1'b0;
assign ctl_tx_send_lfi            = 1'b0;
assign ctl_tx_send_idle           = 1'b0;
assign ctl_tx_fcs_ins_enable      = 1'b1;
assign ctl_tx_ignore_fcs          = 1'b0;
assign ctl_tx_test_pattern        = 1'b0;
assign ctl_tx_test_pattern_enable = 1'b0;
assign ctl_tx_data_pattern_select = 1'b0;
assign ctl_tx_test_pattern_select = 1'b0;
assign ctl_tx_test_pattern_seed_a = 58'h0;
assign ctl_tx_test_pattern_seed_b = 58'h0;
assign ctl_tx_custom_preamble_enable = 1'b0;
assign ctl_tx_ipg_value           = 4'd12;

assign gtwiz_reset_tx_datapath    = 4'b0000;
assign gtwiz_reset_rx_datapath    = 4'b0000;

assign txoutclksel_in             = 3'b101;    // this value should not be changed as per gtwizard 
assign rxoutclksel_in             = 3'b101;    // this value should not be changed as per gtwizard
// assign txoutclksel_in[1] = 3'b101;    // this value should not be changed as per gtwizard 
// assign rxoutclksel_in[1] = 3'b101;    // this value should not be changed as per gtwizard
// assign txoutclksel_in[2] = 3'b101;    // this value should not be changed as per gtwizard 
// assign rxoutclksel_in[2] = 3'b101;    // this value should not be changed as per gtwizard
// assign txoutclksel_in[3] = 3'b101;    // this value should not be changed as per gtwizard 
// assign rxoutclksel_in[3] = 3'b101;    // this value should not be changed as per gtwizard



eth_10G_mphy eth_10gmphy (
  .gt_rxp_in_0                      (gt_rx_in_p),                                           
  .gt_rxn_in_0                      (gt_rx_in_n),                                          
  .gt_txp_out_0                     (gt_tx_out_p),                                        
  .gt_txn_out_0                     (gt_tx_out_n),                                         

  .rx_core_clk_0                    (rx_core_clk),                                      

  .txoutclksel_in_0                 (txoutclksel_in),                                
  .rxoutclksel_in_0                 (rxoutclksel_in),                                

  .gtwiz_reset_tx_datapath_0        (gtwiz_reset_tx_datapath),         
  .gtwiz_reset_rx_datapath_0        (gtwiz_reset_rx_datapath),             

  .rxrecclkout_0                    (),                                

  .sys_reset                        (sys_reset),                                                
  .dclk                             (sys_clk_100MHz),                                                           
  .tx_clk_out_0                     (tx_clk_out),                                          
  .rx_clk_out_0                     (rx_clk_out),                                           
  .gt_refclk_p                      (gt_refclk_in_p),                                             
  .gt_refclk_n                      (gt_refclk_in_n),                                             
  .gt_refclk_out                    (gt_refclk_out),                                        

  .gtpowergood_out_0                (gtpowergood),                          

  .rx_reset_0                       (1'b0),                                       
  .user_rx_reset_0                  (user_rx_reset),                          

  .rx_axis_tvalid_0                 (mac_rx_axis_tvalid),                                  
  .rx_axis_tdata_0                  (mac_rx_axis_tdata),                                    
  .rx_axis_tlast_0                  (mac_rx_axis_tlast),                                    
  .rx_axis_tkeep_0                  (mac_rx_axis_tkeep),                                    
  .rx_axis_tuser_0                  (mac_rx_axis_tuser),                                    

  .ctl_rx_enable_0                  (ctl_rx_enable),                                     
  .ctl_rx_check_preamble_0          (ctl_rx_check_preamble),                     
  .ctl_rx_check_sfd_0               (ctl_rx_check_sfd),                               
  .ctl_rx_force_resync_0            (ctl_rx_force_resync),                         
  .ctl_rx_delete_fcs_0              (ctl_rx_delete_fcs),                             
  .ctl_rx_ignore_fcs_0              (ctl_rx_ignore_fcs),                             
  .ctl_rx_max_packet_len_0          (ctl_rx_max_packet_len),                     
  .ctl_rx_min_packet_len_0          (ctl_rx_min_packet_len),                     
  .ctl_rx_process_lfi_0             (ctl_rx_process_lfi),                           
  .ctl_rx_test_pattern_0            (ctl_rx_test_pattern),                         
  .ctl_rx_data_pattern_select_0     (ctl_rx_data_pattern_select),           
  .ctl_rx_test_pattern_enable_0     (ctl_rx_test_pattern_enable),           
  .ctl_rx_custom_preamble_enable_0  (ctl_rx_custom_preamble_enable),    

  .tx_reset_0                       (1'b0),                                            
  .user_tx_reset_0                  (user_tx_reset),                                   

  .tx_axis_tready_0                 (mac_tx_axis_tready),                                  
  .tx_axis_tvalid_0                 (mac_tx_axis_tvalid),                                  
  .tx_axis_tdata_0                  (mac_tx_axis_tdata),                                    
  .tx_axis_tlast_0                  (mac_tx_axis_tlast),                                    
  .tx_axis_tkeep_0                  (mac_tx_axis_tkeep),                                    
  .tx_axis_tuser_0                  (1'b0),                                    

  .ctl_tx_enable_0                  (ctl_tx_enable),                                     
  .ctl_tx_send_rfi_0                (ctl_tx_send_rfi),                                
  .ctl_tx_send_lfi_0                (ctl_tx_send_lfi),                                
  .ctl_tx_send_idle_0               (ctl_tx_send_idle),                               
  .ctl_tx_fcs_ins_enable_0          (ctl_tx_fcs_ins_enable),                     
  .ctl_tx_ignore_fcs_0              (ctl_tx_ignore_fcs),                             
  .ctl_tx_test_pattern_0            (ctl_tx_test_pattern),                         
  .ctl_tx_test_pattern_enable_0     (ctl_tx_test_pattern_enable),           
  .ctl_tx_test_pattern_select_0     (ctl_tx_test_pattern_select),           
  .ctl_tx_data_pattern_select_0     (ctl_tx_data_pattern_select),           
  .ctl_tx_test_pattern_seed_a_0     (ctl_tx_test_pattern_seed_a),           
  .ctl_tx_test_pattern_seed_b_0     (ctl_tx_test_pattern_seed_b),           
  .ctl_tx_ipg_value_0               (ctl_tx_ipg_value),                               
  .ctl_tx_custom_preamble_enable_0  (ctl_tx_custom_preamble_enable),     

  .tx_unfout_0                      (),                                            
  .tx_preamblein_0                  (1'b0),                                     
  .rx_preambleout_0                 (),                                   

  .gt_loopback_in_0                 (gt_loopback_in),                                
  .qpllreset_in_0                   (1'b0) 
//   .stat_tx_local_fault_0            (),                   
//   .stat_tx_total_bytes_0            (),                   
//   .stat_tx_total_packets_0          (),                   
//   .stat_tx_total_good_bytes_0       (),              
//   .stat_tx_total_good_packets_0     (),         
//   .stat_tx_bad_fcs_0                (),                               
//   .stat_tx_packet_64_bytes_0        (),               
//   .stat_tx_packet_65_127_bytes_0    (),        
//   .stat_tx_packet_128_255_bytes_0   (),      
//   .stat_tx_packet_256_511_bytes_0   (),      
//   .stat_tx_packet_512_1023_bytes_0  (),    
//   .stat_tx_packet_1024_1518_bytes_0 (),   
//   .stat_tx_packet_1519_1522_bytes_0 (),   
//   .stat_tx_packet_1523_1548_bytes_0 (),   
//   .stat_tx_packet_1549_2047_bytes_0 (),   
//   .stat_tx_packet_2048_4095_bytes_0 (),   
//   .stat_tx_packet_4096_8191_bytes_0 (),   
//   .stat_tx_packet_8192_9215_bytes_0 (),   
//   .stat_tx_packet_small_0           (),                  
//   .stat_tx_packet_large_0           (),                     
//   .stat_tx_unicast_0                (),                           
//   .stat_tx_multicast_0              (),                 
//   .stat_tx_broadcast_0              (),                       
//   .stat_tx_vlan_0                   (),                                
//   .stat_tx_frame_error_0            (),                      


//   .stat_rx_framing_err_0            (),                   
//   .stat_rx_framing_err_valid_0      (),            
//   .stat_rx_local_fault_0            (),                        
//   .stat_rx_block_lock_0             (),                          
//   .stat_rx_valid_ctrl_code_0        (),                
//   .stat_rx_status_0                 (),                                  
//   .stat_rx_remote_fault_0           (),                      
//   .stat_rx_bad_fcs_0                (),                                
//   .stat_rx_stomped_fcs_0            (),                        
//   .stat_rx_truncated_0              (),                            
//   .stat_rx_internal_local_fault_0   (),      
//   .stat_rx_received_local_fault_0   (),      
//   .stat_rx_hi_ber_0                 (),                                  
//   .stat_rx_got_signal_os_0          (),                    
//   .stat_rx_test_pattern_mismatch_0  (),    
//   .stat_rx_total_bytes_0            (),                        
//   .stat_rx_total_packets_0          (),                    
//   .stat_rx_total_good_bytes_0       (),              
//   .stat_rx_total_good_packets_0     (),          
//   .stat_rx_packet_bad_fcs_0         (),                  
//   .stat_rx_packet_64_bytes_0        (),                
//   .stat_rx_packet_65_127_bytes_0    (),        
//   .stat_rx_packet_128_255_bytes_0   (),      
//   .stat_rx_packet_256_511_bytes_0   (),      
//   .stat_rx_packet_512_1023_bytes_0  (),    
//   .stat_rx_packet_1024_1518_bytes_0 (),  
//   .stat_rx_packet_1519_1522_bytes_0 (),  
//   .stat_rx_packet_1523_1548_bytes_0 (),  
//   .stat_rx_packet_1549_2047_bytes_0 (),  
//   .stat_rx_packet_2048_4095_bytes_0 (),  
//   .stat_rx_packet_4096_8191_bytes_0 (),  
//   .stat_rx_packet_8192_9215_bytes_0 (),  
//   .stat_rx_packet_small_0           (),                      
//   .stat_rx_packet_large_0           (),                      
//   .stat_rx_unicast_0                (),                                
//   .stat_rx_multicast_0              (),                        
//   .stat_rx_broadcast_0              (),                       
//   .stat_rx_oversize_0               (),                        
//   .stat_rx_toolong_0                (),                       
//   .stat_rx_undersize_0              (),                  
//   .stat_rx_fragment_0               (),                      
//   .stat_rx_vlan_0                   (),                                 
//   .stat_rx_inrangeerr_0             (),                    
//   .stat_rx_jabber_0                 (),                              
//   .stat_rx_bad_code_0               (),                         
//   .stat_rx_bad_sfd_0                (),                           
//   .stat_rx_bad_preamble_0           (),                     

                               
);

endmodule //top_udp

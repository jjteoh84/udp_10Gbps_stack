
`timescale 1ns/1ps

module eth_frame_rx(
    input                            	     rx_axis_aclk,
	input                            	     rx_axis_aresetn,
	/* axis interface from mac */	
    input  [63:0]       	     			 mac_rx_axis_tdata,
    input  [7:0]     	     				 mac_rx_axis_tkeep,
    input                            	     mac_rx_axis_tvalid,		 
    input                            	     mac_rx_axis_tlast,
    input                           	     mac_rx_axis_tuser,
	/* udp axis interface to user */	
	output  [63:0]       	     			 udp_rx_axis_tdata,
    output  [7:0]     	     				 udp_rx_axis_tkeep,
    output                            	     udp_rx_axis_tvalid,		 
    output                            	     udp_rx_axis_tlast,
    output                           	     udp_rx_axis_tuser,
	/* axis interface to icmp module */
	output   [63:0]       	     		 	 ip2icmp_axis_tdata,
	output   [7:0]     	     			 	 ip2icmp_axis_tkeep,
	output                           	 	 ip2icmp_axis_tvalid,
	output                           	 	 ip2icmp_axis_tlast,
	output                          	 	 ip2icmp_axis_tuser,
	
	input  [31:0]							 local_ip_addr,
	input  [47:0]							 local_mac_addr,
	input  [31:0]							 dst_ip_addr,
	output [47:0]							 dst_mac_addr,
	
	output                 				 	 arp_reply_req,
	input 	         						 arp_reply_ack,
	input				  					 arp_request_ack,
	output				  					 arp_request_req,
	
	output									 mac_exist,
    output                                   arp_reply_valid,
    output   [79:0]                          arp_register
);

wire    [63:0]  rx_frame_axis_tdata;
wire    [7:0]   rx_frame_axis_tkeep;
wire            rx_frame_axis_tvalid;
wire            rx_frame_axis_tuser;
wire            rx_frame_axis_tlast;

wire    [47:0]  recv_dst_mac_addr;
wire    [47:0]  recv_src_mac_addr;
wire    [15:0]  recv_type;

wire    [63:0]  mac2ip_rx_axis_tdata;
wire    [7:0]   mac2ip_rx_axis_tkeep;
wire            mac2ip_rx_axis_tvalid;
wire            mac2ip_rx_axis_tlast;
wire            mac2ip_rx_axis_tuser;

wire    [63:0]  mac2arp_rx_axis_tdata;
wire    [7:0]   mac2arp_rx_axis_tkeep;
wire            mac2arp_rx_axis_tvalid;
wire            mac2arp_rx_axis_tlast;
wire            mac2arp_rx_axis_tuser;

wire            arp_reply_valid_wire;
wire    [47:0]  arp_recv_src_mac_addr;
wire    [31:0]  arp_recv_src_ip_addr;

wire    [47:0]  frame_dst_mac_addr;

wire    [15:0] ip_type;

wire    [63:0]  ip2app_axis_tdata;
wire    [7:0]   ip2app_axis_tkeep;
wire            ip2app_axis_tvalid;
wire            ip2app_axis_tlast;
wire            ip2app_axis_tuser;

wire    [63:0]  ip2udp_axis_tdata;
wire    [7:0]   ip2udp_axis_tkeep;
wire            ip2udp_axis_tvalid;
wire            ip2udp_axis_tlast;
wire            ip2udp_axis_tuser;

wire    [31:0]  ip_recv_dst_ip_addr;
wire    [31:0]  ip_recv_src_ip_addr;
wire    [31:0]  ip2udp_recv_dst_ip_addr;
wire    [31:0]  ip2udp_recv_src_ip_addr;

(* mark_debug = "true" *) wire [63:0]     mac_rx_axis_tdata;
(* mark_debug = "true" *) wire mac_rx_axis_tlast;
(* mark_debug = "true" *) wire    [63:0]  rx_frame_axis_tdata;
(* mark_debug = "true" *) wire rx_frame_axis_tlast;
(* mark_debug = "true" *) wire    [63:0]  mac2ip_rx_axis_tdata;
(* mark_debug = "true" *) wire    [63:0] ip2app_axis_tdata;
(* mark_debug = "true" *) wire    [63:0] ip2udp_axis_tdata;
(* mark_debug = "true" *) wire    [15:0] ip_type;
(* mark_debug = "true" *) wire    [47:0]  frame_dst_mac_addr;
(* mark_debug = "true" *) wire    [31:0]  ip_recv_dst_ip_addr;
(* mark_debug = "true" *) wire    [31:0]  ip_recv_src_ip_addr;
(* mark_debug = "true" *) wire    [47:0]  recv_dst_mac_addr;
(* mark_debug = "true" *) wire    [47:0]  recv_src_mac_addr;
(* mark_debug = "true" *) wire    [15:0]  recv_type;
(* mark_debug = "true" *) wire [63:0]     udp_rx_axis_tdata   ;
(* mark_debug = "true" *) wire [7:0]     	udp_rx_axis_tkeep   ;
(* mark_debug = "true" *) wire            udp_rx_axis_tvalid  ; 		 
(* mark_debug = "true" *) wire            udp_rx_axis_tlast   ;

// ------------------------------------------------------------------
// Instantiations
// ------------------------------------------------------------------
us_mac_rx mac_rx(
    .rx_axis_aclk          (rx_axis_aclk         ),
    .rx_axis_aresetn       (rx_axis_aresetn      ),
    .rx_mac_axis_tdata     (mac_rx_axis_tdata    ),
    .rx_mac_axis_tkeep     (mac_rx_axis_tkeep    ),
    .rx_mac_axis_tvalid    (mac_rx_axis_tvalid   ),
    .rx_mac_axis_tuser     (mac_rx_axis_tuser    ),
    .rx_mac_axis_tlast     (mac_rx_axis_tlast    ),
    .rx_frame_axis_tdata   (rx_frame_axis_tdata  ),
    .rx_frame_axis_tkeep   (rx_frame_axis_tkeep  ),
    .rx_frame_axis_tvalid  (rx_frame_axis_tvalid ),
    .rx_frame_axis_tuser   (rx_frame_axis_tuser  ),
    .rx_frame_axis_tlast   (rx_frame_axis_tlast  ),
    .recv_dst_mac_addr     (recv_dst_mac_addr    ),
    .recv_src_mac_addr     (recv_src_mac_addr    ),
    .recv_type             (recv_type            ),
    .local_mac_addr        (local_mac_addr       )
);

mac_rx_mode rx_mac_mode(
    .rx_axis_aclk             (rx_axis_aclk            ),
    .rx_axis_aresetn          (rx_axis_aresetn         ),
    .frame_rx_axis_tdata      (rx_frame_axis_tdata     ),
    .frame_rx_axis_tkeep      (rx_frame_axis_tkeep     ),
    .frame_rx_axis_tvalid     (rx_frame_axis_tvalid    ),
    .frame_rx_axis_tlast      (rx_frame_axis_tlast     ),
    .frame_rx_axis_tuser      (rx_frame_axis_tuser     ),
    .rcvd_dst_mac_addr        (recv_dst_mac_addr       ),
    .rcvd_src_mac_addr        (recv_src_mac_addr       ),
    .rcvd_type                (recv_type               ),
    .ip_rx_axis_tdata         (mac2ip_rx_axis_tdata    ),
    .ip_rx_axis_tkeep         (mac2ip_rx_axis_tkeep    ),
    .ip_rx_axis_tvalid        (mac2ip_rx_axis_tvalid   ),
    .ip_rx_axis_tlast         (mac2ip_rx_axis_tlast    ),
    .ip_rx_axis_tuser         (mac2ip_rx_axis_tuser    ),
    .arp_rx_axis_tdata        (mac2arp_rx_axis_tdata   ),
    .arp_rx_axis_tkeep        (mac2arp_rx_axis_tkeep   ),
    .arp_rx_axis_tvalid       (mac2arp_rx_axis_tvalid  ),
    .arp_rx_axis_tlast        (mac2arp_rx_axis_tlast   ),
    .arp_rx_axis_tuser        (mac2arp_rx_axis_tuser   ),
    .frame_mode_dst_mac_addr  (frame_dst_mac_addr      ),
    .frame_mode_src_mac_addr  ( )
);

us_arp_rx u_us_arp_rx(
    .rx_axis_aclk         (rx_axis_aclk        ),
    .rx_axis_aresetn      (rx_axis_aresetn     ),
    .rx_axis_fmac_tdata  	(mac2arp_rx_axis_tdata   ),
    .rx_axis_fmac_tkeep  	(mac2arp_rx_axis_tkeep   ),
    .rx_axis_fmac_tvalid 	(mac2arp_rx_axis_tvalid  ),
    .rx_axis_fmac_tlast  	(mac2arp_rx_axis_tlast   ),
    .rx_axis_fmac_tuser  	(mac2arp_rx_axis_tuser   ),
    // .rx_axis_fmac_tdata   (local_arp_strip_tdata ),
    // .rx_axis_fmac_tkeep   (local_arp_strip_tkeep ),
    // .rx_axis_fmac_tvalid  (local_arp_strip_tvalid),
    // .rx_axis_fmac_tlast   (local_arp_strip_tlast ),
    // .rx_axis_fmac_tuser   (local_arp_strip_tuser ),
    .local_mac_addr       (local_mac_addr      ),
    .local_ip_addr        (local_ip_addr       ),
    .dst_ip_addr          (dst_ip_addr         ),
    .arp_reply_req        (arp_reply_req       ),
    .arp_reply_ack        (arp_reply_ack       ),
    .arp_reply_valid      (arp_reply_valid_wire),
    .recv_src_mac_addr    (arp_recv_src_mac_addr),
    .recv_src_ip_addr     (arp_recv_src_ip_addr)
);

assign arp_reply_valid = arp_reply_valid_wire;

// Rest of instantiations unchanged...
us_arp_table u_arp_table(
    .clk               (rx_axis_aclk          ),
    .rstn              (rx_axis_aresetn       ),
    .recv_src_mac_addr (arp_recv_src_mac_addr ),
    .recv_src_ip_addr  (arp_recv_src_ip_addr  ),
    .arp_valid         (arp_reply_valid_wire  ),
    .arp_request_req   (arp_request_req       ),
    .arp_request_ack   (arp_request_ack       ),
    .arp_mac_exit      (mac_exist             ),
    .dst_ip_addr       (dst_ip_addr           ),
    .dst_mac_addr      (dst_mac_addr          ),
    .arp_register      (arp_register          )
);

us_ip_rx ip_rx(
    .rx_axis_aclk       (rx_axis_aclk        ),
    .rx_axis_aresetn    (rx_axis_aresetn     ),
    .mac_rx_axis_tdata  (mac2ip_rx_axis_tdata),
    .mac_rx_axis_tkeep  (mac2ip_rx_axis_tkeep),
    .mac_rx_axis_tvalid (mac2ip_rx_axis_tvalid),
    .mac_rx_axis_tuser  (mac2ip_rx_axis_tuser),
    .mac_rx_axis_tlast  (mac2ip_rx_axis_tlast),
    .ip_rx_axis_tdata   (ip2app_axis_tdata   ),
    .ip_rx_axis_tkeep   (ip2app_axis_tkeep   ),
    .ip_rx_axis_tvalid  (ip2app_axis_tvalid  ),
    .ip_rx_axis_tuser   (ip2app_axis_tuser   ),
    .ip_rx_axis_tlast   (ip2app_axis_tlast   ),
    .local_ip_addr      (local_ip_addr       ),
    .recv_dst_ip_addr   (ip_recv_dst_ip_addr ),
    .recv_src_ip_addr   (ip_recv_src_ip_addr ),
    .local_mac_addr     (local_mac_addr      ),
    .recv_dst_mac_addr  (frame_dst_mac_addr  ),
    .ip_type            (ip_type             )
);

us_ip_rx_mode ip_rx_mode(
    .rx_axis_aclk        (rx_axis_aclk         ),
    .rx_axis_aresetn     (rx_axis_aresetn      ),
    .ip_rx_axis_tdata    (ip2app_axis_tdata    ),
    .ip_rx_axis_tkeep    (ip2app_axis_tkeep    ),
    .ip_rx_axis_tvalid   (ip2app_axis_tvalid   ),
    .ip_rx_axis_tuser    (ip2app_axis_tuser    ),
    .ip_rx_axis_tlast    (ip2app_axis_tlast    ),
    .recv_src_ip_addr    (ip_recv_src_ip_addr  ),
    .recv_dst_ip_addr    (ip_recv_dst_ip_addr  ),
    .recv_type           (ip_type              ),
    .ip_mode_src_addr    (ip2udp_recv_src_ip_addr),
    .ip_mode_dst_addr    (ip2udp_recv_dst_ip_addr),
    // .udp_rx_axis_tdata   (ip2udp_axis_tdata    ),
    // .udp_rx_axis_tkeep   (ip2udp_axis_tkeep    ),
    // .udp_rx_axis_tvalid  (ip2udp_axis_tvalid   ),
    // .udp_rx_axis_tuser   (ip2udp_axis_tuser    ),
    // .udp_rx_axis_tlast   (ip2udp_axis_tlast    ),
    .udp_rx_axis_tdata  (udp_rx_axis_tdata   ),
    .udp_rx_axis_tkeep  (udp_rx_axis_tkeep   ),
    .udp_rx_axis_tvalid (udp_rx_axis_tvalid  ),
    .udp_rx_axis_tlast  (udp_rx_axis_tlast   ),
    .udp_rx_axis_tuser  (udp_rx_axis_tuser   ),
    .icmp_rx_axis_tdata  (ip2icmp_axis_tdata   ),
    .icmp_rx_axis_tkeep  (ip2icmp_axis_tkeep   ),
    .icmp_rx_axis_tvalid (ip2icmp_axis_tvalid  ),
    .icmp_rx_axis_tuser  (ip2icmp_axis_tuser   ),
    .icmp_rx_axis_tlast  (ip2icmp_axis_tlast   )
);

// us_udp_rx #(.FPGA_TYPE("usplus")) udp_rx(
//     .rx_axis_aclk       (rx_axis_aclk        ),
//     .rx_axis_aresetn    (rx_axis_aresetn     ),
//     .ip_rx_axis_tdata   (ip2udp_axis_tdata   ),
//     .ip_rx_axis_tkeep   (ip2udp_axis_tkeep   ),
//     .ip_rx_axis_tvalid  (ip2udp_axis_tvalid  ),
//     .ip_rx_axis_tlast   (ip2udp_axis_tlast   ),
//     .ip_rx_axis_tuser   (ip2udp_axis_tuser   ),
//     .udp_rx_axis_tdata  (udp_rx_axis_tdata   ),
//     .udp_rx_axis_tkeep  (udp_rx_axis_tkeep   ),
//     .udp_rx_axis_tvalid (udp_rx_axis_tvalid  ),
//     .udp_rx_axis_tlast  (udp_rx_axis_tlast   ),
//     .udp_rx_axis_tuser  (udp_rx_axis_tuser   ),
//     .recv_dst_ip_addr   (ip2udp_recv_dst_ip_addr),
//     .recv_src_ip_addr   (ip2udp_recv_src_ip_addr)
// );

endmodule
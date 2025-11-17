/****************************************************************************
 * @file    eth_frame_rx.v
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

`timescale 1ns/1ps

module eth_frame_rx(
    input                            	     rx_axis_aclk,
	input                            	     rx_axis_aresetn,
	/* axis	interface from mac  */	
    input  [63:0]       	     			 mac_rx_axis_tdata,
    input  [7:0]     	     				 mac_rx_axis_tkeep,
    input                            	     mac_rx_axis_tvalid,		 
    input                            	     mac_rx_axis_tlast,
    input                           	     mac_rx_axis_tuser,
	/* udp axis	interface to user  */	
	output  [63:0]       	     			 udp_rx_axis_tdata,
    output  [7:0]     	     				 udp_rx_axis_tkeep,
    output                            	     udp_rx_axis_tvalid,		 
    output                            	     udp_rx_axis_tlast,
    output                           	     udp_rx_axis_tuser,
	/* axis	interface to icmp module  */
	output   [63:0]       	     		 	 ip2icmp_axis_tdata  ,
	output   [7:0]     	     			 	 ip2icmp_axis_tkeep  ,
	output                           	 	 ip2icmp_axis_tvalid ,
	output                           	 	 ip2icmp_axis_tlast  ,
	output                          	 	 ip2icmp_axis_tuser  ,
	
	
	input  [31:0]							 local_ip_addr,		//local ip address defined by user
	input  [47:0]							 local_mac_addr,	//local mac address defined by user
	input  [31:0]							 dst_ip_addr,		//destinations ip address defined by user
	output [47:0]							 dst_mac_addr,		//destinations mac address 
	
	output                 				 	 arp_reply_req,     //arp reply request to arp tx module
	input 	         						 arp_reply_ack,     //arp reply ack from arp tx module 
	input				  					 arp_request_ack,	//arp request ack from arp tx module
	output				  					 arp_request_req,   //arp request to arp tx module 
	
	output									 mac_exist,			// mac exist signal
    output                                   arp_reply_valid,
    output   arp_register
);

wire    [63:0]  rx_frame_axis_tdata;
wire    [7:0]   rx_frame_axis_tkeep;
wire            rx_frame_axis_tvalid;
wire            rx_frame_axis_tuser;
wire            rx_frame_axis_tlast;

wire    [47:0]  recv_dst_mac_addr;
wire    [31:0]  recv_src_mac_addr;
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

wire            arp_reply_valid;
wire    [47:0]  arp_recv_src_mac_addr;
wire    [31:0]  arp_recv_src_ip_addr;

wire    [47:0]  frame_dst_mac_addr;
//wire    [47:0]  frame_src_mac_addr;

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


//// ARP Header Stripper (post-demux, local to eth_frame_rx) - FIXED: Fully scoped wires, no prefix collision
//localparam [7:0] ETH_HDR_LEN = 8'd14;  // Fixed Ethernet header bytes

//// Internal FSM regs (local, non-port)
//reg [3:0] arp_strip_byte_cnt;  // Bytes consumed in current beat
//reg [1:0] arp_strip_phase;     // 0: idle, 1: header drop, 2: prepend, 3: pass
//reg [15:0] arp_hdr_buf;        // Saved high 16B from partial header beat

//// Fully local ARP stripped output wires (scoped prefix, no "mac_" or "arp_rx_axis_" reuse) - FIXED
//wire [63:0] local_arp_strip_tdata;
//wire [7:0]  local_arp_strip_tkeep;
//wire        local_arp_strip_tvalid;
//wire        local_arp_strip_tlast;
//wire        local_arp_strip_tuser;
//wire        local_arp_strip_tready = 1'b1;  // Tie (us_arp_rx no tready; always consume)

//// FSM state update (seq, NBA) - Scoped regs
//always @(posedge rx_axis_aclk) begin
//    if (~rx_axis_aresetn) begin
//        arp_strip_phase     <= 2'd0;
//        arp_strip_byte_cnt  <= 4'd0;
//        arp_hdr_buf         <= 16'h0000;
//    end else if (mac2arp_rx_axis_tvalid && local_arp_strip_tready) begin  // Use mac2arp_rx_axis_tvalid from mac_rx_mode
//        case (arp_strip_phase)
//            2'd0: begin
//                arp_strip_phase    <= 2'd1;  // Start on ARP (triggered externally via rcvd_type, but always for simplicity)
//                arp_strip_byte_cnt <= 4'd0;
//            end
//            2'd1: begin
//                arp_strip_byte_cnt <= arp_strip_byte_cnt + 8'd8;
//                if (arp_strip_byte_cnt + 8'd8 > ETH_HDR_LEN) begin
//                    arp_hdr_buf <= mac2arp_rx_axis_tdata[63:48];  // Save 2B ARP start (htype)
//                    arp_strip_phase <= 2'd2;
//                end else begin
//                    arp_strip_phase <= 2'd1;
//                end
//            end
//            2'd2: begin
//                arp_strip_phase <= 2'd3;  // Advance to pass
//            end
//            2'd3: begin
//                if (mac2arp_rx_axis_tlast) begin
//                    arp_strip_phase <= 2'd0;
//                end else begin
//                    arp_strip_phase <= 2'd3;
//                end
//            end
//            default: begin
//                arp_strip_phase <= 2'd0;
//            end
//        endcase
//    end
//end

//// Output mux (structural assign, ternary for wires) - Scoped locals, direct tlast pass
//assign local_arp_strip_tvalid = (arp_strip_phase == 2'd1) ? 1'b0 : mac2arp_rx_axis_tvalid;  // Drop header
//assign local_arp_strip_tlast  = mac2arp_rx_axis_tlast;  // Direct pass (local wire, no collision)
//assign local_arp_strip_tuser  = mac2arp_rx_axis_tuser;

//assign local_arp_strip_tdata  = (arp_strip_phase == 2'd2) ? {mac2arp_rx_axis_tdata[47:0], arp_hdr_buf} :  // Prepend htype to payload start
//                                (arp_strip_phase == 2'd3) ? mac2arp_rx_axis_tdata : 64'h0000000000000000;
//assign local_arp_strip_tkeep  = (arp_strip_phase == 2'd2 || arp_strip_phase == 2'd3) ? mac2arp_rx_axis_tkeep : 8'h00;

//// Upstream tready to mac_rx_mode ARP path (always consume, since no backprop needed)
//wire arp_path_tready = local_arp_strip_tready;  // Passthrough



us_mac_rx mac_rx(
    .rx_axis_aclk         	(rx_axis_aclk          ),
    .rx_axis_aresetn      	(rx_axis_aresetn       ),
    .rx_mac_axis_tdata    	(mac_rx_axis_tdata     ),
    .rx_mac_axis_tkeep    	(mac_rx_axis_tkeep     ),
    .rx_mac_axis_tvalid   	(mac_rx_axis_tvalid    ),
    .rx_mac_axis_tuser    	(mac_rx_axis_tuser    ),
    .rx_mac_axis_tlast    	(mac_rx_axis_tlast     ),
    .rx_frame_axis_tdata  	(rx_frame_axis_tdata   ),
    .rx_frame_axis_tkeep  	(rx_frame_axis_tkeep   ),
    .rx_frame_axis_tvalid 	(rx_frame_axis_tvalid  ),
    .rx_frame_axis_tuser  	(rx_frame_axis_tuser   ),
    .rx_frame_axis_tlast  	(rx_frame_axis_tlast   ),
    .recv_dst_mac_addr    	(recv_dst_mac_addr     ),
    .recv_src_mac_addr    	(recv_src_mac_addr     ),
    .recv_type            	(recv_type             ),
    .local_mac_addr       	(local_mac_addr        )
);


mac_rx_mode rx_mac_mode(
    .rx_axis_aclk            	(rx_axis_aclk             ),
    .rx_axis_aresetn         	(rx_axis_aresetn          ),
    .frame_rx_axis_tdata     	(rx_frame_axis_tdata      ),
    .frame_rx_axis_tkeep     	(rx_frame_axis_tkeep      ),
    .frame_rx_axis_tvalid    	(rx_frame_axis_tvalid     ),
    .frame_rx_axis_tlast     	(rx_frame_axis_tlast      ),
    .frame_rx_axis_tuser      	(rx_frame_axis_tuser      ),
    .rcvd_dst_mac_addr       	(recv_dst_mac_addr        ),
    .rcvd_src_mac_addr       	(recv_src_mac_addr        ),
    .rcvd_type               	(recv_type                ),
    .ip_rx_axis_tdata        	(mac2ip_rx_axis_tdata         ),
    .ip_rx_axis_tkeep        	(mac2ip_rx_axis_tkeep         ),
    .ip_rx_axis_tvalid       	(mac2ip_rx_axis_tvalid        ),
    .ip_rx_axis_tlast        	(mac2ip_rx_axis_tlast         ),
    .ip_rx_axis_tuser        	(mac2ip_rx_axis_tuser          ),
    .arp_rx_axis_tdata       	(mac2arp_rx_axis_tdata        ),
    .arp_rx_axis_tkeep       	(mac2arp_rx_axis_tkeep        ),
    .arp_rx_axis_tvalid      	(mac2arp_rx_axis_tvalid       ),
    .arp_rx_axis_tlast       	(mac2arp_rx_axis_tlast        ),
    .arp_rx_axis_tuser       	(mac2arp_rx_axis_tuser         ),
    .frame_mode_dst_mac_addr 	(frame_dst_mac_addr  ),
    .frame_mode_src_mac_addr 	(  )
);


us_arp_rx u_us_arp_rx(
    .rx_axis_aclk        	(rx_axis_aclk         ),
    .rx_axis_aresetn     	(rx_axis_aresetn      ),
    .rx_axis_fmac_tdata    (local_arp_strip_tdata),  
    .rx_axis_fmac_tkeep    (local_arp_strip_tkeep),
    .rx_axis_fmac_tvalid   (local_arp_strip_tvalid),
    .rx_axis_fmac_tlast    (local_arp_strip_tlast),  
    .rx_axis_fmac_tuser    (local_arp_strip_tuser),
    .local_mac_addr      	(local_mac_addr       ),
    .local_ip_addr       	(local_ip_addr        ),
    .dst_ip_addr         	(dst_ip_addr          ),
    .arp_reply_req       	(arp_reply_req        ),
    .arp_reply_ack       	(arp_reply_ack        ),
    .arp_reply_valid     	(arp_reply_valid      ),
    .recv_src_mac_addr   	(arp_recv_src_mac_addr    ),
    .recv_src_ip_addr    	(arp_recv_src_ip_addr     )
);



us_arp_table u_arp_table(
    .clk               	(rx_axis_aclk           ),
    .rstn              	(rx_axis_aresetn        ),
    .recv_src_mac_addr 	(arp_recv_src_mac_addr  ),
    .recv_src_ip_addr  	(arp_recv_src_ip_addr   ),
    .arp_valid         	(arp_reply_valid        ),
    .arp_request_req    (arp_request_req        ),
    .arp_request_ack    (arp_request_ack        ),
    .arp_mac_exit      	(mac_exist              ),
    .dst_ip_addr       	(dst_ip_addr            ),
    .dst_mac_addr      	(dst_mac_addr           ),
    .arp_register       (arp_register)
);



us_ip_rx ip_rx(
    .rx_axis_aclk       	(rx_axis_aclk        ),
    .rx_axis_aresetn    	(rx_axis_aresetn     ),
    .mac_rx_axis_tdata  	(mac2ip_rx_axis_tdata   ),
    .mac_rx_axis_tkeep  	(mac2ip_rx_axis_tkeep   ),
    .mac_rx_axis_tvalid 	(mac2ip_rx_axis_tvalid  ),
    .mac_rx_axis_tuser  	(mac2ip_rx_axis_tuser   ),
    .mac_rx_axis_tlast  	(mac2ip_rx_axis_tlast   ),
    .ip_rx_axis_tdata   	(ip2app_axis_tdata   ),
    .ip_rx_axis_tkeep   	(ip2app_axis_tkeep    ),
    .ip_rx_axis_tvalid  	(ip2app_axis_tvalid    ),
    .ip_rx_axis_tuser   	(ip2app_axis_tuser    ),
    .ip_rx_axis_tlast   	(ip2app_axis_tlast    ),
    .local_ip_addr      	(local_ip_addr       ),
    .recv_dst_ip_addr   	(ip_recv_dst_ip_addr    ),
    .recv_src_ip_addr   	(ip_recv_src_ip_addr    ),
    .local_mac_addr     	(local_mac_addr      ),
    .recv_dst_mac_addr  	(frame_dst_mac_addr   ),
    .ip_type            	(ip_type            )
);


us_ip_rx_mode ip_rx_mode(
    .rx_axis_aclk        	(rx_axis_aclk          ),
    .rx_axis_aresetn     	(rx_axis_aresetn       ),
    .ip_rx_axis_tdata    	(ip2app_axis_tdata     ),
    .ip_rx_axis_tkeep    	(ip2app_axis_tkeep     ),
    .ip_rx_axis_tvalid   	(ip2app_axis_tvalid    ),
    .ip_rx_axis_tuser    	(ip2app_axis_tuser     ),
    .ip_rx_axis_tlast    	(ip2app_axis_tlast     ),
    .recv_src_ip_addr    	(ip_recv_src_ip_addr   ),
    .recv_dst_ip_addr    	(ip_recv_dst_ip_addr   ),
    .recv_type           	(ip_type               ),
    .ip_mode_src_addr    	(ip2udp_recv_src_ip_addr     ),
    .ip_mode_dst_addr    	(ip2udp_recv_dst_ip_addr     ),
    .udp_rx_axis_tdata   	(ip2udp_axis_tdata    ),
    .udp_rx_axis_tkeep   	(ip2udp_axis_tkeep    ),
    .udp_rx_axis_tvalid  	(ip2udp_axis_tvalid   ),
    .udp_rx_axis_tuser   	(ip2udp_axis_tuser    ),
    .udp_rx_axis_tlast   	(ip2udp_axis_tlast    ),
    .icmp_rx_axis_tdata  	(ip2icmp_axis_tdata   ),
    .icmp_rx_axis_tkeep  	(ip2icmp_axis_tkeep   ),
    .icmp_rx_axis_tvalid 	(ip2icmp_axis_tvalid  ),
    .icmp_rx_axis_tuser  	(ip2icmp_axis_tuser   ),
    .icmp_rx_axis_tlast  	(ip2icmp_axis_tlast   )
);



us_udp_rx #(
    .FPGA_TYPE 	("usplus"  ))
udp_rx(
    .rx_axis_aclk       	(rx_axis_aclk        ),
    .rx_axis_aresetn    	(rx_axis_aresetn     ),
    .ip_rx_axis_tdata   	(ip2udp_axis_tdata    ),
    .ip_rx_axis_tkeep   	(ip2udp_axis_tkeep    ),
    .ip_rx_axis_tvalid  	(ip2udp_axis_tvalid   ),
    .ip_rx_axis_tlast   	(ip2udp_axis_tlast    ),
    .ip_rx_axis_tuser   	(ip2udp_axis_tuser     ),
    .udp_rx_axis_tdata  	(udp_rx_axis_tdata   ),
    .udp_rx_axis_tkeep  	(udp_rx_axis_tkeep   ),
    .udp_rx_axis_tvalid 	(udp_rx_axis_tvalid  ),
    .udp_rx_axis_tlast  	(udp_rx_axis_tlast   ),
    .udp_rx_axis_tuser  	(udp_rx_axis_tuser   ),
    .recv_dst_ip_addr   	(ip2udp_recv_dst_ip_addr    ),
    .recv_src_ip_addr   	(ip2udp_recv_src_ip_addr    )
);


endmodule

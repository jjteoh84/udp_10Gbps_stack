/****************************************************************************
 * @file    udp_stack_top.v
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

module udp_stack_top(

    input   wire            tx_axis_aclk,
    input   wire            tx_axis_aresetn,
    input   wire            rx_axis_aclk,
    input   wire            rx_axis_aresetn,

    input   wire    [31:0]  src_ip_addr,
    input   wire    [31:0]  dst_ip_addr,
    input   wire    [47:0]  src_mac_addr,

    input   wire    [15:0]  udp_src_port,
    input   wire    [15:0]  udp_dst_port,

    output  wire            udp_enable,
    output  wire  arp_reply_req,
    // input wire arp_request_req,  //  Boot/external trigger for outbound ARP
    output wire arp_request_ack,

	/* udp tx axis interface */		  
    input  [63:0]            udp_tx_axis_tdata,
    input  [7:0]     		 udp_tx_axis_tkeep,
    input                    udp_tx_axis_tvalid,		 
    input                    udp_tx_axis_tlast,
    output                   udp_tx_axis_tready,

	output wire [63:0]       udp_rx_axis_tdata,
    output wire [7:0]     	 udp_rx_axis_tkeep,
    output wire              udp_rx_axis_tvalid,		 
    output wire              udp_rx_axis_tlast,
    output wire              udp_rx_axis_tuser,

    output  wire     [63:0]  mac_tx_axis_tdata,
    output  wire     [7:0]   mac_tx_axis_tkeep,
    output  wire             mac_tx_axis_tvalid,
    output  wire             mac_tx_axis_tlast,
    input   wire             mac_tx_axis_tready,

    input       wire[63:0]   mac_rx_axis_tdata   ,
    input       wire[7:0]    mac_rx_axis_tkeep   ,
    input       wire         mac_rx_axis_tvalid  ,
    input       wire         mac_rx_axis_tuser   ,
    input       wire         mac_rx_axis_tlast   ,
    output      wire         arp_reply_valid,
    output      dst_mac_addr,
    output  arp_register

);

/***********************************************************************************************

eth ip frame type code

| Protocol   | Decimal | Hex    | Description                            |
| ---------- | ------- | ------ | -------------------------------------- |
| **ICMP**   | 1       | `0x01` | Internet Control Message Protocol      |
| **IGMP**   | 2       | `0x02` | Internet Group Management Protocol     |
| **TCP**    | 6       | `0x06` | Transmission Control Protocol          |
| **UDP**    | 17      | `0x11` | User Datagram Protocol                 |
| **GRE**    | 47      | `0x2F` | Generic Routing Encapsulation          |
| **ESP**    | 50      | `0x32` | Encapsulating Security Payload (IPsec) |
| **AH**     | 51      | `0x33` | Authentication Header (IPsec)          |
| **ICMPv6** | 58      | `0x3A` | ICMP for IPv6                          |
| **OSPF**   | 89      | `0x59` | Open Shortest Path First               |
| **SCTP**   | 132     | `0x84` | Stream Control Transmission Protocol   |


ethernet mac frame type code

| Protocol                                 | EtherType (Hex) | Description                                  |
| ---------------------------------------- | --------------- | -------------------------------------------- |
| **IPv4**                                 | `0x0800`        | Indicates that the payload is an IPv4 packet |
| **ARP**                                  | `0x0806`        | Indicates that the payload is an ARP packet  |
| **IPv6**                                 | `0x86DD`        | Indicates that the payload is an IPv6 packet |
| **VLAN-tagged (IEEE 802.1Q)**            | `0x8100`        | Indicates that a VLAN tag follows            |
| **PPPoE Discovery**                      | `0x8863`        | PPPoE discovery stage                        |
| **PPPoE Session**                        | `0x8864`        | PPPoE session stage                          |
| **LLDP (Link Layer Discovery Protocol)** | `0x88CC`        | Used for device discovery                    |
| **EAP over LAN (802.1X)**                | `0x888E`        | Network authentication protocol              |
| **MPLS Unicast**                         | `0x8847`        | MPLS unicast traffic                         |
| **MPLS Multicast**                       | `0x8848`        | MPLS multicast traffic                       |

***********************************************************************************************/

wire    [47:0]  dst_mac_addr;
wire            mac_exist;
wire            icmp_not_empty;

// wire            arp_reply_req;
wire            arp_reply_ack;
wire            arp_request_req;
// wire            arp_request_ack;

wire [63:0]     icmp_tx_axis_tdata;
wire [7:0]     	icmp_tx_axis_tkeep;
wire            icmp_tx_axis_tvalid;		 
wire            icmp_tx_axis_tlast;
wire            icmp_tx_axis_tready;

wire   [63:0]   ip2icmp_axis_tdata  ;
wire   [7:0]    ip2icmp_axis_tkeep  ;
wire            ip2icmp_axis_tvalid ;
wire            ip2icmp_axis_tlast  ;
wire            ip2icmp_axis_tuser   ;

assign udp_enable = mac_exist;

eth_frame_tx u_eth_frame_tx(
    .src_mac_addr        	(src_mac_addr         ),
    .dst_mac_addr        	(dst_mac_addr         ),
    .src_ip_addr         	(src_ip_addr          ),
    .dst_ip_addr         	(dst_ip_addr          ),
    .udp_src_port        	(udp_src_port         ),
    .udp_dst_port        	(udp_dst_port         ),
    .mac_exist           	(mac_exist            ),

    .arp_request_req     	(arp_request_req      ),
    .arp_request_ack     	(arp_request_ack      ),
    .arp_reply_req       	(arp_reply_req        ),
    .arp_reply_ack       	(arp_reply_ack        ),

    .tx_axis_aclk        	(tx_axis_aclk         ),
    .tx_axis_aresetn     	(tx_axis_aresetn      ),

    .icmp_not_empty      	(icmp_not_empty       ),
    .icmp_tx_axis_tdata  	(icmp_tx_axis_tdata   ),
    .icmp_tx_axis_tkeep  	(icmp_tx_axis_tkeep   ),
    .icmp_tx_axis_tvalid 	(icmp_tx_axis_tvalid  ),
    .icmp_tx_axis_tlast  	(icmp_tx_axis_tlast   ),
    .icmp_tx_axis_tready 	(icmp_tx_axis_tready  ),

    .udp_tx_axis_tdata   	(udp_tx_axis_tdata    ),
    .udp_tx_axis_tkeep   	(udp_tx_axis_tkeep    ),
    .udp_tx_axis_tvalid  	(udp_tx_axis_tvalid   ),
    .udp_tx_axis_tlast   	(udp_tx_axis_tlast    ),
    .udp_tx_axis_tready  	(udp_tx_axis_tready   ),

    .mac_tx_axis_tdata   	(mac_tx_axis_tdata    ),
    .mac_tx_axis_tkeep   	(mac_tx_axis_tkeep    ),
    .mac_tx_axis_tvalid  	(mac_tx_axis_tvalid   ),
    .mac_tx_axis_tlast   	(mac_tx_axis_tlast    ),
    .mac_tx_axis_tready  	(mac_tx_axis_tready   )
);



eth_frame_rx u_eth_frame_rx(
    .rx_axis_aclk           	(rx_axis_aclk            ),
    .rx_axis_aresetn        	(rx_axis_aresetn         ),

    .mac_rx_axis_tdata      	(mac_rx_axis_tdata       ),
    .mac_rx_axis_tkeep      	(mac_rx_axis_tkeep       ),
    .mac_rx_axis_tvalid     	(mac_rx_axis_tvalid      ),
    .mac_rx_axis_tlast      	(mac_rx_axis_tlast       ),
    .mac_rx_axis_tuser      	(mac_rx_axis_tuser       ),

    .udp_rx_axis_tdata      	(udp_rx_axis_tdata       ),
    .udp_rx_axis_tkeep      	(udp_rx_axis_tkeep       ),
    .udp_rx_axis_tvalid     	(udp_rx_axis_tvalid      ),
    .udp_rx_axis_tlast      	(udp_rx_axis_tlast       ),
    .udp_rx_axis_tuser      	(udp_rx_axis_tuser       ),

    .ip2icmp_axis_tdata     	(ip2icmp_axis_tdata   ),
    .ip2icmp_axis_tkeep     	(ip2icmp_axis_tkeep   ),
    .ip2icmp_axis_tvalid    	(ip2icmp_axis_tvalid  ),
    .ip2icmp_axis_tlast     	(ip2icmp_axis_tlast   ),
    .ip2icmp_axis_tuser     	(ip2icmp_axis_tuser   ),

    .local_ip_addr          	(src_ip_addr           ),
    .local_mac_addr         	(src_mac_addr          ),
    .dst_ip_addr            	(dst_ip_addr             ),
    .dst_mac_addr           	(dst_mac_addr            ),

    .arp_reply_req          	(arp_reply_req           ),
    .arp_reply_ack          	(arp_reply_ack           ),
    .arp_request_ack        	(arp_request_ack         ),
    .arp_request_req        	(arp_request_req         ),

    .mac_exist              	(mac_exist               ),
    .arp_reply_valid            (arp_reply_valid),
    .arp_register (arp_register)
);


us_icmp_reply u_us_icmp_reply(
    .rx_axis_aclk        	(rx_axis_aclk         ),
    .rx_axis_aresetn     	(rx_axis_aresetn      ),

    .ip_rx_axis_tdata    	(ip2icmp_axis_tdata     ),
    .ip_rx_axis_tkeep    	(ip2icmp_axis_tkeep     ),
    .ip_rx_axis_tvalid   	(ip2icmp_axis_tvalid    ),
    .ip_rx_axis_tlast    	(ip2icmp_axis_tlast     ),
    .ip_rx_axis_tuser     	(ip2icmp_axis_tuser     ),

    .icmp_tx_axis_tdata  	(icmp_tx_axis_tdata   ),
    .icmp_tx_axis_tkeep  	(icmp_tx_axis_tkeep   ),
    .icmp_tx_axis_tvalid 	(icmp_tx_axis_tvalid  ),
    .icmp_tx_axis_tlast  	(icmp_tx_axis_tlast   ),
    .icmp_tx_axis_tready 	(icmp_tx_axis_tready  ),

    .icmp_not_empty      	(icmp_not_empty       )
);


endmodule
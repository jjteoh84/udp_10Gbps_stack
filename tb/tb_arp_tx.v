/****************************************************************************
 * @file    us_arp_tx.v
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

`define CLOCK_PERIOD   100

module tb_arp_tx();


reg        tx_axis_aclk         =   0;
reg        tx_axis_aresetn      =   0;

	/* arp tx axis interface */
wire [63:0]       arp_tx_axis_tdata     ;
wire [7:0]        arp_tx_axis_tkeep     ;
wire              arp_tx_axis_tvalid    ;		 
wire              arp_tx_axis_tlast     ;
reg               arp_tx_axis_tready =1 ;

reg [47:0]        dst_mac_addr  = {8'hac, 8'h00, 8'h01, 8'h24, 8'h25, 8'hbc} ;
reg [47:0]        src_mac_addr  = {8'hab, 8'h10, 8'h20, 8'h27, 8'h55, 8'hfc} ;
reg [31:0]        dst_ip_addr   = {8'd192,8'd168,8'd1,  8'd10} ;
reg [31:0]        src_ip_addr   = {8'd192,8'd168,8'd1,  8'd11}  ; 
    
wire              arp_request_ack   ;
wire              arp_reply_ack     ;
reg               arp_reply_req   = 0;
reg               arp_request_req = 0;   

initial begin
#(`CLOCK_PERIOD * 20)begin
    tx_axis_aresetn <= 1;
end

#(`CLOCK_PERIOD)begin
    arp_request_req <= 1;
end

#(`CLOCK_PERIOD)begin
    arp_request_req <= 0;
end

#(`CLOCK_PERIOD * 20)

#(`CLOCK_PERIOD)begin
    arp_reply_req <= 1;
end

#(`CLOCK_PERIOD)begin
    arp_reply_req <= 0;
end

end
us_arp_tx tb_arp(
    .tx_axis_aclk       	(tx_axis_aclk        ),
    .tx_axis_aresetn    	(tx_axis_aresetn     ),
    .arp_tx_axis_tdata  	(arp_tx_axis_tdata   ),
    .arp_tx_axis_tkeep  	(arp_tx_axis_tkeep   ),
    .arp_tx_axis_tvalid 	(arp_tx_axis_tvalid  ),
    .arp_tx_axis_tlast  	(arp_tx_axis_tlast   ),
    .arp_tx_axis_tready 	(arp_tx_axis_tready  ),
    .dst_mac_addr       	(dst_mac_addr        ),
    .src_mac_addr       	(src_mac_addr        ),
    .dst_ip_addr        	(dst_ip_addr         ),
    .src_ip_addr        	(src_ip_addr         ),
    .arp_reply_ack      	(arp_reply_ack       ),
    .arp_reply_req      	(arp_reply_req       ),
    .arp_request_ack    	(arp_request_ack     ),
    .arp_request_req    	(arp_request_req     )
);



always #(`CLOCK_PERIOD/2) tx_axis_aclk = ~tx_axis_aclk;

endmodule
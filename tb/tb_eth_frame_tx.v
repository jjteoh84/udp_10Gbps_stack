/****************************************************************************
 * @file    tb_eth_frame_mode.v
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

`define     CLOCK_PERIOD   100

module tb_eth_frame_tx();

parameter FRAME  = 10;

reg [47:0]		src_mac_addr = {8'hac, 8'h14, 8'h74, 8'h45, 8'hbc, 8'hf4};	
reg [47:0]		dst_mac_addr = {8'ha0, 8'h36, 8'h9f, 8'h7d, 8'he5, 8'h8c};	          
reg [31:0]      src_ip_addr  = {8'd192, 8'd168, 8'd1, 8'd123};           
reg [31:0]      dst_ip_addr  = {8'd192, 8'd168, 8'd1, 8'd101};                                    
reg [15:0]      udp_src_port = 16'h8080;         
reg [15:0]      udp_dst_port = 16'h8007;            

reg           mac_exist =   1;

reg           arp_request_req   =   0;        //arp request
wire          arp_request_ack;        //arp request ack
reg           arp_reply_req     =   0;          //arp reply request from arp rx module
wire          arp_reply_ack;          //arp reply ack to arp rx module     

reg        	  tx_axis_aclk  =0;
reg        	  tx_axis_aresetn=0; 
/* icmp tx axis interface */	
reg			  icmp_not_empty        =   0;			//icmp is ready to send data
reg  [63:0]   icmp_tx_axis_tdata    =   0;
reg  [7:0]    icmp_tx_axis_tkeep    =   0;
reg           icmp_tx_axis_tvalid   =   0;		 
reg           icmp_tx_axis_tlast    =   0;
wire          icmp_tx_axis_tready;   
/* udp tx axis interface */	
reg  [63:0]   udp_tx_axis_tdata     =   0;
reg  [7:0]    udp_tx_axis_tkeep     =   0;
reg           udp_tx_axis_tvalid    =   0;		 
reg           udp_tx_axis_tlast     =   0;
wire          udp_tx_axis_tready;
/* mac tx axis interface */	
wire   [63:0]  mac_tx_axis_tdata;
wire   [7:0]   mac_tx_axis_tkeep;
wire           mac_tx_axis_tvalid;	
wire           mac_tx_axis_tlast;
reg            mac_tx_axis_tready   =   1;    

integer i = 0;
integer k = 0;
integer log_file;
integer clock_count = 0;


function [31:0]modfunc(
    input [31:0]a
);
    modfunc = (a / 8 == 0) ? a / 8 : a/8 + 1;

endfunction


initial begin
    log_file = $fopen("../../../mac_tx_axis_signals_u.txt", "w");

    $fdisplay(log_file, "Clock\tmac_tx_axis_tdata\tmac_tx_axis_tkeep\tmac_tx_axis_tvalid\tmac_tx_axis_tlast\tmac_tx_axis_tready");

    #(`CLOCK_PERIOD * 60)begin
        tx_axis_aresetn <= 1;
    end

    #(`CLOCK_PERIOD * 9)

    for (i = 1; i <= 64; i = i + 1) begin
        if (i <= 8) begin
            #(`CLOCK_PERIOD)begin
                udp_tx_axis_tdata  <= {i , i};
                // To send all 8 bytes, tkeep must be all 1s.
                udp_tx_axis_tkeep  <= 8'hff;
                udp_tx_axis_tvalid <= 1;
                udp_tx_axis_tlast <= 1;
            end                
            #(`CLOCK_PERIOD)begin
                udp_tx_axis_tdata <= 0;
                udp_tx_axis_tkeep <= 8'b00000000;
                udp_tx_axis_tvalid<= 0;
                udp_tx_axis_tlast <= 0;
            end                    
        end
        else begin
            repeat(modfunc(i))begin
                k = k + 1;
                #(`CLOCK_PERIOD)begin
                    udp_tx_axis_tdata <= {i , i};
                    udp_tx_axis_tkeep <= (k == modfunc(i)) ?(
                                         (i % 8 == 1) ? 8'h1  : (i % 8 == 2) ? 8'h3  : (i % 8 == 3) ? 8'h7  : (i % 8 == 4) ? 8'hf :
                                         (i % 8 == 5) ? 8'h1f : (i % 8 == 6) ? 8'h3f : (i % 8 == 7) ? 8'h7f : (i % 8 == 8) ? 8'hff : 8'hff) : 8'hff;
                    udp_tx_axis_tvalid<= 1;
                    udp_tx_axis_tlast <= (k == modfunc(i)) ? 1 : 0;
                end 
            end

            k = 0;
               
            #(`CLOCK_PERIOD)begin
                udp_tx_axis_tdata <= 0;
                udp_tx_axis_tkeep <= 8'b00000000;
                udp_tx_axis_tvalid<= 0;
                udp_tx_axis_tlast <= 0;
            end                 
        end
    end
    #(`CLOCK_PERIOD * 600);
    $fclose(log_file);

    $display("Signal logging completed. Data saved to mac_tx_axis_signals.txt");
    $stop;
end

always @(posedge tx_axis_aclk) begin
    if (tx_axis_aresetn) begin
        clock_count <= clock_count + 1;
        $fdisplay(log_file, "%0d\t%h\t%h\t%d\t%d\t%d", 
                     clock_count, 
                     mac_tx_axis_tdata, 
                     mac_tx_axis_tkeep, 
                     mac_tx_axis_tvalid, 
                     mac_tx_axis_tlast, 
                     mac_tx_axis_tready);
    end
end

eth_frame_tx u_mac_frame_tx(
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
    .tx_axis_aresetn      	(tx_axis_aresetn       ),
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


always #(`CLOCK_PERIOD/2) tx_axis_aclk = ~tx_axis_aclk;

endmodule

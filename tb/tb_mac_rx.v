/****************************************************************************
 * @file    tb_mac_rx.v
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

`define  CLOCK_PERIOD  100

module tb_mac_rx();

reg                rx_axis_aclk   =   0;
reg                rx_axis_aresetn=   0;
//rx axis interface from mac rx module
reg  [63:0]        mac_rx_axis_tdata    =   0;
reg  [7:0]         mac_rx_axis_tkeep    =   0;
reg                mac_rx_axis_tvalid   =   0;
reg                mac_rx_axis_tlast    =   0;
reg                mac_rx_axis_tusr     =   0;
//axis interface to next layer, arp or ip layer
wire  [63:0]       frame_rx_axis_tdata  ;
wire  [7:0]        frame_rx_axis_tkeep  ;
wire               frame_rx_axis_tvalid ;		 
wire               frame_rx_axis_tlast  ;
wire               frame_rx_axis_tusr   ;

reg	[47:0]		   local_mac_addr = {8'hac, 8'h8f, 8'hc3, 8'he4, 8'h42, 8'h57};	//local mac address, defined by user
wire[47:0]		   rcvd_dst_mac_addr;	//received destination mac address
wire[47:0]		   rcvd_src_mac_addr;	//received destination mac address
wire[15:0]		   rcvd_type		;	//received type, 0800: IP, 0806: ARP


initial begin
    #(`CLOCK_PERIOD * 60)begin
        rx_axis_aresetn <= 1;
    end
    #(`CLOCK_PERIOD * 10)
    //1. frame mac
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h8f085742e4c38fac;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h004500085742e4c3;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h11ff004000001d00;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'ha8c00a01a8c069f8;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end     
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0900818080800b01;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end     
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h00000000001747a;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end    
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end   
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end   
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 1;
        mac_rx_axis_tlast <= 1;
    end        
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'h0;
        mac_rx_axis_tvalid<= 0;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end  

// 2. mac frame
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h8f085742e4c38fac;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h004500085742e4c3;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h11ff004001001e00;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'ha8c00a01a8c067f8;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end         
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0a00818080800b01;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end     
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h000000000027279;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end              
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end    
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 1;
        mac_rx_axis_tlast <= 1;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'h0;
        mac_rx_axis_tvalid<= 0;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end      

//3. mac frame
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h8f085742e4c38fac;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h004500085742e4c3;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h11ff004012002f00;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'ha8c00a01a8c045f8;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end         
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h1b00818080800b01;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end     
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h001300000013501c;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end              
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0013000000130000;
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0000000000130000;
        mac_rx_axis_tkeep <= 8'h1f;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tusr  <= 1;
        mac_rx_axis_tlast <= 1;
    end    

    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= 64'h0;
        mac_rx_axis_tkeep <= 8'h0;
        mac_rx_axis_tvalid<= 0;
        mac_rx_axis_tusr  <= 0;
        mac_rx_axis_tlast <= 0;
    end      
end


us_mac_rx 
	
	mac_rx(	
		.rx_axis_aclk           (rx_axis_aclk),
		.rx_axis_aresetn        (rx_axis_aresetn),
        .rx_mac_axis_tdata      (mac_rx_axis_tdata),
        .rx_mac_axis_tkeep      (mac_rx_axis_tkeep),
        .rx_mac_axis_tvalid     (mac_rx_axis_tvalid),		 
        .rx_mac_axis_tlast      (mac_rx_axis_tlast),
        .rx_mac_axis_tuser      (mac_rx_axis_tusr),
		.rx_frame_axis_tdata    (frame_rx_axis_tdata),
        .rx_frame_axis_tkeep    (frame_rx_axis_tkeep),
        .rx_frame_axis_tvalid   (frame_rx_axis_tvalid),  		 
        .rx_frame_axis_tlast    (frame_rx_axis_tlast),
        .rx_frame_axis_tuser    (frame_rx_axis_tusr),
		.local_mac_addr         (local_mac_addr),	//local mac address, defined by user
		.recv_dst_mac_addr      (rcvd_dst_mac_addr),	//received destination mac address
	    .recv_src_mac_addr      (rcvd_src_mac_addr),	//received destination mac address
		.recv_type			    (rcvd_type)//received type, 0800: IP, 0806: ARP
);



always #(`CLOCK_PERIOD / 2) rx_axis_aclk = ~rx_axis_aclk;

endmodule

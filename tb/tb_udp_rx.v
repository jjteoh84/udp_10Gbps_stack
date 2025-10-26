/****************************************************************************
 * @file    tb_udp_rx.v
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

 `define CLOCK_PERIOD 100

module tb_udp_rx();

localparam [31:0] SRC_IP_ADDR = {8'd192,8'd168,8'd1,8'd10};
localparam [31:0] DES_IP_ADDR = {8'd192,8'd168,8'd1,8'd11};
localparam [15:0] SRC_PORT = 16'h8080;
localparam [15:0] DES_PORT = 16'h8081;

reg  rx_axis_aclk    = 0;
reg  rx_axis_aresetn = 0;

reg [63:0]       	     		ip_rx_axis_tdata  = 0;
reg [7:0]     	     		    ip_rx_axis_tkeep  = 0;
reg                             ip_rx_axis_tvalid = 0;		 
reg                             ip_rx_axis_tlast  = 0;
reg                          	ip_rx_axis_tusr   = 0;
/* udp rx axis interface */
wire [63:0]       	   	  udp_rx_axis_tdata     ;
wire [7:0]     	     	  udp_rx_axis_tkeep     ;
wire                      udp_rx_axis_tvalid    ;	 
wire                      udp_rx_axis_tlast     ;
wire                      udp_rx_axis_tusr      ;

integer i = 1;

initial begin
    #(`CLOCK_PERIOD * 60)begin
        rx_axis_aresetn  <= 1;
    end
    #(`CLOCK_PERIOD * 10)
    #(`CLOCK_PERIOD)begin       //0xd643
        ip_rx_axis_tdata    <= {16'hd643, 16'h5800, 16'h8180,16'h8080};
        ip_rx_axis_tkeep    <= 8'hff;
        ip_rx_axis_tvalid   <= 1;
        ip_rx_axis_tlast    <= 0;
        ip_rx_axis_tusr     <= 0;
    end
    repeat(9)begin
        #(`CLOCK_PERIOD)begin
            ip_rx_axis_tdata    <= i;
            ip_rx_axis_tkeep    <= 8'hff;
            ip_rx_axis_tvalid   <= 1;
            ip_rx_axis_tlast    <= 0;
            ip_rx_axis_tusr     <= 0;             
        end
        i = i + 1;    
    end
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata    <= i;
        ip_rx_axis_tkeep    <= 8'hff;
        ip_rx_axis_tvalid   <= 1;
        ip_rx_axis_tlast    <= 0;
        ip_rx_axis_tusr     <= 0; 
    end
    repeat(5)begin
        #(`CLOCK_PERIOD)begin
            ip_rx_axis_tdata    <= 0;
            ip_rx_axis_tkeep    <= 8'hff;
            ip_rx_axis_tvalid   <= 1;
            ip_rx_axis_tlast    <= 0;
            ip_rx_axis_tusr     <= 0; 
    end 
    end
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata    <= 0;
        ip_rx_axis_tkeep    <= 8'hff;
        ip_rx_axis_tvalid   <= 1;
        ip_rx_axis_tlast    <= 1;
        ip_rx_axis_tusr     <= 0; 
    end
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata    <= 0;
        ip_rx_axis_tkeep    <= 8'h0;
        ip_rx_axis_tvalid   <= 0;
        ip_rx_axis_tlast    <= 0;
        ip_rx_axis_tusr     <= 0; 
    end  
    #(`CLOCK_PERIOD * 5)     
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata    <= {16'h35a8, 16'ha800, 16'h8180,16'h8080};
        ip_rx_axis_tkeep    <= 8'hff;
        ip_rx_axis_tvalid   <= 1;
        ip_rx_axis_tlast    <= 0;
        ip_rx_axis_tusr     <= 0; 
        i                   <= 1;
    end
    repeat(19)begin
        #(`CLOCK_PERIOD)begin
            ip_rx_axis_tdata    <= i;
            ip_rx_axis_tkeep    <= 8'hff;
            ip_rx_axis_tvalid   <= 1;
            ip_rx_axis_tlast    <= 0;
            ip_rx_axis_tusr     <= 0;             
        end
        i = i + 1;    
    end
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata    <= i;
        ip_rx_axis_tkeep    <= 8'hff;
        ip_rx_axis_tvalid   <= 1;
        ip_rx_axis_tlast    <= 1;
        ip_rx_axis_tusr     <= 0; 
    end    
    #(`CLOCK_PERIOD)begin
        ip_rx_axis_tdata    <= 0;
        ip_rx_axis_tkeep    <= 8'h0;
        ip_rx_axis_tvalid   <= 0;
        ip_rx_axis_tlast    <= 0;
        ip_rx_axis_tusr     <= 0; 
    end        
end

us_udp_rx #(
    .FPGA_TYPE("usplus")
)u_us_udp_rx(
    .rx_axis_aclk       	(rx_axis_aclk        ),
    .rx_axis_aresetn    	(rx_axis_aresetn     ),
    .ip_rx_axis_tdata   	(ip_rx_axis_tdata    ),
    .ip_rx_axis_tkeep   	(ip_rx_axis_tkeep    ),
    .ip_rx_axis_tvalid  	(ip_rx_axis_tvalid   ),
    .ip_rx_axis_tlast   	(ip_rx_axis_tlast    ),
    .ip_rx_axis_tuser    	(ip_rx_axis_tusr     ),
    .udp_rx_axis_tdata  	(udp_rx_axis_tdata   ),
    .udp_rx_axis_tkeep  	(udp_rx_axis_tkeep   ),
    .udp_rx_axis_tvalid 	(udp_rx_axis_tvalid  ),
    .udp_rx_axis_tlast  	(udp_rx_axis_tlast   ),
    .udp_rx_axis_tuser  	(udp_rx_axis_tusr    ),
    .recv_dst_ip_addr   	(DES_IP_ADDR    ),
    .recv_src_ip_addr   	(SRC_IP_ADDR    )
);



always #(`CLOCK_PERIOD / 2) rx_axis_aclk = ~rx_axis_aclk;


endmodule
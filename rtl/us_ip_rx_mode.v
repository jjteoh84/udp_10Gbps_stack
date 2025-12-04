/****************************************************************************
 * @file    us_ip_rx_mode.v
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

module us_ip_rx_mode (
    input   wire        rx_axis_aclk,
    input   wire        rx_axis_aresetn,

    input   wire[63:0]  ip_rx_axis_tdata,
    input   wire[7:0]   ip_rx_axis_tkeep,
    input   wire        ip_rx_axis_tvalid,
    input   wire        ip_rx_axis_tuser,
    input   wire        ip_rx_axis_tlast,

    input   wire[31:0]  recv_src_ip_addr,
    input   wire[31:0]  recv_dst_ip_addr,
    input   wire[15:0]   recv_type,

    output  reg[31:0]   ip_mode_src_addr,
    output  reg[31:0]   ip_mode_dst_addr,

    output  reg [63:0]  udp_rx_axis_tdata,
    output  reg [7:0]   udp_rx_axis_tkeep,
    output  reg         udp_rx_axis_tvalid,
    output  reg         udp_rx_axis_tuser,
    output  reg         udp_rx_axis_tlast,    

    output  reg [63:0]  icmp_rx_axis_tdata,
    output  reg [7:0]   icmp_rx_axis_tkeep,
    output  reg         icmp_rx_axis_tvalid,
    output  reg         icmp_rx_axis_tuser,
    output  reg         icmp_rx_axis_tlast    
);
    
localparam TYPE_UDP  = 15'h0011;
localparam TYPE_ICMP = 15'h0001;

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        //ip's src addreess and destination 
        ip_mode_src_addr <= 0;
        ip_mode_dst_addr <= 0;
        //udp'data packet
        udp_rx_axis_tdata <= 0;
        udp_rx_axis_tkeep <= 0;
        udp_rx_axis_tvalid<= 0;
        udp_rx_axis_tuser <= 0;
        udp_rx_axis_tlast <= 0;
        //icmp's data packet
        icmp_rx_axis_tdata<= 0;
        icmp_rx_axis_tkeep<= 0;
        icmp_rx_axis_tvalid<= 0;
        icmp_rx_axis_tuser<= 0;
        icmp_rx_axis_tlast<= 0;
    end
    else if (recv_type == TYPE_UDP) begin
        //ip's src addreess and destination 
        ip_mode_src_addr <= recv_src_ip_addr;
        ip_mode_dst_addr <= recv_dst_ip_addr;
        //udp'data packet
        // udp_rx_axis_tdata <= ip_rx_axis_tdata;
        // udp_rx_axis_tkeep <= ip_rx_axis_tkeep;
        udp_rx_axis_tdata <= {
        ip_rx_axis_tdata[7:0],
        ip_rx_axis_tdata[15:8],
        ip_rx_axis_tdata[23:16],
        ip_rx_axis_tdata[31:24],
        ip_rx_axis_tdata[39:32],
        ip_rx_axis_tdata[47:40],
        ip_rx_axis_tdata[55:48],
        ip_rx_axis_tdata[63:56]
        };  
        
        udp_rx_axis_tkeep <={
        ip_rx_axis_tkeep[0],
        ip_rx_axis_tkeep[1],
        ip_rx_axis_tkeep[2],
        ip_rx_axis_tkeep[3],
        ip_rx_axis_tkeep[4],
        ip_rx_axis_tkeep[5],
        ip_rx_axis_tkeep[6],
        ip_rx_axis_tkeep[7]
    };
        udp_rx_axis_tvalid<= ip_rx_axis_tvalid;
        udp_rx_axis_tuser <= ip_rx_axis_tuser;
        udp_rx_axis_tlast <= ip_rx_axis_tlast;
        //icmp's data packet
        icmp_rx_axis_tdata<= 0;
        icmp_rx_axis_tkeep<= 0;
        icmp_rx_axis_tvalid<= 0;
        icmp_rx_axis_tuser<= 0;
        icmp_rx_axis_tlast<= 0;        
    end
    else if (recv_type == TYPE_ICMP) begin
        //ip's src addreess and destination 
        ip_mode_src_addr <= recv_src_ip_addr;
        ip_mode_dst_addr <= recv_dst_ip_addr;
        //udp'data packet
        udp_rx_axis_tdata <= 0;
        udp_rx_axis_tkeep <= 0;
        udp_rx_axis_tvalid<= 0;
        udp_rx_axis_tuser <= 0;
        udp_rx_axis_tlast <= 0;
        //icmp's data packet
        icmp_rx_axis_tdata  <= ip_rx_axis_tdata;
        icmp_rx_axis_tkeep  <= ip_rx_axis_tkeep;
        icmp_rx_axis_tvalid <= ip_rx_axis_tvalid;
        icmp_rx_axis_tuser  <= ip_rx_axis_tuser;
        icmp_rx_axis_tlast  <= ip_rx_axis_tlast;       
    end
    else begin
        //ip's src addreess and destination 
        ip_mode_src_addr <= 0;
        ip_mode_dst_addr <= 0;
        //udp'data packet
        udp_rx_axis_tdata <= 0;
        udp_rx_axis_tkeep <= 0;
        udp_rx_axis_tvalid<= 0;
        udp_rx_axis_tuser <= 0;
        udp_rx_axis_tlast <= 0;
        //icmp's data packet
        icmp_rx_axis_tdata<= 0;
        icmp_rx_axis_tkeep<= 0;
        icmp_rx_axis_tvalid<= 0;
        icmp_rx_axis_tuser<= 0;
        icmp_rx_axis_tlast<= 0;        
    end
end

endmodule

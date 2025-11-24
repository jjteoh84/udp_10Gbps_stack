/****************************************************************************
 * @file    us_arp_table.v
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

module us_arp_table(
    input   wire      clk              ,
    input   wire      rstn             ,

    input   [47:0]    recv_src_mac_addr,
    input   [31:0]    recv_src_ip_addr ,
    input   [31:0]    dst_ip_addr      ,
    output reg [47:0] dst_mac_addr     ,

    input             arp_valid        ,

    output  reg       arp_request_req   ,
    input             arp_request_ack   ,

    output  reg      arp_mac_exit  ,   
    output     arp_register

);
    
reg     [79:0]  arp_register    =   0;

/* **********************************************************************
 * arp table state machine
 **********************************************************************/

localparam [2:0]  ARP_IDLE  = 3'b001;
localparam [2:0]  ARP_REQ   = 3'b010;
localparam [2:0]  ARP_END   = 3'b100;
localparam [31:0] ARP_TIMEOUT_CYCLES = 32'd156250000; // ~1s at 156.25 MHz (adjust: 32'd78125000 for 0.5s)

reg        [2:0]  arp_state = 0;
reg        [2:0]  arp_next_state ;

reg        [31:0] counter   = 0;

always @(posedge clk) begin
    if(~rstn)begin
        arp_state       <= ARP_IDLE;  
    end
    else begin
        arp_state       <= arp_next_state;
    end
end

reg arp_valid_dly = 1'b0;
always @(posedge clk) arp_valid_dly <= arp_valid;
wire valid_edge = arp_valid & ~arp_valid_dly;


always @(posedge clk) begin
    if (~rstn) begin
        arp_register <= {32'h0,{48{1'b1}}};
    end
    else if (valid_edge) begin
        arp_register <= {recv_src_ip_addr, recv_src_mac_addr};  // Edge-safe
    end
    else begin
        arp_register <= arp_register;
    end
end

always @(posedge clk) begin
    if (~rstn) begin
        arp_mac_exit  <= 0;
        dst_mac_addr  <= {48{1'b1}};
    end
    else if (dst_ip_addr == arp_register[79:48] && (arp_register[47:0] != {48{1'b1}})) begin
        arp_mac_exit  <= 1;
        dst_mac_addr  <= arp_register[47:0];
    end
    else begin
        arp_mac_exit  <= 0;
        dst_mac_addr  <= {48{1'b1}};
    end    
end






always @(*) begin
    case (arp_state)
        ARP_IDLE: begin
                    if (~arp_mac_exit) begin
                        arp_next_state <= ARP_REQ;
                    end
                    else begin
                        arp_next_state <= ARP_IDLE;
                    end
                  end 
       
        ARP_REQ : begin
                    if (arp_request_ack) begin
                        arp_next_state <= ARP_END;
                    end
                    else begin
                        arp_next_state <= ARP_REQ;
                    end
                  end 
        ARP_END : begin
                    if (arp_mac_exit) begin
                        arp_next_state  <= ARP_IDLE;
                    end
                    else if (counter == ARP_TIMEOUT_CYCLES) begin
                        arp_next_state  <= ARP_IDLE;
                    end
                    else begin
                        arp_next_state  <= ARP_END;
                    end
                  end 
        

        default : begin
            arp_next_state  <= ARP_IDLE;
        end
    endcase
end





always @(posedge clk) begin
    if (~rstn) begin
        counter <= 0;
    end
    else if(arp_state == ARP_END)begin
        counter <= counter + 1;
    end
    else begin
        counter <= 0;
    end
end

always @(posedge clk) begin
    if (~rstn) begin
        arp_request_req  <= 0;
    end
    else if (arp_state == ARP_IDLE &(arp_state != arp_next_state)) begin
        arp_request_req  <= 1;
    end
    else if(arp_request_ack)begin
        arp_request_req  <= 0;
    end
end



endmodule //arp_table



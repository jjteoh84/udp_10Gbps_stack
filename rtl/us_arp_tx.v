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

/*
+------+------+--+---+------+----------+--------+---------+--------+
| HType| PType|HL|PL |Opcode|SenderMAC |SenderIP|TargetMAC|TargetIP|
| (2B) | (2B) |1B|1B | (2B) |   (6B)   |   (4B) | (6B)    |  (4B)  |
+------+------+--+---+-----+----------+------+------------+--------+
ex:
+------+------+--+---+------+------------------+-------------+------------------+-------------+
| HType| PType|HL|PL |Opcode|   SenderMAC      |  SenderIP   |   TargetMAC      |  TargetIP   |
+------+------+--+---+------+------------------+-------------+------------------+-------------+
|0x0001|0x0800|06|04|0x0001|ac:14:45:ff:af:c4 |192.168.1.144|00:00:00:00:00:00 |192.168.1.149|
+------+------+--+---+------+------------------+-------------+------------------+-------------+
*/


`timescale 1ns/1ps

module us_arp_tx(
    input       wire        tx_axis_aclk,
    input       wire        tx_axis_aresetn,

	/* arp tx axis interface */
    output reg [63:0]       arp_tx_axis_tdata,
    output reg [7:0]        arp_tx_axis_tkeep,
    output reg              arp_tx_axis_tvalid,		 
    output reg              arp_tx_axis_tlast,
    input                   arp_tx_axis_tready,

    input       wire[47:0]  dst_mac_addr,
    input       wire[47:0]  src_mac_addr,

    output reg				arp_not_empty,	

    input       wire[31:0]  dst_ip_addr,
    input       wire[31:0]  src_ip_addr,  

    output      reg         arp_reply_ack,
    input       wire        arp_reply_req,
    output      reg         arp_request_ack,
    input       wire        arp_request_req    

);

/* **********************************************************************
 * arp data packet
 **********************************************************************/

localparam mac_type         = 16'h0806 ;
localparam hardware_type    = 16'h0001 ;
localparam protocol_type    = 16'h0800 ;
localparam mac_length       = 8'h06    ;
localparam ip_length        = 8'h04    ;

localparam ARP_REQUEST_CODE = 16'h0001 ;
localparam ARP_REPLY_CODE   = 16'h0002 ;
    
reg  [15:0]        op       =   0;					
reg  [31:0]        arp_dst_ip_addr  =   0;	
reg  [47:0]        arp_dst_mac_addr =   0;	
reg  [31:0]		   timeout  =   0;			


/* **********************************************************************
 * arp send state machine
 **********************************************************************/

localparam  [8:0]   ARP_IDLE       =   9'b000000001;
localparam  [8:0]   ARP_REQUEST    =   9'b000000010;
localparam  [8:0]   ARP_REPLY      =   9'b000000100;
localparam  [8:0]   ARP_TX_DATA0   =   9'b000001000;
localparam  [8:0]   ARP_TX_DATA1   =   9'b000010000;
localparam  [8:0]   ARP_TX_DATA2   =   9'b000100000;
localparam  [8:0]   ARP_TX_DATA3   =   9'b001000000;
localparam  [8:0]   ARP_TIMEOUT    =   9'b010000000;
localparam  [8:0]   ARP_ENDL       =   9'b100000000;

reg         [8:0]   arp_state      =    0;
reg         [8:0]   arp_next_state =    0;

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        arp_state       <= ARP_IDLE;
//        arp_next_state  <= ARP_IDLE;
    end
    else begin
        arp_state  <= arp_next_state;
    end
end

always @(*) begin
    case (arp_state)
        ARP_IDLE    : begin
                            if (arp_request_req) begin
                                arp_next_state  <= ARP_REQUEST;
                            end
                            else if(arp_reply_req)begin
                                arp_next_state  <= ARP_REPLY;
                            end
                            else begin
                                arp_next_state  <= ARP_IDLE;
                            end
                      end
        ARP_REQUEST : begin
                            arp_next_state  <= ARP_TX_DATA0 ;
                      end        
        ARP_REPLY   : begin
                            arp_next_state  <= ARP_TX_DATA0 ;
                      end      
        ARP_TX_DATA0: begin
                            if (arp_tx_axis_tready & arp_tx_axis_tvalid) begin
                                arp_next_state <= ARP_TX_DATA1;
                            end
                            else if(timeout == 32'd999999)begin
                                arp_next_state <= ARP_TIMEOUT;
                            end
                            else begin
                                arp_next_state <= ARP_TX_DATA0;
                            end
                      end 
        ARP_TX_DATA1: begin
                            if (arp_tx_axis_tready & arp_tx_axis_tvalid) begin
                                arp_next_state <= ARP_TX_DATA2;
                            end
                            else begin
                                arp_next_state <= ARP_TX_DATA1;
                            end
                      end        
        ARP_TX_DATA2: begin
                            if (arp_tx_axis_tready & arp_tx_axis_tvalid) begin
                                arp_next_state <= ARP_TX_DATA3;
                            end
                            else begin
                                arp_next_state <= ARP_TX_DATA2;
                            end
                      end 
        ARP_TX_DATA3: begin
                            if (arp_tx_axis_tready & arp_tx_axis_tvalid) begin
                                arp_next_state <= ARP_ENDL;
                            end
                            else begin
                                arp_next_state <= ARP_TX_DATA3;
                            end
                      end                        
        ARP_TIMEOUT : begin
                            arp_next_state  <= ARP_IDLE ;
                      end
        ARP_ENDL    : begin
                            arp_next_state  <= ARP_IDLE ;
                      end
        default: begin
                       arp_next_state  <= ARP_IDLE ;     
                 end
    endcase
end

// op code
always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        op <= 0;
    end
    else if(arp_state == ARP_REPLY)begin
        op <= ARP_REPLY_CODE;
    end
    else if(arp_state == ARP_REQUEST)begin
        op <= ARP_REQUEST_CODE;
    end
    else begin
        op <= op;
    end
end

// time out
always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        timeout  <= 0;
    end
    else if(arp_state == ARP_TX_DATA0)begin
        timeout  <= timeout + 1;
    end
    else begin
        timeout  <= 0;
    end
end


always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        arp_not_empty <= 0;
    end
    else if(arp_state == ARP_REQUEST || arp_state == ARP_REPLY)begin
        arp_not_empty <= 1;
    end
    else begin
        arp_not_empty <= 0;
    end
end



always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        arp_dst_ip_addr  <= 0;
    end
    else if(arp_state == ARP_REPLY || arp_state == ARP_REQUEST)begin
        arp_dst_ip_addr <= dst_ip_addr;
    end
    else begin
        arp_dst_ip_addr  <= arp_dst_ip_addr;
    end
end


always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        arp_dst_mac_addr  <= 0;
    end
    else if(arp_state == ARP_REPLY || arp_state == ARP_REQUEST)begin
        arp_dst_mac_addr <= dst_mac_addr;
    end
    else begin
        arp_dst_mac_addr  <= arp_dst_mac_addr;
    end
end

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        arp_request_ack  <= 0;
    end
    else if(arp_state == ARP_REQUEST)begin
        arp_request_ack  <= 1;
    end
    else begin
        arp_request_ack  <= 0;
    end
end

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        arp_reply_ack  <= 0;
    end
    else if(arp_state == ARP_REPLY)begin
        arp_reply_ack <= 1;
    end
    else begin
        arp_reply_ack <= 0;
    end
end



always @(*) begin
    if (arp_tx_axis_tready) begin
        case (arp_state)
            ARP_TX_DATA0: begin
                arp_tx_axis_tvalid  <= 1;
            end
            ARP_TX_DATA1: begin
                arp_tx_axis_tvalid  <= 1;
            end
            ARP_TX_DATA2: begin
                arp_tx_axis_tvalid  <= 1;
            end
            ARP_TX_DATA3: begin
                arp_tx_axis_tvalid  <= 1;
            end  
            default: begin
                arp_tx_axis_tvalid  <= 0;
            end
        endcase
    end else begin
        arp_tx_axis_tvalid  <= 0;
    end
end

always @(*) begin
    if (~tx_axis_aresetn) begin
        arp_tx_axis_tlast  <= 0;
    end
    else if(arp_state == ARP_TX_DATA3)begin
        arp_tx_axis_tlast  <= 1;
    end
    else begin
        arp_tx_axis_tlast  <= 0;
    end
end

always @(*) begin
    case (arp_state)
        ARP_TX_DATA0 : begin
            arp_tx_axis_tdata  <= { 
                                   hardware_type[15:8], hardware_type[7:0],
                                   protocol_type[15:8], protocol_type[7:0],
                                   mac_length,         ip_length,
                                   op[15:8],           op[7:0]
                                   };
            arp_tx_axis_tkeep  <= 8'hff;
                               
        end
        ARP_TX_DATA1 : begin
            arp_tx_axis_tdata <= {
                                 src_mac_addr[47:40], src_mac_addr[39:32],
                                 src_mac_addr[31:24], src_mac_addr[23:16],
                                 src_mac_addr[15:8],  src_mac_addr[7:0],
                                 src_ip_addr[31:24], src_ip_addr[23:16]
                                };
            arp_tx_axis_tkeep  <= 8'hff;                    
        end
        ARP_TX_DATA2 : begin
            arp_tx_axis_tdata <= {
                                    src_ip_addr[15:8],  src_ip_addr[7:0],
                                    arp_dst_mac_addr[47:40], arp_dst_mac_addr[39:32],
                                    arp_dst_mac_addr[31:24], arp_dst_mac_addr[23:16],
                                    arp_dst_mac_addr[15:8],  arp_dst_mac_addr[7:0]
                                };
            arp_tx_axis_tkeep  <= 8'hff;                     
        end
        ARP_TX_DATA3 : begin
            arp_tx_axis_tdata <= {
                                    arp_dst_ip_addr[31:24], arp_dst_ip_addr[23:16],
                                    arp_dst_ip_addr[15:8],  arp_dst_ip_addr[7:0],
                                    32'h0
                                };
            arp_tx_axis_tkeep  <= 8'h0f;             
        end
        default: begin
            arp_tx_axis_tdata <= 0;
            arp_tx_axis_tkeep <= 0;
        end
    endcase
end

endmodule //us_arp_tx


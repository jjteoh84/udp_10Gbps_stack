/****************************************************************************
 * @file    us_udp_tx.v
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
  0      7 8     15 16    23 24    31
 +--------+--------+--------+--------+
 |          Source IP Address        |
 +--------+--------+--------+--------+
 |       Destination IP Address      |
 +--------+--------+--------+--------+
 |  Zero  |Protocol|     UDP Length  |
 +--------+--------+--------+--------+
  0      7 8     15 16    23 24    31
 +--------+--------+--------+--------+
 |     Source Port | Destination Por |
 +--------+--------+--------+--------+
 |     Length      |  Checksum       |
 +--------+--------+--------+--------+

 */

`timescale 1ns/1ps

module us_udp_tx_v1(

    input      [31:0]                src_ip_addr,     //source ip address
    input      [31:0]                dst_ip_addr,     //destination ip address
                                           
    input      [15:0]                udp_src_port,    //udp source port
    input      [15:0]                udp_dst_port,    //udp destination port
          
	input                            tx_axis_aclk,
    input                            tx_axis_aresetn, 
	/* udp tx axis interface */		  
    input  [63:0]       			 udp_tx_axis_tdata,
    input  [7:0]     			     udp_tx_axis_tkeep,
    input                            udp_tx_axis_tvalid,		 
    input                            udp_tx_axis_tlast,
    output                           udp_tx_axis_tready,
	/* tx axis interface to ip */
	output reg [63:0]       		 ip_tx_axis_tdata,
    output reg [7:0]     		     ip_tx_axis_tkeep,
    output reg                       ip_tx_axis_tvalid,		 
    output reg                       ip_tx_axis_tlast,
    input                            ip_tx_axis_tready,

	input				     		 mac_exist,		
    output 	                         udp_not_empty			

);

reg                 udp_tx_axis_tlast_d1 = 0 ;
reg                 udp_tx_axis_tlast_d0 = 0;
/* ******************************************************************************
 * checksum parameter decare
 *******************************************************************************/
reg        [15:0]  checksum_payload   = 0;
reg        [15:0]  checksum_payload0  = 0;
reg        [15:0]  checksum_payload1  = 0;
reg        [15:0]  checksum_payload2  = 0;
reg        [15:0]  checksum_payload3  = 0;
reg        [15:0]  checksum_temp_load0= 0;
reg        [15:0]  checksum_temp_load1= 0;
reg        [15:0]  checksum_temp_load2= 0;
reg        [15:0]  checksum_temp_load3= 0;
reg        [15:0]  checksum_header0   = 0;
reg        [15:0]  checksum_header1   = 0;
reg        [15:0]  checksum_header2   = 0;
reg        [15:0]  checksum_header3   = 0;
reg        [15:0]  checksum_header4   = 0;
reg        [15:0]  checksum_header5   = 0;
reg        [15:0]  checksum_header6   = 0;
reg        [15:0]  checksum_header7   = 0;
reg        [15:0]  checksum_header8   = 0;

/* ******************************************************************************
 * STATE machine for check sum
 *******************************************************************************/
localparam [3:0]    CKS_IDLE      = 4'b0001;
localparam [3:0]    CKS_LENGTH    = 4'b0010;
localparam [3:0]    CKS_PACKET    = 4'b0100;
localparam [3:0]    CKS_ENDL      = 4'b1000;

reg        [3:0]    cks_state        = 4'b0;
reg        [3:0]    cks_next_state   = 4'b0;
reg        [6:0]    check_count      = 7'b0;
reg        [15:0]   checksum         = 'b0;
wire       [15:0]   packet_len_bytes;

reg         [15:0]  checksum_length =   0;
reg         [15:0]  checksum_data   =   0;

//wire            udp_payload_fifo_almost_full    ;
//wire            udp_payload_fifo_empty          ;
//wire            udp_payload_fifo_full           ;
wire [73:0]     udp_payload_fifo_data           ;
reg             udp_payload_fifo_rden    = 0    ;

reg             udp_checksum_rden   =   0   ;
wire [31:0]     udp_checksum_dout           ;    
wire            udp_checksum_almost_full    ;
wire            udp_checksum_empty          ;

reg             checkpacket_rden    =   0;
reg             checkpacket_wren    =   0;
wire [31:0]     checkpacket_dout;
wire            checkpacket_empty        ;
wire            checkpacket_almost_full  ;
/* ******************************************************************************
 * STATE machine for ip tx
 *******************************************************************************/
localparam [6:0]    IP_IDLE    = 7'b0000001;
localparam [6:0]    IP_WAIT    = 7'b0000010;
localparam [6:0]    IP_HEADER  = 7'b0000100;
localparam [6:0]    IP_DATA    = 7'b0001000;
localparam [6:0]    IP_END0    = 7'b0010000;
localparam [6:0]    IP_END1    = 7'b0100000;
localparam [6:0]    IP_END2    = 7'b1000000;

reg        [6:0]    ip_state        = 4'b0;
reg        [6:0]    ip_next_state   = 4'b0;
reg                 ip_start        =   0;


assign udp_tx_axis_tready = mac_exist & ~(checkpacket_almost_full | udp_checksum_almost_full);

assign udp_not_empty      = ~checkpacket_empty;
/* ******************************************************************************
 * 1. Calcute udp data packet length
 *******************************************************************************/
axis_counter u_axis_counter(
    .axis_aclk        	(tx_axis_aclk             ),
    .axis_aresetn     	(tx_axis_aresetn          ),
    .axis_tvalid      	(udp_tx_axis_tvalid       ),
    .axis_tready      	(udp_tx_axis_tready       ),
    .axis_tdata       	(udp_tx_axis_tdata        ),
    .axis_tlast       	(udp_tx_axis_tlast        ),
    .axis_tkeep       	(udp_tx_axis_tkeep        ),
    .packet_len_bytes 	(packet_len_bytes         )
);

/* Two-stage register for tlast  */
always @(posedge tx_axis_aclk)
begin
    if (~tx_axis_aresetn)
	begin
		udp_tx_axis_tlast_d0 <= 1'b0 ;
		udp_tx_axis_tlast_d1 <= 1'b0 ;
	end
	else
	begin
		udp_tx_axis_tlast_d0 <= udp_tx_axis_tlast ;
		udp_tx_axis_tlast_d1 <= udp_tx_axis_tlast_d0 ;
	end
end

//Store the packet portion of udp in the fifo
xpm_sync_fifo #(
    .WIDTH     	(74     ),
    .DEPTH     	(11     ),
    .FIFO_TYPE 	("fwft"  )
    )
udp_payload(
    .clk         	(tx_axis_aclk                                                   ),
    .rst_n       	(tx_axis_aresetn                                                ),
    .wr_en       	(udp_tx_axis_tready & udp_tx_axis_tvalid                        ),
    .rd_en       	(udp_payload_fifo_rden                                          ),
    .data        	({udp_tx_axis_tdata ,udp_tx_axis_tkeep,
                             udp_tx_axis_tvalid, udp_tx_axis_tlast}                        ),
    .dout        	(udp_payload_fifo_data                                          ),
    .full        	(  ),
    .empty       	(  ),
    .almost_full 	(  )
);

/* ******************************************************************************
 * 2. Calcute udp data packet checksum
 *******************************************************************************/
function    [15:0]  checksum_gen
  (
    input       [15:0]  dataina,
    input       [15:0]  datainb
  );
  
    reg [16:0]  sum ;

  begin
    sum = dataina[15:0] + datainb[15:0];
    checksum_gen = sum[16] ? sum[15:0] + 1 : sum[15:0];
  end
  
endfunction

function    [15:0]  checksum_plus
  (
    input       [15:0]  dataina,
    input       [15:0]  datainb,
    input       [15:0]  datainc,
    input       [15:0]  dataind
  );
  
  reg [15:0]  sum0;
  reg [15:0]  sum1;

  begin
    sum0 = checksum_gen(dataina , datainb);
    sum1 = checksum_gen(sum0    , datainc);
    checksum_plus = checksum_gen(sum1    , dataind);
  end
  
endfunction

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        cks_state      <= CKS_IDLE;
    end else begin
        cks_state      <= cks_next_state;
    end
end

always @(*) begin
    case (cks_state)
        CKS_IDLE    : begin
            if(~udp_checksum_empty )begin
                cks_next_state  <= CKS_LENGTH;
            end
            else begin
                cks_next_state  <= CKS_IDLE;
            end
        end
        CKS_LENGTH : begin
            // if (udp_tx_axis_tlast) begin
            cks_next_state  <= CKS_PACKET;
            // end
            // else begin
            //     cks_next_state  <= CKS_PAYLOAD;
            // end
        end
        CKS_PACKET  : begin
            if (check_count == 6) begin
                cks_next_state <= CKS_ENDL;
            end
            else cks_next_state <= CKS_PACKET;
        end 
        CKS_ENDL    : begin
            cks_next_state  <= CKS_IDLE;
        end
        default: begin
            cks_next_state <= CKS_IDLE;
        end
    endcase
end

always @(posedge  tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        checksum_temp_load0<= 0;
        checksum_temp_load1<= 0;
        checksum_temp_load2<= 0;
        checksum_temp_load3<= 0;
        // checksum_payload   <= 0;
        checksum_payload0  <= 0;
        checksum_payload1  <= 0;
        checksum_payload2  <= 0;
        checksum_payload3  <= 0;
    end
    else if (udp_tx_axis_tready & udp_tx_axis_tvalid) begin
        if (udp_tx_axis_tlast) begin
            case (udp_tx_axis_tkeep)
                8'b00000001: begin
                    checksum_payload0 <= checksum_gen(checksum_temp_load0, {udp_tx_axis_tdata[7:0], 8'h00});
                    checksum_payload1 <= checksum_temp_load1;
                    checksum_payload2 <= checksum_temp_load2;
                    checksum_payload3 <= checksum_temp_load3;
                end
                8'b00000011: begin
                    checksum_payload0 <= checksum_gen(checksum_temp_load0, {udp_tx_axis_tdata[7:0], udp_tx_axis_tdata[15:8]});        
                    checksum_payload1 <= checksum_temp_load1;
                    checksum_payload2 <= checksum_temp_load2;
                    checksum_payload3 <= checksum_temp_load3;          
                end
                8'b00000111: begin
                    checksum_payload0 <= checksum_gen(checksum_temp_load0, {udp_tx_axis_tdata[7:0]  , udp_tx_axis_tdata[15:8]});  
                    checksum_payload1 <= checksum_gen(checksum_temp_load1, {udp_tx_axis_tdata[23:16], 8'h0});          
                    checksum_payload2 <= checksum_temp_load2;
                    checksum_payload3 <= checksum_temp_load3;                   
                end
                8'b00001111: begin
                    checksum_payload0 <= checksum_gen(checksum_temp_load0, {udp_tx_axis_tdata[7:0]  , udp_tx_axis_tdata[15:8]});  
                    checksum_payload1 <= checksum_gen(checksum_temp_load1, {udp_tx_axis_tdata[23:16], udp_tx_axis_tdata[31:24]}); 
                    checksum_payload2 <= checksum_temp_load2;
                    checksum_payload3 <= checksum_temp_load3;                            
                end
                8'b00011111: begin
                    checksum_payload0 <= checksum_gen(checksum_temp_load0, {udp_tx_axis_tdata[7:0]  , udp_tx_axis_tdata[15:8]});  
                    checksum_payload1 <= checksum_gen(checksum_temp_load1, {udp_tx_axis_tdata[23:16], udp_tx_axis_tdata[31:24]}); 
                    checksum_payload2 <= checksum_gen(checksum_temp_load2, {udp_tx_axis_tdata[39:32], 8'h00});      
                    checksum_payload3 <= checksum_temp_load3;                  
                end
                8'b00111111: begin
                    checksum_payload0 <= checksum_gen(checksum_temp_load0, {udp_tx_axis_tdata[7:0]  , udp_tx_axis_tdata[15:8]});  
                    checksum_payload1 <= checksum_gen(checksum_temp_load1, {udp_tx_axis_tdata[23:16], udp_tx_axis_tdata[31:24]}); 
                    checksum_payload2 <= checksum_gen(checksum_temp_load2, {udp_tx_axis_tdata[39:32], udp_tx_axis_tdata[47:40]});       
                    checksum_payload3 <= checksum_temp_load3;                     
                end
                8'b01111111: begin
                    checksum_payload0 <= checksum_gen(checksum_temp_load0, {udp_tx_axis_tdata[7:0]  , udp_tx_axis_tdata[15:8]});  
                    checksum_payload1 <= checksum_gen(checksum_temp_load1, {udp_tx_axis_tdata[23:16], udp_tx_axis_tdata[31:24]}); 
                    checksum_payload2 <= checksum_gen(checksum_temp_load2, {udp_tx_axis_tdata[39:32], udp_tx_axis_tdata[47:40]}); 
                    checksum_payload3 <= checksum_gen(checksum_temp_load3, {udp_tx_axis_tdata[55:48], 8'h00});                       
                end
                8'b11111111: begin
                    checksum_payload0 <= checksum_gen(checksum_temp_load0, {udp_tx_axis_tdata[7:0]  , udp_tx_axis_tdata[15:8]});  
                    checksum_payload1 <= checksum_gen(checksum_temp_load1, {udp_tx_axis_tdata[23:16], udp_tx_axis_tdata[31:24]}); 
                    checksum_payload2 <= checksum_gen(checksum_temp_load2, {udp_tx_axis_tdata[39:32], udp_tx_axis_tdata[47:40]});   
                    checksum_payload3 <= checksum_gen(checksum_temp_load3, {udp_tx_axis_tdata[55:48], udp_tx_axis_tdata[63:56]});                    
                end                
                default: begin
                    // checksum_payload0  <= 0;
                    // checksum_payload1  <= 0;
                end
            endcase
            checksum_temp_load0<= 0;
            checksum_temp_load1<= 0;
            checksum_temp_load2<= 0;
            checksum_temp_load3<= 0;
            // checksum_temp_load <= 0;
        end
        else begin
            checksum_temp_load0 <= checksum_gen(checksum_temp_load0, {udp_tx_axis_tdata[7:0]   , udp_tx_axis_tdata[15:8]});     
            checksum_temp_load1 <= checksum_gen(checksum_temp_load1, {udp_tx_axis_tdata[23:16] , udp_tx_axis_tdata[31:24]});     
            checksum_temp_load2 <= checksum_gen(checksum_temp_load2, {udp_tx_axis_tdata[39:32] , udp_tx_axis_tdata[47:40]});     
            checksum_temp_load3 <= checksum_gen(checksum_temp_load3, {udp_tx_axis_tdata[55:48] , udp_tx_axis_tdata[63:56]});     
        end
    end
end

reg     [31:0]  check_payload_data = 0;

always @(*) begin
    if(~udp_tx_axis_tlast_d0 &udp_tx_axis_tlast_d1  )begin
        check_payload_data = {packet_len_bytes + 8 , checksum_plus(checksum_payload0,checksum_payload1,checksum_payload2,checksum_payload3)};
    end
    else begin
        check_payload_data = 0;
    end
end

xpm_sync_fifo #(
    .WIDTH     	(32     ),
    .DEPTH     	(6      ),
    .FIFO_TYPE 	("fwft"  )
    )
udp_checkpayload(
    .clk         	(tx_axis_aclk                                                   ),
    .rst_n       	(tx_axis_aresetn                                                ),
    .wr_en       	(~udp_tx_axis_tlast_d0 &udp_tx_axis_tlast_d1                    ),
    .rd_en       	(udp_checksum_rden                                              ),
    .data        	(check_payload_data                                             ),
    .dout        	(udp_checksum_dout                                              ),
    .full        	(                                                               ),
    .empty       	(udp_checksum_empty                                             ),
    .almost_full 	(udp_checksum_almost_full                                       )
);

always @(posedge tx_axis_aclk) begin
    if(~tx_axis_aresetn)begin
        udp_checksum_rden <= 0;
    end else if (cks_state == CKS_LENGTH) begin
        udp_checksum_rden <= 1;
    end else begin
        udp_checksum_rden <= 0;
    end
end

always @(posedge tx_axis_aclk) begin
    if(~tx_axis_aresetn)begin
        checksum_length <= 0;
        checksum_data   <= 0;
    end else if (cks_state == CKS_LENGTH) begin
        checksum_length <= udp_checksum_dout[31:16];
        checksum_data   <= udp_checksum_dout[15:0];
    end 
end


always @(posedge tx_axis_aclk) begin
    if(~tx_axis_aresetn)begin
        check_count <= 0;
    end else if (cks_state == CKS_PACKET) begin
        check_count <= check_count + 1;
    end else begin
        check_count <= 0;
    end
end

always @(posedge tx_axis_aclk) begin
    if(~tx_axis_aresetn)begin
        checksum_header0 <= 0;
        checksum_header1 <= 0;
        checksum_header2 <= 0;
        checksum_header3 <= 0;
        checksum_header4 <= 0;
        checksum_header5 <= 0;
        checksum_header6 <= 0;
        checksum_header7 <= 0;
        checksum_header8 <= 0;
    end
    else if (cks_state == CKS_PACKET) begin
        checksum_header0  <=  checksum_gen( src_ip_addr[15:0]  , src_ip_addr[31:16]);
        checksum_header1  <=  checksum_gen( dst_ip_addr[15:0]  , dst_ip_addr[31:16]);
        checksum_header2  <=  checksum_gen({8'h0000, 8'd17}    , checksum_length);
        checksum_header3  <=  checksum_gen(udp_src_port        , udp_dst_port);
        checksum_header4  <=  checksum_gen(checksum_data  ,  checksum_length);
        checksum_header5  <=  checksum_gen(checksum_header0  , checksum_header1);
        checksum_header6  <=  checksum_gen(checksum_header2  , checksum_header3);
        checksum_header7  <=  checksum_gen(checksum_header4  , checksum_header5);
        checksum_header8  <=  checksum_gen(checksum_header6  , checksum_header7);
    end
    else if(cks_state == CKS_IDLE)begin
        checksum_header0 <= 0;
        checksum_header1 <= 0;
        checksum_header2 <= 0;
        checksum_header3 <= 0;
        checksum_header4 <= 0;
        checksum_header5 <= 0;
        checksum_header6 <= 0;
        checksum_header7 <= 0;
        checksum_header8 <= 0;        
    end
    else begin
        checksum_header0 <= checksum_header0;
        checksum_header1 <= checksum_header1;
        checksum_header2 <= checksum_header2;
        checksum_header3 <= checksum_header3;
        checksum_header4 <= checksum_header4;
        checksum_header5 <= checksum_header5;
        checksum_header6 <= checksum_header6;
        checksum_header7 <= checksum_header7;
        checksum_header8 <= checksum_header8;                
    end
end

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        checkpacket_wren  <= 0;
    end
    else if (cks_state == CKS_ENDL) begin
        checkpacket_wren  <= 1;
    end
    else begin
        checkpacket_wren <= 0;
    end
end



xpm_sync_fifo #(
    .WIDTH     	(32     ),
    .DEPTH     	(6      ),
    .FIFO_TYPE 	("fwft"  )
    )
udp_checkpacket(
    .clk         	(tx_axis_aclk                                                   ),
    .rst_n       	(tx_axis_aresetn                                                ),
    .wr_en       	(checkpacket_wren                                               ),
    .rd_en       	(checkpacket_rden                                               ),
    .data        	({~checksum_header8 ,checksum_length      }                     ),
    .dout        	(checkpacket_dout                                               ),
    .full        	(                                                               ),
    .empty       	(checkpacket_empty                                              ),
    .almost_full 	(checkpacket_almost_full                                        )
);

/* ******************************************************************************
 * 3. send data packet to ip module
 *******************************************************************************/

reg [31:0]  checksum_packet_length =   0;
reg [31:0]  checksum_packet_data   =   0;


always @(posedge tx_axis_aclk) begin
    if(~tx_axis_aresetn)begin
        ip_state      <= IP_IDLE;
    end 
    else begin
        ip_state      <= ip_next_state;
    end
end

always @(*) begin
    case (ip_state)
        IP_IDLE   : begin
            if (udp_not_empty & ip_tx_axis_tready) begin
                ip_next_state <= IP_WAIT;
            end
            else begin
                ip_next_state <= IP_IDLE;
            end
        end 
        IP_WAIT :begin
            ip_next_state <= IP_HEADER;
        end
        IP_HEADER : begin
            if(ip_tx_axis_tready)begin
                ip_next_state <= IP_DATA;
            end
            else begin
                ip_next_state <= IP_HEADER;
            end
        end
        IP_DATA   : begin
            if (ip_tx_axis_tlast & ip_tx_axis_tvalid & ip_tx_axis_tready) begin
                ip_next_state <= IP_END0;
            end
            else begin
                ip_next_state <= IP_DATA;
            end
        end
        IP_END0:begin
            ip_next_state <= IP_END1;
        end
        IP_END1:begin
            ip_next_state <= IP_END2;
        end
        IP_END2:begin
            ip_next_state <= IP_IDLE;
        end
        default: begin
            ip_next_state <= IP_IDLE;
        end
    endcase
end


always @(posedge tx_axis_aclk) begin
    if(~tx_axis_aresetn)begin
        checkpacket_rden <= 0;
    end else if (ip_state == IP_IDLE & (ip_state != ip_next_state)) begin
        checkpacket_rden <= 1;
    end else begin
        checkpacket_rden <= 0;
    end
end

always @(posedge tx_axis_aclk) begin
    if(~tx_axis_aresetn)begin
        checksum_packet_length <= 0;
        checksum_packet_data   <= 0;
    end else if (ip_state == IP_WAIT) begin
        checksum_packet_length <= checkpacket_dout[15:0];
        checksum_packet_data   <= checkpacket_dout[31:16];
    end 
end


always @(*) begin
    udp_payload_fifo_rden = (ip_state == IP_DATA) & ip_tx_axis_tready ? 1 : 0;
end
 
always @(*) begin
    if (~tx_axis_aresetn) begin
        ip_tx_axis_tdata  <= 0;
        ip_tx_axis_tkeep  <= 0;
        ip_tx_axis_tlast  <= 0;
        ip_tx_axis_tvalid <= 0;
    end 
    else if (ip_state == IP_HEADER) begin
        ip_tx_axis_tdata  <= {
                                udp_src_port[15:8], udp_src_port[7:0],
                                udp_dst_port[15:8], udp_dst_port[7:0],
                                checksum_packet_length[15:8], checksum_packet_length[7:0],
                                checksum_packet_data[15:8], checksum_packet_data[7:0]
                             };
        ip_tx_axis_tkeep  <= 8'hff;
        ip_tx_axis_tlast  <= 0;
        ip_tx_axis_tvalid <= 1;        
    end
    else if (ip_state == IP_DATA) begin
        ip_tx_axis_tdata  <= udp_payload_fifo_data[73:10];
        ip_tx_axis_tkeep  <= udp_payload_fifo_data[9:2];
        ip_tx_axis_tlast  <= udp_payload_fifo_data[0];
        ip_tx_axis_tvalid <= udp_payload_fifo_data[1];
    end
    else begin
        ip_tx_axis_tdata  <= 0;
        ip_tx_axis_tkeep  <= 0;
        ip_tx_axis_tlast  <= 0;
        ip_tx_axis_tvalid <= 0;        
    end
end

endmodule //us_udp_tx


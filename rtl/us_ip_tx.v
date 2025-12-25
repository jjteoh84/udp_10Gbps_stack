/****************************************************************************
 * @file    us_ip_tx.v
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

/*******************************************************************************
 ***********************************ip header 20 BYTE**********************************

  0                   1                   2                   3  
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |Version|  IHL  |Type of Service|          Total Length         |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |         Identification        |Flags|      Fragment Offset    |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |  Time to Live |    Protocol   |         Header Checksum       |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                       Source Address                          |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                    Destination Address                        |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                    Options (if any)           |    Padding    |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

|-----------------------------------------------------------------------------------------------------------------------|
| Field                        | Length (bits) | Description                                                            |
| ---------------------------- | ------------- | ---------------------------------------------------------------------- |
| Version                      | 4             | IP protocol version (IPv4 = 4)                                         |
| IHL (Header Length)          | 4             | Header length, in 32-bit words. Minimum value is 5 (20 bytes).         |
| Type of Service (TOS) / DSCP | 8             | Type of Service / Differentiated Services Code Point                   |
| Total Length                 | 16            | Total length of the IP datagram (header + data), in bytes              |
| Identification               | 16            | Datagram identifier, used for fragmentation and reassembly             |
| Flags                        | 3             | Fragmentation control flags (DF = Don't Fragment, MF = More Fragments) |
| Fragment Offset              | 13            | Fragment offset within the original datagram, in 8-byte units          |
| Time To Live (TTL)           | 8             | Time to live, maximum hop count                                        |
| Protocol                     | 8             | Upper-layer protocol number (TCP = 6, UDP = 17, ICMP = 1, etc.)        |
| Header Checksum              | 16            | Checksum for the header                                                |
| Source IP Address            | 32            | Source IP address                                                      |
| Destination IP Address       | 32            | Destination IP address                                                 |
| Options (optional)           | variable      | Optional fields (e.g., routing, timestamp), usually omitted            |
| Padding                      | variable      | Padding to align the header to a 32-bit boundary                       |

*******************************************************************************/
// plus

// An 8-byte UDP header.
// Source Port (2 bytes): 0x1234
// Destination Port (2 bytes): 0x5678
// UDP Length (2 bytes): 8 (header) + 5 (payload) = 13 bytes (0x000D).
// UDP Checksum (2 bytes): Calculated over a pseudo-header, the UDP header, and the payload.

//plus

// The raw payload N bytes.

`timescale 1ns/1ps

module us_ip_tx(
        input  [7:0]         			ip_send_type,			//send type : udp or icmp
        input  [31:0]        			src_ip_addr,			//source ip address
        input  [31:0]        			dst_ip_addr,			//destination ip address
			
					
		input                			tx_axis_aclk,
        input                			tx_axis_aresetn,  
		/* ip tx axis interface */			
		input  [63:0]        			ip_tx_axis_tdata,
        input  [7:0]     	  			ip_tx_axis_tkeep,
        input                			ip_tx_axis_tvalid,		 
        input                			ip_tx_axis_tlast,
        output 	           				ip_tx_axis_tready,
		/* tx axis interface to frame */			
		output reg [63:0]    			frame_tx_axis_tdata,
		output reg [7:0]     			frame_tx_axis_tkeep,
		output reg           			frame_tx_axis_tvalid,	
		output reg           			frame_tx_axis_tlast,
        input                			frame_tx_axis_tready,
		 
		output						 	ip_not_empty,	//ip layer is ready to send data
		output 						    recv_ip_end			//receive stream end signal
);




localparam ip_version    = 4'h4     ;  //ipv4
localparam header_len    = 4'h5     ;  //header length Fixed 5
localparam TTL    		 = 8'hff     ;  //ttl

/* ******************************************************************************
 * STATE machine for check sum
 *******************************************************************************/

localparam	CKS_IDLE	=	4'b0001;
localparam	CKS_GEN0	=	4'b0010;
localparam	CKS_GEN1	=	4'b0100;
localparam	CKS_ENDL	=	4'b1000;

reg [3:0]	cks_state		=	0;
reg [3:0]	cks_next_state	=	0;

 /* ******************************************************************************
 * 1. calculate udp packet's length
 *******************************************************************************/
wire		stream_byte_fifo_empty		 ;
reg 		stream_byte_rden		=	0;
wire [31:0] stream_byte_rdata			 ;
reg         stream_data_rden             ;
wire [73:0] stream_data_rdata		   	 ;


eth_axis_fifo 
	#(
		.TransType("IP")
	)
ip_stream_inst
	(
	.tx_type				   ({8'h00,ip_send_type}    ),		
	.tx_axis_aclk              (tx_axis_aclk            ),
    .tx_axis_aresetn   		   (tx_axis_aresetn  		),			
	.tx_axis_tdata             (ip_tx_axis_tdata        ),
    .tx_axis_tkeep             (ip_tx_axis_tkeep        ),
    .tx_axis_tvalid 		   (ip_tx_axis_tvalid 		), 
    .tx_axis_tlast             (ip_tx_axis_tlast        ),
    .tx_axis_tready 		   (ip_tx_axis_tready 		), 
	.stream_byte_fifo_empty    (stream_byte_fifo_empty  ),		
	.stream_byte_rden	       (stream_byte_rden	    ),
	.stream_byte_rdata 	       (stream_byte_rdata 	    ),	 
	.stream_data_rden          (stream_data_rden        ),
	.stream_data_rdata  	   (stream_data_rdata  	    ),	 
	.rcv_stream_end            (recv_ip_end             )
    );

 /* ******************************************************************************
 * 2. calculate ip header checksum
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

reg [15:0]      checksum_header = 0;
reg [15:0]		checksum_header0= 0;
reg [15:0]		checksum_header1= 0;
reg [15:0]		checksum_header2= 0;
reg [15:0]		checksum_header3= 0;
reg [15:0]		checksum_header4= 0;
reg [15:0]		checksum_header5= 0;
reg [15:0]		checksum_header6= 0;
reg [15:0]		checksum_header7= 0;
reg [15:0]		checksum_header8= 0;

reg [5:0]		check_counter       = 0;
reg [15:0]		ip_packet_length    = 0;
reg [7:0]		ip_type             = 0;
reg [15:0]      identification      = 0;

reg [55:0]      ip_head_fifo_data   = 0;
wire[55:0]      ip_head_fifo_dout      ;
reg             ip_head_fifo_wren   = 0;
reg             ip_head_fifo_rden   = 0;
wire            ip_head_fifo_empty     ;
//wire            ip_head_fifo_full      ;
wire            ip_head_fifo_almost_full     ;

always @(posedge tx_axis_aclk) begin
	if (~tx_axis_aresetn) begin
		cks_state <= CKS_IDLE;
//		cks_next_state <= CKS_IDLE;
	end
	else begin
		cks_state <= cks_next_state;
	end
end


always @(*) begin
	case (cks_state)
		CKS_IDLE: begin
			if (~stream_byte_fifo_empty) begin
				cks_next_state <= CKS_GEN0;
			end
			else begin
				cks_next_state <= CKS_IDLE;
			end
		end
		CKS_GEN0: begin
			cks_next_state <= CKS_GEN1;
		end
		CKS_GEN1: begin
			if (check_counter == 7) begin
				cks_next_state <= CKS_ENDL;
			end
			else begin
				cks_next_state <= CKS_GEN1;
			end
		end
		CKS_ENDL: begin
			if (~ip_head_fifo_almost_full) begin
				cks_next_state <= CKS_IDLE;
			end
			else begin
				cks_next_state <= CKS_ENDL;
			end
		end						
		default: begin
			cks_next_state <= CKS_IDLE;
		end
	endcase
end

always @(posedge tx_axis_aclk) begin
	if (~tx_axis_aresetn) begin
		ip_packet_length <= 0;
		ip_type          <= 0;
	end
	else if (cks_state == CKS_GEN0) begin
		ip_packet_length <= stream_byte_rdata[15:0] + 16'd20;
		ip_type          <= stream_byte_rdata[23:16];
	end
end

always @(posedge tx_axis_aclk) begin
	if (~tx_axis_aresetn) begin
		stream_byte_rden <= 0;
	end
	else if (cks_state == CKS_IDLE && (cks_state != cks_next_state)) begin
		stream_byte_rden <= 1;
	end
	else begin
		stream_byte_rden <= 0;
	end
end


always @(posedge tx_axis_aclk) begin
	if (~tx_axis_aresetn) begin
		check_counter <= 0;
	end
	else if (cks_state == CKS_GEN1) begin
		check_counter <= check_counter + 1;
	end
	else begin
		check_counter <= 0;
	end
end



always @(posedge tx_axis_aclk) begin
	if (~tx_axis_aresetn) begin
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
	else if (cks_state == CKS_GEN1) begin
		checksum_header0 <= checksum_gen({16'h4500}        ,  ip_packet_length)  ;
		checksum_header1 <= checksum_gen(identification    ,  16'h4000)          ;
		checksum_header2 <= checksum_gen({TTL,ip_type}     ,  16'h0000)          ;
		checksum_header3 <= checksum_gen(src_ip_addr[31:16] ,  src_ip_addr[15:0]);
		checksum_header4 <= checksum_gen(dst_ip_addr[31:16] ,  dst_ip_addr[15:0]);
		checksum_header5 <= checksum_gen(checksum_header0  ,  checksum_header1)  ;
		checksum_header6 <= checksum_gen(checksum_header2  ,  checksum_header3)  ;
		checksum_header7 <= checksum_gen(checksum_header4  ,  checksum_header5)  ;
		checksum_header8 <= checksum_gen(checksum_header6  ,  checksum_header7)  ;
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
		checksum_header  <=  0;
	end
	else if (check_counter == 6) begin
		checksum_header <= ~checksum_header8;
	end
	else begin
		checksum_header <= checksum_header;
	end
end

always @(posedge tx_axis_aclk) begin
	if (~tx_axis_aresetn) begin
		ip_head_fifo_data <= 0;
		ip_head_fifo_wren <= 0;
		identification    <= 0;
	end
	else if (cks_state == CKS_ENDL) begin
		ip_head_fifo_data <= {identification, ip_packet_length, checksum_header, ip_type};
		ip_head_fifo_wren <= 1;
		identification    <= identification + 1;
	end
	else begin
		identification    <= identification;
		ip_head_fifo_wren <= 0;
		ip_head_fifo_data <= 0;
	end
end

xpm_sync_fifo #(
    .WIDTH     	(56     ),
    .DEPTH     	(6      ),
    .FIFO_TYPE 	("fwft"  )
    )
ip_head(
    .clk         	(tx_axis_aclk                                                   ),
    .rst_n       	(tx_axis_aresetn                                                ),
    .wr_en       	(ip_head_fifo_wren                                              ),
    .rd_en       	(ip_head_fifo_rden                                              ),
    .data        	(ip_head_fifo_data                                              ),
    .dout        	(ip_head_fifo_dout                                              ),
    .full        	(  ),
    .empty       	(ip_head_fifo_empty                                             ),
    .almost_full 	(ip_head_fifo_almost_full                                       )
);



 /* ******************************************************************************
 * 3. send ip data packet to fifo for cache
 *******************************************************************************/
reg		[73:0]	ip_send_wdata		=	0;
wire    [73:0]  ip_send_rdata            ;
reg				ip_send_wren		=	0;
reg				ip_send_rden		=	0;
wire			ip_send_empty			;
//wire			ip_send_full			;
wire			ip_send_almost_full  	;

reg		[7:0]	frame_type			=	0;
reg		[15:0]	frame_checksum		=	0;
reg		[15:0]	frame_idcode		=	0;
reg		[15:0]	frame_length		=	0;


wire	[63:0]	ip_axis_tdata	 		;
wire	[7:0]	ip_axis_tkeep			;
reg 	[63:0]	ip_axis_tdata_reg 		;
reg 	[7:0]	ip_axis_tkeep_reg		;
reg 			ip_axis_tlast_reg		;
reg 			ip_axis_tvalid_reg		;
wire			ip_axis_tvalid			;
//wire			ip_axis_tready			;
wire			ip_axis_tlast			;


localparam		IP_SEND_IDLE		= 8'b00000001;
localparam		IP_SEND_WAIT		= 8'b00000010;
localparam		IP_SEND_HEADER0		= 8'b00000100;
localparam		IP_SEND_HEADER1		= 8'b00001000;
localparam		IP_SEND_HEADER2		= 8'b00010000;
localparam		IP_SEND_DATA0		= 8'b00100000;
localparam		IP_SEND_DATA1		= 8'b01000000;
localparam		IP_SEND_ENDL		= 8'b10000000;

reg 	[7:0]	ip_send_state		=	8'b0;
reg 	[7:0]	ip_send_next_state	=	8'b0;

assign ip_not_empty = ~ip_send_empty;

always @(posedge tx_axis_aclk) begin
	if (~tx_axis_aresetn) begin
		ip_send_state  		<= IP_SEND_IDLE;
//		ip_send_next_state  <= IP_SEND_IDLE;
	end
	else begin
		ip_send_state       <= ip_send_next_state;
	end
end

always @(*) begin
	case (ip_send_state)
		IP_SEND_IDLE	: begin
			if (~ip_head_fifo_empty) begin
				ip_send_next_state  <= IP_SEND_WAIT;
			end
			else begin
				ip_send_next_state  <= IP_SEND_IDLE;
			end
		end
		IP_SEND_WAIT	: begin
			ip_send_next_state <= IP_SEND_HEADER0;
		end		
		IP_SEND_HEADER0	: begin
			if (~ip_send_almost_full) begin
				ip_send_next_state <= IP_SEND_HEADER1;
			end
			else begin
				ip_send_next_state <= IP_SEND_HEADER0;
			end
		end
		IP_SEND_HEADER1	: begin
			if (~ip_send_almost_full) begin
				ip_send_next_state <= IP_SEND_HEADER2;
			end
			else begin
				ip_send_next_state <= IP_SEND_HEADER1;
			end			
		end	
		IP_SEND_HEADER2	: begin
			if (~ip_send_almost_full) begin
				ip_send_next_state <= IP_SEND_DATA0;
			end
			else begin
				ip_send_next_state <= IP_SEND_HEADER2;
			end			
		end
		IP_SEND_DATA0	: begin
			// if (~ip_send_almost_full & ip_axis_tvalid & ip_axis_tlast &(ip_axis_tkeep[7:4] != 0)) begin
			if (~ip_send_almost_full & ip_axis_tvalid & ~ip_axis_tlast ) begin
				ip_send_next_state <= IP_SEND_DATA1;
			end
			// else if(~ip_send_almost_full & ip_axis_tvalid & ip_axis_tlast &(ip_axis_tkeep[7:4] == 0))begin
			else if(~ip_send_almost_full & ip_axis_tvalid & ip_axis_tlast)begin
				ip_send_next_state <= IP_SEND_ENDL;
			end
			else begin
				ip_send_next_state <= IP_SEND_DATA0;
			end			
		end		
		IP_SEND_DATA1	: begin
			if (~ip_send_almost_full & ip_axis_tvalid & ip_axis_tlast ) begin
				ip_send_next_state <= IP_SEND_ENDL;
			end
			else begin
				ip_send_next_state <= IP_SEND_DATA1;
			end			
		end
		IP_SEND_ENDL	: begin
			ip_send_next_state  <= IP_SEND_IDLE;
		end						
		default: begin
			ip_send_next_state  <= IP_SEND_IDLE;
		end
	endcase
end


always @(posedge tx_axis_aclk) begin
	if (~tx_axis_aresetn) begin
		ip_head_fifo_rden <= 0;
	end
	else if (ip_send_state == IP_SEND_IDLE && (ip_send_next_state != ip_send_state)) begin
		ip_head_fifo_rden <= 1;
	end
	else begin
		ip_head_fifo_rden <= 0;
	end
end

always @(posedge tx_axis_aclk) begin
	if (~tx_axis_aresetn) begin
		frame_idcode	<= 0;
		frame_checksum  <= 0;
		frame_length    <= 0;
		frame_type      <= 0;
	end
	else if (ip_send_state == IP_SEND_WAIT) begin
		frame_idcode   <= ip_head_fifo_dout[55:40];
		frame_length   <= ip_head_fifo_dout[39:24];
		frame_checksum <= ip_head_fifo_dout[23:8];		
		frame_type     <= ip_head_fifo_dout[7:0];
	end
	else begin
		frame_idcode	<= frame_idcode;
		frame_checksum  <= frame_checksum;
		frame_length    <= frame_length;
		frame_type      <= frame_type;
	end
end

always @(*) begin
	stream_data_rden = (ip_send_state == IP_SEND_HEADER2 || ip_send_state == IP_SEND_DATA0 || ip_send_state == IP_SEND_DATA1) && (~ip_send_almost_full);
                    //    && (stream_data_rdata[1] == 1'b1); // stream_data_rdata[1] = ip_axis_tvalid
end

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        ip_send_wren <= 0;
	end
	else if (ip_send_state == IP_SEND_HEADER0 ||
		     ip_send_state == IP_SEND_HEADER1 || ip_send_state == IP_SEND_HEADER2 || 
	         ip_send_state == IP_SEND_DATA0   || ip_send_state == IP_SEND_DATA1) begin
		ip_send_wren <= 1;
	end
	else begin
		ip_send_wren <= 0;
    end
end

assign ip_axis_tdata    = stream_data_rdata[73:10];
assign ip_axis_tkeep    = stream_data_rdata[9:2];
assign ip_axis_tvalid   = stream_data_rdata[1];
assign ip_axis_tlast    = stream_data_rdata[0];

always @(posedge tx_axis_aclk) begin
	ip_axis_tdata_reg  <= ip_axis_tdata;
end

always @(posedge tx_axis_aclk) begin
	ip_axis_tkeep_reg  <= ip_axis_tkeep;
end
always @(posedge tx_axis_aclk) begin
	ip_axis_tlast_reg  <= ip_axis_tlast;
end
always @(posedge tx_axis_aclk) begin
	ip_axis_tvalid_reg <= ip_axis_tvalid;
end

/*****************************************************************************
 *  ip_send_wdata
 *  tkeep  tdata    tvalid    tlast
 *  7:0    71:8      73        72
 
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |Version|  IHL  |Type of Service|          Total Length         |

 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |         Identification        |Flags|      Fragment Offset    |
*****************************************************************************/  
              
always @(posedge tx_axis_aclk) begin
	case (ip_send_state)

		IP_SEND_IDLE	: begin
			ip_send_wdata[7:0]  <=  8'h00;
			ip_send_wdata[71:8] <=  64'h0;
			ip_send_wdata[72]   <=  0;
			ip_send_wdata[73]   <=  0;
		end

		IP_SEND_HEADER0	: begin
			ip_send_wdata[7:0]  <=  8'hff;
			ip_send_wdata[72]   <=  0;
			ip_send_wdata[73]   <=  1;
			ip_send_wdata[15:8] <=  8'h00;
			ip_send_wdata[23:16]<=  8'h40;
			ip_send_wdata[31:24]<=  frame_idcode[7:0];
			ip_send_wdata[39:32]<=  frame_idcode[15:8];
			ip_send_wdata[47:40]<=  frame_length[7:0];
			ip_send_wdata[55:48]<=  frame_length[15:8];
			ip_send_wdata[63:56]<=  8'h00;
			ip_send_wdata[71:64]<=  {ip_version, header_len};
		end
/*****************************************************************************
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |  Time to Live |    Protocol   |         Header Checksum       |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                       Source Address                          |
*****************************************************************************/
		IP_SEND_HEADER1	: begin
			ip_send_wdata[7:0]  <=  8'hff;
			ip_send_wdata[72]   <=  0;
			ip_send_wdata[73]   <=  1;
			ip_send_wdata[15:8] <=  src_ip_addr[7:0];
			ip_send_wdata[23:16]<=  src_ip_addr[15:8];
			ip_send_wdata[31:24]<=  src_ip_addr[23:16];
			ip_send_wdata[39:32]<=  src_ip_addr[31:24];
			ip_send_wdata[47:40]<=  frame_checksum[7:0];
			ip_send_wdata[55:48]<=  frame_checksum[15:8];
			ip_send_wdata[63:56]<=  frame_type;
			ip_send_wdata[71:64]<=  TTL;
		end	

/*****************************************************************************
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                    Destination Address                        |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                    Options (if any)           |    Padding    |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 *  ip_send_wdata
 *  tkeep  tdata    tvalid    tlast
 *  7:0    71:8      73        72
*****************************************************************************/
		IP_SEND_HEADER2	: begin
			ip_send_wdata[7:0]  <=  8'hFF;  
			ip_send_wdata[72]   <=  0;
			ip_send_wdata[73]   <=  1;
			ip_send_wdata[15:8] <=  ip_axis_tdata[39:32];
			ip_send_wdata[23:16]<=  ip_axis_tdata[47:40];
			ip_send_wdata[31:24]<=  ip_axis_tdata[55:48];
			ip_send_wdata[39:32]<=  ip_axis_tdata[63:56];
			ip_send_wdata[47:40]<=  dst_ip_addr[7:0];
			ip_send_wdata[55:48]<=  dst_ip_addr[15:8];
			ip_send_wdata[63:56]<=  dst_ip_addr[23:16];
			ip_send_wdata[71:64]<=  dst_ip_addr[31:24];
		end	

		IP_SEND_DATA0	: begin
			if (ip_axis_tvalid & ip_axis_tlast) begin
				if(ip_axis_tkeep[3:0] == 4'h0)begin
					ip_send_wdata[7:0] <= {4'b1111, ip_axis_tkeep[7:4]  };
					ip_send_wdata[72]  <= 1;
					ip_send_wdata[73]  <= 1;
				end
				else begin
					ip_send_wdata[7:0] <= 8'hff;
					ip_send_wdata[72]  <= 1;
					ip_send_wdata[73]  <= 1;					
				end
			end
			else begin
				ip_send_wdata[7:0] <= 8'hff;
					ip_send_wdata[72]  <= ip_axis_tlast;
					ip_send_wdata[73]  <= 1;					
			end
			ip_send_wdata[15:8]  <= ip_axis_tdata[39:32];
			ip_send_wdata[23:16] <= ip_axis_tdata[47:40];
			ip_send_wdata[31:24] <= ip_axis_tdata[55:48];
			ip_send_wdata[39:32] <= ip_axis_tdata[63:56];	
			ip_send_wdata[47:40]<=  ip_axis_tdata_reg[7:0];
			ip_send_wdata[55:48]<=  ip_axis_tdata_reg[15:8];
			ip_send_wdata[63:56]<=  ip_axis_tdata_reg[23:16];
			ip_send_wdata[71:64]<=  ip_axis_tdata_reg[31:24];		
		end	

		IP_SEND_DATA1	:	begin
			ip_send_wdata[7:0]  <= {(ip_axis_tkeep_reg << 4), ip_axis_tkeep[7:4] };
			ip_send_wdata[72]   <= ip_axis_tlast;
			ip_send_wdata[73]   <= 1;	

			ip_send_wdata[15:8]  <= ip_axis_tdata[39:32];
			ip_send_wdata[23:16] <= ip_axis_tdata[47:40];
			ip_send_wdata[31:24] <= ip_axis_tdata[55:48];
			ip_send_wdata[39:32] <= ip_axis_tdata[63:56];	
			ip_send_wdata[47:40]<=  ip_axis_tdata_reg[7:0];
			ip_send_wdata[55:48]<=  ip_axis_tdata_reg[15:8];
			ip_send_wdata[63:56]<=  ip_axis_tdata_reg[23:16];
			ip_send_wdata[71:64]<=  ip_axis_tdata_reg[31:24];	
		end

		default: begin
			
		end
	endcase
end


xpm_sync_fifo #(
    .WIDTH     	(74     ),
    .DEPTH     	(11      ),
    .FIFO_TYPE 	("fwft"  )
    )
ip_send(
    .clk         	(tx_axis_aclk                                                   ),
    .rst_n       	(tx_axis_aresetn                                                ),
    .wr_en       	(ip_send_wren                                                   ),
    .rd_en       	(ip_send_rden                                                   ),
    .data        	(ip_send_wdata                                                  ),
    .dout        	(ip_send_rdata                                                  ),
    .full        	(),
    .empty       	(ip_send_empty                                                  ),
    .almost_full 	(ip_send_almost_full                                            )
);

 /* ******************************************************************************
 * 4. send ip data to ethernet mac frame
 *******************************************************************************/

localparam		FRAME_SEND_IDLE	=	6'b000001;
localparam		FRAME_SEND_DATA	=	6'b000010;
localparam		FRAME_SEND_END0	=	6'b000100;
localparam		FRAME_SEND_END1	=	6'b001000;
localparam		FRAME_SEND_END2	=	6'b010000;
localparam		FRAME_SEND_END3	=	6'b100000;

reg 		[5:0]	frame_state			=	0;
reg 		[5:0]	frame_next_state	=	0;

always @(posedge tx_axis_aclk) begin
	if (~tx_axis_aresetn) begin
		frame_state   	   <= FRAME_SEND_IDLE;
	end
	else begin
		frame_state        <= frame_next_state;
	end
end

always @(*) begin
	case (frame_state)
		FRAME_SEND_IDLE : begin
			if (~ip_send_empty) begin
				frame_next_state	<=	FRAME_SEND_DATA;
			end
			else begin
				frame_next_state	<= 	FRAME_SEND_IDLE;
			end
		end
		FRAME_SEND_DATA : begin
			if (frame_tx_axis_tvalid & frame_tx_axis_tready & frame_tx_axis_tlast) begin
				frame_next_state	<= 	FRAME_SEND_IDLE;
			end
			else begin
				frame_next_state	<= 	FRAME_SEND_DATA;
			end
		end
		// FRAME_SEND_END0:begin
		// 	frame_next_state	<= 	FRAME_SEND_END1;
		// end
		// FRAME_SEND_END1:begin
		// 	frame_next_state	<= 	FRAME_SEND_END2;
		// end
		// FRAME_SEND_END2:begin
		// 	frame_next_state	<= 	FRAME_SEND_END3;
		// end
		// FRAME_SEND_END3:begin
		// 	frame_next_state	<= 	FRAME_SEND_IDLE;
		// end
		default: begin
			frame_next_state	<= 	FRAME_SEND_IDLE;
		end
	endcase
end


always @(*) begin
	ip_send_rden = (frame_state == FRAME_SEND_DATA) & frame_tx_axis_tready & (~ip_send_empty);
end

always @(*) begin
	if (~tx_axis_aresetn) begin
		frame_tx_axis_tdata		<= 0;
		frame_tx_axis_tkeep		<= 0;
		frame_tx_axis_tlast		<= 0;
		frame_tx_axis_tvalid	<= 0;		
	end
	else if (frame_state == FRAME_SEND_DATA) begin
		frame_tx_axis_tdata		<= ip_send_rdata[71:8];
		frame_tx_axis_tkeep		<= ip_send_rdata[7:0];
		frame_tx_axis_tlast		<= ip_send_rdata[72];
		frame_tx_axis_tvalid	<= ip_send_rdata[73];
	end
	else begin
		frame_tx_axis_tdata		<= 0;
		frame_tx_axis_tkeep		<= 0;
		frame_tx_axis_tlast		<= 0;
		frame_tx_axis_tvalid	<= 0;				
	end
end


(* mark_debug = "true" *) reg 		[5:0]  frame_state;
(* mark_debug = "true" *) wire  ip_send_empty;
(* mark_debug = "true" *) reg 	[7:0] ip_send_next_state;
(* mark_debug = "true" *) reg 	[7:0] ip_send_state;
(* mark_debug = "true" *) wire	[63:0]	ip_axis_tdata;
(* mark_debug = "true" *) wire			ip_axis_tlast;
(* mark_debug = "true" *) wire			ip_axis_tvalid;
(* mark_debug = "true" *) wire	[7:0]	ip_axis_tkeep;
(* mark_debug = "true" *) reg				ip_send_wren;
(* mark_debug = "true" *) reg				ip_send_rden;
endmodule

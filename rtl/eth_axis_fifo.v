/****************************************************************************
 * @file    eth_axis_fifo.v
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

module eth_axis_fifo
	#(
		parameter TransType = "IP",
		parameter StreamFIFOWidth = 74,		//do not modify  tdata(64)+tvalid(1)+tlast(1)
		parameter StreamFIFODepth = 11,
		parameter StreamCountWidth = 16,	//do not modify
		parameter StreamCountDepth = 8,
		parameter StreamWidth =64			//do not modify
	)
	(
		 input 	[StreamCountWidth-1:0]					tx_type,				//type: arp type, ip type and so on									
		 input                							tx_axis_aclk,
         input                							tx_axis_aresetn,  
		/* axis interface */			
		 input  [StreamWidth-1:0]        				tx_axis_tdata,
         input  [StreamWidth/8-1:0]     	  			tx_axis_tkeep,
         input                							tx_axis_tvalid,		 
         input                							tx_axis_tlast,
         output 	           							tx_axis_tready,
			
		 input 											stream_byte_rden	  ,	//byte fifo read enable signal
		 output [StreamCountWidth*2-1:0]				stream_byte_rdata 	  ,	//byte fifo read data
		 output											stream_byte_fifo_empty,	//byte fifo empty		 
		 input											stream_data_rden ,		//data fifo read enable signal
		 output [StreamFIFOWidth-1:0]           		stream_data_rdata ,		//data fifo read data	
		 output reg										rcv_stream_end			//stream received end signal
    );


reg										stream_byte_wren ;				//byte fifo write enable signal
wire [StreamCountWidth-1:0]				stream_byte_len		  ;			//byte length signal
//wire									stream_byte_fifo_full ;			//byte fifo full signal
wire									stream_byte_fifo_almost_full ;	//byte fifo almost full, when assert, only one data can be write in fifo

//wire									stream_data_fifo_full ;			//data fifo full signal
wire									stream_data_fifo_almost_full ;	//data fifo almost full signal, when assert, only one data can be write in fifo
reg										stream_data_wren ;				//data fifo write enable signal
reg [StreamFIFOWidth-1:0]           	stream_data_wdata ;				//data fifo write data

//reg [7:0]								last_tkeep ;					//last tkeep signal, not used
reg [15:0]								trans_type ;					//type latch for tx_type
/* Receiver stream data from udp or icmp FSM */
localparam IDLE               = 4'b0001 ;
localparam STREAM	     	  = 4'b0010 ;
localparam STREAM_END   	  = 4'b0100 ;
localparam STREAM_END_WAIT	  = 4'b1000 ;



reg [3:0]    state  ;
reg [3:0]    next_state ;

always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_aresetn)
      state  <=  IDLE  ;
    else
      state  <= next_state ;
  end
  
always @(*)
  begin
    case(state)
      IDLE            :
           next_state <= STREAM ;
	  STREAM  :
		begin
          if (tx_axis_tvalid & tx_axis_tready &tx_axis_tlast)
            next_state <= STREAM_END ;
          else
            next_state <= STREAM ;
        end 
	  STREAM_END  : 
		begin
			if (~stream_byte_fifo_almost_full)
				next_state <= STREAM_END_WAIT ;
			else
				next_state <= STREAM_END ;
		end
	  STREAM_END_WAIT :
			next_state <= IDLE ;
	  default          :
        next_state <= IDLE ;
	endcase
  end
/* latch for tx_type */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_aresetn)
      trans_type <= 16'd0 ;
    else if (state == STREAM)
      trans_type <= tx_type ;
  end 

assign tx_axis_tready = (state == STREAM) & ~(stream_data_fifo_almost_full | stream_byte_fifo_almost_full) ;
/* stream received end signal */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_aresetn)
      rcv_stream_end <= 1'b0 ;
    else if (state == STREAM_END)
      rcv_stream_end <= 1'b1 ;
    else
      rcv_stream_end <= 1'b0 ;
  end 


/* Write stream enable signal */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_aresetn)
      stream_data_wren  <= 1'b0 ;
    else if (state == STREAM && tx_axis_tvalid == 1'b1 && tx_axis_tready == 1'b1)
      stream_data_wren  <= 1'b1 ;
	else
	  stream_data_wren  <= 1'b0 ;
  end 
/* Write stream data to fifo */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_aresetn)
      stream_data_wdata <= {StreamFIFOWidth{1'b0}} ;
    else if (state == STREAM && tx_axis_tvalid == 1'b1 && tx_axis_tready == 1'b1)
      stream_data_wdata  <= {tx_axis_tdata,tx_axis_tkeep,tx_axis_tvalid,tx_axis_tlast} ;
    else
      stream_data_wdata <= {StreamFIFOWidth{1'b0}};
  end
 


/* stream counter write enable */
always @(posedge tx_axis_aclk)
  begin
    if (~tx_axis_aresetn)
	begin
	  stream_byte_wren   <= 1'b0 ;
	end
    else if (state == STREAM_END && ~(stream_byte_fifo_almost_full))
	begin
	  stream_byte_wren   <= 1'b1 ;
	end
	else
	begin
	  stream_byte_wren   <= 1'b0 ;
	end
  end 
 

 
axis_counter stream_inst
      (       
		.axis_aclk          (tx_axis_aclk),
        .axis_aresetn     	(tx_axis_aresetn), 			
		.axis_tdata         (tx_axis_tdata),
        .axis_tkeep         (tx_axis_tkeep),
        .axis_tvalid 	    (tx_axis_tvalid),
        .axis_tlast         (tx_axis_tlast),
        .axis_tready 	  	(tx_axis_tready), 		
		.packet_len_bytes    (stream_byte_len)
      ) ;
 
/* sync fifo for stream data  */
 xpm_sync_fifo 
#(
  .WIDTH(StreamFIFOWidth) ,
  .DEPTH(StreamFIFODepth),
  .FIFO_TYPE("fwft")
)
stream_data_fifo
(
  .clk       		(tx_axis_aclk   ),
  .rst_n     		(tx_axis_aresetn ),
  .wr_en      		(stream_data_wren),
  .rd_en      		(stream_data_rden  ),
  .data      		(stream_data_wdata),
  .dout         	(stream_data_rdata ),
  .full      		(),
  .almost_full  	(stream_data_fifo_almost_full),
  .empty     		( 	)
) ; 


/* sync fifo for byte length  */
generate
if (TransType == "IP")

	xpm_sync_fifo 
	#(
	.WIDTH(32) ,
	.DEPTH(StreamCountDepth),
	.FIFO_TYPE("fwft")
	)
	stream_byte_fifo
	(
	.clk       		(tx_axis_aclk   			 ),
	.rst_n     		(tx_axis_aresetn 			 ),
	.wr_en      	(stream_byte_wren			 ),
	.rd_en      	(stream_byte_rden  			 ),
	.data      		({trans_type,stream_byte_len}),
	.dout       	(stream_byte_rdata 			 ),
	.full      		( 		 ),
	.empty     		(stream_byte_fifo_empty  	 ),
	.almost_full  	(stream_byte_fifo_almost_full)
	) ;  
else if (TransType == "FRAME")
	xpm_sync_fifo 
	#(
	.WIDTH(16) ,
	.DEPTH(StreamCountDepth),
	.FIFO_TYPE("fwft")
	)
	stream_byte_fifo
	(
	.clk       	  (tx_axis_aclk  				),
	.rst_n     	  (tx_axis_aresetn 				),
	.wr_en        (stream_byte_wren				),
	.rd_en        (stream_byte_rden  			),
	.data      	  (trans_type					),
	.dout         (stream_byte_rdata 			),
	.full      	  (stream_byte_fifo_full 		),
	.empty     	  (stream_byte_fifo_empty 		),
	.almost_full  (stream_byte_fifo_almost_full	)
	) ; 
endgenerate


endmodule

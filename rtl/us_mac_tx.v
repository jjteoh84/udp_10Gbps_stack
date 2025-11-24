/****************************************************************************
 * @file    us_mac_frame_tx.v
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
+-------------------+-------------------+-------------------+-------------------+
|   Preamble (7B)   |   SFD (1B)        |                   |                   |
| 10101010...       | 10101011          |                   |                   |
+-------------------+-------------------+-------------------+-------------------+
|                        Destination MAC Address (6B)                           |
+-------------------------------------------------------------------------------+
|                          Source MAC Address (6B)                              |
+-------------------------------------------------------------------------------+
|   EtherType / Length (2B)   |                                              ...|
+-----------------------------+-------------------------------------------------+
|                         Payload / Data (46 ~ 1500B)                           |
|   (if <46B, pad with zeros to reach minimum frame size)                       |
+-------------------------------------------------------------------------------+
|                  Frame Check Sequence (FCS, CRC-32, 4B)                       |
+-------------------------------------------------------------------------------+


*/

`timescale 1ns/1ps

module us_mac_tx(

    input   wire    [47:0]  src_mac_addr,
    input   wire    [47:0]  dst_mac_addr,

    input   wire    [15:0] eth_type,

    output  wire            recv_axis_end,

    input   wire            tx_axis_aclk,
    input   wire            tx_axis_aresetn,

    input   wire    [63:0]  frame_tx_axis_tdata,
    input   wire    [7:0]   frame_tx_axis_tkeep,
    input   wire            frame_tx_axis_tvalid,
    input   wire            frame_tx_axis_tlast,
    output  wire            frame_tx_axis_tready,

    output  reg     [63:0]  mac_tx_axis_tdata,
    output  reg     [7:0]   mac_tx_axis_tkeep,
    output  reg             mac_tx_axis_tvalid,
    output  reg             mac_tx_axis_tlast,
    input   wire            mac_tx_axis_tready
);


/* **********************************************************************
 * 1. store data to fifo
 **********************************************************************/


wire[73:0]      stream_data_rdata       ;
reg             stream_data_rden    =   0;

wire[31:0]      stream_byte_rdata       ;
reg             stream_byte_rden    =   0;
wire            stream_byte_fifo_empty  ;

eth_axis_fifo #(
    .TransType        	("IP"    ),
    .StreamFIFOWidth  	(74      ),
    .StreamFIFODepth  	(11      ),
    .StreamCountWidth 	(16      ),
    .StreamCountDepth 	(4       ),
    .StreamWidth      	(64      ))
u_eth_axis_fifo(
    .tx_type                	(eth_type                ),
    .tx_axis_aclk           	(tx_axis_aclk            ),
    .tx_axis_aresetn        	(tx_axis_aresetn         ),
    .tx_axis_tdata          	(frame_tx_axis_tdata     ),
    .tx_axis_tkeep          	(frame_tx_axis_tkeep     ),
    .tx_axis_tvalid         	(frame_tx_axis_tvalid    ),
    .tx_axis_tlast          	(frame_tx_axis_tlast     ),
    .tx_axis_tready         	(frame_tx_axis_tready    ),
    .stream_byte_rden       	(stream_byte_rden        ),
    .stream_byte_rdata      	(stream_byte_rdata       ),
    .stream_byte_fifo_empty 	(stream_byte_fifo_empty  ),
    .stream_data_rden       	(stream_data_rden        ),
    .stream_data_rdata      	(stream_data_rdata       ),
    .rcv_stream_end         	(recv_axis_end        )
);

/* **********************************************************************
 * 2. Component Ethernet mac frame
 **********************************************************************/
wire [7:0]  frame_tx_keep  ;
reg  [7:0]  frame_tx_keep_reg  = 0;
wire [63:0] frame_tx_data  ;
reg  [63:0] frame_tx_data_reg =0;
wire        frame_tx_valid ;
//wire        frame_tx_ready ;
wire        frame_tx_tlast ;

reg [15:0]  frame_length    =   0;
reg [15:0]  frame_type      =   0;

reg         mac_send_wren       =   0;
reg         mac_send_rden       =   0;
reg [73:0]  mac_send_wdata      =   0;
wire[73:0]  mac_send_rdata           ;
//wire        mac_send_full            ;
wire        mac_send_empty           ;
wire        mac_send_almost_full     ;


localparam MAC_FRAME_IDLE       = 11'b00000000001;
localparam MAC_FRAME_WAIT       = 11'b00000000010;
localparam MAC_FRAME_HEADER0    = 11'b00000000100;
localparam MAC_FRAME_HEADER1    = 11'b00000001000;
localparam MAC_FRAME_PAYLOAD    = 11'b00000100000;
localparam MAC_FRAME_LAST       = 11'b00001000000;
localparam MAC_FRAME_PADDING0   = 11'b00010000000;
localparam MAC_FRAME_PADDING1   = 11'b001_0000_0000;
localparam MAC_FRAME_PADDING2   = 11'b010_0000_0000;
localparam MAC_FRAME_ENDL       = 11'b100_0000_0000;


reg     [10:0]   mac_state       =   0;
reg     [10:0]   mac_next_state  =   0;

reg signed [15:0] pad_counter;

always @(posedge tx_axis_aclk) begin
    if(~tx_axis_aresetn)begin
        pad_counter <= 'b0;
    end
    else if (mac_state == MAC_FRAME_HEADER1) begin
        pad_counter <= $signed(46 - frame_length);
    end
    else begin
        pad_counter <= pad_counter; 
    end
end

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        mac_state       <= MAC_FRAME_IDLE;
    end
    else begin
        mac_state       <= mac_next_state;
    end
end

always @(*) begin
    case (mac_state)
        MAC_FRAME_IDLE: begin
            if (~stream_byte_fifo_empty) begin
                mac_next_state  <= MAC_FRAME_WAIT;
            end
            else begin
                mac_next_state  <= MAC_FRAME_IDLE;
            end
        end

        MAC_FRAME_WAIT : begin
            mac_next_state <= MAC_FRAME_HEADER0;
        end

        MAC_FRAME_HEADER0 : begin
            if (~mac_send_almost_full) begin
                mac_next_state <= MAC_FRAME_HEADER1;
            end
            else begin
                mac_next_state <= MAC_FRAME_HEADER0;
            end
        end

        MAC_FRAME_HEADER1 : begin
            if (~mac_send_almost_full) begin
                mac_next_state <= MAC_FRAME_PAYLOAD;
            end
            else begin
                mac_next_state <= MAC_FRAME_HEADER1;
            end
        end


        MAC_FRAME_PAYLOAD : begin
            if (~mac_send_almost_full & frame_tx_tlast & frame_tx_valid & (frame_tx_keep[7:2] == 0)) begin
                if (pad_counter > 0) begin
                    mac_next_state <= MAC_FRAME_PADDING0;
                end
                else begin
                    mac_next_state <= MAC_FRAME_ENDL;
                end
            end
            else if (~mac_send_almost_full & frame_tx_tlast & frame_tx_valid & (frame_tx_keep[7:2] != 0)) begin
                mac_next_state <= MAC_FRAME_LAST;
            end
            else begin
                mac_next_state <= MAC_FRAME_PAYLOAD;
            end
        end

        MAC_FRAME_LAST :begin
            if (~mac_send_almost_full & pad_counter > 0) begin
                mac_next_state <= MAC_FRAME_PADDING0;
            end
            else if (~mac_send_almost_full) begin
                mac_next_state <= MAC_FRAME_ENDL;
            end
            else begin
                mac_next_state <= MAC_FRAME_LAST;
            end
        end

        MAC_FRAME_PADDING0 :begin
            mac_next_state <= MAC_FRAME_PADDING1;
        end

        MAC_FRAME_PADDING1 :begin
            mac_next_state <= MAC_FRAME_PADDING2;
        end

        MAC_FRAME_PADDING2 :begin
            mac_next_state <= MAC_FRAME_ENDL;
        end


        MAC_FRAME_ENDL   : begin
            mac_next_state  <= MAC_FRAME_IDLE;
        end

        default: begin
            mac_next_state  <= MAC_FRAME_IDLE;
        end
    endcase
end


assign  frame_tx_data   =  stream_data_rdata[73:10];
assign  frame_tx_keep   =  stream_data_rdata[9:2];
assign  frame_tx_valid  =  stream_data_rdata[1];
assign  frame_tx_tlast  =  stream_data_rdata[0];

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        frame_tx_data_reg <= 0;
    end
    else begin
        frame_tx_data_reg <= frame_tx_data;
    end
end

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        frame_tx_keep_reg <= 0;
    end
    else begin
        frame_tx_keep_reg <= frame_tx_keep;
    end
end

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        mac_send_wren  <=  0;
    end
    else if (mac_state == MAC_FRAME_HEADER0 || mac_state == MAC_FRAME_HEADER1 
          || mac_state == MAC_FRAME_PAYLOAD || mac_state == MAC_FRAME_PADDING0
          || mac_state == MAC_FRAME_LAST    || mac_state == MAC_FRAME_PADDING1
          || mac_state == MAC_FRAME_PADDING2) begin
        mac_send_wren  <= 1;
    end
    else begin
        mac_send_wren  <= 0;
    end
end

always @(*) begin
    stream_data_rden = (mac_state == MAC_FRAME_HEADER1 
                     || mac_state == MAC_FRAME_PAYLOAD ) & (~mac_send_almost_full) ? 1 : 0;
end

always @(*) begin
    stream_byte_rden = (mac_state == MAC_FRAME_HEADER1) ? 1 : 0;
end

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        frame_length <= 0;
        frame_type   <= 0;
    end
    else if (mac_state == MAC_FRAME_WAIT) begin
        frame_length <= stream_byte_rdata[15:0];
        frame_type   <= stream_byte_rdata[31:16];
    end
end
// 7:0   71:8    72      73
// keep   data   valid  last

always @(posedge tx_axis_aclk) begin
    case (mac_state)
        MAC_FRAME_IDLE: begin
            mac_send_wdata[7:0]  <= 8'h00;
            mac_send_wdata[71:8] <= 64'h00;
            mac_send_wdata[72]   <= 0;
            mac_send_wdata[73]   <= 0;
        end
    
        MAC_FRAME_HEADER0 : begin
            mac_send_wdata[7:0]   <= 8'hff;
            mac_send_wdata[15:8]  <= dst_mac_addr[47:40];
            mac_send_wdata[23:16] <= dst_mac_addr[39:32];
            mac_send_wdata[31:24] <= dst_mac_addr[31:24];
            mac_send_wdata[39:32] <= dst_mac_addr[23:16];
            mac_send_wdata[47:40] <= dst_mac_addr[15:8];
            mac_send_wdata[55:48] <= dst_mac_addr[7:0];
            mac_send_wdata[63:56] <= src_mac_addr[47:40];    
            mac_send_wdata[71:64] <= src_mac_addr[39:32];        
            mac_send_wdata[72]    <= 1;
            mac_send_wdata[73]    <= 0;
        end

        MAC_FRAME_HEADER1 : begin
            mac_send_wdata[7:0]   <= 8'hff;
            mac_send_wdata[15:8]  <= src_mac_addr[31:24];
            mac_send_wdata[23:16] <= src_mac_addr[23:16];
            mac_send_wdata[31:24] <= src_mac_addr[15:8];
            mac_send_wdata[39:32] <= src_mac_addr[7:0];
            mac_send_wdata[47:40] <= frame_type[15:8];
            mac_send_wdata[55:48] <= frame_type[7:0];
            mac_send_wdata[63:56] <= frame_tx_data[7:0];    
            mac_send_wdata[71:64] <= frame_tx_data[15:8];   
            mac_send_wdata[72]    <= 1;
            mac_send_wdata[73]    <= 0;                       
        end

        MAC_FRAME_PAYLOAD:begin
            if (frame_tx_tlast & frame_tx_valid) begin
                mac_send_wdata[72]    <= 1;
                if (pad_counter > 0) begin
                    mac_send_wdata[7:0]   <= 8'hff;
                    mac_send_wdata[73]    <= 0;                                    
                end
                else begin
                    if(frame_tx_keep[7:2] == 6'b00)begin
                        mac_send_wdata[7:0]   <= {frame_tx_keep[1:0],6'b111111};   
                        mac_send_wdata[73]    <= 1;              
                    end
                    else begin
                        mac_send_wdata[7:0]   <= 8'hff;
                        mac_send_wdata[73]    <= 0; 
                    end 
                end
            end
            else begin
                mac_send_wdata[7:0]   <= 8'hff;
                mac_send_wdata[72]    <= 1;
                mac_send_wdata[73]    <= 0;    
            end 

            mac_send_wdata[15:8]  <= frame_tx_data_reg[23:16];           
            mac_send_wdata[23:16] <= frame_tx_data_reg[31:24];
            mac_send_wdata[31:24] <= frame_tx_data_reg[39:32];
            mac_send_wdata[39:32] <= frame_tx_data_reg[47:40];
            mac_send_wdata[47:40] <= frame_tx_data_reg[55:48];
            mac_send_wdata[55:48] <= frame_tx_data_reg[63:56];

            mac_send_wdata[63:56] <= frame_tx_keep[0] ? frame_tx_data[7:0]  : 8'b0;    
            mac_send_wdata[71:64] <= frame_tx_keep[1] ? frame_tx_data[15:8] : 8'b0;   
            
        end

        MAC_FRAME_LAST   : begin
            if (pad_counter <= 0) begin
                mac_send_wdata[7:0]   <= frame_tx_keep_reg >> 2 ; 
                mac_send_wdata[72]    <= 1; //valid
                mac_send_wdata[73]    <= 1; //last     
            end
            else begin
                mac_send_wdata[7:0]   <= 8'hff ; 
                mac_send_wdata[72]    <= 1; //valid
                mac_send_wdata[73]    <= 0; //last                    
            end
            mac_send_wdata[15:8]  <= frame_tx_data_reg[23:16];           
            mac_send_wdata[23:16] <= frame_tx_data_reg[31:24];
            mac_send_wdata[31:24] <= frame_tx_data_reg[39:32];
            mac_send_wdata[39:32] <= frame_tx_data_reg[47:40];
            mac_send_wdata[47:40] <= frame_tx_data_reg[55:48];
            mac_send_wdata[55:48] <= frame_tx_data_reg[63:56];
            mac_send_wdata[63:56] <= 8'h00;    
            mac_send_wdata[71:64] <= 8'h00;                
        end

        MAC_FRAME_PADDING0:begin
            mac_send_wdata[7:0]   <= 8'hff; 
            mac_send_wdata[72]    <= 1; //valid
            mac_send_wdata[73]    <= 0; //last 

            mac_send_wdata[15:8]  <= 8'h00;           
            mac_send_wdata[23:16] <= 8'h00;
            mac_send_wdata[31:24] <= 8'h00;
            mac_send_wdata[39:32] <= 8'h00;
            mac_send_wdata[47:40] <= 8'h00;
            mac_send_wdata[55:48] <= 8'h00;
            mac_send_wdata[63:56] <= 8'h00;    
            mac_send_wdata[71:64] <= 8'h00;                             
        end

        MAC_FRAME_PADDING1:begin
            mac_send_wdata[7:0]   <= 8'hff; 
            mac_send_wdata[72]    <= 1; //valid
            mac_send_wdata[73]    <= 0; //last 

            mac_send_wdata[15:8]  <= 8'h00;           
            mac_send_wdata[23:16] <= 8'h00;
            mac_send_wdata[31:24] <= 8'h00;
            mac_send_wdata[39:32] <= 8'h00;
            mac_send_wdata[47:40] <= 8'h00;
            mac_send_wdata[55:48] <= 8'h00;
            mac_send_wdata[63:56] <= 8'h00;    
            mac_send_wdata[71:64] <= 8'h00;                            
        end

        MAC_FRAME_PADDING2:begin
            mac_send_wdata[7:0]   <= 8'hff; 
            mac_send_wdata[72]    <= 1; //valid
            mac_send_wdata[73]    <= 1; //last 

            mac_send_wdata[15:8]  <= 8'h00;           
            mac_send_wdata[23:16] <= 8'h00;
            mac_send_wdata[31:24] <= 8'h00;
            mac_send_wdata[39:32] <= 8'h00;
            mac_send_wdata[47:40] <= 8'h00;
            mac_send_wdata[55:48] <= 8'h00;
            mac_send_wdata[63:56] <= 8'h00;    
            mac_send_wdata[71:64] <= 8'h00;                               
        end        

        default: begin
            mac_send_wdata[7:0]  <= 8'h00;
            mac_send_wdata[71:8] <= 64'h00;
            mac_send_wdata[72]   <= 0;
            mac_send_wdata[73]   <= 0;            
        end
    endcase
end


xpm_sync_fifo #(
    .WIDTH     	(74     ),
    .DEPTH     	(11      ),
    .FIFO_TYPE 	("fwft"  )
    )
mac_send(
    .clk         	(tx_axis_aclk                                                   ),
    .rst_n       	(tx_axis_aresetn                                                ),
    .wr_en       	(mac_send_wren                                                   ),
    .rd_en       	(mac_send_rden                                                   ),
    .data        	(mac_send_wdata                                                  ),
    .dout        	(mac_send_rdata                                                  ),
    .full        	(                                                   ),
    .empty       	(mac_send_empty                                                  ),
    .almost_full 	(mac_send_almost_full                                            )
);


/* **********************************************************************
 * 3. transmit mac frame to xxv-ethernet
 **********************************************************************/

localparam  MAC_SEND_IDLE = 2'b01;
localparam  MAC_SEND_DATA = 2'b10;

reg     [1:0]   mac_send_state      =   2'b00;
reg     [1:0]   mac_send_next_state =   2'b00;

always @(posedge tx_axis_aclk) begin
    if (~tx_axis_aresetn) begin
        mac_send_state      <= MAC_SEND_IDLE;
    end
    else begin
        mac_send_state <= mac_send_next_state;
    end
end

always @(*) begin
    case (mac_send_state)
        MAC_SEND_IDLE : begin
            if (~mac_send_empty) begin
                mac_send_next_state <= MAC_SEND_DATA;
            end
            else begin
                mac_send_next_state <= MAC_SEND_IDLE;
            end
        end

        MAC_SEND_DATA : begin
            if (mac_tx_axis_tready & mac_tx_axis_tvalid & mac_tx_axis_tlast) begin
                mac_send_next_state <= MAC_SEND_IDLE;
            end
            else begin
                mac_send_next_state <= MAC_SEND_DATA;
            end
        end
        default: begin
            mac_send_next_state <= MAC_SEND_IDLE;
        end
    endcase
end

always @(*) begin
    mac_send_rden = mac_tx_axis_tready & (mac_send_state == MAC_SEND_DATA) & (~mac_send_empty);
end

always @(*) begin
    if (mac_send_state == MAC_SEND_DATA) begin
        mac_tx_axis_tdata <= mac_send_rdata[71:8];
        mac_tx_axis_tkeep <= mac_send_rdata[7:0];
        mac_tx_axis_tvalid <= mac_send_rdata[72];
        mac_tx_axis_tlast <= mac_send_rdata[73];
    end
    else begin
        mac_tx_axis_tdata  <= 0;
        mac_tx_axis_tkeep  <= 0;
        mac_tx_axis_tvalid <= 0;
        mac_tx_axis_tlast  <= 0;        
    end
end

endmodule

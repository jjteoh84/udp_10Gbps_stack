/****************************************************************************
 * @file    tb_udp_tx.v
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

module tb_us_ip_tx();

reg  [7:0]         			ip_send_type    =   8'h11;			//send type : udp or icmp
reg  [31:0]        			src_ip_addr     =   {8'd192, 8'd168, 8'd1, 8'd10};			//source ip address
reg  [31:0]        			dst_ip_addr     =   {8'd192, 8'd168, 8'd1, 8'd11};			//destination ip address
			
					
reg                			tx_axis_aclk    =0;
reg                			tx_axis_aresetn =0; 
/* ip tx axis interface */			
reg  [63:0]        			ip_tx_axis_tdata    =0;
reg  [7:0]     	  			ip_tx_axis_tkeep    =0;
reg                			ip_tx_axis_tvalid   =0;		 
reg                			ip_tx_axis_tlast    =0;
wire 	           			ip_tx_axis_tready   ;
/* tx axis interface to frame */			
wire [63:0]    			    frame_tx_axis_tdata;
wire [7:0]     			    frame_tx_axis_tkeep;
wire           			    frame_tx_axis_tvalid;	
wire           			    frame_tx_axis_tlast;
reg                		    frame_tx_axis_tready=1;
		 
wire						 ip_not_empty;	//ip layer is ready to send data
wire 					     recv_stream_end;		//receive stream end signal

reg [7:0] i   =   0;

initial begin
    #(`CLOCK_PERIOD * 60)begin
        tx_axis_aresetn  <= 1;
    end
    #(`CLOCK_PERIOD * 10)
    repeat(9)begin
        #(`CLOCK_PERIOD)begin
            ip_tx_axis_tdata  <= ip_tx_axis_tdata + 1;
            ip_tx_axis_tkeep  <= 8'hff;
            ip_tx_axis_tvalid <= 1;
            ip_tx_axis_tlast  <= 0;            
        end
    end
    #(`CLOCK_PERIOD)begin
            ip_tx_axis_tdata  <= ip_tx_axis_tdata + 1;
            ip_tx_axis_tkeep  <= 8'hff;
            ip_tx_axis_tvalid <= 1;
            ip_tx_axis_tlast  <= 1;           
    end
    #(`CLOCK_PERIOD)begin
            ip_tx_axis_tdata  <= 0 ;
            ip_tx_axis_tkeep  <= 8'h00;
            ip_tx_axis_tvalid <= 0;
            ip_tx_axis_tlast  <= 0;           
    end          

    #(`CLOCK_PERIOD * 10)
  
    repeat(19)begin
        #(`CLOCK_PERIOD)begin
            ip_tx_axis_tdata  <= ip_tx_axis_tdata + 1;
            ip_tx_axis_tkeep  <= 8'hff;
            ip_tx_axis_tvalid <= 1;
            ip_tx_axis_tlast  <= 0;            
        end
    end
    #(`CLOCK_PERIOD)begin
            ip_tx_axis_tdata  <= ip_tx_axis_tdata + 1;
            ip_tx_axis_tkeep  <= 8'hff;
            ip_tx_axis_tvalid <= 1;
            ip_tx_axis_tlast  <= 1;           
    end
    #(`CLOCK_PERIOD)begin
            ip_tx_axis_tdata  <= 0 ;
            ip_tx_axis_tkeep  <= 8'h00;
            ip_tx_axis_tvalid <= 0;
            ip_tx_axis_tlast  <= 0;           
    end  

    #(`CLOCK_PERIOD * 2)
  
    repeat(20)begin
        #(`CLOCK_PERIOD)begin
            ip_tx_axis_tdata  <= {8'h1 + i,8'h2 + i,8'h3 + i,8'h4 + i,8'h5 + i,8'h6 + i,8'h7 + i,8'h8 + i};
            ip_tx_axis_tkeep  <= 8'hff;
            ip_tx_axis_tvalid <= 1;
            ip_tx_axis_tlast  <= 0;      
            i = i + 1;      
        end
    end
    #(`CLOCK_PERIOD)begin
            ip_tx_axis_tdata  <= {8'h1 + i,8'h2 + i,8'h3 + i,8'h4 + i,8'h5 + i,8'h6 + i,8'h7 + i,8'h8 + i};
            ip_tx_axis_tkeep  <= 8'h0f;
            ip_tx_axis_tvalid <= 1;
            ip_tx_axis_tlast  <= 1;           
    end
    #(`CLOCK_PERIOD)begin
            ip_tx_axis_tdata  <= 0 ;
            ip_tx_axis_tkeep  <= 8'h00;
            ip_tx_axis_tvalid <= 0;
            ip_tx_axis_tlast  <= 0;           
    end     
end

us_ip_tx u_us_ip_tx(
    .ip_send_type         	(ip_send_type          ),
    .src_ip_addr          	(src_ip_addr           ),
    .dst_ip_addr          	(dst_ip_addr           ),
    .tx_axis_aclk         	(tx_axis_aclk          ),
    .tx_axis_aresetn      	(tx_axis_aresetn       ),
    .ip_tx_axis_tdata     	(ip_tx_axis_tdata      ),
    .ip_tx_axis_tkeep     	(ip_tx_axis_tkeep      ),
    .ip_tx_axis_tvalid    	(ip_tx_axis_tvalid     ),
    .ip_tx_axis_tlast     	(ip_tx_axis_tlast      ),
    .ip_tx_axis_tready    	(ip_tx_axis_tready     ),
    .frame_tx_axis_tdata  	(frame_tx_axis_tdata   ),
    .frame_tx_axis_tkeep  	(frame_tx_axis_tkeep   ),
    .frame_tx_axis_tvalid 	(frame_tx_axis_tvalid  ),
    .frame_tx_axis_tlast  	(frame_tx_axis_tlast   ),
    .frame_tx_axis_tready 	(frame_tx_axis_tready  ),
    .ip_not_empty         	(ip_not_empty          ),
    .recv_stream_end      	(recv_stream_end       )
);

always #(`CLOCK_PERIOD / 2) tx_axis_aclk = ~tx_axis_aclk;

endmodule
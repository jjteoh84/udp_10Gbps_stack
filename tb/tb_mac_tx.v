/****************************************************************************
 * @file    tb_frame_tx.v
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

`define CLOCK_PERIOD  100

module tb_mac_tx();

reg    [47:0]  src_mac_addr =   {8'hac, 8'hab, 8'h12, 8'h14, 8'h55, 8'h24};
reg    [47:0]  dst_mac_addr =   {8'hac, 8'hbb, 8'h12, 8'h14, 8'h55, 8'h24};
reg    [15:0]  eth_type     =   16'h0800;
wire           recv_axis_end;
reg            tx_axis_aclk =   0;
reg            tx_axis_aresetn= 0;
reg    [63:0]  frame_tx_axis_tdata  =   0;
reg    [7:0]   frame_tx_axis_tkeep  =   0;
reg            frame_tx_axis_tvalid =   0;
reg            frame_tx_axis_tlast  =   0;
wire           frame_tx_axis_tready;
wire     [63:0]mac_tx_axis_tdata;
wire     [7:0] mac_tx_axis_tkeep;
wire           mac_tx_axis_tvalid;
wire           mac_tx_axis_tlast;
reg            mac_tx_axis_tready = 1;


initial begin
    #(`CLOCK_PERIOD * 60)begin
        tx_axis_aresetn <= 1;
    end
    #(`CLOCK_PERIOD * 9 + `CLOCK_PERIOD / 2)begin
        repeat(19)begin
            #(`CLOCK_PERIOD)begin
                frame_tx_axis_tdata <= frame_tx_axis_tdata + 1;
                frame_tx_axis_tkeep <= 8'hff;
                frame_tx_axis_tvalid<= 1;
                frame_tx_axis_tlast <= 0;
            end
        end
        #(`CLOCK_PERIOD)begin
            frame_tx_axis_tdata <= frame_tx_axis_tdata + 1;
            frame_tx_axis_tkeep <= 8'hff;
            frame_tx_axis_tvalid<= 1;
            frame_tx_axis_tlast <= 1;
        end        
        #(`CLOCK_PERIOD)begin
            frame_tx_axis_tdata <= 0;
            frame_tx_axis_tkeep <= 8'h00;
            frame_tx_axis_tvalid<= 0;
            frame_tx_axis_tlast <= 0;
        end  
        #(`CLOCK_PERIOD * 6)         
        repeat(29)begin
            #(`CLOCK_PERIOD)begin
                frame_tx_axis_tdata <= frame_tx_axis_tdata + 1;
                frame_tx_axis_tkeep <= 8'hff;
                frame_tx_axis_tvalid<= 1;
                frame_tx_axis_tlast <= 0;
            end            
        end
        #(`CLOCK_PERIOD)begin
            frame_tx_axis_tdata <= frame_tx_axis_tdata + 1;
            frame_tx_axis_tkeep <= 8'h3f;
            frame_tx_axis_tvalid<= 1;
            frame_tx_axis_tlast <= 1;
        end        
        #(`CLOCK_PERIOD)begin
            frame_tx_axis_tdata <= 0;
            frame_tx_axis_tkeep <= 8'h00;
            frame_tx_axis_tvalid<= 0;
            frame_tx_axis_tlast <= 0;
        end    
        #(`CLOCK_PERIOD * 6)         
        repeat(29)begin
            #(`CLOCK_PERIOD)begin
                frame_tx_axis_tdata <= frame_tx_axis_tdata + 1;
                frame_tx_axis_tkeep <= 8'hff;
                frame_tx_axis_tvalid<= 1;
                frame_tx_axis_tlast <= 0;
            end            
        end
        #(`CLOCK_PERIOD)begin
            frame_tx_axis_tdata <= frame_tx_axis_tdata + 1;
            frame_tx_axis_tkeep <= 8'h03;
            frame_tx_axis_tvalid<= 1;
            frame_tx_axis_tlast <= 1;
        end        
        #(`CLOCK_PERIOD)begin
            frame_tx_axis_tdata <= 0;
            frame_tx_axis_tkeep <= 8'h00;
            frame_tx_axis_tvalid<= 0;
            frame_tx_axis_tlast <= 0;
        end            
        #(`CLOCK_PERIOD * 5)
        repeat(3)begin
            #(`CLOCK_PERIOD)begin
                frame_tx_axis_tdata <= frame_tx_axis_tdata + 1;
                frame_tx_axis_tkeep <= 8'hff;
                frame_tx_axis_tvalid<= 1;
                frame_tx_axis_tlast <= 0;
            end            
        end    
        #(`CLOCK_PERIOD)begin
            frame_tx_axis_tdata <= 64'habcdef;
            frame_tx_axis_tkeep <= 8'h1f;
            frame_tx_axis_tvalid<= 1;
            frame_tx_axis_tlast <= 1;
        end         
        #(`CLOCK_PERIOD)begin
            frame_tx_axis_tdata <= 0;
            frame_tx_axis_tkeep <= 8'h00;
            frame_tx_axis_tvalid<= 0;
            frame_tx_axis_tlast <= 0;
        end   
        #(`CLOCK_PERIOD * 5)
        repeat(3)begin
            #(`CLOCK_PERIOD)begin
                frame_tx_axis_tdata <= frame_tx_axis_tdata + 1;
                frame_tx_axis_tkeep <= 8'hff;
                frame_tx_axis_tvalid<= 1;
                frame_tx_axis_tlast <= 0;
            end            
        end  
        #(`CLOCK_PERIOD)begin
            frame_tx_axis_tdata <= 64'h123456789abcdef;
            frame_tx_axis_tkeep <= 8'h3f;
            frame_tx_axis_tvalid<= 1;
            frame_tx_axis_tlast <= 1;
        end         
        #(`CLOCK_PERIOD)begin
            frame_tx_axis_tdata <= 0;
            frame_tx_axis_tkeep <= 8'h00;
            frame_tx_axis_tvalid<= 0;
            frame_tx_axis_tlast <= 0;
        end            
    end
end


us_mac_tx u_us_mac_frame_tx(
    .src_mac_addr         	(src_mac_addr          ),
    .dst_mac_addr         	(dst_mac_addr          ),
    .eth_type             	(eth_type              ),
    .recv_axis_end        	(recv_axis_end         ),
    .tx_axis_aclk         	(tx_axis_aclk          ),
    .tx_axis_aresetn      	(tx_axis_aresetn       ),
    .frame_tx_axis_tdata  	(frame_tx_axis_tdata   ),
    .frame_tx_axis_tkeep  	(frame_tx_axis_tkeep   ),
    .frame_tx_axis_tvalid 	(frame_tx_axis_tvalid  ),
    .frame_tx_axis_tlast  	(frame_tx_axis_tlast   ),
    .frame_tx_axis_tready 	(frame_tx_axis_tready  ),
    .mac_tx_axis_tdata    	(mac_tx_axis_tdata     ),
    .mac_tx_axis_tkeep    	(mac_tx_axis_tkeep     ),
    .mac_tx_axis_tvalid   	(mac_tx_axis_tvalid    ),
    .mac_tx_axis_tlast    	(mac_tx_axis_tlast     ),
    .mac_tx_axis_tready   	(mac_tx_axis_tready    )
);

always #(`CLOCK_PERIOD / 2) tx_axis_aclk = ~tx_axis_aclk;

endmodule

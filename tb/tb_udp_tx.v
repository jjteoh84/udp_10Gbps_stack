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

module tb_udp_tx();

localparam [31:0] SRC_IP_ADDR = {8'd192,8'd168,8'd1,8'd10};
localparam [31:0] DES_IP_ADDR = {8'd192,8'd168,8'd1,8'd11};
localparam [15:0] SRC_PORT = 16'h8080;
localparam [15:0] DES_PORT = 16'h8081;

reg  tx_axis_aclk = 0;
reg  tx_axis_areset = 0;
// output declaration of module udp_tx
wire       udp_tx_axis_tready;
reg [63:0 ]udp_tx_axis_tdata = 0;
reg [7:0]  udp_tx_axis_tkeep = 0;
reg        udp_tx_axis_tvalid = 0;
reg        udp_tx_axis_tlast = 0;


wire [63:0] ip_tx_axis_tdata;
wire [7:0]  ip_tx_axis_tkeep;
wire        ip_tx_axis_tvalid;
wire        ip_tx_axis_tlast;

wire        udp_not_empty;

us_udp_tx u_udp_tx(
   .src_ip_addr        	(SRC_IP_ADDR         ),
   .dst_ip_addr        	(DES_IP_ADDR         ),
   .udp_src_port       	(SRC_PORT            ),
   .udp_dst_port       	(DES_PORT            ),
   .tx_axis_aclk       	(tx_axis_aclk        ),
   .tx_axis_aresetn    	(tx_axis_areset      ),
   .udp_tx_axis_tdata  	(udp_tx_axis_tdata   ),
   .udp_tx_axis_tkeep  	(udp_tx_axis_tkeep   ),
   .udp_tx_axis_tvalid 	(udp_tx_axis_tvalid  ),
   .udp_tx_axis_tlast  	(udp_tx_axis_tlast   ),
   .udp_tx_axis_tready 	(udp_tx_axis_tready  ),
   .ip_tx_axis_tdata   	(ip_tx_axis_tdata    ),
   .ip_tx_axis_tkeep   	(ip_tx_axis_tkeep    ),
   .ip_tx_axis_tvalid  	(ip_tx_axis_tvalid   ),
   .ip_tx_axis_tlast   	(ip_tx_axis_tlast    ),
   .ip_tx_axis_tready  	(1'b1                ),
   .mac_exist          	(1'b1           ),
   .udp_not_empty      	(udp_not_empty       )
);

integer i = 0;

initial begin
    #(`CLOCK_PERIOD * 60)begin
        tx_axis_areset <= 1;
    end
    #(`CLOCK_PERIOD * 4)
    repeat(9)begin
        #(`CLOCK_PERIOD)begin
        udp_tx_axis_tdata <= udp_tx_axis_tdata + 1;
        udp_tx_axis_tkeep <= 8'hff;
        udp_tx_axis_tvalid <= 1;
        udp_tx_axis_tlast <= 0;
        end
    end
    #(`CLOCK_PERIOD)begin
        udp_tx_axis_tdata <= udp_tx_axis_tdata + 1;
        udp_tx_axis_tkeep <= 8'hff;
        udp_tx_axis_tvalid <= 1;
        udp_tx_axis_tlast <= 1;
    end
     #(`CLOCK_PERIOD)begin
         udp_tx_axis_tdata <= 0 ;
         udp_tx_axis_tkeep <= 8'h00;
         udp_tx_axis_tvalid <= 0;
         udp_tx_axis_tlast <= 0;
     end    
    repeat(19)begin
        #(`CLOCK_PERIOD)begin
        udp_tx_axis_tdata <= i + 1;
        udp_tx_axis_tkeep <= 8'hff;
        udp_tx_axis_tvalid <= 1;
        udp_tx_axis_tlast <= 0;
        end
        i = i + 1;
    end

    #(`CLOCK_PERIOD)begin
        udp_tx_axis_tdata <= i + 1;
        udp_tx_axis_tkeep <= 8'hff;
        udp_tx_axis_tvalid <= 1;
        udp_tx_axis_tlast <= 1;
    end
     #(`CLOCK_PERIOD)begin
         udp_tx_axis_tdata <= 0 ;
         udp_tx_axis_tkeep <= 8'h00;
         udp_tx_axis_tvalid <= 0;
         udp_tx_axis_tlast <= 0;
     end 
    i = 0;
    repeat(1)begin
        #(`CLOCK_PERIOD)begin
        udp_tx_axis_tdata <= i + 1;
        udp_tx_axis_tkeep <= 8'hff;
        udp_tx_axis_tvalid <= 1;
        udp_tx_axis_tlast <= 0;
        end
        i = i + 1;
    end
    #(`CLOCK_PERIOD)begin
        udp_tx_axis_tdata <= i +1;
        udp_tx_axis_tkeep <= 8'h0f;
        udp_tx_axis_tvalid <= 1;
        udp_tx_axis_tlast <= 1;
    end
    #(`CLOCK_PERIOD)begin
        udp_tx_axis_tdata <= 0 ;
        udp_tx_axis_tkeep <= 8'h00;
        udp_tx_axis_tvalid <= 0;
        udp_tx_axis_tlast <= 0;
    end 

end

always #(`CLOCK_PERIOD/2) tx_axis_aclk = ~tx_axis_aclk;

endmodule

/****************************************************************************
 * @file    tb_axis_counter.v
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

 module tb_axis_counter();

    reg        axis_aclk    =   0;
    reg        axis_aresetn =   0;

    /*
     * user packet axis interface
     */
    reg         axis_tvalid =   0;
    reg         axis_tready =   0;
    reg [63:0]  axis_tdata  =   0;
    reg         axis_tlast  =   0;
    reg [7:0]   axis_tkeep  =   0;

    /* 
     * output packet length
     */
    wire [15:0]  packet_len_bytes;
 
 initial begin
    #(`CLOCK_PERIOD * 20) axis_aresetn <= 1;

    repeat(20)begin
        #(`CLOCK_PERIOD)begin
            axis_tvalid <= 1;
            axis_tready <= 1;
            axis_tdata <= axis_tdata + 1;
            axis_tlast <= 0;
            axis_tkeep <= 8'hff;
        end
    end
    #(`CLOCK_PERIOD)begin
            axis_tvalid <= 1;
            axis_tready <= 1;
            axis_tdata <= axis_tdata + 1;
            axis_tlast <= 1;
            axis_tkeep <= 8'h0f;
    end  
    repeat(40)begin
        #(`CLOCK_PERIOD)begin
            axis_tvalid <= 1;
            axis_tready <= 1;
            axis_tdata <= axis_tdata + 1;
            axis_tlast <= 0;
            axis_tkeep <= 8'hff;
        end
    end   
    #(`CLOCK_PERIOD)begin
            axis_tvalid <= 1;
            axis_tready <= 1;
            axis_tdata <= axis_tdata + 1;
            axis_tlast <= 1;
            axis_tkeep <= 8'h0f;
    end  
    #(`CLOCK_PERIOD)begin
            axis_tvalid <= 0;
            axis_tready <= 0;
            axis_tdata <= axis_tdata + 1;
            axis_tlast <= 0;
            axis_tkeep <= 8'h00;
    end  
 end
 
 axis_counter u_axis_counter(
    .axis_aclk        	(axis_aclk         ),
    .axis_aresetn     	(axis_aresetn      ),
    .axis_tvalid      	(axis_tvalid       ),
    .axis_tready      	(axis_tready       ),
    .axis_tdata       	(axis_tdata        ),
    .axis_tlast       	(axis_tlast        ),
    .axis_tkeep       	(axis_tkeep        ),
    .packet_len_bytes 	(packet_len_bytes  )
 );

 
 always #(`CLOCK_PERIOD/ 2)axis_aclk = ~axis_aclk;

 endmodule
/****************************************************************************
 * @file    tb_udp_stack_top.v
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

module tb_udp_stack_top();

localparam      UDP_SRC_PORT    =   16'h8080;
localparam      UDP_DST_PORT    =   16'h4554;
localparam      SRC_IP_ADDR     =   {8'd192, 8'd168, 8'd1, 8'd144};
localparam      DST_IP_ADDR     =   {8'd192, 8'd168, 8'd1, 8'd149};
localparam      SRC_MAC_ADDR    =   {8'hac, 8'h14, 8'h45, 8'hff,8'haf, 8'hc4};

/*
arp packet
||
||
\/
+------+------+--+---+------+------------------+-------------+------------------+-------------+
| HType| PType|HL|PL |Opcode|   SenderMAC      |  SenderIP   |   TargetMAC      |  TargetIP   |
+------+------+--+---+------+------------------+-------------+------------------+-------------+
|0x0001|0x0800|06|04|0x0001|ac:14:45:ff:af:c4 |192.168.1.144|00:00:00:00:00:00 |192.168.1.149|
+------+------+--+---+------+------------------+-------------+------------------+-------------+
||
||
\/
mac packet
+----------------+----------------+----------+-----------------------------------+----------+
|  目标MAC地址   |   源MAC地址    | 类型字段 |             数据部分              | 帧校验序�? |
|   (6字节)      |    (6字节)     | (2字节)  |            (46-1500字节)          |  (4字节)  |
+----------------+----------------+----------+-----------------------------------+----------+
| FF:FF:FF:FF:FF:FF | AC:14:45:FF:AF:C4 |  0x0806  | [ARP请求数据包] + 填充           | [CRC32]  |
+----------------+----------------+----------+-----------------------------------+----------+

*/

reg            tx_axis_aclk     =   0;
reg            tx_axis_aresetn  =   0;
reg            rx_axis_aclk     =   0;
reg            rx_axis_aresetn  =   0;
reg    [31:0]  src_ip_addr      =   SRC_IP_ADDR;
reg    [31:0]  dst_ip_addr      =   DST_IP_ADDR;
reg    [47:0]  src_mac_addr     =   SRC_MAC_ADDR;
reg    [15:0]  udp_src_port     =   UDP_SRC_PORT;
reg    [15:0]  udp_dst_port     =   UDP_DST_PORT;
wire           udp_enable;
/* udp tx axis interface */		  
reg [63:0]     udp_tx_axis_tdata    =   0;
reg [7:0]      udp_tx_axis_tkeep    =   0;
reg            udp_tx_axis_tvalid   =   0;		 
reg            udp_tx_axis_tlast    =   0;
wire           udp_tx_axis_tready;

wire [63:0]    udp_rx_axis_tdata;
wire [7:0]     udp_rx_axis_tkeep;
wire           udp_rx_axis_tvalid;		 
wire           udp_rx_axis_tlast;
wire           udp_rx_axis_tuser;

wire [63:0]    mac_tx_axis_tdata;
wire [7:0]     mac_tx_axis_tkeep;
wire           mac_tx_axis_tvalid;
wire           mac_tx_axis_tlast;
reg            mac_tx_axis_tready = 1;

reg [63:0]     mac_rx_axis_tdata  = 0 ;
reg [7:0]      mac_rx_axis_tkeep  = 0 ;
reg            mac_rx_axis_tvalid = 0 ;
reg            mac_rx_axis_tuser  = 0 ;
reg            mac_rx_axis_tlast  = 0 ;

/*
 *
 */
integer fd;
integer fc;
integer fe;

integer r;
integer i ;
reg [63:0] data_buf;
integer frame_idx;
integer word_idx;

initial begin
    $display("Current working directory:");
    $system("cd");  // 在仿真控制台打印当前目录
end

initial begin
    #(`CLOCK_PERIOD*60)begin
        tx_axis_aresetn <= 1;
        rx_axis_aresetn <= 1;
    end
/********************************************************************************
 test arp tx and rx
||
|| mac packet
\/
| dse MAC (Dst MAC)  | MAC (Src MAC)     | EtherType | HType  | PType  | HL | PL | Opcode | SenderMAC         | SenderIP      | TargetMAC         | TargetIP      |
| ------------------ | ----------------- | --------- | ------ | ------ | -- | -- | ------ | ----------------- | ------------- | ----------------- | ------------- |
| ac:14:45:ff:af:c4  | ac:70:12:56:41:23 | 0x0806    | 0x0001 | 0x0800 | 06 | 04 | 0x0002 | ac:70:12:56:41:23 | 192.168.1.149 | ac:14:45:ff:af:c4 | 192.168.1.144 |
||
||
\/ arp packet

*********************************************************************************/
    #(`CLOCK_PERIOD*60)begin
        mac_rx_axis_tdata <= {8'h70,8'hac,8'hc4,8'haf,8'hff,8'h45,8'h14,8'hac};
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tuser <= 0;
        mac_rx_axis_tlast <= 0;
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= {8'h01,8'h00,8'h06,8'h08,8'h23,8'h41,8'h56,8'h12};
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tuser <= 0;
        mac_rx_axis_tlast <= 0;        
    end
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= {8'h70,8'hac,8'h02,8'h00,8'h04,8'h06,8'h00,8'h08};
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tuser <= 0;
        mac_rx_axis_tlast <= 0;        
    end   
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= {8'h95,8'h01,8'ha8,8'hc0,8'h23,8'h41,8'h56,8'h12};
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tuser <= 0;
        mac_rx_axis_tlast <= 0;        
    end     
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= {8'ha8,8'hc0,8'hc4,8'haf,8'hff,8'h45,8'h14,8'hac};
        mac_rx_axis_tkeep <= 8'hff;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tuser <= 0;
        mac_rx_axis_tlast <= 0;        
    end     
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= {8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h90,8'h01};
        mac_rx_axis_tkeep <= 8'h03;
        mac_rx_axis_tvalid<= 1;
        mac_rx_axis_tuser <= 0;
        mac_rx_axis_tlast <= 1;        
    end    
    #(`CLOCK_PERIOD)begin
        mac_rx_axis_tdata <= {8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00,8'h00};
        mac_rx_axis_tkeep <= 8'h00;
        mac_rx_axis_tvalid<= 0;
        mac_rx_axis_tuser <= 0;
        mac_rx_axis_tlast <= 0;        
    end    


/********************************************************************************
 * test udp tx 
 * Xilinx is now part of AMD!

    The purpose of the wiki is to provide you with the tools you need to complete projects and tasks which use Xilinx products. 
    If you have any technical questions on the subjects contained in this Wiki please ask them on the boards located at the AMD Adaptive Support Community. 
    There are multiple boards on the Xilinx Community Forums. Please try to select the best one to fit your topic. 
    If there are any issues with this Wiki itself or its infrastructure please report them here.
    Click on any of the pictures or links to get started and find more information on the topic you are looking for.
    Please help us improve the depth and quality of information on this wiki. You may provide us feedback by sending email to wiki-help @ xilinx.com.
 *******************************************************************************/
    #(`CLOCK_PERIOD * 20)
    fd = $fopen("E:/udp_10Gbps_stack-main/python/udp-tx-data.bin", "rb");
    if (fd == 0) begin
        $display("Failed to open file!");
        $finish;
    end
    fc = $fopen("E:/udp_10Gbps_stack-main/python/mac-tx-data.bin", "wb");
    if (fc == 0) begin
        $display("Failed to open mac-tx-data.bin!");
        $finish;
    end
    // 
    for (frame_idx = 1; frame_idx <= 20; frame_idx = frame_idx + 1) begin
        for (word_idx = 1; word_idx <= frame_idx; word_idx = word_idx + 1) begin
     
            r = $fread(data_buf, fd);

            @(posedge tx_axis_aclk);
            udp_tx_axis_tdata  <= {data_buf[7:0]  ,data_buf[15:8], data_buf[23:16],data_buf[31:24],
                                   data_buf[39:32],data_buf[47:40],data_buf[55:48],data_buf[63:56]};
            udp_tx_axis_tkeep  <= 8'hFF;
            udp_tx_axis_tvalid <= 1;
         
            udp_tx_axis_tlast  <= (word_idx == frame_idx) ? 1'b1 : 1'b0;
        end
            @(posedge tx_axis_aclk);
            udp_tx_axis_tvalid <= 0;
            udp_tx_axis_tlast  <= 0;
    end

    $fclose(fd);
    $display("All UDP frames sent.");


/********************************************************************************
 * test udp rx from bin file (17 frames from testbench_mac_rx_gen.py)
 *   
 *******************************************************************************/
    fe = $fopen("E:/udp_10Gbps_stack-main/python/mac-rx-reply.bin", "rb");
    if(fe == 0)begin
        $display("Failed to open file!");
        $finish;
    end

    #(`CLOCK_PERIOD * 20)begin
        for (frame_idx = 1; frame_idx <= 13; frame_idx = frame_idx + 1) begin
            if(frame_idx == 1 )begin
                for (word_idx = 1; word_idx <= frame_idx + 6; word_idx = word_idx + 1)begin
                    r = $fread(data_buf, fe);
                    @(posedge tx_axis_aclk);
                    mac_rx_axis_tdata <= {data_buf[7:0]  ,data_buf[15:8], data_buf[23:16],data_buf[31:24],
                                          data_buf[39:32],data_buf[47:40],data_buf[55:48],data_buf[63:56]};
                    mac_rx_axis_tkeep <= 8'hff;
                    mac_rx_axis_tvalid<= 1;
                    mac_rx_axis_tlast <= (word_idx == frame_idx + 6) ? 1'b1 : 1'b0;
                end
                @(posedge tx_axis_aclk);
                mac_rx_axis_tvalid <= 0;
                mac_rx_axis_tlast  <= 0;
            end
            else if(frame_idx >1 && frame_idx <= 5)begin 
                for (word_idx = 1; word_idx <= 8; word_idx = word_idx + 1)begin
                    r = $fread(data_buf, fe);
                    @(posedge tx_axis_aclk);
                    mac_rx_axis_tdata <= {data_buf[7:0]  ,data_buf[15:8], data_buf[23:16],data_buf[31:24],
                                          data_buf[39:32],data_buf[47:40],data_buf[55:48],data_buf[63:56]};
                    mac_rx_axis_tkeep <= 8'hff;
                    mac_rx_axis_tvalid<= 1;
                    mac_rx_axis_tlast <= (word_idx == 8) ? 1'b1 : 1'b0;
                end
                @(posedge tx_axis_aclk);
                mac_rx_axis_tvalid <= 0;
                mac_rx_axis_tlast  <= 0;
            end
            else if(frame_idx >5 && frame_idx <= 7)begin 
                for (word_idx = 1; word_idx <= 9; word_idx = word_idx + 1)begin
                    r = $fread(data_buf, fe);
                    @(posedge tx_axis_aclk);
                    mac_rx_axis_tdata <= {data_buf[7:0]  ,data_buf[15:8], data_buf[23:16],data_buf[31:24],
                                          data_buf[39:32],data_buf[47:40],data_buf[55:48],data_buf[63:56]};
                    mac_rx_axis_tkeep <= 8'hff;
                    mac_rx_axis_tvalid<= 1;
                    mac_rx_axis_tlast <= (word_idx == 9) ? 1'b1 : 1'b0;
                end
                @(posedge tx_axis_aclk);
                mac_rx_axis_tvalid <= 0;
                mac_rx_axis_tlast  <= 0;
            end
            else if(frame_idx == 8 || frame_idx == 9)begin 
                for (word_idx = 1; word_idx <= 10; word_idx = word_idx + 1)begin
                    r = $fread(data_buf, fe);
                    @(posedge tx_axis_aclk);
                    mac_rx_axis_tdata <= {data_buf[7:0]  ,data_buf[15:8], data_buf[23:16],data_buf[31:24],
                                          data_buf[39:32],data_buf[47:40],data_buf[55:48],data_buf[63:56]};
                    mac_rx_axis_tkeep <= 8'hff;
                    mac_rx_axis_tvalid<= 1;
                    mac_rx_axis_tlast <= (word_idx == 10) ? 1'b1 : 1'b0;
                end
                @(posedge tx_axis_aclk);
                mac_rx_axis_tvalid <= 0;
                mac_rx_axis_tlast  <= 0;
            end
            else if(frame_idx == 10)begin 
                for (word_idx = 1; word_idx <= 11; word_idx = word_idx + 1)begin
                    r = $fread(data_buf, fe);
                    @(posedge tx_axis_aclk);
                    mac_rx_axis_tdata <= {data_buf[7:0]  ,data_buf[15:8], data_buf[23:16],data_buf[31:24],
                                          data_buf[39:32],data_buf[47:40],data_buf[55:48],data_buf[63:56]};
                    mac_rx_axis_tkeep <= 8'hff;
                    mac_rx_axis_tvalid<= 1;
                    mac_rx_axis_tlast <= (word_idx == 11) ? 1'b1 : 1'b0;
                end
                @(posedge tx_axis_aclk);
                mac_rx_axis_tvalid <= 0;
                mac_rx_axis_tlast  <= 0;
            end

            else if(frame_idx == 11)begin 
                for (word_idx = 1; word_idx <= 14; word_idx = word_idx + 1)begin
                    r = $fread(data_buf, fe);
                    @(posedge tx_axis_aclk);
                    mac_rx_axis_tdata <= {data_buf[7:0]  ,data_buf[15:8], data_buf[23:16],data_buf[31:24],
                                          data_buf[39:32],data_buf[47:40],data_buf[55:48],data_buf[63:56]};
                    mac_rx_axis_tkeep <= 8'hff;
                    mac_rx_axis_tvalid<= 1;
                    mac_rx_axis_tlast <= (word_idx == 14) ? 1'b1 : 1'b0;
                end
                @(posedge tx_axis_aclk);
                mac_rx_axis_tvalid <= 0;
                mac_rx_axis_tlast  <= 0;
            end
            else if(frame_idx == 12)begin 
                for (word_idx = 1; word_idx <= 13; word_idx = word_idx + 1)begin
                    r = $fread(data_buf, fe);
                    @(posedge tx_axis_aclk);
                    mac_rx_axis_tdata <= {data_buf[7:0]  ,data_buf[15:8], data_buf[23:16],data_buf[31:24],
                                          data_buf[39:32],data_buf[47:40],data_buf[55:48],data_buf[63:56]};
                    mac_rx_axis_tkeep <= 8'hff;
                    mac_rx_axis_tvalid<= 1;
                    mac_rx_axis_tlast <= (word_idx == 13) ? 1'b1 : 1'b0;
                end
                @(posedge tx_axis_aclk);
                mac_rx_axis_tvalid <= 0;
                mac_rx_axis_tlast  <= 0;
            end
            else if(frame_idx ==13)begin 
                for (word_idx = 1; word_idx <= 12; word_idx = word_idx + 1)begin
                    r = $fread(data_buf, fe);
                    @(posedge tx_axis_aclk);
                    mac_rx_axis_tdata <= {data_buf[7:0]  ,data_buf[15:8], data_buf[23:16],data_buf[31:24],
                                          data_buf[39:32],data_buf[47:40],data_buf[55:48],data_buf[63:56]};
                    mac_rx_axis_tkeep <= 8'hff;
                    mac_rx_axis_tvalid<= 1;
                    mac_rx_axis_tlast <= (word_idx == 12) ? 1'b1 : 1'b0;
                end
                @(posedge tx_axis_aclk);
                mac_rx_axis_tvalid <= 0;
                mac_rx_axis_tlast  <= 0;
            end
        end
        $fclose(fe);
    end
end

/********************************************************************************
 * test mac tx data write into file
 *   
 *******************************************************************************/
always @(posedge tx_axis_aclk) begin
    if (!tx_axis_aresetn) begin

    end else begin
        if (mac_tx_axis_tvalid & udp_enable) begin
            $display("TX WRITE: Cycle %0t, enable=%b, data=%h", $time, udp_enable, mac_tx_axis_tdata);  // Debug: Confirms ARP reply trigger
            for (i = 7; i >= 0; i = i - 1) begin
                $fwrite(fc, "%c", mac_tx_axis_tdata[i*8 +: 8]);
            end
        end
    end
end

final begin
    $fclose(fc);
    $display("mac-tx-data.bin written successfully.");
end

udp_stack_top u_udp_stack_top(
    .tx_axis_aclk       	(tx_axis_aclk        ),
    .tx_axis_aresetn    	(tx_axis_aresetn     ),
    .rx_axis_aclk       	(rx_axis_aclk        ),
    .rx_axis_aresetn    	(rx_axis_aresetn     ),
    .src_ip_addr        	(src_ip_addr         ),
    .dst_ip_addr        	(dst_ip_addr         ),
    .src_mac_addr       	(src_mac_addr        ),
    .udp_src_port       	(udp_src_port        ),
    .udp_dst_port       	(udp_dst_port        ),
    .udp_enable             (udp_enable),
    .udp_tx_axis_tdata  	(udp_tx_axis_tdata   ),
    .udp_tx_axis_tkeep  	(udp_tx_axis_tkeep   ),
    .udp_tx_axis_tvalid 	(udp_tx_axis_tvalid  ),
    .udp_tx_axis_tlast  	(udp_tx_axis_tlast   ),
    .udp_tx_axis_tready 	(udp_tx_axis_tready  ),
    .udp_rx_axis_tdata  	(udp_rx_axis_tdata   ),
    .udp_rx_axis_tkeep  	(udp_rx_axis_tkeep   ),
    .udp_rx_axis_tvalid 	(udp_rx_axis_tvalid  ),
    .udp_rx_axis_tlast  	(udp_rx_axis_tlast   ),
    .udp_rx_axis_tuser  	(udp_rx_axis_tuser   ),
    .mac_tx_axis_tdata  	(mac_tx_axis_tdata   ),
    .mac_tx_axis_tkeep  	(mac_tx_axis_tkeep   ),
    .mac_tx_axis_tvalid 	(mac_tx_axis_tvalid  ),
    .mac_tx_axis_tlast  	(mac_tx_axis_tlast   ),
    .mac_tx_axis_tready 	(mac_tx_axis_tready  ),
    .mac_rx_axis_tdata  	(mac_rx_axis_tdata   ),
    .mac_rx_axis_tkeep  	(mac_rx_axis_tkeep   ),
    .mac_rx_axis_tvalid 	(mac_rx_axis_tvalid  ),
    .mac_rx_axis_tuser  	(mac_rx_axis_tuser   ),
    .mac_rx_axis_tlast  	(mac_rx_axis_tlast   )
);


always #(`CLOCK_PERIOD/2) rx_axis_aclk = ~rx_axis_aclk;
always #(`CLOCK_PERIOD/2) tx_axis_aclk = ~tx_axis_aclk;

endmodule
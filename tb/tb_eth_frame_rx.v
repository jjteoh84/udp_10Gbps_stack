`timescale 1ns/1ps

module tb_eth_frame_rx();

// Parameters
localparam CLK_PERIOD = 6.4;  // 156.25 MHz clock
localparam NUM_BEATS = 8;

// DUT ports
wire rx_axis_aclk;
wire rx_axis_aresetn;

reg  [63:0] mac_rx_axis_tdata;
reg  [7:0]  mac_rx_axis_tkeep;
reg         mac_rx_axis_tvalid;
reg         mac_rx_axis_tlast;
reg         mac_rx_axis_tuser = 1'b0;

wire [63:0] udp_rx_axis_tdata;
wire [7:0]  udp_rx_axis_tkeep;
wire        udp_rx_axis_tvalid;
wire        udp_rx_axis_tlast;
wire        udp_rx_axis_tuser;

wire [63:0] ip2icmp_axis_tdata;
wire [7:0]  ip2icmp_axis_tkeep;
wire        ip2icmp_axis_tvalid;
wire        ip2icmp_axis_tlast;
wire        ip2icmp_axis_tuser;

reg  [31:0] local_ip_addr   = 32'hc0a8017b;  // 192.168.1.123
reg  [47:0] local_mac_addr  = 48'hac147445bcf4;
reg  [31:0] dst_ip_addr     = 32'hc0a80165;  // 192.168.1.101

wire [47:0] dst_mac_addr;
wire        arp_reply_req;
reg         arp_reply_ack   = 1'b0;
reg         arp_request_ack = 1'b0;
wire        arp_request_req;
wire        mac_exist;
wire        arp_reply_valid;
wire [79:0] arp_register;

// Probes
wire [47:0] recv_src_mac_addr;
wire [31:0] recv_src_ip_addr;
wire [63:0] rx_axis_fmac_tdata;

// DUT
eth_frame_rx dut (
    .rx_axis_aclk       (rx_axis_aclk      ),
    .rx_axis_aresetn    (rx_axis_aresetn   ),
    .mac_rx_axis_tdata  (mac_rx_axis_tdata ),
    .mac_rx_axis_tkeep  (mac_rx_axis_tkeep ),
    .mac_rx_axis_tvalid (mac_rx_axis_tvalid),
    .mac_rx_axis_tlast  (mac_rx_axis_tlast ),
    .mac_rx_axis_tuser  (mac_rx_axis_tuser ),
    .udp_rx_axis_tdata  (udp_rx_axis_tdata ),
    .udp_rx_axis_tkeep  (udp_rx_axis_tkeep ),
    .udp_rx_axis_tvalid (udp_rx_axis_tvalid),
    .udp_rx_axis_tlast  (udp_rx_axis_tlast ),
    .udp_rx_axis_tuser  (udp_rx_axis_tuser ),
    .ip2icmp_axis_tdata (ip2icmp_axis_tdata),
    .ip2icmp_axis_tkeep (ip2icmp_axis_tkeep),
    .ip2icmp_axis_tvalid(ip2icmp_axis_tvalid),
    .ip2icmp_axis_tlast (ip2icmp_axis_tlast),
    .ip2icmp_axis_tuser (ip2icmp_axis_tuser),
    .local_ip_addr      (local_ip_addr     ),
    .local_mac_addr     (local_mac_addr    ),
    .dst_ip_addr        (dst_ip_addr       ),
    .dst_mac_addr       (dst_mac_addr      ),
    .arp_reply_req      (arp_reply_req     ),
    .arp_reply_ack      (arp_reply_ack     ),
    .arp_request_ack    (arp_request_ack   ),
    .arp_request_req    (arp_request_req   ),
    .mac_exist          (mac_exist         ),
    .arp_reply_valid    (arp_reply_valid   ),
    .arp_register       (arp_register      )
);

assign recv_src_mac_addr = dut.u_us_arp_rx.recv_src_mac_addr;
assign recv_src_ip_addr  = dut.u_us_arp_rx.recv_src_ip_addr;
assign rx_axis_fmac_tdata = dut.mac2arp_rx_axis_tdata;

// Packet data (exact Linux ARP reply)
reg [63:0] packet_data [0:NUM_BEATS-1];
reg [7:0]  packet_tkeep [0:NUM_BEATS-1];

initial begin
    packet_data[0] = 64'h36a0f4bc457414ac; packet_tkeep[0] = 8'hFF;
    packet_data[1] = 64'h010006088ce57d9f; packet_tkeep[1] = 8'hFF;
    packet_data[2] = 64'h36a0020004060008; packet_tkeep[2] = 8'hFF;
    packet_data[3] = 64'h6501a8c08ce57d9f; packet_tkeep[3] = 8'hFF;
    packet_data[4] = 64'ha8c0f4bc457414ac; packet_tkeep[4] = 8'hFF;
    packet_data[5] = 64'h0000000000007b01; packet_tkeep[5] = 8'hFF;
    packet_data[6] = 64'h0000000000000000; packet_tkeep[6] = 8'hFF;
    packet_data[7] = 64'h0000627ace6e0000; packet_tkeep[7] = 8'hFF;
end

// Clean AXI-Stream driver - starts several cycles after reset deassertion
reg [3:0] beat_cnt = 4'd0;

always @(posedge rx_axis_aclk or negedge rx_axis_aresetn) begin
    if (~rx_axis_aresetn) begin
        beat_cnt           <= 4'd0;
        mac_rx_axis_tvalid <= 1'b0;
        mac_rx_axis_tlast  <= 1'b0;
        mac_rx_axis_tdata  <= 64'd0;
        mac_rx_axis_tkeep  <= 8'd0;
    end else begin
        if (beat_cnt < NUM_BEATS) begin
            mac_rx_axis_tdata  <= packet_data[beat_cnt];
            mac_rx_axis_tkeep  <= packet_tkeep[beat_cnt];
            mac_rx_axis_tvalid <= 1'b1;
            mac_rx_axis_tlast  <= (beat_cnt == NUM_BEATS-1);
            beat_cnt           <= beat_cnt + 1'd1;
        end else begin
            mac_rx_axis_tvalid <= 1'b0;
            mac_rx_axis_tlast  <= 1'b0;
            mac_rx_axis_tdata  <= 64'd0;
            mac_rx_axis_tkeep  <= 8'd0;
        end
    end
end

// Clock and reset generation
reg clk  = 1'b0;
reg rstn = 1'b0;
always #(CLK_PERIOD/2) clk = ~clk;
assign rx_axis_aclk    = clk;
assign rx_axis_aresetn = rstn;

initial begin
    rstn = 1'b0;
    #(CLK_PERIOD*10);
    rstn = 1'b1;
    #(CLK_PERIOD*300);
    $display("=== Simulation Complete ===");
    $finish;
end

// VCD dump
initial begin
    $dumpfile("tb_eth_frame_rx.vcd");
    $dumpvars(0, tb_eth_frame_rx);
end

// Verification checks
reg test_passed = 1'b1;

always @(posedge rx_axis_aclk) begin
    if (rx_axis_aresetn) begin
        // First payload beat after 14-byte Ethernet header
        if (beat_cnt == 4'd3 && mac_rx_axis_tvalid) begin
            if (rx_axis_fmac_tdata !== 64'h0200040600080100) begin
                $display("ERROR @ %0t : ARP stripper first beat wrong: 0x%h (expected 0x0200040600080100)", $time, rx_axis_fmac_tdata);
                test_passed = 1'b0;
            end else
                $display("PASS  @ %0t : ARP stripper first beat correct", $time);
        end

        // ARP fields parsed correctly
        if (beat_cnt == 4'd5 && arp_reply_valid) begin
            if (recv_src_mac_addr !== 48'ha0369f7de58c) begin
                $display("ERROR @ %0t : src MAC = 0x%h (exp 0xa0369f7de58c)", $time, recv_src_mac_addr);
                test_passed = 1'b0;
            end else $display("PASS  @ %0t : src MAC correct", $time);

            if (recv_src_ip_addr !== 32'hc0a80165) begin
                $display("ERROR @ %0t : src IP  = 0x%h (exp 0xc0a80165)", $time, recv_src_ip_addr);
                test_passed = 1'b0;
            end else $display("PASS  @ %0t : src IP correct", $time);

            $display("PASS  @ %0t : arp_reply_valid asserted correctly", $time);
        end

        // Padding/passthrough check
        if (beat_cnt == 4'd0 && mac_rx_axis_tlast && mac_rx_axis_tvalid) begin  // beat_cnt wraps to 0 after last beat
            if (rx_axis_fmac_tdata[47:0] !== 48'h627ace6e0000) begin
                $display("ERROR @ %0t : passthrough padding corrupted", $time);
                test_passed = 1'b0;
            end else
                $display("PASS  @ %0t : passthrough padding intact", $time);
        end
    end
end

// Monitor
always @(posedge rx_axis_aclk) begin
    if (rx_axis_aresetn && mac_rx_axis_tvalid)
        $display("T=%0t | beat=%0d | in=0x%016h | out=0x%016h | mac=%h | ip=%h | arp_vld=%b",
                 $time, beat_cnt-1, mac_rx_axis_tdata, rx_axis_fmac_tdata,
                 recv_src_mac_addr, recv_src_ip_addr, arp_reply_valid);
end

// Final result
initial begin
    # (CLK_PERIOD*350);
    if (test_passed)
        $display("=== ALL TESTS PASSED ===");
    else
        $display("=== TEST FAILED - see errors above ===");
end

endmodule
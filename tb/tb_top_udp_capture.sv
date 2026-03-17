`timescale 1ns / 1ps
`default_nettype none


module tb_top_udp_capture;

    localparam real CLK720_PERIOD = 1.388888; // 720 MHz
    localparam real CLK156_PERIOD = 6.4;      // 156.25 MHz
    localparam real CLK300_PERIOD = 3.333333; // 300 MHz

    reg         sys_clk_300Mhz_p = 0;
    reg         sys_clk_300Mhz_n = 1;
    reg         gt_refclk_in_p = 0;
    reg         gt_refclk_in_n = 1;
    reg         clk_720m_p = 0;
    reg         clk_720m_n = 1;
    
    reg         data_p = 1;  // Idle high (common for LVDS)
    reg         data_n = 0;
    
    reg         gt_rx_in_p = 0;
    reg         gt_rx_in_n = 1;

    wire        gt_tx_out_n;
    wire        gt_tx_out_p;
    wire        si5328_rst;
    wire        sfp0_tx_disable;
    wire [4:0]  led;

    reg         sys_reset = 1;

    // ===================================================================
    // Instantiate DUT
    // ===================================================================
    top_udp dut (
        .gt_refclk_in_p    (gt_refclk_in_p),
        .gt_refclk_in_n    (gt_refclk_in_n),
        .sys_reset         (sys_reset),
        .sys_clk_300Mhz_p  (sys_clk_300Mhz_p),
        .sys_clk_300Mhz_n  (sys_clk_300Mhz_n),
        .gt_rx_in_p        (gt_rx_in_p),
        .gt_rx_in_n        (gt_rx_in_n),
        .gt_tx_out_n       (gt_tx_out_n),
        .gt_tx_out_p       (gt_tx_out_p),
        .si5328_rst        (si5328_rst),
        .sfp0_tx_disable   (sfp0_tx_disable),
        .led               (led),
        .clk_720m_p        (clk_720m_p),
        .clk_720m_n        (clk_720m_n),
        .data_p            (data_p),
        .data_n            (data_n)
    );

    // Clocks
    always #(CLK720_PERIOD/2.0) begin
        clk_720m_p <= ~clk_720m_p;
        clk_720m_n <= ~clk_720m_n;
    end
    always #(CLK300_PERIOD/2.0) begin
        sys_clk_300Mhz_p <= ~sys_clk_300Mhz_p;
        sys_clk_300Mhz_n <= ~sys_clk_300Mhz_n;
    end
    always #(CLK156_PERIOD/2.0) begin
        gt_refclk_in_p <= ~gt_refclk_in_p;
        gt_refclk_in_n <= ~gt_refclk_in_n;
    end

    // Wait for internal clocks to be active (since ethernet IP generates them)
    wire tx_axis_aclk = dut.tx_clk_out;
    wire rx_axis_aclk = dut.rx_clk_out;

    // Expected packet
    localparam [16:0] HEADER = 17'b10101010101010101;
    reg [127:0] expected_packet = {HEADER, 111'h0F0F_0F0F_0F0F_0F0F_0F0F_0F0F_0F0F};

    // Send 128-bit packet
    task send_packet;
        integer i;
        reg [127:0] packet;
        begin
            packet = expected_packet;
            
            // Short Idle before packet (ensure separation). 
            data_p <= 1; data_n <= 0;
            repeat(72) @(posedge clk_720m_p);

            // Send packet MSB-first (earliest bit first)
            for (i = 127; i >= 0; i = i - 1) begin
                data_p <= packet[i];
                data_n <= ~packet[i];
                @(posedge clk_720m_p);
            end
            
            // Idle after
            data_p <= 1; data_n <= 0;
            repeat(72) @(posedge clk_720m_p);
        end
    endtask

    integer beat_cnt = 0;
    reg [127:0] received_packet;

    // Monitor AXI-Stream entering the UDP stack (from latch capture)
    always @(posedge tx_axis_aclk) begin
        if (dut.udp_tx_axis_tvalid && dut.udp_stack_tx_axis_tready && !dut.reg_tx_tvalid) begin
            if (dut.udp_tx_axis_tlast) begin
                received_packet[63:0] = dut.udp_tx_axis_tdata;
                $display("%t: [UDP_TX] Beat 1 (tlast): 0x%016x", $time, dut.udp_tx_axis_tdata);
                if (received_packet == expected_packet)
                    $display(">>> LATRIC TO UDP STACK PACKET CORRECT <<<");
                else
                    $display(">>> LATRIC TO UDP STACK MISMATCH! Exp: 0x%032x, Got: 0x%032x", expected_packet, received_packet);
            end else begin
                received_packet[127:64] = dut.udp_tx_axis_tdata;
                $display("%t: [UDP_TX] Beat 0: 0x%016x", $time, dut.udp_tx_axis_tdata);
            end
        end
    end

    // Monitor AXI-Stream leaving the UDP stack (entering MAC/Eth IP)
    always @(posedge tx_axis_aclk) begin
        if (dut.mac_tx_axis_tvalid && dut.mac_tx_axis_tready) begin
            $display("%t: [MAC_TX] Data out to Ethernet: 0x%016x, tlast=%b, tkeep=%h", 
                     $time, dut.mac_tx_axis_tdata, dut.mac_tx_axis_tlast, dut.mac_tx_axis_tkeep);
        end
    end

    initial begin
        $display("=== Testbench top_udp capture Start ===");
        
        // Initial setup
        clk_720m_p = 0; clk_720m_n = 1;
        data_p = 1; data_n = 0;
        
        sys_reset = 1;
        #1000;
        sys_reset = 0;

        // Optionally force the Ethernet PHY lock signals if simulation takes too long
        // force dut.eth_10G.rx_core_clk_0 = tx_axis_aclk;
        
        // Wait for system MMCM to lock
        wait(dut.mmcm_locked == 1'b1);
        $display("%t: System MMCM Locked", $time);

        // Wait for transceiver to become ready (tx_axis_aclk starts toggling)
        // Give it some time to initialize
        #50000; 
        
        // If ARP is needed to send UDP packets, we can simply force the 
        // internal mac_exist and dst_mac_addr registers inside udp_stack_top.
        $display("%t: Forcing FPGA ARP table to bypass ARP resolution...", $time);
        
        force dut.u_udp_stack_top.u_eth_frame_tx.mac_exist = 1'b1;
        force dut.u_udp_stack_top.u_eth_frame_tx.dst_mac_addr = 48'hac_70_12_56_41_23;
        
        // Wait for LATRIC IDELAY training to complete
        $display("%t: Waiting for LATRIC training...", $time);
        
        // Send packets continuously until training is done
        while (dut.u_latric_raw128_capture.training_done == 1'b0) begin
            send_packet();
        end
        $display("%t: LATRIC Training completed. Center Tap: %0d", $time, dut.u_latric_raw128_capture.center_tap);
        

        
        // Send the test packets
        $display("%t: Sending actual test packets...", $time);
        #10000;
        
        send_packet();
        send_packet();
        send_packet();
        
        #50000;
        
        $display("=== Testbench Complete ===");
        $finish;
    end
    
    // Timeout
    initial begin
        #500_000_000; // 500 us
        $display("ERROR: Simulation timeout");
        $finish;
    end

endmodule

`timescale 1ns / 1ps
`default_nettype none

module tb_latric_raw128_capture;

    localparam real CLK720_PERIOD = 1.388888;     // 720 MHz
    localparam real CLK156_PERIOD = 6.4;     // 156.25 MHz
    localparam real CLK300_PERIOD = 3.333;   // 300 MHz
    localparam real BIT_PERIOD = CLK720_PERIOD;  // One bit = one 720 MHz cycle in modeled domain

    reg         clk720_p = 0;
    reg         clk720_n = 0;
    reg         data_p = 1;  // Idle high (common for LVDS)
    reg         data_n = 0;
    reg         tx_axis_aclk = 0;
    reg         tx_axis_aresetn = 0;
    wire [63:0] m_axis_tdata;
    wire [7:0]  m_axis_tkeep;
    wire        m_axis_tvalid;
    wire        m_axis_tlast;
    reg         m_axis_tready = 1;
    reg         sys_reset = 1;
    reg         ref_clk_300 = 0;
    reg         re_train = 0;
    reg        training_done;
    wire [4:0]  center_tap;

     // ===================================================================
    // Instantiate DUT
    // ===================================================================
    latric_raw128_capture dut (
        .clk720_p      (clk720_p),
        .clk720_n      (clk720_n),
        .data_p         (data_p),
        .data_n         (data_n),
        .tx_axis_aclk   (tx_axis_aclk),
        .tx_axis_aresetn (tx_axis_aresetn),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tkeep   (m_axis_tkeep),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tlast   (m_axis_tlast),
        .m_axis_tready  (m_axis_tready),
        .sys_reset      (sys_reset),
        .center_tap     (center_tap),
        .training_done  (training_done)
    );

    // Clocks
    initial clk720_p = 0;
    initial clk720_n = 1;

    always #(CLK720_PERIOD/2) begin
        clk720_p <= ~clk720_p;
        clk720_n <= ~clk720_n;
    end
    always #(CLK156_PERIOD/2)  tx_axis_aclk = ~tx_axis_aclk;
    always #(CLK300_PERIOD/2)  ref_clk_300 = ~ref_clk_300;

    // Expected packet
    localparam [16:0] HEADER = 17'b10101010101010101;
    // Use mixed payload to avoid aliasing with 1010... header during alignment search
    reg [127:0] expected_packet = {HEADER, 111'h0F0F_0F0F_0F0F_0F0F_0F0F_0F0F_0F0F}; 
    reg [127:0] received_packet;

    // Helper to insert misalignment bits (phase shift)
    task inject_misalignment;
        input integer bits;
        begin
            if (bits > 0) begin
                repeat(bits) begin
                    @(posedge clk720_p);
                    data_p <= 0; data_n <= 1;
                end
            end
        end
    endtask

    // Send 128-bit packet
    task send_packet;
        integer i;
        reg [127:0] packet;
        begin
            packet = expected_packet;
            
            // Short Idle before packet (ensure separation). 
            // Sync to clock and use 72 cycles (multiple of 8) to preserve alignment and avoid drift.
            data_p <= 1; data_n <= 0;
            repeat(72) @(posedge clk720_p);

            // Send packet MSB-first (earliest bit first)
            for (i = 127; i >= 0; i = i - 1) begin
                data_p <= packet[i];
                data_n <= ~packet[i];
                @(posedge clk720_p);
            end
            
            // Idle after
            data_p <= 1; data_n <= 0;
            repeat(72) @(posedge clk720_p);
        end
    endtask

    task verify_training;
        input integer max_packets;
        integer i;

        begin
            // Loop sending packets until training is done
            for (i = 0; i < max_packets; i = i + 1) begin
                if (training_done) begin
                    $display("Training completed successfully at time %t", $time);
                    $display("Center tap value: %0d", center_tap);
                    return;
                end
                else begin
                    send_packet();
                end
            end

            // Final check after last packet
            if (training_done) begin
                $display("Training completed successfully at time %t", $time);
                $display("Center tap value: %0d", center_tap);
                return;
            end

            $display("ERROR: Training did not complete within %0d packets", max_packets);
            $fatal;
        end
    endtask

    task run_test;
        input integer misalign;
        integer k;
        begin
            // 1. Reset DUT to clear previous alignment
            sys_reset = 1;
            tx_axis_aresetn = 0;
            #1000;
            sys_reset = 0;
            #1000;
            tx_axis_aresetn = 1;
            #5000; // Wait for logic to settle

            // 2. Inject static misalignment
            inject_misalignment(misalign);

            // 3. Send Training Burst (to ensure lock) + Test Packet
            // Sending 16 packets ensures we cover the 8-slip hunt cycle (~48 cycles) multiple times
//            $display("Sending burst for misalignment: %0d", misalign);
            // for (k = 0; k < 16; k = k + 1) begin
            //     send_packet();
            // end
            
            // Wait for training to complete (after the reset above)
            verify_training(500);
            if (training_done) begin
                // Send actual test packets now that training is done
                $display("Tranining is done. Now sending burst for misalignment: %0d", misalign);
                #10000; // Wait for DUT settle counter (15 cycles @ 90MHz) to expire
                for (k = 0; k < 16; k = k + 1) begin
                    send_packet();
                end;
            end
            #10000;
        end
    endtask
    
    task check_packet;
      begin
        if (received_packet == expected_packet)
          $display(">>> PACKET CORRECT <<<");
        else
          $display(">>> MISMATCH! Exp: 0x%032x, Got: 0x%032x", expected_packet, received_packet);

      end
    endtask

    initial begin
        $display("=== Testbench Start ===");

        // Initial setup
        clk720_p = 0; clk720_n = 1;
        data_p = 1; data_n = 0;

        $display("\nTest 1: No misalignment");

        // 1. Reset DUT to clear previous alignment
        sys_reset = 1;
        tx_axis_aresetn = 0;
        #1000;
        sys_reset = 0;
        #1000;
        tx_axis_aresetn = 1;
        #5000; // Wait for logic to settle

        // run_test handles reset and training internally now
        run_test(0);

        #10000;

        $display("\nTest 2: 3-bit misalignment");
        
        run_test(3);

        #10000;

        $display("\nTest 3: 7-bit misalignment");
        run_test(7);

//        re_train = 1;
//        #1000;
//        re_train = 0;
//        #50_000;

        $display("=== Testbench Complete ===");
        $finish;
    end

    // ===================================================================
    // Strategic Debug Monitor
    // ===================================================================
    always @(posedge dut.clk90_buf) begin
        if (dut.pattern_match && dut.training_done) begin
            $display("[Time %t] DEBUG: Pattern Match! Slip=%d, State=%d, Settle=%d, Grace=%d, Idle=%d, ShiftReg=0x%08x", 
                     $time, dut.slip_cnt, dut.state, dut.settle, dut.grace_cnt, dut.is_idle, dut.shift_reg);
        end
        if (dut.packet_ready) begin
            $display("[Time %t] DEBUG: Packet Assembled: 0x%032x", $time, dut.packet_reg);
        end
    end

    integer beat_cnt = 0;
    always @(posedge tx_axis_aclk) begin
      if (m_axis_tvalid && m_axis_tready) begin
        if (beat_cnt == 0) begin
          received_packet[127:64] = m_axis_tdata;
          $display(
              "%t: Beat %0d: 0x%016x %s", $time, beat_cnt, m_axis_tdata,
              m_axis_tlast ? "(tlast)" : "");
          beat_cnt = beat_cnt + 1;
        end else begin
          received_packet[63:0] = m_axis_tdata;
          $display(
              "%t: Beat %0d: 0x%016x %s", $time, beat_cnt, m_axis_tdata,
              m_axis_tlast ? "(tlast)" : "");
          beat_cnt = 0;
        end

        if (m_axis_tlast) begin
          check_packet;
        end
      end
//      else begin
//        if (!training_done) begin
//          $display("Still Training");
//            end
//        end
     end

    // Timeout
    initial begin
        #10_000_000;
        $display("ERROR: Simulation timeout");
        $finish;
    end
    
    

endmodule
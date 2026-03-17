`timescale 1ns / 1ps
`default_nettype none
`define SIMULATION  //remove if not simulating



// If delay tuning doesn't work, other option is just use falling edge of the 720 MHz clock.

module latric_raw128_capture (
    input  wire        clk720_p,
    input  wire        clk720_n,
    input  wire        data_p,
    input  wire        data_n,
    input  wire        tx_axis_aclk,      // 156.25 MHz UDP clock domain
    input  wire        tx_axis_aresetn,   // Active-low reset
    
    // AXI-Stream Output
    output wire [63:0] m_axis_tdata,
    output wire [7:0]  m_axis_tkeep,
    output wire        m_axis_tvalid,
    output wire        m_axis_tlast,
    input  wire        m_axis_tready,

    // Control & Status
    input  wire        sys_reset,         // Active-high system reset
    output reg        training_done,
    output reg  [8:0]  center_tap,
    output reg [2:0]  led
);



    // ===================================================================
    // Clock buffering
    // ===================================================================
  
    wire clk720_ibuf;
    wire clk360_buf;
    wire clk_90m;  
    wire clk90_buf;
    wire locked;
`ifdef SIMULATION


    IBUFGDS clk_buf (
        .O (clk720_ibuf),
        .I (clk720_p),
        .IB(clk720_n)
    );

    // Simulation Clock Generation
    reg r_clk360 = 0;
    always @(posedge clk720_ibuf) r_clk360 <= ~r_clk360;
    assign clk360_buf = r_clk360;

    reg [1:0] r_div4 = 0;
    always @(posedge clk360_buf) r_div4 <= r_div4 + 1;
    assign clk_90m = r_div4[1];
    assign clk90_buf = clk_90m;

    assign locked = 1'b1;

`else
    
    IBUFDS #(
        .DIFF_TERM   ("TRUE"),
        .IBUF_LOW_PWR("FALSE"),
        .IOSTANDARD  ("LVDS")     // adjust to your board (common: DIFF_SSTL12, LVDS)
    ) u_ibuf_clk (
        .I  (clk720_p),
        .IB (clk720_n),
        .O  (clk720_ibuf)
    );


    // ============================================================================
    // Generate 360 MHz from 720 MHz using MMCME3_ADV (Kintex UltraScale compliant)
    // VCO = 1440 MHz (legal max), PFD = 144 MHz
    // ============================================================================
    wire clk360;
    wire clkfb;
    

    MMCME3_ADV #(
        .BANDWIDTH            ("OPTIMIZED"),
        .CLKFBOUT_MULT_F      (10.0),           // M = 10
        .CLKFBOUT_PHASE       (0.0),
        .CLKIN1_PERIOD        (1.388888888),    // 720 MHz
        .CLKOUT0_DIVIDE_F     (4.0),            // D = 4 → 1440 / 4 = 360 MHz
        .CLKOUT0_DUTY_CYCLE   (0.5),
        .CLKOUT0_PHASE        (0.0),
        .DIVCLK_DIVIDE        (5),              // Critical: pre-divide by 5
        .IS_CLKINSEL_INVERTED (1'b0),
        .IS_PSEN_INVERTED     (1'b0),
        .IS_PSINCDEC_INVERTED (1'b0),
        .IS_PWRDWN_INVERTED   (1'b0),
        .IS_RST_INVERTED      (1'b0),
        .REF_JITTER1          (0.010),
        .STARTUP_WAIT         ("FALSE")
    )
    u_mmcm (
        .CLKIN1      (clk720_ibuf),
        .CLKINSEL    (1'b1),
        .CLKFBIN     (clkfb),
        .RST         (1'b0),
        .PWRDWN      (1'b0),
        .CLKFBOUT    (clkfb),
        .CLKFBOUTB   (),
        .LOCKED      (locked),
        .CLKOUT0     (clk360),
        .CLKOUT0B    (),
        .PSCLK       (1'b0),
        .PSEN        (1'b0),
        .PSINCDEC    (1'b0),
        .PSDONE      ()
    );


    
    BUFG u_buf_clk360 (.I(clk360), .O(clk360_buf));
        
    
    // CRITICAL: BUFGCE_DIV derives 90MHz (720/8) with deterministic phase
    BUFGCE_DIV #(
        .BUFGCE_DIVIDE(8),      // Divide by 8 → 90MHz
        .SIM_DEVICE("ULTRASCALE")
    ) bufgce_div_inst (
        .I   (clk720_ibuf),      // 720MHz global clock input
        .CE  (1'b1),            // Always enabled
        .CLR (1'b0),            // No clear
        .O   (clk_90m)        // 90MHz output for CLKDIV
    );

    assign clk90_buf = clk_90m;
`endif
    

    // ========================================================================
    // 2. Data input buffering (Bank 47)
    // ========================================================================
    wire data_single;

`ifdef SIMULATION
    assign data_single = data_p;
`else
    IBUFDS #(
        .DIFF_TERM("TRUE"),     // Internal 100Ω termination (MANDATORY for 720Mbps)
        .IOSTANDARD("LVDS")  // HP bank input standard
    ) ibufds_data (
        .I  (data_p),   // U21
        .IB (data_n),   // U22
        .O  (data_single)
    );
`endif


    // ============================================================================
    // IDELAYE3 calibration controller (required for stable / calibrated delays)
    // One instance services all IDELAYE3 in the same I/O region
    // ============================================================================
    wire idelay_rdy;  // Optional: goes high when calibration complete (~5-10 µs after reset deassert)
    
    IDELAYCTRL #(
        .SIM_DEVICE ("ULTRASCALE")          // Use "ULTRASCALE_PLUS" if your device is UltraScale+
    ) u_idelayctrl (
        .RDY     (idelay_rdy),              // 1-bit output: Ready flag (calibration done)
        .REFCLK  (clk360_buf),              // 1-bit input: Reference clock (200-800 MHz range)
                                            // 360 MHz is excellent - stable from MMCM
        .RST     (sys_reset)                      // 1-bit input: Active-high reset (synchronous to REFCLK)
    );
    // ============================================================================
    // Input delay element for phase tuning (HP bank only)
    // ============================================================================
    wire data_delayed;
    wire vio_force_training_done;
    reg       auto_load;
    reg [8:0] final_delay_tap;
`ifdef SIMULATION
    assign vio_force_training_done = 1'b0;
    // // Bypass IDELAY in simulation (zero delay = direct pass-through)
    // assign data_delay = data_se;
    // Behavioral model for IDELAYE3 to test training.
    // This model implements a programmable delay line using a shift register.
    // Each 'delay_tap' value corresponds to a delay of one clk720_buf cycle.
    // This is a functional approximation, not a timing-accurate one, but it
    // allows the training algorithm to be verified.
    reg [511:0] delay_line = 0;
    reg [8:0]  active_delay_tap = 0;

    always @(posedge clk90_buf) begin
        if (auto_load) active_delay_tap <= auto_delay_tap;
    end

    always @(posedge clk720_ibuf) delay_line <= {delay_line[510:0], data_single};
    assign data_delayed = delay_line[active_delay_tap];
`else
    assign vio_force_training_done = 1'b0;
    wire [8:0] vio_delay_tap;
    wire       vio_load;
    wire       vio_manual_tap_en;

    reg       final_load;

    (* DONT_TOUCH = "TRUE" *)  // Helpful during debug
    IDELAYE3 #(
        .DELAY_SRC        ("IDATAIN"),
        .DELAY_TYPE       ("VAR_LOAD"),
        .DELAY_VALUE      (0),                  // initial (overridden by training/VIO)
        .REFCLK_FREQUENCY (360.0),              // Match your REFCLK frequency exactly
        .DELAY_FORMAT     ("COUNT"),            // or "TIME" once you want calibrated ps
        .UPDATE_MODE      ("ASYNC")             // safe for debug sweeps
    ) u_idelay_data (
        .CLK                (clk_90m),
        .CE               (1'b0),
        .INC              (1'b0),
        .LOAD               (final_load),
        .CNTVALUEIN       (final_delay_tap),
        .CNTVALUEOUT      (),
        .DATAOUT          (data_delayed),
        .IDATAIN          (data_single),
        .DATAIN           (1'b0),
        .RST              (sys_reset),
        .EN_VTC           (1'b1)                // almost always tied high
    );

//    // VIO for Manual IDELAY Tuning
//    vio_0 vio_inst (
//        .clk(clk_90m),
//        .probe_in0(vio_manual_tap_en),       // 1: Enable Manual Mode
//        .probe_in1(vio_force_training_done), // 1: Bypass Training FSM
//        .probe_in2(vio_load),                // Manual Load Pulse
//        .probe_in3(vio_delay_tap)            // Manual Tap [8:0]
//    );

    always_comb begin
        final_delay_tap = vio_manual_tap_en ? vio_delay_tap : auto_delay_tap;
        final_load      = vio_manual_tap_en ? vio_load : auto_load;
    end
`endif

    // ===================================================================
    // Deserialization: DDR 1:8 
    // ===================================================================
    wire [7:0] des_out;


`ifdef SIMULATION
    // Simple behavioral model for ISERDESE3 in sim
    // Must emulate 1:8 deserialization properly to avoid race conditions with clk90
    reg [7:0] des_out_sim;
    // Update on NEGEDGE to ensure data is stable 0.7ns before posedge clk90 samples it
    always @(negedge clk720_ibuf) begin
        if (sys_reset) 
            des_out_sim <= 8'b0;
        else
            des_out_sim <= {des_out_sim[6:0], data_delayed}; 
    end
    assign des_out = des_out_sim;  
`else
     
    ISERDESE3 #(
        .DATA_WIDTH         (8),                // 8 for 1:8 in DDR
        .FIFO_ENABLE        ("FALSE"),
        .SIM_DEVICE         ("ULTRASCALE"),
        .IS_CLK_INVERTED    (1'b0),
        .IS_CLK_B_INVERTED  (1'b1),             // Inverted for DDR mode
        .IS_RST_INVERTED    (1'b0)
    ) iserdes_inst (
        .Q                  (des_out), 
        .D                  (data_delayed),
        .CLK                (clk360_buf),
        .CLK_B              (clk360_buf),       // Inverted via attribute for DDR
        .CLKDIV             (clk_90m),
        .RST                (sys_reset)
       
    );
`endif




    // ===================================================================
    // Fabric bitslip and alignment logic (90 MHz domain)
    // ===================================================================
    
`ifdef SIMULATION
    localparam [15:0] TAP_OBSERVE_PERIOD = 16'd256; // Increased to capture >3 packets (272 cycles each)
    localparam [9:0]  STARTUP_WAIT       = 10'd64;
    localparam [9:0] MAX_TRAIN_TAPS = 10'd10;
    localparam [9:0]  MATCH_THRESH       = 10'd3;   // Lower threshold for short window
`else
    localparam [15:0] TAP_OBSERVE_PERIOD = 16'd30000;
    localparam [9:0]  STARTUP_WAIT       = 10'd511;
    localparam [9:0] MAX_TRAIN_TAPS = 10'd512;
    localparam [9:0]  MATCH_THRESH       = 10'd5;  // Tune: Matches per observation period
`endif
    localparam [16:0] HEADER_PATTERN     = 17'b10101010101010101;

    logic [9:0] startup_delay = 10'd0;
    logic [7:0] des_out_reg = 8'hFF;
    logic [31:0] shift_reg = 32'hFFFFFFFF;
    logic [2:0] slip_cnt = 3'd0;
    logic [3:0] settle = 4'd15;
    logic [3:0] grace_cnt = 4'd0;
    logic aligned = 1'b0;
    logic  [3:0]  count = 4'd0;    
    logic  [3:0]  state = 4'd1;                   // Start in alignment
    logic  [127:0] packet_reg = 128'b0;
    logic packet_ready = 1'b0; 
    logic bitslip_reg = 1'b0;
    
    // Missing declarations
    logic [9:0] current_tap;
    logic [9:0] match_cnt;
    logic [9:0] final_match_cnt;
    logic [15:0] observe_cnt;
    logic [8:0] min_pass_tap;
    logic [8:0] max_pass_tap;
    logic [8:0] auto_delay_tap;
   
    logic [127:0] dbg_packet_reg;

    wire [15:0] concat = {des_out_reg, des_out};
    wire [7:0] aligned_out = concat[slip_cnt +: 8];
    wire [16:0] pattern_window = shift_reg[23:7];
    wire pattern_match = (pattern_window == HEADER_PATTERN);
    wire is_idle = (&shift_reg) || (~|shift_reg);



always_ff @(posedge clk_90m) begin
        if (sys_reset) begin
            state        <= 4'd0;
            aligned      <= 1'b0;
            bitslip_reg  <= 1'b0;
            count        <= 4'd0;
            shift_reg    <= 32'hFFFFFFFF; // Init to 1s (Idle High) to prevent false activity detect
            packet_reg   <= 128'b0;
            slip_cnt     <= 3'd0;
            des_out_reg  <= 8'b0;
            settle       <= 4'd15;       // Initial fill + check timing
            packet_ready <= 1'b0;
            grace_cnt    <= 4'd0;

            startup_delay <= 10'd0;
            current_tap   <= 10'd0;
            match_cnt     <= 10'd0;
            final_match_cnt     <= 10'd0;

            training_done <= 1'b0;
            observe_cnt  <= 16'd0;
            min_pass_tap <= 9'd511;
            max_pass_tap <= 9'd0;
            auto_delay_tap <= 9'd0;
            auto_load    <= 1'b0;
            center_tap   <= 9'd0;
        end else begin 
            // Default
            auto_load    <= 1'b0;
            bitslip_reg  <= 1'b0;
            packet_ready <= 1'b0;
            des_out_reg <= des_out;
            shift_reg <= {shift_reg[23:0], aligned_out};

            // Grace Counter: Wait for header to shift in after Idle ends
            if (is_idle) begin
                grace_cnt <= 4'd0;
            end else begin
                if (grace_cnt < 4'd12) 
                    grace_cnt <= grace_cnt + 1'b1;
            end

            // // Re-train Trigger
            // if (re_train) begin
            //     training_done <= 1'b0;
            //     startup_delay <= 10'd0;
            //     current_tap   <= 10'd0;
            //     min_pass_tap  <= 9'd511;
            //     max_pass_tap  <= 9'd0;
            // end

            // Startup delay: Wait for IDELAYCTRL ready + Timer. Block activity until saturated (prevents blind slipping during initial idle)
            if (!idelay_rdy) begin
                startup_delay <= 10'd0;
                training_done <= 1'b0;
                current_tap   <= 10'd0;
                observe_cnt   <= 16'd0;
                match_cnt     <= 10'd0;
                final_match_cnt     <= 10'd0;
                min_pass_tap  <= 9'd511;
                max_pass_tap  <= 9'd0;
                auto_delay_tap <= 9'd0;
                auto_load     <= 1'b0;
                settle        <= 4'd15;
                grace_cnt     <= 4'd0;
                slip_cnt      <= 3'd0;
                shift_reg     <= 32'hFFFFFFFF;
                aligned       <= 1'b0;
                state         <= 4'd1;
            end else if (startup_delay < STARTUP_WAIT) begin
                startup_delay <= startup_delay + 1'b1;
                settle        <= 4'd15;      // Prevent early checks
                grace_cnt     <= 4'd0;
            end 


            else if (!training_done && !vio_force_training_done) begin
                // ────────────────────────────────────
                // Training phase: Sweep taps 0...MAX_TRAIN_TAPS
                // ────────────────────────────────────
                if (current_tap <= MAX_TRAIN_TAPS) begin
                    if (observe_cnt == 16'd0) begin
                        // Start new tap: auto_load and reset align logic
                        if (current_tap < MAX_TRAIN_TAPS) begin
                            auto_delay_tap   <= current_tap[8:0];
                            auto_load        <= 1'b1;
                            observe_cnt      <= TAP_OBSERVE_PERIOD;
                        end else begin
                            // Verification setup: Load center tap
                            if (min_pass_tap <= max_pass_tap) begin
                                auto_delay_tap <= (10'(min_pass_tap) + 10'(max_pass_tap)) >> 1;
                                center_tap     <= (10'(min_pass_tap) + 10'(max_pass_tap)) >> 1;
                                auto_load      <= 1'b1;
                                observe_cnt    <= TAP_OBSERVE_PERIOD;
                            end else begin
                                // No good window: Reset
                                current_tap   <= 10'd0;
                                min_pass_tap  <= 9'd511;
                                max_pass_tap  <= 9'd0;
                                // observe_cnt remains 0 to trigger load of tap 0 next cycle
                            end
                        end

                        match_cnt   <= 10'd0;
                        state       <= 4'd1;      // Enter hunt for this tap
                        slip_cnt    <= 3'd0;
                        aligned     <= 1'b0;
                        settle      <= 4'd15;
                        grace_cnt   <= 4'd0;
                        shift_reg   <= 32'hFFFFFFFF;  // Reset to idle
                    end else begin
                        // Observe: Run normal hunt/collect, count matches
                        observe_cnt <= observe_cnt - 1'b1;
                        
                        
                        case (state)
                            4'd1: begin  // Alignment state (without packet_ready generation)
                                if (settle == 4'd0) begin
                                    if (pattern_match) begin
                                        aligned      <= 1'b1;
                                        state        <= 4'd2;
                                        match_cnt <= match_cnt + 1'b1;
                                        // // Initialize at LSB so left-shifts move it to MSB
                                        // // Capture Header (from shift_reg) AND the next byte (aligned_out) immediately
                                        // packet_reg   <= {96'b0, shift_reg[23:0], aligned_out}; 
                                        count        <= 4'd0;
                                    end else begin
                                        // Only slip if:
                                        // 1. Not aligned
                                        // 2. Not Idle (don't slip on filler)
                                        // 3. Grace period expired (gave time for header to shift in)
                                        if (!aligned && !is_idle && (grace_cnt == 4'd12)) begin
                                            bitslip_reg  <= 1'b1;
                                            settle       <= 4'd15; // Increase settle to ensure full flush
                                            grace_cnt    <= 4'd0; // Reset grace for next position
                                            shift_reg    <= 32'hFFFFFFFF; // Reset to 1s to avoid triggering is_idle=0 on 1s input
                                        end
                                    end
                                end else begin
                                    settle <= settle - 1'b1;
                                end
                            end

                            4'd2: begin  // Collection state
                                // Shift left: Old data moves to MSB, New data enters LSB (aligned_out)
                                // packet_reg <= {packet_reg[119:0], aligned_out};
                                count <= count + 1'b1;
                                
                                if (count == 4'd11) begin  // After 12 shifts (0→11) + Init = 13 bytes
                                    // packet_ready <= 1'b1;
                                    state <= 4'd1;
                                end
                            end
                        endcase

                        if (bitslip_reg) begin
                            slip_cnt <= slip_cnt + 1'b1;
                        end

                        // End of observation for this tap
                        if (observe_cnt == 16'd1) begin  
                            if (current_tap < MAX_TRAIN_TAPS) begin
                                if (match_cnt >= MATCH_THRESH) begin
                                    if (current_tap[8:0] < min_pass_tap) min_pass_tap <= current_tap[8:0];
                                    if (current_tap[8:0] > max_pass_tap) max_pass_tap <= current_tap[8:0];
                                end
                            end else begin
                                // Verification pass complete
                                final_match_cnt <= match_cnt;
                                training_done   <= 1'b1;
                            end
                            current_tap <= current_tap + 1'b1;
                        end
                    end
                end
            end else begin
                // Normal operation
                case (state)
                    4'd1: begin  // Alignment state
                        if (settle == 4'd0) begin
                            if (pattern_match) begin
                                aligned      <= 1'b1;
                                state        <= 4'd2;
                                // Initialize at LSB so left-shifts move it to MSB
                                // Capture Header (from shift_reg) AND the next byte (aligned_out) immediately
                                packet_reg   <= {96'b0, shift_reg[23:0], aligned_out}; 
                                count        <= 4'd0;
                            end else begin
                                packet_reg   <= 128'b0;
                                // Only slip if:
                                // 1. Not aligned
                                // 2. Not Idle (don't slip on filler)
                                // 3. Grace period expired (gave time for header to shift in)
                                if (!aligned && !is_idle && (grace_cnt == 4'd12)) begin
                                    bitslip_reg  <= 1'b1;
                                    settle       <= 4'd15; // Increase settle to ensure full flush
                                    grace_cnt    <= 4'd0; // Reset grace for next position
                                    shift_reg    <= 32'hFFFFFFFF; // Reset to 1s to avoid triggering is_idle=0 on 1s input
                                end
                            end
                        end else begin
                            settle <= settle - 1'b1;
                        end
                    end

                    4'd2: begin  // Collection state
                        // Shift left: Old data moves to MSB, New data enters LSB (aligned_out)
                        packet_reg <= {packet_reg[119:0], aligned_out};
                        count <= count + 1'b1;
                        if (count == 4'd11) begin  // After 12 shifts (0→11) + Init = 13 bytes
                            packet_ready <= 1'b1;
                            state <= 4'd1;
                            dbg_packet_reg <= {packet_reg[119:0], aligned_out};
                        end
                    end
                endcase

                if (bitslip_reg) begin
                    slip_cnt <= slip_cnt + 1'b1;
                end
            end
        end
    end



    // ===================================================================
    // Async FIFO: 128-bit packet → 64-bit AXI-Stream (CDC 90 MHz → 156.25 MHz)
    // ===================================================================

    wire [127:0] fifo_din = packet_reg; 
    wire        fifo_wr_en;
    wire        fifo_full;
    wire [127:0] fifo_dout;
    wire        fifo_rd_en;
    wire        fifo_empty;
    wire        wr_rst_busy;
    wire        rd_rst_busy;

    assign fifo_wr_en = packet_ready && !fifo_full && !wr_rst_busy;

    xpm_fifo_async #(
        .FIFO_MEMORY_TYPE    ("auto"),
        .FIFO_WRITE_DEPTH    (64),
        .WRITE_DATA_WIDTH    (128),
        .READ_DATA_WIDTH     (128),     // Changed to symmetric 128-bit completely avoiding XPM FWFT asymmetry logic
        .READ_MODE           ("fwft"),
        .FIFO_READ_LATENCY   (0),
        .USE_ADV_FEATURES    ("1000"),
        .WAKEUP_TIME         (0)
    ) fifo_inst (
        .rst         (sys_reset),
        .wr_clk      (clk90_buf),
        .wr_en       (fifo_wr_en),
        .din         (fifo_din),
        .full        (fifo_full),
        .wr_rst_busy (wr_rst_busy),
        .rd_clk      (tx_axis_aclk),
        .rd_en       (fifo_rd_en),
        .dout        (fifo_dout),
        .empty       (fifo_empty),
        .rd_rst_busy (rd_rst_busy)
    );

    // ===================================================================
    // Read-side FSM: Output two 64-bit beats per packet, tlast on second
    // ===================================================================
    reg beat_cnt      = 1'b0;

    always @(posedge tx_axis_aclk) begin
        if (!tx_axis_aresetn || rd_rst_busy) begin
            beat_cnt <= 1'b0;
        end
        else if (m_axis_tvalid && m_axis_tready) begin
            // Advance beat count on every successful handshake
            beat_cnt <= ~beat_cnt;
        end
    end

    // Only pop after the SECOND beat has been accepted by downstream
    assign fifo_rd_en   = !fifo_empty && m_axis_tready && !rd_rst_busy && (beat_cnt == 1'b1);

    // Simplified: Direct mapping. First beat gets the upper bits (Header).
    assign m_axis_tdata = (beat_cnt == 1'b0) ? fifo_dout[127:64] : fifo_dout[63:0];
    assign m_axis_tkeep = 8'hFF;
    assign m_axis_tvalid = !fifo_empty && !rd_rst_busy;
    assign m_axis_tlast = beat_cnt;

    



    // ============================================================================
    // Simple counter-based LED blinker (using 360 MHz)
    // ============================================================================
    localparam integer CNT_1HZ = 360_000_000;   // 360 MHz / 2 = 1 Hz toggle
    logic [$clog2(CNT_1HZ)-1:0] cnt = '0;
    
    always_ff @(posedge clk360_buf) begin
        if (!locked) begin
            cnt     <= '0;
            led[2]   <= 1'b0;
            led[1]   <= 1'b0;
            led[0]   <= 1'b1;        // 1 = not locked
        end
        else begin
            led[0]   <= 1'b0; 
            if (cnt == CNT_1HZ-1) begin
                cnt   <= '0;
                led[1] <= ~led[1];
                led[2] <= des_out[0];
            end
            else begin
                cnt   <= cnt + 1;
            end
        end
    end



    
    (* mark_debug = "true" *)    wire dbg_idelay_rdy = idelay_rdy;                   
    (* mark_debug = "true" *)    wire [7:0] dbg_des_out = des_out;    
    (* mark_debug = "true" *)    wire [7:0]  dbg_aligned_out = aligned_out;   
    (* mark_debug = "true" *)    wire [31:0] dbg_shift_reg = shift_reg;      
    (* MARK_DEBUG = "TRUE" *)    wire dbg_pattern_match = pattern_match; 
    (* MARK_DEBUG = "TRUE" *)    reg dbg_packet_ready = packet_ready; 
    (* MARK_DEBUG = "TRUE" *)    wire [127:0] dbg_fifo_din = fifo_din;
    
    (* MARK_DEBUG = "TRUE" *) wire dbg_clk720_ibuf = clk720_ibuf;                                       
    (* MARK_DEBUG = "TRUE" *) wire dbg_locked = locked;
    (* MARK_DEBUG = "TRUE" *) wire dbg_clk360 = clk360_buf;
    (* mark_debug = "true" *)    wire dbg_clk90_buf = clk90_buf;

    (* mark_debug = "true" *) logic dbg_beat_cnt = beat_cnt;
    
    // Auto-training signals (from latric_raw128 example)
    (* mark_debug = "true" *) logic dbg_training_done = training_done;
    (* mark_debug = "true" *) logic [8:0] dbg_center_tap = center_tap;
    (* mark_debug = "true" *) logic [9:0] dbg_current_tap = current_tap;
    (* mark_debug = "true" *) logic [9:0] dbg_match_cnt = match_cnt;
    (* mark_debug = "true" *) logic [9:0] dbg_final_match_cnt = final_match_cnt;
    (* mark_debug = "true" *) logic [8:0] dbg_min_pass_tap = min_pass_tap;
    (* mark_debug = "true" *) logic [8:0] dbg_max_pass_tap = max_pass_tap;
    (* mark_debug = "true" *) logic [8:0] dbg_auto_delay_tap = auto_delay_tap;
    (* mark_debug = "true" *) logic [8:0] dbg_final_delay_tap = final_delay_tap;



    (* mark_debug = "true" *)    wire [63:0] dbg_m_axis_tdata = m_axis_tdata;
    (* mark_debug = "true" *)    wire [7:0] dbg_m_axis_tkeep = m_axis_tkeep;
    (* mark_debug = "true" *)    wire dbg_m_axis_tvalid = m_axis_tvalid;
    (* mark_debug = "true" *)    wire dbg_m_axis_tlast = m_axis_tlast; 
    (* mark_debug = "true" *)    wire dbg_m_axis_tready = m_axis_tready;


    // // VIO signals
    // (* mark_debug = "true" *) wire vio_manual_tap_en;
    // (* mark_debug = "true" *) wire vio_force_training_done;
    // (* mark_debug = "true" *) wire vio_load;
    // (* mark_debug = "true" *) wire [8:0] vio_delay_tap;
    // (* mark_debug = "true" *) logic [8:0] final_delay_tap = 9'd0;
    // (* mark_debug = "true" *) logic final_load = 1'b0;

endmodule
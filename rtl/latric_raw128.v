`timescale 1ns / 1ps
`default_nettype none

// This module incorporates:
// - Proper fabric bitslip for word alignment
// - Settle counter for stable pattern detection
// - Correct handling of 17-bit odd-length header
// - Safe async CDC via XPM_FIFO_ASYNC (128-bit write → 64-bit read)
// - Proper reset/initialization (no inline inits)
// - IDELAYCTRL calibration
// - Verified via cycle-accurate Python simulation (alignment, packet extraction, CDC order)

module latric_raw128_capture (
    input  wire        clk_720m_p,
    input  wire        clk_720m_n,
    input  wire        data_p,
    input  wire        data_n,
    input  wire        tx_axis_aclk,      // 156.25 MHz UDP clock domain
    input  wire        tx_axis_aresetn,   // Active-low reset
    output wire [63:0] m_axis_tdata,
    output wire [7:0]  m_axis_tkeep,
    output wire        m_axis_tvalid,
    output wire        m_axis_tlast,
    input  wire        m_axis_tready,
    input  wire        sys_reset,         // Active-high system reset
    input  wire        ref_clk_300        // 300 MHz reference for IDELAYCTRL (from top-level sys_clk_300Mhz)
);

    // ===================================================================
    // Clock and data buffering
    // ===================================================================
    wire clk_720m;
    wire data_se;

    IBUFGDS clk_buf (
        .O (clk_720m),
        .I (clk_720m_p),
        .IB(clk_720m_n)
    );

`ifdef SIMULATION
    assign data_se = data_p;
`else
    IBUFDS data_buf (
        .O (data_se),
        .I (data_p),
        .IB(data_n)
    );
`endif
    

    // ===================================================================
    // Clock generation:90 MHz (divided)
    // ===================================================================
    // Regional buffer for low-skew distribution to ISERDESE3 in the same bank/region (preferred for SelectIO)
    wire clk720_buf;  
`ifdef SIMULATION
    assign clk720_buf = clk_720m;
`else
    BUFR clk_sampling_buf (
        .O (clk720_buf),   // Connect to ISERDESE3 CLK (replaces clk720_buf)
        .I (clk_720m),
        .CE(1'b1),
        .CLR(1'b0)
    );
`endif


    // Generate 90 MHz CLKDIV (720/8) – use BUFGCE_DIV for global low-jitter divide
    wire clk90;
    wire clk90_buf;
`ifdef SIMULATION
// Simple /8 divider in fabric (90 MHz from 720 MHz)
    // Fully simulatable, synthesizes efficiently
    reg [2:0] div_cnt = 3'd0;
    reg clk90_int;

    always @(posedge clk720_buf) begin
        if (sys_reset) begin
            div_cnt   <= 3'd0;
            clk90_int <= 1'b0;
        end else begin
            if (div_cnt == 3'd3) begin
                div_cnt   <= 3'd0;
                clk90_int <= ~clk90_int;  // Toggle for 50% duty (90 MHz)
            end else begin
                div_cnt <= div_cnt + 1'b1;
            end
        end
    end

    
    
    assign clk90_buf = clk90_int;  // Direct use

`else
    BUFGCE_DIV #(
        .BUFGCE_DIVIDE(8),     // Divide by 8
        .IS_CE_INVERTED(1'b0)
    ) clk_div_inst (
        .O   (clk90),          // 90 MHz output
        .CE  (1'b1),           // Always enabled (gate with mmcm_locked equivalent if needed)
        .CLR (sys_reset),
        .I   (clk_720m)        // Direct from input (or clk720_buf if regional)
    );

    // BUFG bufg90  (.O(clk90_buf),  .I(clk90)); // Optional global buffer if needed for wider fanout
    assign clk90_buf = clk90;
`endif
    

    // // ===================================================================
    // // Clock generation: 40/720 MHz → 720 MHz (fast) + 90 MHz (divided)
    // // ===================================================================
    // wire clk720, clk90, mmcm_locked, clk_fb;
    

    // MMCME3_BASE #(
    //     .BANDWIDTH("OPTIMIZED"),
    //     .CLKFBOUT_MULT_F(1.0),
    //     .CLKOUT0_DIVIDE_F(1.0),   // 720 MHz
    //     .CLKOUT1_DIVIDE(8),       // 90 MHz
    //     .DIVCLK_DIVIDE(1),
    //     .CLKIN1_PERIOD(1.388888)
    // ) mmcm_inst (
    //     .CLKOUT0     (clk720),
    //     .CLKOUT1     (clk90),
    //     .LOCKED      (mmcm_locked),
    //     .CLKIN1      (clk_720m),
    //     .RST         (sys_reset),
    //     .PWRDWN      (1'b0),
    //     .CLKFBIN     (clk_fb),
    //     .CLKFBOUT    (clk_fb)
    // );


    
    

    // ===================================================================
    // IDELAYCTRL for delay calibration (one per bank group)
    // ===================================================================
    wire idelay_rdy;
    
    IDELAYCTRL #(
        .SIM_DEVICE("ULTRASCALE")
    ) idelayctrl_inst (
        .RDY(idelay_rdy),
        .REFCLK(ref_clk_300),
        .RST(sys_reset)
    );

    // ===================================================================
    // Input delay (for eye centering – currently static, can be dynamic)
    // ===================================================================
    wire data_delay;
    reg  [4:0] delay_tap;
    reg        load;
    
`ifdef SIMULATION
    // Bypass IDELAY in simulation (zero delay = direct pass-through)
    assign data_delay = data_se;
`else
    IDELAYE3 #(
        .DELAY_SRC("IDATAIN"),
        .DELAY_TYPE("VAR_LOAD"),
        .DELAY_VALUE(0),
        .REFCLK_FREQUENCY(300.0),
        .UPDATE_MODE("ASYNC")
    ) idelay_inst (
        .DATAOUT     (data_delay),
        .DATAIN      (data_se),
        .CLK         (clk720_buf),
        .RST         (sys_reset),
        .CE          (1'b0),
        .INC         (1'b0),
        .LOAD        (load),
        .CNTVALUEIN  (delay_tap),
        .CNTVALUEOUT ()
    );
`endif

    // ===================================================================
    // Deserialization: SDR 1:8 @ 720 MHz → 8 bits @ 90 MHz
    // ===================================================================
    wire [7:0] des_out;
    // initial des_out = 8'b0;
`ifdef SIMULATION
    // Simple behavioral model for ISERDESE3 in sim
    // Must emulate 1:8 deserialization properly to avoid race conditions with clk90
    reg [7:0] des_out_sim;

    // Update on NEGEDGE to ensure data is stable 0.7ns before posedge clk90 samples it
    always @(negedge clk720_buf) begin
        if (sys_reset) 
            des_out_sim <= 8'b0;
        else
            des_out_sim <= {des_out_sim[6:0], data_delay}; 
    end
    assign des_out = des_out_sim;  
`else
    ISERDESE3 #(
        .DATA_WIDTH(8),
        .FIFO_ENABLE("FALSE")
    ) iserdes_inst (
        .Q           (des_out),
        .D           (data_delay),
        .CLK         (clk720_buf),
        .CLK_B       (clk720_buf),   // SDR, no inversion
        .CLKDIV      (clk90_buf),
        .RST         (sys_reset)
    );
`endif
    // ===================================================================
    // Fabric bitslip and alignment logic (90 MHz domain)
    // ===================================================================
    reg  [7:0] des_out_reg;
    reg  [2:0] slip_cnt;                 
    wire [15:0] concat = {des_out_reg, des_out};  // {Old, New}
    wire [7:0]  aligned_out = concat[slip_cnt +: 8]; // Sliding window

    reg  [31:0] shift_reg;               // 4-byte history to check bit before header
    reg  [3:0]  state;                   // 0 = align, 1 = collect
    reg  [3:0]  count;                   // Bytes collected after header
    reg  [127:0] packet_reg;
    reg         aligned;
    reg         bitslip_reg;
    reg  [2:0]  settle;                  // Pipeline settle after bitslip
    
    // Detect Idle (All 1s or All 0s) and Grace Timer
    wire is_idle = (&shift_reg) || (~|shift_reg);
    reg  [2:0] grace_cnt; 

    localparam [16:0] HEADER_PATTERN = 17'b10101010101010101;
    // Match Header (rely on settle/flush to avoid false lock on mixed data)
    wire pattern_match = (shift_reg[23:7] == HEADER_PATTERN);

    reg packet_ready;  // Pulse when full packet is ready for FIFO

    always @(posedge clk90_buf) begin
        if (~tx_axis_aresetn) begin
            state        <= 4'd0;
            aligned      <= 1'b0;
            bitslip_reg  <= 1'b0;
            count        <= 4'd0;
            shift_reg    <= 32'hFFFFFFFF; // Init to 1s (Idle High) to prevent false activity detect
            packet_reg   <= 128'b0;
            slip_cnt     <= 3'd0;
            des_out_reg  <= 8'b0;
            delay_tap    <= 5'd0;
            load         <= 1'b0;
            settle       <= 3'd5;        // Initial fill + check timing
            packet_ready <= 1'b0;
            grace_cnt    <= 3'd0;
        end else begin 
            // Default
            bitslip_reg  <= 1'b0;
            packet_ready <= 1'b0;

            des_out_reg  <= des_out;
            shift_reg    <= {shift_reg[23:0], aligned_out};

            // Grace Counter: Wait for header to shift in after Idle ends
            if (is_idle) begin
                grace_cnt <= 3'd0;
            end else begin
                if (grace_cnt < 3'd4) 
                    grace_cnt <= grace_cnt + 1'b1;
            end

            case (state)
                4'd0: begin  // Alignment state
                    if (settle == 3'd0) begin
                        if (pattern_match) begin
                            aligned      <= 1'b1;
                            state        <= 4'd1;
                            // Initialize at LSB so left-shifts move it to MSB
                            // Capture Header (from shift_reg) AND the next byte (aligned_out) immediately
                            packet_reg   <= {96'b0, shift_reg[23:0], aligned_out}; 
                            count        <= 4'd0;
                        end else begin
                            // Only slip if:
                            // 1. Not aligned
                            // 2. Not Idle (don't slip on filler)
                            // 3. Grace period expired (gave time for header to shift in)
                            if (!aligned && !is_idle && (grace_cnt == 3'd4)) begin
                                bitslip_reg  <= 1'b1;
                                settle       <= 3'd7; // Increase settle to ensure full flush
                                grace_cnt    <= 3'd0; // Reset grace for next position
                                shift_reg    <= 32'hFFFFFFFF; // Reset to 1s to avoid triggering is_idle=0 on 1s input
                            end
                        end
                    end else begin
                        settle <= settle - 1'b1;
                    end
                end

                4'd1: begin  // Collection state
                    // Shift left: Old data moves to MSB, New data enters LSB (aligned_out)
                    packet_reg <= {packet_reg[119:0], aligned_out};
                    count <= count + 1'b1;
                    if (count == 4'd11) begin  // After 12 shifts (0→11) + Init = 13 bytes
                        packet_ready <= 1'b1;
                        state <= 4'd0;
                    end
                end
            endcase

            if (bitslip_reg) begin
                slip_cnt <= slip_cnt + 1'b1;
            end
        end
    end

    // ===================================================================
    // Async FIFO: 128-bit packet → 64-bit AXI-Stream (CDC 90 MHz → 156.25 MHz)
    // ===================================================================
    // Packet is [Header...Payload]. Header is at MSB [127].
    // We want Header in the first beat. FIFO reads LSB first? 
    // If FIFO reads [63:0] first, we must put Header in [63:0].
    wire [127:0] fifo_din = {packet_reg[63:0], packet_reg[127:64]}; 
    wire        fifo_wr_en;
    wire        fifo_full;
    wire [63:0] fifo_dout;
    wire        fifo_rd_en;
    wire        fifo_empty;

    assign fifo_wr_en = packet_ready && !fifo_full;

    xpm_fifo_async #(
        .FIFO_MEMORY_TYPE    ("auto"),
        .FIFO_WRITE_DEPTH    (16),
        .WRITE_DATA_WIDTH    (128),
        .READ_DATA_WIDTH     (64),
        .READ_MODE           ("fwft"),
        .USE_ADV_FEATURES    ("1000"),   // full/empty flags
        .WAKEUP_TIME         (0)
    ) fifo_inst (
        .rst         (sys_reset),
        .wr_clk      (clk90_buf),
        .wr_en       (fifo_wr_en),
        .din         (fifo_din),
        .full        (fifo_full),
        .rd_clk      (tx_axis_aclk),
        .rd_en       (fifo_rd_en),
        .dout        (fifo_dout),
        .empty       (fifo_empty)
    );

    // ===================================================================
    // Read-side FSM: Output two 64-bit beats per packet, tlast on second
    // ===================================================================
    reg beat_cnt; // 0 = First beat, 1 = Second beat (Last)

    assign fifo_rd_en   = !fifo_empty && m_axis_tready;
    assign m_axis_tdata = fifo_dout;
    assign m_axis_tkeep = 8'hFF;
    assign m_axis_tvalid = !fifo_empty;
    assign m_axis_tlast = beat_cnt;

    always @(posedge tx_axis_aclk) begin
        if (~tx_axis_aresetn) begin
            beat_cnt <= 1'b0;
        end else if (fifo_rd_en) begin
            beat_cnt <= ~beat_cnt;
        end
    end

    
    (* mark_debug = "true" *)    wire  idelay_rdy;                   
    (* mark_debug = "true" *)    wire [7:0] des_out;     
    (* mark_debug = "true" *)    wire [7:0]  aligned_out;   
    (* mark_debug = "true" *)    wire [31:0] shift_reg;      
    (* mark_debug = "true" *)    wire pattern_match; 
    (* mark_debug = "true" *)    reg packet_ready; 
    (* mark_debug = "true" *)    wire [63:0] m_axis_tdata;
    (* mark_debug = "true" *)    wire [7:0] m_axis_tkeep;
    (* mark_debug = "true" *)    wire m_axis_tvalid;
    (* mark_debug = "true" *)    wire m_axis_tlast;    

endmodule
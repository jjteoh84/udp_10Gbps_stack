`default_nettype none
`timescale 1ns / 1ps

module payload_generator (

    input  wire        aclk,
    input  wire        aresetn,

    input  wire        enable,
    

    input  wire        reg_wr_en,             // register map for external read/writes
    input  wire [7:0]  reg_addr,
    input  reg [31:0]  reg_wdata,
    input  wire        reg_rd_en,
    output reg [31:0]  reg_rdata,
    output reg         reg_ack,

    output reg  [63:0] m_axis_tdata,
    output reg  [7:0]  m_axis_tkeep,
    output reg         m_axis_tvalid,
    output reg         m_axis_tlast,
    input  wire        m_axis_tready,
    output reg [15:0]  beat
);


    reg [3:0]  mode = 4'd1;                   // 4-bit mode select
    reg [15:0] cfg_pkt_len_bytes = 16'd24;      // payload length in bytes
    reg [31:0] cfg_ipg_cycles = 32'd0;         // inter-packet gap in clock cycles
    reg [31:0] cfg_total_packets = 32'd0;      // 0 = infinite


    
    // ===================================================================
    // Mode definition
    // ===================================================================
    localparam [3:0]
        MODE_IDLE          = 4'd0,
        MODE_FIXED_HELLO   = 4'd1,   // "Hello from FPGA" + counter
        MODE_INC64         = 4'd2,   // pure incrementing counter (throughput)
        MODE_PRBS31        = 4'd3,   // true PRBS-31
        MODE_STABILITY     = 4'd4,   // seq + timestamp + ports
        MODE_SWEEP_LEN     = 4'd5,   // 64 → 9000 → 64...
        MODE_RANDOM_GAP    = 4'd6,
        MODE_MIN_IPG       = 4'd7,   // exactly 12 cycles IPG
        MODE_JUMBO_B2B     = 4'd8,
        MODE_TINY_B2B      = 4'd9;

    // ===================================================================
    // State registers
    // ===================================================================
    localparam [26:0] PKT_INTERVAL = 27'd15_625_000;  // ~100 ms at 156.25 MHz
    reg [63:0]  data_cntr   = 0;
    reg [63:0]  seq_num     = 0;
    reg [63:0]  timestamp   = 0;
    reg [31:0]  pkt_sent    = 0;
    //     reg [15:0]  beat        = 0;
    reg [31:0]  gap_cnt     = 0;
    reg         pkt_active  = 0;
    reg         pkt_done   = 0;
    
    reg [15:0]  sweep_bytes = 64; // Length sweep

    // Derived signals
    wire [15:0] pkt_len_bytes = (mode == MODE_FIXED_HELLO) ? 16'd24 :          // force 32-byte hello packet
                                        (mode == MODE_SWEEP_LEN)   ? sweep_bytes : cfg_pkt_len_bytes;
    wire [15:0] beats_per_pkt = (pkt_len_bytes + 7) >> 3;
    wire        is_last_beat  = (beat == beats_per_pkt - 1);
    wire        transfer      = m_axis_tready;

    // PRBS-31 (31-bit, taps 31+28)
    reg [30:0] prbs = 31'h7fffffff;
    always @(posedge aclk)
        if (!aresetn) prbs <= 31'h7fffffff;
        else if (transfer && mode == MODE_PRBS31)
            prbs <= {prbs[29:0], prbs[30] ^ prbs[27]};
    wire [63:0] prbs64 = {prbs, prbs, prbs[30:3]};


    always @(posedge aclk) begin
        if (!aresetn) begin
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
            m_axis_tkeep  <= 8'hFF;
            m_axis_tdata  <= 0;
            reg_ack       <= 0;
            reg_rdata     <= 32'hDEADBEEF;

            mode              <= 4'd1;
            cfg_pkt_len_bytes <= 16'd24;
            cfg_ipg_cycles    <= 0;
            cfg_total_packets <= 0;
        
            pkt_active    <= 0;
            beat          <= 0;
            gap_cnt       <= 0;
            pkt_sent      <= 0;
            seq_num       <= 0;
            data_cntr     <= 0;
            timestamp     <= 0;
            sweep_bytes   <= 64;
        end else begin
            

            // ========================================
            // 1. AXI-Lite over UDP Register interface 
            // ========================================
            if (reg_wr_en) begin
                case (reg_addr)
                    8'd0: mode              <= reg_wdata[3:0];
                    8'd1: cfg_pkt_len_bytes <= reg_wdata[15:0];
                    8'd2: cfg_ipg_cycles    <= reg_wdata;
                    8'd3: cfg_total_packets <= reg_wdata;
                    8'd4: begin
                        seq_num   <= 0;
                        pkt_sent  <= 0;
                        data_cntr <= 0;
                    end
                endcase
            end

            if (reg_rd_en) begin
                case (reg_addr)
                    8'd0:  reg_rdata <= {28'd0, mode};
                    8'd1:  reg_rdata <= {16'd0, cfg_pkt_len_bytes};
                    8'd2:  reg_rdata <= cfg_ipg_cycles;
                    8'd3:  reg_rdata <= cfg_total_packets;
                    8'd10: reg_rdata <= pkt_sent;
                    8'd11: reg_rdata <= seq_num[31:0];
                    8'd12: reg_rdata <= seq_num[63:32];
                    default: reg_rdata <= 32'hFEEDFACE;
                endcase
                reg_ack <= 1;
            end



            // ========================================
            // 2. Normal operation (only if enabled)
            // ========================================
            if (enable && (cfg_total_packets == 0 || pkt_sent < cfg_total_packets)) begin
                // Timer
                if (timestamp == PKT_INTERVAL - 1 && mode == MODE_FIXED_HELLO)begin
                    timestamp <= 0;
                    beat <= 0;

                end else  timestamp <= timestamp + 1'b1;
            

                // Default outputs
                m_axis_tvalid <= 0;
                m_axis_tlast  <= 0;
                m_axis_tkeep  <= 8'hFF;

            

                // ===========================================================
                // Gap counter - decrements every cycle when not sending
                // ===========================================================
                if (gap_cnt != 0) begin
                    gap_cnt <= gap_cnt - 1;
                end

                // ===========================================================
                // Start new packet 
                // ===========================================================
                if (!pkt_active && gap_cnt == 0 && mode != MODE_FIXED_HELLO) begin
                    pkt_active <= 1;
                    beat       <= 0;
                end

                 if (!pkt_active && timestamp == PKT_INTERVAL - 1 && mode == MODE_FIXED_HELLO)  begin
                    pkt_active <= 1'b1;
                    beat       <= 0;
                end
            
                // ===========================================================
                // Transmit beats
                // ===========================================================
                if (pkt_active && transfer)  begin
                    m_axis_tvalid <= 1;
                    m_axis_tlast  <= is_last_beat;
                    beat <= beat + 1;

                    // Payload mux
                    case (mode)
                        MODE_FIXED_HELLO:
                            case (beat)
                                0: m_axis_tdata <= 64'h48656c6c_6f206672; // "Hello fr" 64'h48656c6c_6f206672;
                                1: m_axis_tdata <= 64'h6f6d2046_50474120; // "om FPGA " 64'h6f6d2046_50474120;
                                2: m_axis_tdata <= {32'd0, pkt_sent};
                                default: m_axis_tdata <= 64'h0000_0000_0000_0000;
                            endcase

                        MODE_INC64:
                            m_axis_tdata <= data_cntr + beat;

                        MODE_PRBS31:
                            m_axis_tdata <= prbs64;

                        MODE_STABILITY: case (beat[3:0])
                            0: m_axis_tdata <= 64'hfedcba98_76543210;
                            1: m_axis_tdata <= seq_num;
                            2: m_axis_tdata <= timestamp;
                            3: m_axis_tdata <= 64'h00000780_00008080; // dst/src port
                            default: m_axis_tdata <= data_cntr + beat;
                        endcase

                        default:
                            m_axis_tdata <= data_cntr + beat;
                    endcase
                  

                    if (is_last_beat) begin
                        pkt_active <= 0;
                        pkt_sent   <= pkt_sent + 1;
                        seq_num    <= seq_num + 1;
                        data_cntr  <= data_cntr + beats_per_pkt;

                        // tkeep for last beat if not multiple of 8 bytes
                        case (pkt_len_bytes[2:0])
                            3'd0: m_axis_tkeep <= 8'hFF;
                            3'd1: m_axis_tkeep <= 8'h01;
                            3'd2: m_axis_tkeep <= 8'h03;
                            3'd3: m_axis_tkeep <= 8'h07;
                            3'd4: m_axis_tkeep <= 8'h0F;
                            3'd5: m_axis_tkeep <= 8'h1F;
                            3'd6: m_axis_tkeep <= 8'h3F;
                            3'd7: m_axis_tkeep <= 8'h7F;
                        endcase


                        // Length sweep
                        if (mode == MODE_SWEEP_LEN) begin
                            sweep_bytes <= (sweep_bytes >= 9000) ? 64 : sweep_bytes + 128;
                        end

                        // *** THIS IS THE CRITICAL FIX ***
                        // Set next gap based on mode
                        case (mode)
                            MODE_RANDOM_GAP: gap_cnt <= $urandom % 1000;
                            MODE_MIN_IPG:    gap_cnt <= 12;
                            MODE_JUMBO_B2B,
                            MODE_TINY_B2B,
                            MODE_INC64:      gap_cnt <= 0;                    // back-to-back
                            default:         gap_cnt <= cfg_ipg_cycles;
                        endcase
                    end
                    
                end
            end
        end
    end


(* mark_debug = "true" *)    reg [3:0]  mode;                   // 4-bit mode select
(* mark_debug = "true" *)    reg [15:0] cfg_pkt_len_bytes;      // payload length in bytes
(* mark_debug = "true" *)    reg [31:0] cfg_ipg_cycles;         // inter-packet gap in clock cycles
(* mark_debug = "true" *)    reg [31:0] cfg_total_packets; 

//reg [31:0] pkt_cnt    = 32'd0;
//reg [2:0]  beat       = 3'd0;        // 0-3
//reg        pkt_active = 1'b0;
//reg [26:0] timer      = 27'd0;

//localparam [26:0] PKT_INTERVAL = 27'd15_625_000;  // ~100 ms at 156.25 MHz

//always @(posedge aclk or negedge aresetn) begin
//    if (!aresetn) begin
//        timer      <= 0;
//        pkt_active <= 0;
//        beat       <= 0;
//        pkt_cnt    <= 0;
//    end else if (enable) begin
//        // Timer
//        if (timer == PKT_INTERVAL - 1) timer <= 0;
//        else                           timer <= timer + 1'b1;

//        // Start new packet
//        if (!pkt_active && timer == PKT_INTERVAL - 1) begin
//            pkt_active <= 1'b1;
//            beat       <= 0;
//            pkt_cnt    <= pkt_cnt + 1'b1;
//        end
//        // Advance on tready
//        else if (pkt_active && m_axis_tready) begin
//            if (beat == 3) pkt_active <= 0;
//            beat <= beat + 1'b1;
//        end
//    end
//end

//// ── Payload: 32 bytes exactly ───────────────────────────────────────
//// "Hello from FPGA PKT: 00000000" 
//reg [63:0] payload ;
//always @(*) begin
//    case (beat) 
//        2'd0: payload = 64'h72_66_20_6f_6c_6c_65_48;  // "Hello fr"
//        2'd1: payload = 64'h20_41_47_50_46_20_6d_6f;  // "om FPGA "
//        2'd2: payload = 64'h30_30_30_20_3a_54_4b_50;  // "PKT: 000"  
//        2'd3: payload = 64'h30_30_30_30_30_30_30_30;  // "00000000"
//        default: payload = 64'h0;
//    endcase
//end

//assign m_axis_tdata = payload;
//assign m_axis_tkeep = 8'hFF;
//assign m_axis_tvalid = pkt_active;
//assign m_axis_tlast = pkt_active && (beat == 3) && m_axis_tready;    

endmodule
`timescale 1ns/1ps
module axi4lite_udp_server #(
    parameter UDP_PORT = 16'hC0DE
)(
    input  wire        clk,
    input  wire        rst_n,

    // UDP RX AXI-Stream (from UDP/IP stack)
    input  wire [63:0] s_axis_rx_tdata,
    input  wire [7:0]  s_axis_rx_tkeep,
    input  wire        s_axis_rx_tvalid,
    input  wire        s_axis_rx_tlast,
    output wire        s_axis_rx_tready,

    // UDP TX AXI-Stream (to UDP/IP stack)
    output reg  [63:0] m_axis_tx_tdata  = 0,
    output reg  [7:0]  m_axis_tx_tkeep  = 0,
    output reg         m_axis_tx_tvalid = 0,
    output reg         m_axis_tx_tlast  = 0,
    input  wire        m_axis_tx_tready,

    // AXI-Lite register interface
    output reg         reg_wr_en     = 0,
    output reg  [15:0] reg_addr      = 0,   // Now 16-bit address
    output reg  [31:0] reg_wdata     = 0,
    output reg         reg_rd_en     = 0,
    input  wire [31:0] reg_rdata,
    input  wire        reg_ack       // pulse when read data valid
);

    assign s_axis_rx_tready = 1'b1;  // always ready - backpressure handled upstream

    // ===================================================================
    // CRC16-CCITT (x^16 + x^12 + x^5 + 1), prepared but commented out
    // ===================================================================
    /*
    function automatic [15:0] crc16_ccitt;
        input [47:0] data;  // 6 bytes = 48 bits
        reg [15:0] crc;
        integer i;
        begin
            crc = 16'hFFFF;
            for (i = 0; i < 48; i = i + 1) begin
                crc = crc ^ {data[47-i], 15'b0};
                crc = crc[0] ? (crc >> 1) ^ 16'h1021 : crc >> 1;
            end
            crc16_ccitt = crc;
        end
    endfunction
    */

    // ===================================================================
    // State machine to parse UDP payload across multiple beats
    // ===================================================================
    localparam IDLE        = 2'd0;
    localparam COLLECT_6   = 2'd1;
    localparam WAIT_ACK    = 2'd2;

    reg [1:0]  state = IDLE;
    reg [15:0] addr_buf;
    reg [31:0] data_buf;
    reg [7:0]  byte_count;  // how many payload bytes collected after magic
    reg [47:0] payload_bytes;  // collected 6 bytes after 0xC0DE

    always @(posedge clk) begin
        if (!rst_n) begin
            state         <= IDLE;
            reg_wr_en     <= 0;
            reg_rd_en     <= 0;
            reg_addr      <= 0;
            reg_wdata     <= 0;
            m_axis_tx_tvalid <= 0;
            byte_count    <= 0;
            payload_bytes <= 0;
        end else begin
            // Default: clear strobes
            reg_wr_en <= 0;
            reg_rd_en <= 0;
            m_axis_tx_tvalid <= 0;

            if (m_axis_tx_tvalid && m_axis_tx_tready) begin
                m_axis_tx_tvalid <= 0;
            end

            case (state)
                IDLE: begin
                    byte_count <= 0;
                    if (s_axis_rx_tvalid) begin
                        // Scan all possible 16-bit alignments in this beat for 0xC0DE (big-endian)
                        if      (s_axis_rx_tkeep[1] && s_axis_rx_tdata[15:0]   == UDP_PORT) begin
                            byte_count <= (s_axis_rx_tkeep[7] ? 6 : (8 - 2));  // bytes left in beat
                            payload_bytes[47:40] <= s_axis_rx_tdata[23:16];
                            payload_bytes[39:32] <= s_axis_rx_tdata[31:24];
                            payload_bytes[31:24] <= s_axis_rx_tdata[39:32];
                            payload_bytes[23:16] <= s_axis_rx_tdata[47:40];
                            payload_bytes[15:8]  <= s_axis_rx_tdata[55:48];
                            payload_bytes[7:0]   <= s_axis_rx_tdata[63:56];
                            state <= (byte_count >= 6) ? COLLECT_6 : COLLECT_6;
                        end
                        else if (s_axis_rx_tkeep[3] && s_axis_rx_tdata[31:16]  == UDP_PORT) begin
                            byte_count <= (s_axis_rx_tkeep[7] ? 5 : (8 - 4));
                            payload_bytes[39:32] <= s_axis_rx_tdata[39:32];
                            payload_bytes[31:24] <= s_axis_rx_tdata[47:40];
                            payload_bytes[23:16] <= s_axis_rx_tdata[55:48];
                            payload_bytes[15:8]  <= s_axis_rx_tdata[63:56];
                            state <= COLLECT_6;
                        end
                        else if (s_axis_rx_tkeep[5] && s_axis_rx_tdata[47:32]  == UDP_PORT) begin
                            byte_count <= (s_axis_rx_tkeep[7] ? 4 : (8 - 6));
                            payload_bytes[31:24] <= s_axis_rx_tdata[55:48];
                            payload_bytes[23:16] <= s_axis_rx_tdata[63:56];
                            state <= COLLECT_6;
                        end
                        else if (s_axis_rx_tkeep[7] && s_axis_rx_tdata[63:48]  == UDP_PORT) begin
                            byte_count <= 3;
                            state <= COLLECT_6;
                        end
                    end
                end

                COLLECT_6: begin
                    if (s_axis_rx_tvalid) begin
                        reg [7:0] bytes_this_beat = 0;
                        case (byte_count)
                            0: bytes_this_beat = 6;
                            1: bytes_this_beat = 5;
                            2: bytes_this_beat = 4;
                            3: bytes_this_beat = 3;
                            4: bytes_this_beat = 2;
                            5: bytes_this_beat = 1;
                            default: bytes_this_beat = 6;
                        endcase

                        // Shift in new bytes (big-endian order)
                        if (s_axis_rx_tkeep[0]) payload_bytes[47:40] <= s_axis_rx_tdata[15:8];
                        if (s_axis_rx_tkeep[1]) payload_bytes[39:32] <= s_axis_rx_tdata[23:16];
                        if (s_axis_rx_tkeep[2]) payload_bytes[31:24] <= s_axis_rx_tdata[31:24];
                        if (s_axis_rx_tkeep[3]) payload_bytes[23:16] <= s_axis_rx_tdata[39:32];
                        if (s_axis_rx_tkeep[4]) payload_bytes[15:8]  <= s_axis_rx_tdata[47:40];
                        if (s_axis_rx_tkeep[5]) payload_bytes[7:0]   <= s_axis_rx_tdata[55:48];
                        if (s_axis_rx_tkeep[6]) payload_bytes[47:8]  <= s_axis_rx_tdata[63:24]; // shift left

                        byte_count <= byte_count + bytes_this_beat;

                        if (byte_count + bytes_this_beat >= 6) begin
                            // Extract final payload
                            addr_buf <= {payload_bytes[45:38], payload_bytes[37:30]}; // BE → 16-bit addr
                            data_buf <= {payload_bytes[29:22], payload_bytes[21:14],
                                         payload_bytes[13:6],  payload_bytes[5:0]};   // BE-byte BE → LE

                            if (data_buf != 32'h0000_0000)
                                reg_wr_en <= 1;
                            else
                                reg_rd_en <= 1;

                            reg_addr  <= addr_buf;
                            reg_wdata <= data_buf;

                            state <= WAIT_ACK;
                        end
                    end
                end

                WAIT_ACK: begin
                    if (reg_ack) begin
                        // Transmit reply: C0DE | addr | rdata | CRC (later)
                        m_axis_tx_tdata  <= {reg_rdata[7:0],   reg_rdata[15:8],
                                            reg_rdata[23:16], reg_rdata[31:24],
                                            addr_buf[7:0],    addr_buf[15:8],
                                            UDP_PORT, 16'h0000}; // CRC placeholder
                        m_axis_tx_tkeep  <= 8'hFF;
                        m_axis_tx_tvalid <= 1;
                        m_axis_tx_tlast  <= 1;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase

            // Handle tlast to reset on packet end (safety)
            if (s_axis_rx_tvalid && s_axis_rx_tlast)
                if (state != WAIT_ACK) state <= IDLE;
        end
    end

    // Debug signals
    (* mark_debug = "true" *) reg [1:0]  debug_state = state;
    (* mark_debug = "true" *) reg [15:0] debug_addr  = reg_addr;
    (* mark_debug = "true" *) reg [31:0] debug_wdata = reg_wdata;

endmodule
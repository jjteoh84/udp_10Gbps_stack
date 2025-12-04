// axi4lite_udp_server.sv
// AXI-Lite over UDP - for register access
// UDP port: 0xC0DE (49406)
// Packet format (8-byte payload):
//   [15:0] 0xC0DE (magic)
//   [15:0] address[15:0]
//   [31:0] wdata (if write) or 0x00000000 (if read)
//   [15:0] CRC16-CCITT of bytes 0-5
//
// Reply (only on read):
//   [15:0] 0xC0DE
//   [15:0] address
//   [31:0] rdata
//   [15:0] CRC16

`timescale 1ns/1ps
module axi4lite_udp_server #(
    parameter UDP_PORT = 16'hC0DE
)(
    input  wire        clk,
    input  wire        rst_n,

    // UDP RX stream (from your UDP stack)
    input  wire [63:0] s_axis_tdata,
    input  wire [7:0]  s_axis_tkeep,
    input  wire        s_axis_tvalid,
    input  wire        s_axis_tlast,
    output wire        s_axis_tready,

    // UDP TX stream (to your UDP stack)
    output reg  [63:0] m_axis_tdata  = 0,
    output reg  [7:0]  m_axis_tkeep  = 0,
    output reg         m_axis_tvalid = 0,
    output reg         m_axis_tlast  = 0,
    input  wire        m_axis_tready,

    // AXI-Lite register interface (to your payload_generator)
    output reg         reg_wr_en     = 0,
    output reg  [7:0]  reg_addr      = 0,   //(16-bit address = 65k registers) - just change this and adjust the CRC16-CCITT calculation  and the always block below
    output reg  [31:0] reg_wdata     = 0,
    output reg         reg_rd_en     = 0,
    input  wire [31:0] reg_rdata,
    input  wire        reg_ack       // pulse when read data is valid
);

    assign s_axis_tready = 1'b1;  // always ready

    // CRC16-CCITT (x^16 + x^12 + x^5 + 1)
    function automatic [15:0] crc16;
        input [47:0] data;
        reg [15:0] crc;
        integer i;
        begin
            crc = 16'hFFFF;
            for (i = 0; i < 48; i=i+1) begin
                crc = crc ^ {data[47-i], 15'd0};
                crc = crc[0] ? (crc >> 1) ^ 16'h1021 : crc >> 1;
            end
            crc16 = crc;
        end
    endfunction

    reg [2:0] state = 0;
    reg [63:0] pkt;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= 0;
            m_axis_tvalid <= 0;
            reg_wr_en <= 0;
            reg_rd_en <= 0;
        end else begin
            reg_wr_en <= 0;
            reg_rd_en <= 0;
            m_axis_tvalid <= 0;

            // // Example: 16-bit address version
            // if (s_axis_tdata[63:48] == UDP_PORT && s_axis_tkeep == 8'hFF) begin  // 12-byte packet
            //     automatic [79:0] data = s_axis_tdata[79:0];  // adjust bit range
            //     automatic [15:0] crc_calc = crc16(data[79:16]);
            //     if (crc_calc == data[15:0]) begin
            //         reg_addr  <= data[31:16];   // 16-bit address
            //         reg_wdata <= data[63:32];

            if (s_axis_tvalid && s_axis_tkeep[0] && s_axis_tlast) begin
                pkt <= {s_axis_tdata[7:0], s_axis_tdata[15:8], s_axis_tdata[23:16], s_axis_tdata[31:24],
                        s_axis_tdata[39:32], s_axis_tdata[47:40], s_axis_tdata[55:48], s_axis_tdata[63:56]};

                if (s_axis_tdata[63:48] == UDP_PORT && s_axis_tkeep == 8'h0F) begin  // 8-byte packet
                    reg [47:0] data = {s_axis_tdata[15:0], s_axis_tdata[47:16]};
                    reg [15:0] crc_calc = crc16(data);
                    reg [15:0] crc_rcvd = s_axis_tdata[15:0]; //s_axis_tdata[63:48];

                    if (crc_calc == crc_rcvd) begin
                        reg_addr  <= s_axis_tdata[31:24];
                        reg_wdata <= {s_axis_tdata[23:16], s_axis_tdata[15:8], s_axis_tdata[7:0], s_axis_tdata[39:32]}; // byte swap

                        if (s_axis_tdata[47:16] != 0) begin
                            reg_wr_en <= 1;  // write
                        end else begin
                            reg_rd_en <= 1;  // read request
                        end
                    end
                end
            end

            // Reply on read
            if (reg_ack) begin
                reg [47:0] reply_data = {16'hC0DE, reg_addr, 8'h00, reg_rdata[7:0], reg_rdata[15:8], reg_rdata[23:16], reg_rdata[31:24]};
                reg [15:0] crc = crc16(reply_data);

                // m_axis_tdata  <= {crc, reply_data};
                m_axis_tdata  <= {reply_data, crc};
                m_axis_tkeep  <= 8'h0F;
                m_axis_tvalid <= 1;
                m_axis_tlast  <= 1;
            end

            if (m_axis_tvalid && m_axis_tready)
                m_axis_tvalid <= 0;
        end
    end


    (* mark_debug = "true" *) wire [63:0] s_axis_tdata;
    (* mark_debug = "true" *) wire [7:0]  s_axis_tkeep;
    (* mark_debug = "true" *) wire        s_axis_tvalid;
    (* mark_debug = "true" *) wire        s_axis_tlast;

    (* mark_debug = "true" *) reg  [63:0] m_axis_tdata;
    (* mark_debug = "true" *) reg  [7:0]  m_axis_tkeep;
    (* mark_debug = "true" *) reg         m_axis_tvalid;
    (* mark_debug = "true" *) reg         m_axis_tlast;

    (* mark_debug = "true" *) reg         reg_wr_en;
    (* mark_debug = "true" *) reg  [7:0]  reg_addr;   //(16-bit address = 65k registers) - just change this and adjust the CRC16-CCITT calculation  and the always block below
    (* mark_debug = "true" *) reg  [31:0] reg_wdata;
    (* mark_debug = "true" *) reg         reg_rd_en;
    (* mark_debug = "true" *) wire [31:0] reg_rdata;
    
endmodule
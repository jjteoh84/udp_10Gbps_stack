// rtl/loopback_fifo.v
//
// This module contains a simple AXI-Stream FIFO for loopback testing.
// It uses a Xilinx Parameterized Macro (XPM) for the FIFO implementation.
// The FIFO is configured to be wide enough for 10Gbps Ethernet frames.
// It is a common clock FIFO.

`default_nettype none
`timescale 1ns/1ps

module loopback_fifo (
    // Slave side (write to FIFO)
    input  wire        s_aclk,
    input  wire        s_aresetn,
    input  wire [63:0] s_axis_tdata,
    input  wire [7:0]  s_axis_tkeep,
    input  wire        s_axis_tlast,
    input  wire        s_axis_tvalid,

    // Master side (read from FIFO)
    input  wire        m_aclk,
    output wire [63:0] m_axis_tdata,
    output wire [7:0]  m_axis_tkeep,
    output wire        m_axis_tlast,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,

    // Status
    output wire        almost_empty_axis
);

wire s_axis_tready; // FIFO is always ready to accept data, but the upstream module doesn't check it.

xpm_fifo_axis #(
    .CASCADE_HEIGHT(0),
    .CDC_SYNC_STAGES(2),
    .CLOCKING_MODE("common_clock"),
    .ECC_MODE("no_ecc"),
    .FIFO_DEPTH(2048),
    .FIFO_MEMORY_TYPE("auto"),
    .PACKET_FIFO("false"),
    .PROG_EMPTY_THRESH(10),
    .PROG_FULL_THRESH(10),
    .RD_DATA_COUNT_WIDTH(12),
    .RELATED_CLOCKS(0),
    .SIM_ASSERT_CHK(1),
    .TDATA_WIDTH(64),
    .TDEST_WIDTH(1),
    .TID_WIDTH(1),
    .TUSER_WIDTH(1),
    .USE_ADV_FEATURES("1000"),
    .WR_DATA_COUNT_WIDTH(12)
)
xpm_fifo_inst (
    .almost_empty_axis  (almost_empty_axis),
    .almost_full_axis   (),
    .dbiterr_axis       (),
    .m_axis_tdata       (m_axis_tdata),
    .m_axis_tdest       (),
    .m_axis_tid         (),
    .m_axis_tkeep       (m_axis_tkeep),
    .m_axis_tlast       (m_axis_tlast),
    .m_axis_tstrb       (),
    .m_axis_tuser       (),
    .m_axis_tvalid      (m_axis_tvalid),
    .prog_empty_axis    (),
    .prog_full_axis     (),
    .rd_data_count_axis (),
    .s_axis_tready      (s_axis_tready),
    .sbiterr_axis       (),
    .wr_data_count_axis (),
    .injectdbiterr_axis (),
    .injectsbiterr_axis (),
    .m_aclk             (m_aclk),
    .m_axis_tready      (m_axis_tready),
    .s_aclk             (s_aclk),
    .s_aresetn          (s_aresetn),
    .s_axis_tdata       (s_axis_tdata),
    .s_axis_tdest       (),
    .s_axis_tid         (),
    .s_axis_tkeep       (s_axis_tkeep),
    .s_axis_tlast       (s_axis_tlast),
    .s_axis_tstrb       (),
    .s_axis_tuser       (),
    .s_axis_tvalid      (s_axis_tvalid)
);

endmodule

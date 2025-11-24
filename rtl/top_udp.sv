
`default_nettype none
`timescale 1ns/1ps

module top_udp(
    input   wire    gt_refclk_in_p,
    input   wire    gt_refclk_in_n,

    input   wire    sys_reset,

    input   wire    sys_clk_300Mhz_p,
    input   wire    sys_clk_300Mhz_n,

    input   wire    gt_rx_in_p,
    input   wire    gt_rx_in_n,
    output  wire    gt_tx_out_n,
    output  wire    gt_tx_out_p,
    output  wire    si5328_rst,
    output wire sfp0_tx_disable,
    output wire [4:0] led
);


/****************************************************************
 * 10Gbps eth mac and phy interface signals
 *   for xxv_ethernet
 ***************************************************************/
wire [0:0]      rx_core_clk                 ;
wire [0:0]      rx_clk_out                  ;
wire [0:0]      tx_clk_out                  ;

wire [0:0]      gtpowergood                 ;
wire [2:0]      gt_loopback_in              ;

// RX  Control Signals
wire            ctl_rx_test_pattern         ;
wire            ctl_rx_test_pattern_enable  ;
wire            ctl_rx_data_pattern_select  ;
wire            ctl_rx_enable               ;
wire            ctl_rx_delete_fcs           ;
wire            ctl_rx_ignore_fcs           ;
wire [14:0]     ctl_rx_max_packet_len       ;
wire [7:0]      ctl_rx_min_packet_len       ;
wire            ctl_rx_custom_preamble_enable;
wire            ctl_rx_check_sfd            ;
wire            ctl_rx_check_preamble       ;
wire            ctl_rx_process_lfi          ;
wire            ctl_rx_force_resync         ;
//// TX_0 Control Signals
wire            ctl_tx_test_pattern         ;
wire            ctl_tx_test_pattern_enable  ;
wire            ctl_tx_test_pattern_select  ;
wire            ctl_tx_data_pattern_select  ;
wire [57:0]     ctl_tx_test_pattern_seed_a  ;
wire [57:0]     ctl_tx_test_pattern_seed_b  ;
wire            ctl_tx_enable               ;
wire            ctl_tx_fcs_ins_enable       ;
wire [3:0]      ctl_tx_ipg_value            ;
wire            ctl_tx_send_lfi             ;
wire            ctl_tx_send_rfi             ;
wire            ctl_tx_send_idle            ;
wire            ctl_tx_custom_preamble_enable;
wire            ctl_tx_ignore_fcs           ;

wire [3:0]      gtwiz_reset_tx_datapath     ;
wire [3:0]      gtwiz_reset_rx_datapath     ;

wire [2:0]      txoutclksel_in              ;
wire [2:0]      rxoutclksel_in              ;

wire            user_tx_reset               ;
wire            user_rx_reset               ;
wire            gt_refclk_out               ;

/****************************************************************
 * udp stack signals
 *   for 10Gbps stack
 ***************************************************************/
wire            tx_axis_aclk = tx_clk_out;
wire            rx_axis_aclk = rx_clk_out;

wire            tx_axis_aresetn = ~user_tx_reset;
wire            rx_axis_aresetn = ~user_rx_reset;

wire    [31:0]  src_ip_addr = {8'd192,8'd168,8'd1,8'd123};
wire    [31:0]  dst_ip_addr = {8'd192,8'd168,8'd1,8'd101};

wire    [15:0]  udp_src_port=  16'h8080;
wire    [15:0]  udp_dst_port=  16'h8007;

// wire    [47:0]  src_mac_addr = {8'ha0, 8'h36, 8'h9f, 8'h7d, 8'he5, 8'h8c};
wire    [47:0] src_mac_addr = {8'hac, 8'h14, 8'h74, 8'h45, 8'hbc, 8'hf4};

wire            udp_enable          ;

wire    [63:0]  udp_tx_axis_tdata   ;
wire    [7:0]   udp_tx_axis_tkeep   ;
wire            udp_tx_axis_tvalid  ;  
wire            udp_tx_axis_tlast   ;
wire            udp_tx_axis_tready  ;

wire [63:0]     udp_rx_axis_tdata   ;
wire [7:0]     	udp_rx_axis_tkeep   ;
wire            udp_rx_axis_tvalid  ; 		 
wire            udp_rx_axis_tlast   ;
wire            udp_rx_axis_tuser   ;

wire [63:0]     mac_tx_axis_tdata   ;
wire [7:0]      mac_tx_axis_tkeep   ;
wire            mac_tx_axis_tvalid  ;
wire            mac_tx_axis_tlast   ;
wire            mac_tx_axis_tready  ;

wire[63:0]      mac_rx_axis_tdata   ;
wire[7:0]       mac_rx_axis_tkeep   ;
wire            mac_rx_axis_tvalid  ;
wire            mac_rx_axis_tuser   ;
wire            mac_rx_axis_tlast   ;

wire            empty               ;


wire arp_reply_valid;
reg    [47:0]  dst_mac_addr;
reg [79:0] arp_register;
wire arp_reply_req;

// Intermediate wires for FIFO TX outputs (pre-mux)
wire [63:0] fifo_tx_axis_tdata;
wire [7:0]  fifo_tx_axis_tkeep;
wire        fifo_tx_axis_tvalid;
wire        fifo_tx_axis_tlast;
wire        fifo_tx_axis_tready;  // From mux to FIFO

// Wire from UDP stack's tready output (rename for clarity)
wire        udp_stack_tx_axis_tready;


/****************************************************************
 * Convert the 300MHz differential clock to a 300MHz single-ended 
 * clock, which is used for mmcm frequency division
 ***************************************************************/
wire    sys_clk_300Mhz;
    
IBUFGDS #(
    .DIFF_TERM("FALSE"),    // Differential Termination (Virtex-4/5, Spartan-3E/3A)
    .IBUF_DELAY_VALUE("0"), // Specify the amount of added input delay for 
    .IOSTANDARD("DEFAULT")  // Specify the input I/O standard
) IBUFGDS_inst (
    .O  (sys_clk_300Mhz),  // Clock buffer output
    .I  (sys_clk_300Mhz_p),  // Diff_p clock buffer input (connect directly to top-level port)
    .IB (sys_clk_300Mhz_n) // Diff_n clock buffer input (connect directly to top-level port)
);


// /****************************************************************
//  * Convert the 300MHz differential clock to a 156.25MHz single-ended 
//  * clock
//  ***************************************************************/
//  wire clk_out_156m25;
//  wire clk_locked;
//  clk_wiz_0 clock_gen (
//     .clk_in1(sys_clk_300Mhz),
//     .clk_out_156m25 (clk_out_156m25),
//     .reset(sys_reset),
//     .locked(clk_locked)
//  );


/****************************************************************
 * The mmcm module is used to divide the 300MHz single-ended 
 * clock into 100MHz single-ended clocks
 *
 * computational formula:
 *   Fout = (Fin * MULT_F) / (DIVCLK_DIVIDE * CLKOUTn_DIVIDE)
 *   fout = 100MHz ; fin = 300MHz ; MMULT_F = 1;
 *   DIVCLK_DIVIDE = 3; CLKOUTn_DIVIDE = 1;
 ***************************************************************/

wire    sys_clk_100MHz_ibufg;
wire    sys_clk_fb;
wire    sys_clk_100MHz;
wire    mmcm_locked;
MMCME3_BASE #(
   .BANDWIDTH("OPTIMIZED"),    // Jitter programming (HIGH, LOW, OPTIMIZED)
   .CLKFBOUT_MULT_F(10),      // Multiply value for all CLKOUT (2.000-64.000)
   .CLKFBOUT_PHASE(0.0),       // Phase offset in degrees of CLKFB (-360.000-360.000)
   .CLKIN1_PERIOD(3.333),        // Input clock period in ns units, ps resolution (i.e., 33.333 is 30 MHz).
   .CLKOUT0_DIVIDE_F(10),     // Divide amount for CLKOUT0 (1.000-128.000)
   // CLKOUT0_DUTY_CYCLE - CLKOUT6_DUTY_CYCLE: Duty cycle for each CLKOUT (0.001-0.999).
   .CLKOUT0_DUTY_CYCLE(0.5),
   .CLKOUT1_DUTY_CYCLE(0.5),
   .CLKOUT2_DUTY_CYCLE(0.5),
   .CLKOUT3_DUTY_CYCLE(0.5),
   .CLKOUT4_DUTY_CYCLE(0.5),
   .CLKOUT5_DUTY_CYCLE(0.5),
   .CLKOUT6_DUTY_CYCLE(0.5),
   // CLKOUT0_PHASE - CLKOUT6_PHASE: Phase offset for each CLKOUT (-360.000-360.000).
   .CLKOUT0_PHASE(0.0),
   .CLKOUT1_PHASE(0.0),
   .CLKOUT2_PHASE(0.0),
   .CLKOUT3_PHASE(0.0),
   .CLKOUT4_PHASE(0.0),
   .CLKOUT5_PHASE(0.0),
   .CLKOUT6_PHASE(0.0),
   // CLKOUT1_DIVIDE - CLKOUT6_DIVIDE: Divide amount for each CLKOUT (1-128)
   .CLKOUT1_DIVIDE(1),
   .CLKOUT2_DIVIDE(1),
   .CLKOUT3_DIVIDE(1),
   .CLKOUT4_DIVIDE(1),
   .CLKOUT5_DIVIDE(1),
   .CLKOUT6_DIVIDE(1),
   .CLKOUT4_CASCADE("FALSE"),  // Cascade CLKOUT4 counter with CLKOUT6 (FALSE, TRUE)
   .DIVCLK_DIVIDE(3),          // Master division value (1-106)
   // Programmable Inversion Attributes: Specifies built-in programmable inversion on specific pins
   .IS_CLKFBIN_INVERTED(1'b0), // Optional inversion for CLKFBIN
   .IS_CLKIN1_INVERTED(1'b0),  // Optional inversion for CLKIN1
   .IS_PWRDWN_INVERTED(1'b0),  // Optional inversion for PWRDWN
   .IS_RST_INVERTED(1'b0),     // Optional inversion for RST
   .REF_JITTER1(0.0),          // Reference input jitter in UI (0.000-0.999)
   .STARTUP_WAIT("FALSE")      // Delays DONE until MMCM is locked (FALSE, TRUE)
)
MMCME3_BASE_inst (
   // Clock Outputs outputs: User configurable clock outputs
   .CLKOUT0 (sys_clk_100MHz_ibufg),     // 1-bit output: CLKOUT0
   .CLKOUT0B(),   // 1-bit output: Inverted CLKOUT0
   .CLKOUT1 (),     // 1-bit output: CLKOUT1
   .CLKOUT1B(),   // 1-bit output: Inverted CLKOUT1
   .CLKOUT2 (),     // 1-bit output: CLKOUT2
   .CLKOUT2B(),   // 1-bit output: Inverted CLKOUT2
   .CLKOUT3 (),     // 1-bit output: CLKOUT3
   .CLKOUT3B(),   // 1-bit output: Inverted CLKOUT3
   .CLKOUT4 (),     // 1-bit output: CLKOUT4
   .CLKOUT5 (),     // 1-bit output: CLKOUT5
   .CLKOUT6 (),     // 1-bit output: CLKOUT6
   // Feedback outputs: Clock feedback ports
   .CLKFBOUT(sys_clk_fb),   // 1-bit output: Feedback clock
   .CLKFBOUTB(), // 1-bit output: Inverted CLKFBOUT
   // Status Ports outputs: MMCM status ports
   .LOCKED  (mmcm_locked),       // 1-bit output: LOCK
   // Clock Inputs inputs: Clock input
   .CLKIN1  (sys_clk_300Mhz),       // 1-bit input: Clock
   // Control Ports inputs: MMCM control ports
   .PWRDWN  (1'b0),       // 1-bit input: Power-down
   .RST     (sys_reset),             // 1-bit input: Reset
   // Feedback inputs: Clock feedback ports
   .CLKFBIN (sys_clk_fb)      // 1-bit input: Feedback clock
);

BUFG BUFG_inst (
    .O(sys_clk_100MHz),     // Clock buffer output
    .I(sys_clk_100MHz_ibufg)      // Clock buffer input
);


xpm_fifo_axis #(
    .CASCADE_HEIGHT(0),             // DECIMAL
    .CDC_SYNC_STAGES(2),            // DECIMAL
    .CLOCKING_MODE("common_clock"), // String
    .ECC_MODE("no_ecc"),            // String
    .FIFO_DEPTH(2048),              // DECIMAL
    .FIFO_MEMORY_TYPE("auto"),      // String
    .PACKET_FIFO("false"),          // String
    .PROG_EMPTY_THRESH(10),         // DECIMAL
    .PROG_FULL_THRESH(10),          // DECIMAL
    .RD_DATA_COUNT_WIDTH(12),        // DECIMAL
    .RELATED_CLOCKS(0),             // DECIMAL
    .SIM_ASSERT_CHK(1),             // DECIMAL; 0=disable simulation messages, 1=enable simulation messages
    .TDATA_WIDTH(64),               // DECIMAL
    .TDEST_WIDTH(1),                // DECIMAL
    .TID_WIDTH(1),                  // DECIMAL
    .TUSER_WIDTH(1),                // DECIMAL
    .USE_ADV_FEATURES("1000"),      // String
    .WR_DATA_COUNT_WIDTH(12)         // DECIMAL
)

xpm_fifo_udp_data_echo (
    .almost_empty_axis  (empty),   
    .almost_full_axis   (),     
    .dbiterr_axis       (),             
    .m_axis_tdata       (fifo_tx_axis_tdata),             
    .m_axis_tdest       (),             
    .m_axis_tid         (),                 
    .m_axis_tkeep       (fifo_tx_axis_tkeep),             
    .m_axis_tlast       (fifo_tx_axis_tlast),             
    .m_axis_tstrb       (),             
    .m_axis_tuser       (),             
    .m_axis_tvalid      (fifo_tx_axis_tvalid),           
    .prog_empty_axis    (),       
    .prog_full_axis     (),         
    .rd_data_count_axis (), 
    .s_axis_tready      (1'b1),           
    .sbiterr_axis       (),             
    .wr_data_count_axis (), 
    .injectdbiterr_axis (), 
    .injectsbiterr_axis (), 
    .m_aclk             (tx_axis_aclk),                         
    .m_axis_tready      (fifo_tx_axis_tready),           
    .s_aclk             (rx_axis_aclk),                         
    .s_aresetn          (rx_axis_aresetn),                   
    .s_axis_tdata       (udp_rx_axis_tdata),            
    .s_axis_tdest       (),            
    .s_axis_tid         (),                
    .s_axis_tkeep       (udp_rx_axis_tkeep),             
    .s_axis_tlast       (udp_rx_axis_tlast),             
    .s_axis_tstrb       (),             
    .s_axis_tuser       (),             
    .s_axis_tvalid      (udp_rx_axis_tvalid)            
);


udp_stack_top u_udp_stack_top(
    .tx_axis_aclk       	(tx_axis_aclk        ),
    .tx_axis_aresetn    	(tx_axis_aresetn     ),
    .rx_axis_aclk       	(rx_axis_aclk        ),
    .rx_axis_aresetn    	(rx_axis_aresetn     ),
    .src_ip_addr        	(src_ip_addr         ),
    .dst_ip_addr        	(dst_ip_addr         ),
    .src_mac_addr       	(src_mac_addr      ),
    .udp_src_port       	(udp_src_port        ),
    .udp_dst_port       	(udp_dst_port        ),
    .udp_enable         	(udp_enable          ),
    .arp_reply_req          (arp_reply_req),
    // .arp_request_req        (arp_boot_req),  
    // .arp_request_ack        (arp_request_ack),
    .udp_tx_axis_tdata  	(udp_tx_axis_tdata   ), 
    .udp_tx_axis_tkeep  	(udp_tx_axis_tkeep   ),
    .udp_tx_axis_tvalid 	(udp_tx_axis_tvalid  ),
    .udp_tx_axis_tlast  	(udp_tx_axis_tlast   ),
    .udp_tx_axis_tready 	(udp_stack_tx_axis_tready  ),
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
    .mac_rx_axis_tlast  	(mac_rx_axis_tlast   ),
    .arp_reply_valid        (arp_reply_valid),
    .dst_mac_addr           (dst_mac_addr),
    .arp_register (arp_register)
);

// Minimal Payload Generator: Adapted from tb_udp_tx.v stimulus
// Bursts: 10 beats full (incr data), 20 beats full, 2 beats partial (tkeep=0x0F)
// Trigger: Post-reset (one-shot) or timer (~1s @100MHz)
// Muxes with echo FIFO (sel=1 for gen; tie low for echo-only)

//localparam [2:0] GEN_IDLE     = 3'b000;
//localparam [2:0] GEN_BURST1   = 3'b001;  // 9+1 full beats
//localparam [2:0] GEN_BURST2   = 3'b010;  // 19+1 full beats
//localparam [2:0] GEN_BURST3   = 3'b011;  // 1+1 partial
//localparam [2:0] GEN_TIMER    = 3'b100;  // Wait ~100M cycles (~1s)
//localparam [26:0] TIMER_THRESHOLD = 28'd100_000_000;  // ~0.5s @100MHz; adjust as needed

//reg [2:0] gen_state = GEN_IDLE, gen_next_state;
//reg [63:0] gen_tdata = 64'h0;
//reg [7:0] gen_tkeep = 8'hFF;
//reg [15:0] burst_cnt = 16'h0;  // Per-burst beat counter
//reg [27:0] timer_cnt = 28'h0;  // ~1s timer (100M cycles)
//reg gen_enable = 1'b0;         // Post-reset one-shot
//reg gen_tvalid = 1'b0; 
//reg gen_tlast = 1'b0;
//wire gen_sel = 1'b1;           // 1=gen mode, 0=echo FIFO (for testing)
//wire gen_tready;
//always @(posedge tx_axis_aclk) begin  // Tx domain
//    if (sys_reset) begin
//        gen_state <= GEN_IDLE;
//        gen_enable <= 1'b0;
//        burst_cnt <= 16'h0;
//        timer_cnt <= 28'h0;
//        gen_tvalid <= 1'b0;
//        gen_tlast <= 1'b0;
//        gen_tdata <= 64'h0;  // Start with known incremental payload
//    end else begin
//        gen_state <= gen_next_state;
        
//        // Free-running timer: Increment always, reset only on threshold in GEN_TIMER
//        if (gen_state == GEN_TIMER && timer_cnt == TIMER_THRESHOLD - 1'b1) begin
//            timer_cnt <= 27'h0;  // Reset at exact threshold (prevents overflow)
//        end else begin
//            timer_cnt <= timer_cnt + 1'b1;
//        end
        
//        // Burst counter: Only during active bursts
//        if (gen_enable && (gen_next_state != GEN_IDLE)) begin
//            burst_cnt <= burst_cnt + 1'b1;
//        end else if (gen_next_state == GEN_IDLE) begin
//            burst_cnt <= 16'h0;  // Reset on idle entry
//        end
        
//        // One-shot enable: Now reliable since timer free-runs
//        if (!gen_enable && timer_cnt > 100) begin
//            gen_enable <= 1'b1;
//        end
        
//        // Incremental data: Update only when generating
//        if (gen_tvalid) begin
//            gen_tdata <= gen_tdata + 64'h1;
//        end
//    end
//end

//// Connect gen_tready from mux
//assign gen_tready = gen_sel ? udp_stack_tx_axis_tready : 1'b1;

//always @(*) begin  // Combo next-state
//    gen_next_state = gen_state;
//    gen_tvalid = 1'b0;
//    gen_tlast = 1'b0;
//    gen_tkeep = 8'hFF;
//    case (gen_state)
//        GEN_IDLE: begin
//            if (gen_enable && gen_tready) begin  // Respect backpressure
//                gen_next_state = GEN_BURST1;
//                gen_tvalid = 1'b1;
//            end
//        end
//        GEN_BURST1: begin
//            gen_tvalid = gen_tready;
//            if (burst_cnt == 9 && gen_tready) begin  // 9 full + 1 last (like TB repeat(9)+1)
//                gen_tlast = 1'b1;
//                gen_next_state = GEN_TIMER;
//            end
//        end
//        GEN_BURST2: begin  // Trigger after timer (or chain from BURST1)
//            gen_tvalid = gen_tready;
//            if (burst_cnt == 19 && gen_tready) begin
//                gen_tlast = 1'b1;
//                gen_next_state = GEN_BURST3;
//            end
//        end
//        GEN_BURST3: begin
//            gen_tvalid = gen_tready;
//            gen_tkeep = 8'h0F;  // Partial like TB
//            if (burst_cnt == 1 && gen_tready) begin
//                gen_tlast = 1'b1;
//                gen_next_state = GEN_TIMER;
//            end
//        end
//        GEN_TIMER: begin
//            if (timer_cnt >= TIMER_THRESHOLD - 1'b1) begin
//                gen_next_state = GEN_BURST2;
//            end
//        end
//        default: gen_next_state = GEN_IDLE;
//    endcase
//end

//// Mux to udp_tx_axis_* (drive gen if sel=1, else FIFO)
//assign udp_tx_axis_tdata  = gen_sel ? gen_tdata  : fifo_tx_axis_tdata;
//assign udp_tx_axis_tkeep  = gen_sel ? gen_tkeep  : fifo_tx_axis_tkeep;
//assign udp_tx_axis_tvalid = gen_sel ? gen_tvalid : fifo_tx_axis_tvalid;
//assign udp_tx_axis_tlast  = gen_sel ? gen_tlast  : fifo_tx_axis_tlast;

//// FIFO tready: Bypass if gen (or mux logic)
//assign fifo_tx_axis_tready = gen_sel ? 1'b1 : udp_stack_tx_axis_tready;

// /// ARP Boot Trigger: One-shot pulse post-reset, driven to stack
// // Domain: tx_clk_out[0] (TX core clk from MAC IP)
// // Reset Sync: 2FF chain for meta-stability (best practice)
// reg rst_tx_sync1 = 1'b0, rst_tx_sync2 = 1'b0;
// wire tx_reset_sync = rst_tx_sync2;  // Synced active-high for logic

// always @(posedge tx_clk_out[0] or posedge sys_reset) begin  // Async assert
//     if (sys_reset) begin
//         rst_tx_sync1 <= 1'b1;
//         rst_tx_sync2 <= 1'b1;
//     end else begin
//         rst_tx_sync1 <= 1'b0;
//         rst_tx_sync2 <= rst_tx_sync1;
//     end
// end

// reg [7:0] arp_boot_cnt = 8'h0;
// reg arp_boot_req = 1'b0;
// wire arp_request_ack;
// always @(posedge tx_clk_out[0]) begin
//     if (tx_reset_sync) begin  // Use synced reset (active-high here)
//         arp_boot_cnt <= 8'h0;
//         arp_boot_req <= 1'b0;
//     end else if (arp_boot_cnt < 8'd100) begin
//         arp_boot_cnt <= arp_boot_cnt + 1'b1;
//         if (arp_boot_cnt == 8'd50) arp_boot_req <= 1'b1;  // Mid-hold pulse (50 cycles post-reset)
//     end else if (arp_request_ack) begin  // Deassert on TX ack (prevents retry spam)
//         arp_boot_req <= 1'b0;
//     end
// end




assign rx_core_clk                = tx_clk_out;
assign gt_loopback_in             = 2'h00;
assign ctl_rx_enable              = 1'b1;
assign ctl_rx_check_preamble      = 1'b1;
assign ctl_rx_check_sfd           = 1'b1;
assign ctl_rx_force_resync        = 1'b0;
assign ctl_rx_delete_fcs          = 1'b1;
assign ctl_rx_ignore_fcs          = 1'b0;
assign ctl_rx_process_lfi         = 1'b0;
assign ctl_rx_test_pattern        = 1'b0;
assign ctl_rx_test_pattern_enable = 1'b0;
assign ctl_rx_data_pattern_select = 1'b0;
assign ctl_rx_max_packet_len      = 15'd1536;
assign ctl_rx_min_packet_len      = 15'd42;
assign ctl_rx_custom_preamble_enable = 1'b0;


assign ctl_tx_enable              = 1'b1;
assign ctl_tx_send_rfi            = 1'b0;
assign ctl_tx_send_lfi            = 1'b0;
assign ctl_tx_send_idle           = 1'b0;
assign ctl_tx_fcs_ins_enable      = 1'b1;
assign ctl_tx_ignore_fcs          = 1'b0;
assign ctl_tx_test_pattern        = 1'b0;
assign ctl_tx_test_pattern_enable = 1'b0;
assign ctl_tx_data_pattern_select = 1'b0;
assign ctl_tx_test_pattern_select = 1'b0;
assign ctl_tx_test_pattern_seed_a = 58'h0;
assign ctl_tx_test_pattern_seed_b = 58'h0;
assign ctl_tx_custom_preamble_enable = 1'b0;
assign ctl_tx_ipg_value           = 4'd12;

assign gtwiz_reset_tx_datapath    = 4'b0000;
assign gtwiz_reset_rx_datapath    = 4'b0000;

assign txoutclksel_in             = 3'b101;    // this value should not be changed as per gtwizard 
assign rxoutclksel_in             = 3'b101;    // this value should not be changed as per gtwizard
// assign txoutclksel_in[1] = 3'b101;    // this value should not be changed as per gtwizard 
// assign rxoutclksel_in[1] = 3'b101;    // this value should not be changed as per gtwizard
// assign txoutclksel_in[2] = 3'b101;    // this value should not be changed as per gtwizard 
// assign rxoutclksel_in[2] = 3'b101;    // this value should not be changed as per gtwizard
// assign txoutclksel_in[3] = 3'b101;    // this value should not be changed as per gtwizard 
// assign rxoutclksel_in[3] = 3'b101;    // this value should not be changed as per gtwizard



eth_10G_mphy eth_10gmphy (
  .gt_rxp_in_0                      (gt_rx_in_p),                                           
  .gt_rxn_in_0                      (gt_rx_in_n),                                          
  .gt_txp_out_0                     (gt_tx_out_p),                                        
  .gt_txn_out_0                     (gt_tx_out_n),                                         

  .rx_core_clk_0                    (rx_core_clk),                                      

  .txoutclksel_in_0                 (txoutclksel_in),                                
  .rxoutclksel_in_0                 (rxoutclksel_in),                                

  .gtwiz_reset_tx_datapath_0        (gtwiz_reset_tx_datapath),         
  .gtwiz_reset_rx_datapath_0        (gtwiz_reset_rx_datapath),             

  .rxrecclkout_0                    (),                                

  .sys_reset                        (sys_reset),                                                
  .dclk                             (sys_clk_100MHz),                                                           
  .tx_clk_out_0                     (tx_clk_out),                                          
  .rx_clk_out_0                     (rx_clk_out),                                           
  .gt_refclk_p                      (gt_refclk_in_p),                                             
  .gt_refclk_n                      (gt_refclk_in_n),                                             
  .gt_refclk_out                    (gt_refclk_out),                                        

  .gtpowergood_out_0                (gtpowergood),                          

  .rx_reset_0                       (1'b0),                                       
  .user_rx_reset_0                  (user_rx_reset),                          

  .rx_axis_tvalid_0                 (mac_rx_axis_tvalid),                                  
  .rx_axis_tdata_0                  (mac_rx_axis_tdata),                                    
  .rx_axis_tlast_0                  (mac_rx_axis_tlast),                                    
  .rx_axis_tkeep_0                  (mac_rx_axis_tkeep),                                    
  .rx_axis_tuser_0                  (mac_rx_axis_tuser),                                    

  .ctl_rx_enable_0                  (ctl_rx_enable),                                     
  .ctl_rx_check_preamble_0          (ctl_rx_check_preamble),                     
  .ctl_rx_check_sfd_0               (ctl_rx_check_sfd),                               
  .ctl_rx_force_resync_0            (ctl_rx_force_resync),                         
  .ctl_rx_delete_fcs_0              (ctl_rx_delete_fcs),                             
  .ctl_rx_ignore_fcs_0              (ctl_rx_ignore_fcs),                             
  .ctl_rx_max_packet_len_0          (ctl_rx_max_packet_len),                     
  .ctl_rx_min_packet_len_0          (ctl_rx_min_packet_len),                     
  .ctl_rx_process_lfi_0             (ctl_rx_process_lfi),                           
  .ctl_rx_test_pattern_0            (ctl_rx_test_pattern),                         
  .ctl_rx_data_pattern_select_0     (ctl_rx_data_pattern_select),           
  .ctl_rx_test_pattern_enable_0     (ctl_rx_test_pattern_enable),           
  .ctl_rx_custom_preamble_enable_0  (ctl_rx_custom_preamble_enable),    

  .tx_reset_0                       (1'b0),                                            
  .user_tx_reset_0                  (user_tx_reset),                                   

  .tx_axis_tready_0                 (mac_tx_axis_tready),                                  
  .tx_axis_tvalid_0                 (mac_tx_axis_tvalid),                                  
  .tx_axis_tdata_0                  (mac_tx_axis_tdata),                                    
  .tx_axis_tlast_0                  (mac_tx_axis_tlast),                                    
  .tx_axis_tkeep_0                  (mac_tx_axis_tkeep),                                    
  .tx_axis_tuser_0                  (1'b0),                                    

  .ctl_tx_enable_0                  (ctl_tx_enable),                                     
  .ctl_tx_send_rfi_0                (ctl_tx_send_rfi),                                
  .ctl_tx_send_lfi_0                (ctl_tx_send_lfi),                                
  .ctl_tx_send_idle_0               (ctl_tx_send_idle),                               
  .ctl_tx_fcs_ins_enable_0          (ctl_tx_fcs_ins_enable),                     
  .ctl_tx_ignore_fcs_0              (ctl_tx_ignore_fcs),                             
  .ctl_tx_test_pattern_0            (ctl_tx_test_pattern),                         
  .ctl_tx_test_pattern_enable_0     (ctl_tx_test_pattern_enable),           
  .ctl_tx_test_pattern_select_0     (ctl_tx_test_pattern_select),           
  .ctl_tx_data_pattern_select_0     (ctl_tx_data_pattern_select),           
  .ctl_tx_test_pattern_seed_a_0     (ctl_tx_test_pattern_seed_a),           
  .ctl_tx_test_pattern_seed_b_0     (ctl_tx_test_pattern_seed_b),           
  .ctl_tx_ipg_value_0               (ctl_tx_ipg_value),                               
  .ctl_tx_custom_preamble_enable_0  (ctl_tx_custom_preamble_enable),     

  .tx_unfout_0                      (),                                            
  .tx_preamblein_0                  (1'b0),                                     
  .rx_preambleout_0                 (),                                   

  .gt_loopback_in_0                 (gt_loopback_in),                                
  .qpllreset_in_0                   (1'b0) 
//   .stat_tx_local_fault_0            (),                   
//   .stat_tx_total_bytes_0            (),                   
//   .stat_tx_total_packets_0          (),                   
//   .stat_tx_total_good_bytes_0       (),              
//   .stat_tx_total_good_packets_0     (),         
//   .stat_tx_bad_fcs_0                (),                               
//   .stat_tx_packet_64_bytes_0        (),               
//   .stat_tx_packet_65_127_bytes_0    (),        
//   .stat_tx_packet_128_255_bytes_0   (),      
//   .stat_tx_packet_256_511_bytes_0   (),      
//   .stat_tx_packet_512_1023_bytes_0  (),    
//   .stat_tx_packet_1024_1518_bytes_0 (),   
//   .stat_tx_packet_1519_1522_bytes_0 (),   
//   .stat_tx_packet_1523_1548_bytes_0 (),   
//   .stat_tx_packet_1549_2047_bytes_0 (),   
//   .stat_tx_packet_2048_4095_bytes_0 (),   
//   .stat_tx_packet_4096_8191_bytes_0 (),   
//   .stat_tx_packet_8192_9215_bytes_0 (),   
//   .stat_tx_packet_small_0           (),                  
//   .stat_tx_packet_large_0           (),                     
//   .stat_tx_unicast_0                (),                           
//   .stat_tx_multicast_0              (),                 
//   .stat_tx_broadcast_0              (),                       
//   .stat_tx_vlan_0                   (),                                
//   .stat_tx_frame_error_0            (),                      


//   .stat_rx_framing_err_0            (),                   
//   .stat_rx_framing_err_valid_0      (),            
//   .stat_rx_local_fault_0            (),                        
//   .stat_rx_block_lock_0             (),                          
//   .stat_rx_valid_ctrl_code_0        (),                
//   .stat_rx_status_0                 (),                                  
//   .stat_rx_remote_fault_0           (),                      
//   .stat_rx_bad_fcs_0                (),                                
//   .stat_rx_stomped_fcs_0            (),                        
//   .stat_rx_truncated_0              (),                            
//   .stat_rx_internal_local_fault_0   (),      
//   .stat_rx_received_local_fault_0   (),      
//   .stat_rx_hi_ber_0                 (),                                  
//   .stat_rx_got_signal_os_0          (),                    
//   .stat_rx_test_pattern_mismatch_0  (),    
//   .stat_rx_total_bytes_0            (),                        
//   .stat_rx_total_packets_0          (),                    
//   .stat_rx_total_good_bytes_0       (),              
//   .stat_rx_total_good_packets_0     (),          
//   .stat_rx_packet_bad_fcs_0         (),                  
//   .stat_rx_packet_64_bytes_0        (),                
//   .stat_rx_packet_65_127_bytes_0    (),        
//   .stat_rx_packet_128_255_bytes_0   (),      
//   .stat_rx_packet_256_511_bytes_0   (),      
//   .stat_rx_packet_512_1023_bytes_0  (),    
//   .stat_rx_packet_1024_1518_bytes_0 (),  
//   .stat_rx_packet_1519_1522_bytes_0 (),  
//   .stat_rx_packet_1523_1548_bytes_0 (),  
//   .stat_rx_packet_1549_2047_bytes_0 (),  
//   .stat_rx_packet_2048_4095_bytes_0 (),  
//   .stat_rx_packet_4096_8191_bytes_0 (),  
//   .stat_rx_packet_8192_9215_bytes_0 (),  
//   .stat_rx_packet_small_0           (),                      
//   .stat_rx_packet_large_0           (),                      
//   .stat_rx_unicast_0                (),                                
//   .stat_rx_multicast_0              (),                        
//   .stat_rx_broadcast_0              (),                       
//   .stat_rx_oversize_0               (),                        
//   .stat_rx_toolong_0                (),                       
//   .stat_rx_undersize_0              (),                  
//   .stat_rx_fragment_0               (),                      
//   .stat_rx_vlan_0                   (),                                 
//   .stat_rx_inrangeerr_0             (),                    
//   .stat_rx_jabber_0                 (),                              
//   .stat_rx_bad_code_0               (),                         
//   .stat_rx_bad_sfd_0                (),                           
//   .stat_rx_bad_preamble_0           (),                     

                               
);


// (* mark_debug = "true" *) wire udp_enable;
// (* mark_debug = "true" *) wire [63:0] udp_tx_axis_tdata;
// (* mark_debug = "true" *) wire udp_tx_axis_tvalid;
// (* mark_debug = "true" *) wire udp_tx_axis_tlast;
// (* mark_debug = "true" *) wire udp_tx_axis_tready;
// (* mark_debug = "true" *) wire [63:0] mac_tx_axis_tdata;
// (* mark_debug = "true" *) wire mac_tx_axis_tvalid;
// (* mark_debug = "true" *) wire mac_tx_axis_tlast;
// (* mark_debug = "true" *) wire mac_tx_axis_tready;
// (* mark_debug = "true" *) wire [0:0] gtpowergood;
// (* mark_debug = "true" *) wire gt_tx_out_p;  // Physical out




// Sync TX disable deassert (low = enable; sys_clk_100MHz domain)
reg [1:0] tx_disable_sync;
always @(posedge sys_clk_100MHz) begin
    if (sys_reset) tx_disable_sync <= 2'b11;  // High during reset (disable TX)
    else tx_disable_sync <= {tx_disable_sync[0], ~mmcm_locked_sync};  // Low post-lock
end
assign sfp0_tx_disable = tx_disable_sync[1];  // High = disable, low = enable


// Sync lock for gating (sys_clk_100MHz domain, 2-FF for meta-stability)
reg [1:0] lock_sync;  
always @(posedge sys_clk_100MHz) begin
    if (sys_reset) lock_sync <= 2'b00;  
    else lock_sync <= {lock_sync[0], mmcm_locked};  // Shift-in lock
end
wire mmcm_locked_sync = lock_sync[1];


wire debug_clk_en = ~lock_sync[1];  

// 2-FF sync for reset deassert (sys_clk_100MHz domain)
reg [1:0] rst_sync;  
always @(posedge sys_clk_100MHz) begin
    if (sys_reset) rst_sync <= 2'b11;  
    else rst_sync <= {rst_sync[0], 1'b0};  
end
assign si5328_rst = ~rst_sync[1];  

// ===================================================================
// UDP Test Payload Generator (ASCII "Hello from FPGA" with Packet Counter)
// ===================================================================
// Features:
// - Single-beat packets (64B AXI-Stream beat, tkeep=8'hFF)
// - Payload: "Hello from FPGA PKT: 00000000" (ASCII, 28 chars incl. counter)
// - Counter increments per packet (hex in payload for easy Wireshark decode)
// - Rate: ~1 packet/second @ 156.25 MHz (tunable via PKT_INTERVAL)
// - Gated on udp_enable (post-MMCM lock) and synced reset
// ===================================================================

reg [31:0] pkt_cnt    = 32'd0;
reg [2:0]  beat       = 3'd0;        // 0-3
reg        pkt_active = 1'b0;
reg [26:0] timer      = 27'd0;

localparam [26:0] PKT_INTERVAL = 27'd15_625_000;  // ~100 ms at 156.25 MHz

always @(posedge tx_clk_out or negedge tx_axis_aresetn) begin
    if (!tx_axis_aresetn) begin
        timer      <= 0;
        pkt_active <= 0;
        beat       <= 0;
        pkt_cnt    <= 0;
    end else if (udp_enable) begin
        // Timer
        if (timer == PKT_INTERVAL - 1) timer <= 0;
        else                           timer <= timer + 1'b1;

        // Start new packet
        if (!pkt_active && timer == PKT_INTERVAL - 1) begin
            pkt_active <= 1'b1;
            beat       <= 0;
            pkt_cnt    <= pkt_cnt + 1'b1;
        end
        // Advance on tready
        else if (pkt_active && udp_stack_tx_axis_tready) begin
            if (beat == 3) pkt_active <= 0;
            beat <= beat + 1'b1;
        end
    end
end

// ── Payload: 32 bytes exactly ───────────────────────────────────────
// "Hello from FPGA PKT: 00000000" 
reg [63:0] payload ;
always @(*) begin
    case (beat) 
        2'd0: payload = 64'h72_66_20_6f_6c_6c_65_48;  // "Hello fr"
        2'd1: payload = 64'h20_41_47_50_46_20_6d_6f;  // "om FPGA "
        2'd2: payload = 64'h30_30_30_20_3a_54_4b_50;  // "PKT: 000"  
        2'd3: payload = 64'h30_30_30_30_30_30_30_30;  // "00000000"
        default: payload = 64'h0;
    endcase
end


reg gen_sel = 1'b1;  // 1 = this simple gen, 0 = echo Fifo
assign udp_tx_axis_tdata  = gen_sel ? payload  : fifo_tx_axis_tdata;
assign udp_tx_axis_tkeep  = gen_sel ? 8'hFF  : fifo_tx_axis_tkeep;
assign udp_tx_axis_tvalid = gen_sel ? pkt_active : fifo_tx_axis_tvalid;
assign udp_tx_axis_tlast  = gen_sel ? pkt_active && (beat == 3) && udp_stack_tx_axis_tready  : fifo_tx_axis_tlast;

// FIFO tready: Bypass if gen (or mux logic)
assign fifo_tx_axis_tready = gen_sel ? 1'b1 : udp_stack_tx_axis_tready;



ila_0 ila_tx_debug (
    .clk(tx_clk_out),
    .probe0(rx_clk_out),
    .probe1(udp_tx_axis_tvalid),     // Post-mux
    .probe2(udp_tx_axis_tlast),
    .probe3(udp_stack_tx_axis_tready), // Probe stack tready
    .probe4(udp_tx_axis_tdata),      // 64-bit: Post-mux
    .probe5(mac_tx_axis_tdata),      // 64-bit: From stack
    .probe6(mac_tx_axis_tvalid),
    .probe7(mac_tx_axis_tlast),
    .probe8(mac_tx_axis_tready),
    .probe9(gtpowergood[0]),     // GT status
    .probe10(pkt_active),     // Reset status
    // .probe10(sys_reset),     // Reset status
    .probe11(udp_enable),       // MMCM lock
    .probe12(beat),
    .probe13(arp_reply_valid),  // Reply parsed?
    .probe14(arp_reply_req),
    .probe15(dst_mac_addr),
    .probe16(arp_register[79:32]),// Table IP (32b slice)
    .probe17(mac_rx_axis_tvalid), // RX traffic?
    .probe18(mac_rx_axis_tdata)
);



// LED Indicators 
reg [31:0] cnt_300M = 32'd0;
always @(posedge sys_clk_300Mhz) begin
    cnt_300M <= cnt_300M + 1;
end
assign led[0] = cnt_300M[26];


reg [31:0] cnt_156_25M = 32'd0;
always @(posedge gt_refclk_out) begin
    cnt_156_25M <= cnt_156_25M + 1;
end
assign led[1] = cnt_156_25M[26];


// LED Indicators 
reg [31:0] cnt_100M = 32'd0;
always @(posedge sys_clk_100MHz) begin
    cnt_100M <= cnt_100M + 1;
end
assign led[2] = cnt_100M[26];
// assign led[2] = mmcm_locked;



reg [31:0] cnt_tx_clk_out = 32'd0;
always @(posedge tx_clk_out) begin
    cnt_tx_clk_out <= cnt_tx_clk_out + 1;
end
assign led[3] = cnt_tx_clk_out[26];


reg [31:0] cnt_rx_clk_out = 32'd0;
always @(posedge rx_clk_out) begin
    cnt_rx_clk_out <= cnt_rx_clk_out + 1;
end
assign led[4] = cnt_rx_clk_out[26];


endmodule //top_udp

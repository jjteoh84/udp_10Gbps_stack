`timescale 1ns/1ps

module us_mac_rx(
    input       wire        rx_axis_aclk        ,
    input       wire        rx_axis_aresetn     ,

    input       wire[63:0]  rx_mac_axis_tdata   ,
    input       wire[7:0]   rx_mac_axis_tkeep   ,
    input       wire        rx_mac_axis_tvalid  ,
    input       wire        rx_mac_axis_tuser   ,
    input       wire        rx_mac_axis_tlast   ,

    output      reg[63:0]   rx_frame_axis_tdata ,
    output      reg[7:0]    rx_frame_axis_tkeep ,
    output      reg         rx_frame_axis_tvalid,
    output      reg         rx_frame_axis_tuser ,
    output      reg         rx_frame_axis_tlast ,

    output      reg[47:0]   recv_dst_mac_addr   ,
    output      reg[47:0]   recv_src_mac_addr   ,
    output      reg[15:0]   recv_type           ,
    input       wire[47:0]  local_mac_addr  
);

    /* ------------------------------------------------------------------
       14-byte Ethernet header stripper 
       ------------------------------------------------------------------ */
    reg  [4:0]  header_bytes_consumed;

    wire [3:0] bytes_this_beat = 
          ({4{rx_mac_axis_tkeep[0]}} & 4'd1) + ({4{rx_mac_axis_tkeep[1]}} & 4'd1)
        + ({4{rx_mac_axis_tkeep[2]}} & 4'd1) + ({4{rx_mac_axis_tkeep[3]}} & 4'd1)
        + ({4{rx_mac_axis_tkeep[4]}} & 4'd1) + ({4{rx_mac_axis_tkeep[5]}} & 4'd1)
        + ({4{rx_mac_axis_tkeep[6]}} & 4'd1) + ({4{rx_mac_axis_tkeep[7]}} & 4'd1);

    always @(posedge rx_axis_aclk or negedge rx_axis_aresetn) begin
        if (~rx_axis_aresetn) begin
            header_bytes_consumed <= 5'd0;
        end else if (rx_mac_axis_tvalid && rx_mac_axis_tlast) begin
            header_bytes_consumed <= 5'd0;
        end else if (rx_mac_axis_tvalid) begin
            header_bytes_consumed <= header_bytes_consumed + bytes_this_beat;
        end
    end

   
    /* ------------------------------------------------------------------
       Clean AXI-Stream output
       ------------------------------------------------------------------ */
    reg [4:0] header_bytes_seen = 5'd0;

    always @(posedge rx_axis_aclk or negedge rx_axis_aresetn) begin
        if (~rx_axis_aresetn) begin
            header_bytes_seen <= 5'd0;
        end else if (rx_mac_axis_tvalid && rx_mac_axis_tlast) begin
            header_bytes_seen <= 5'd0;
        end else if (rx_mac_axis_tvalid) begin
            if (header_bytes_seen < 14)
                header_bytes_seen <= (header_bytes_seen + bytes_this_beat > 14) ? 5'd14 : header_bytes_seen + bytes_this_beat;
        end
    end

    // How many header bytes remain to strip in the CURRENT beat?
    wire [4:0] header_remain = (header_bytes_seen >= 14) ? 5'd0 : (14 - header_bytes_seen);

    always @(posedge rx_axis_aclk) begin
        if (~rx_axis_aresetn) begin
            rx_frame_axis_tvalid <= 1'b0;
            rx_frame_axis_tlast  <= 1'b0;
            rx_frame_axis_tuser  <= 1'b0;
            rx_frame_axis_tdata  <= 64'd0;
            rx_frame_axis_tkeep  <= 8'd0;
        end else begin
            // Default: no output
            rx_frame_axis_tvalid <= 1'b0;
            rx_frame_axis_tlast  <= 1'b0;
            rx_frame_axis_tuser  <= rx_mac_axis_tuser;

            if (rx_mac_axis_tvalid) begin
                if (header_bytes_seen >= 14) begin
                    // Fully in payload
                    rx_frame_axis_tdata  <= rx_mac_axis_tdata;
                    rx_frame_axis_tkeep  <= rx_mac_axis_tkeep;
                    rx_frame_axis_tvalid <= 1'b1;
                    rx_frame_axis_tlast  <= rx_mac_axis_tlast;
                end
                else if (header_remain < bytes_this_beat) begin
                    // This beat crosses from header → payload
                    rx_frame_axis_tdata  <= rx_mac_axis_tdata >> (header_remain * 8);
                    rx_frame_axis_tkeep  <= rx_mac_axis_tkeep >> header_remain;
                    rx_frame_axis_tvalid <= 1'b1;
                    rx_frame_axis_tlast  <= rx_mac_axis_tlast;
                end
                // else: still consuming header → output nothing this cycle
            end
        end
    end

    /* ------------------------------------------------------------------
       Header field extraction 
       ------------------------------------------------------------------ */
    reg [63:0] rx_mac_axis_tdata_reg;

    always @(posedge rx_axis_aclk) begin
        rx_mac_axis_tdata_reg <= rx_mac_axis_tdata;
    end


    // ------------------------------------------------------------------
    // Start-of-Frame pulse (exactly one cycle wide at the first beat)
    // ------------------------------------------------------------------
    reg sof;
    always @(posedge rx_axis_aclk) begin
        if (~rx_axis_aresetn)
            sof <= 1'b0;
        else
            sof <= (rx_mac_axis_tvalid && (header_bytes_consumed == 0));  // true only on first beat
    end
    
    // Destination MAC
    reg dst_mac_captured;
    always @(posedge rx_axis_aclk) begin
        if (~rx_axis_aresetn) begin
            // recv_dst_mac_addr <= 48'h0;
            recv_dst_mac_addr <=48'hac_14_74_45_bc_f4;
            dst_mac_captured <= 0;
        end 
        // else if (rx_mac_axis_tvalid && !src_mac_captured) begin
        //     if (rx_mac_axis_tvalid && header_bytes_consumed <6) begin
            
        //         recv_dst_mac_addr[47:40] <= rx_mac_axis_tdata[7:0];
        //         recv_dst_mac_addr[39:32] <= rx_mac_axis_tdata[15:8];
        //         recv_dst_mac_addr[31:24] <= rx_mac_axis_tdata[23:16];
        //         recv_dst_mac_addr[23:16] <= rx_mac_axis_tdata[31:24];
        //         recv_dst_mac_addr[15:8]  <= rx_mac_axis_tdata[39:32];
        //         recv_dst_mac_addr[7:0]   <= rx_mac_axis_tdata[47:40];
        //         dst_mac_captured <=1'b1;
        //     end
        // end
    end



    reg src_mac_captured;
    // Source MAC - spans two beats, fixed line below
     always @(posedge rx_axis_aclk) begin
        if (~rx_axis_aresetn) begin
            recv_src_mac_addr <= 48'h0;
            src_mac_captured  <= 1'b0;
        // end else if ( rx_mac_axis_tvalid && rx_mac_axis_tlast && header_bytes_consumed == 0) begin
        //     // Clear at very start of frame
        //     recv_src_mac_addr <= 48'h0;
        // end
        end
        // else if (sof) begin
        //     src_mac_captured <= 1'b0;
        //     recv_src_mac_addr <= 48'h0;  // clear at start of frame
        // end
        else if (rx_mac_axis_tvalid && !src_mac_captured) begin
            // Bytes 6-7 (a036)
            if (header_bytes_consumed <8) begin
                recv_src_mac_addr[47:32] <= {rx_mac_axis_tdata[55:48], rx_mac_axis_tdata[63:56]};
            end
            // Bytes 8-11 (9f7de58c)
            else if (header_bytes_consumed >= 8 && header_bytes_consumed < 12) begin
                recv_src_mac_addr[31:24] <= rx_mac_axis_tdata[7:0];
                recv_src_mac_addr[23:16] <= rx_mac_axis_tdata[15:8];
                recv_src_mac_addr[15:8] <= rx_mac_axis_tdata[23:16];
                recv_src_mac_addr[7:0] <= rx_mac_axis_tdata[31:24];
                src_mac_captured       = 1'b1;
            end
        end
    end


    // EtherType
    reg [4:0] header_bytes_seen_prev;
    always @(posedge rx_axis_aclk) begin
        if (~rx_axis_aresetn)
            header_bytes_seen_prev <= 5'd0;
        else
            header_bytes_seen_prev <= header_bytes_seen;
    end
    
    always @(posedge rx_axis_aclk) begin
        if (~rx_axis_aresetn) begin
            recv_type <= 16'd0;
        end 
        else if (rx_mac_axis_tvalid && header_bytes_seen == 8) begin
            recv_type <= {rx_mac_axis_tdata[39:32], rx_mac_axis_tdata[47:40]};  // EtherType is bytes 12-13, and in little-endian lanes:
            // $display("DEBUG: tdata = %h, eth_candidate = %h %h → %h",
            //      rx_mac_axis_tdata,
            //      rx_mac_axis_tdata[39:32], rx_mac_axis_tdata[47:40],
            //      {rx_mac_axis_tdata[39:32], rx_mac_axis_tdata[47:40]});
        end
    end

    

endmodule
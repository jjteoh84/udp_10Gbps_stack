/****************************************************************************
 * @file    us_ip_rx.v
 * @brief  
 * @author  weslie (zzhi4832@gmail.com)
 * @version 1.0
 * @date    2025-01-22
 * 
 * @par :
 * ___________________________________________________________________________
 * |    Date       |  Version    |       Author     |       Description      |
 * |---------------|-------------|------------------|------------------------|
 * |               |   v1.0      |    weslie        |                        |
 * |---------------|-------------|------------------|------------------------|
 * 
 * @copyright Copyright (c) 2025 welie
 * ***************************************************************************/

/** **************************************************************************** ***************************************

  0                   1                   2                   3  
  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |Version|  IHL  |Type of Service|          Total Length         |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |         Identification        |Flags|      Fragment Offset    |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |  Time to Live |    Protocol   |         Header Checksum       |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                       Source Address                          |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                    Destination Address                        |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
 |                    Options (if any)           |    Padding    |
 +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

|-----------------------------------------------------------------------------------------------------------------------|
| Field                        | Length (bits) | Description                                                            |
| ---------------------------- | ------------- | ---------------------------------------------------------------------- |
| Version                      | 4             | IP protocol version (IPv4 = 4)                                         |
| IHL (Header Length)          | 4             | Header length, in 32-bit words. Minimum value is 5 (20 bytes).         |
| Type of Service (TOS) / DSCP | 8             | Type of Service / Differentiated Services Code Point                   |
| Total Length                 | 16            | Total length of the IP datagram (header + data), in bytes              |
| Identification               | 16            | Datagram identifier, used for fragmentation and reassembly             |
| Flags                        | 3             | Fragmentation control flags (DF = Don't Fragment, MF = More Fragments) |
| Fragment Offset              | 13            | Fragment offset within the original datagram, in 8-byte units          |
| Time To Live (TTL)           | 8             | Time to live, maximum hop count                                        |
| Protocol                     | 8             | Upper-layer protocol number (TCP = 6, UDP = 17, ICMP = 1, etc.)        |
| Header Checksum              | 16            | Checksum for the header                                                |
| Source IP Address            | 32            | Source IP address                                                      |
| Destination IP Address       | 32            | Destination IP address                                                 |
| Options (optional)           | variable      | Optional fields (e.g., routing, timestamp), usually omitted            |
| Padding                      | variable      | Padding to align the header to a 32-bit boundary                       |

timing diagram

https://wavedrom.com/editor.html

{signal: [
  {name: 'source_clk'  ,  wave: 'n...........', period:1}, 
  {name: 'tvalid'      ,  wave: '01.......0|'},
  {name: 'tdata[7:0]'  ,  wave: '3447222229|',data:["xx","HD","HD","DA","D","D","D","D","D"]},
  {name: 'tdata[15:8]' ,  wave: '3447222229|',data:["xx","HD","HD","DA","D","D","D","D","D"]},
  {name: 'tdata[23:16]',  wave: '344722229.|',data:["xx","HD","HD","DA","D","D","D","D",""]},
  {name: 'tdata[31:24]',  wave: '344722229.|',data:["xx","HD","HD","DA","D","D","D","D",""]},
  {name: 'tdata[39:32]',  wave: '346222229.|',data:["xx","HD","SA","D","D","D","D","D",""]},
  {name: 'tdata[47:40]',  wave: '346222229.|',data:["xx","HD","SA","D","D","D","D","D",""]},
  {name: 'tdata[55:48]',  wave: '346222229.|',data:["xx","HD","SA","D","D","D","D","D",""]},
  {name: 'tdata[63:56]',  wave: '346222229.|',data:["xx","HD","SA","D","D","D","D","D",""]},
  {name: 'tkeep[7:0]'  ,  wave: '32......89|',data:["xx","0xff","0x3"]},
  {name: 'tuser'       ,  wave: '0..........'},
  {name: 'tlast'       ,  wave: '0.......10.'},
]}


**************************************************************************************************************************/

module us_ip_rx(
    input   wire        rx_axis_aclk    ,
    input   wire        rx_axis_aresetn ,

    input   wire[63:0]  mac_rx_axis_tdata   ,
    input   wire[7:0]   mac_rx_axis_tkeep   ,
    input   wire        mac_rx_axis_tvalid  ,
    input   wire        mac_rx_axis_tuser   ,
    input   wire        mac_rx_axis_tlast   ,

    output  wire[63:0]   ip_rx_axis_tdata    ,
    output  wire[7:0]    ip_rx_axis_tkeep    ,
    output  wire         ip_rx_axis_tvalid   ,
    output  wire         ip_rx_axis_tuser    ,
    output  wire         ip_rx_axis_tlast    ,

    input   wire[31:0]  local_ip_addr       ,
    output  wire[31:0]  recv_dst_ip_addr    ,
    output  wire[31:0]  recv_src_ip_addr    ,
    input   wire[47:0]  local_mac_addr      ,
    input       [47:0]  recv_dst_mac_addr   ,  
    output  wire[15:0]  ip_type
);

/* **********************************************************************
 * 1. store machine for receive mac frame
 **********************************************************************/
localparam  RECV_IP_HEADER0 =   7'b000001;
localparam  RECV_IP_HEADER1 =   7'b000010;
localparam  RECV_IP_HEADER2 =   7'b000100;
localparam  RECV_IP_PAYLOAD =   7'b001000;
localparam  RECV_IP_GOOD    =   7'b010000;
localparam  RECV_IP_FAIL    =   7'b100000;


reg     [5:0]   recv_ip_state        =   0;
reg     [5:0]   recv_ip_next_state   =   0;

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        recv_ip_state <= RECV_IP_HEADER0;
    end
    else begin
        recv_ip_state <= recv_ip_next_state;
    end
end

always @(*) begin
    case (recv_ip_state)
        RECV_IP_HEADER0: begin
            if (mac_rx_axis_tvalid) begin
                recv_ip_next_state <= RECV_IP_HEADER1;
            end
            else begin
                recv_ip_next_state <= RECV_IP_HEADER0;
            end
        end

        RECV_IP_HEADER1: begin
            if (mac_rx_axis_tvalid) begin
                recv_ip_next_state <= RECV_IP_HEADER2;
            end
            else if (mac_rx_axis_tvalid & mac_rx_axis_tlast) begin
                recv_ip_next_state <= RECV_IP_FAIL;
            end
            else begin
                recv_ip_next_state <= RECV_IP_HEADER1;
            end
        end

        RECV_IP_HEADER2: begin
            if (mac_rx_axis_tvalid) begin
                recv_ip_next_state <= RECV_IP_PAYLOAD;
            end
            else if (mac_rx_axis_tvalid & mac_rx_axis_tlast) begin
                recv_ip_next_state <= RECV_IP_FAIL;
            end            
            else begin
                recv_ip_next_state <= RECV_IP_HEADER2;
            end
        end

        RECV_IP_PAYLOAD:begin
            if (mac_rx_axis_tlast & mac_rx_axis_tvalid & mac_rx_axis_tuser) begin
                recv_ip_next_state <= RECV_IP_FAIL;
            end
            else if (mac_rx_axis_tlast & mac_rx_axis_tvalid & ~mac_rx_axis_tuser) begin
                recv_ip_next_state <= RECV_IP_GOOD;
            end
            else begin
                recv_ip_next_state <= RECV_IP_PAYLOAD;
            end
        end

        RECV_IP_GOOD : begin
            recv_ip_next_state <= RECV_IP_HEADER0;
        end

        RECV_IP_FAIL : begin
            recv_ip_next_state <= RECV_IP_HEADER0;
        end

        default: begin
            recv_ip_next_state <= RECV_IP_HEADER0;
        end
    endcase
end


/* **********************************************************************
 * 2. Extract the information from the ip data packet
 **********************************************************************/

reg     [3:0]   ip_version        =   0;
reg     [3:0]   ip_header_length  =   0;
reg     [7:0]   ip_tos            =   0;
reg     [15:0]  ip_length         =   0;

reg     [15:0]  ip_idcode         =   0;
reg     [2:0]   ip_flag           =   0;
reg     [12:0]  ip_frog_offset    =   0;

reg     [7:0]   ip_ttl            =   0;
reg     [7:0]   ip_protocol       =   0;
reg     [15:0]  ip_checksum       =   0;

reg     [31:0]  ip_src_addr       =   0;

reg     [31:0]  ip_dst_addr       =   0;

// ─────────────────────────────────────────────────────────────────────────────
// IPv4 HEADER EXTRACTION FOR 14-BYTE ETHERNET header + LITTLE-ENDIAN LANES
// ─────────────────────────────────────────────────────────────────────────────
// First beat after MAC strip: contains IP bytes 0–7 (shifted into lanes 1–7)
// tdata[7:0]     = garbage/padding (or VLAN)
// tdata[15:8]    = IP byte 0  → Version/IHL
// tdata[23:16]   = IP byte 1  → TOS
// tdata[31:24]   = IP byte 2  → Total Len MSB
// tdata[39:32]   = IP byte 3  → Total Len LSB
// tdata[47:40]   = IP byte 4  → ID MSB
// tdata[55:48]   = IP byte 5  → ID LSB
// tdata[63:56]   = IP byte 6  → Flags + Fragment MS
        
always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        ip_version       <= 0;
        ip_header_length <= 0;
        ip_tos           <= 0;
      
    end
    else if (mac_rx_axis_tvalid && (recv_ip_state == RECV_IP_HEADER0)) begin
        

        ip_version      <= mac_rx_axis_tdata[7:4];
        ip_header_length<= mac_rx_axis_tdata[3:0];
        ip_tos          <= mac_rx_axis_tdata[15:8];
              
    end
    else begin
        ip_version      <= ip_version;
        ip_header_length<= ip_header_length;
        ip_tos          <= ip_tos;
                 
    end
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        ip_length        <= 0;
        ip_idcode        <= 0;
        ip_flag          <= 0;
        ip_frog_offset   <= 0;  
        ip_ttl      <=  0;
        ip_protocol <=  0;

    end

    else if (mac_rx_axis_tvalid && (recv_ip_state == RECV_IP_HEADER1)) begin
        ip_length       <= {mac_rx_axis_tdata[7:0],mac_rx_axis_tdata[15:8]};
        ip_idcode       <= {mac_rx_axis_tdata[23:16] , mac_rx_axis_tdata[31:24]};
        ip_flag         <= mac_rx_axis_tdata[34:32];
        ip_frog_offset  <= mac_rx_axis_tdata[47:35];  
        ip_ttl      <=  mac_rx_axis_tdata[55:48];
        ip_protocol <=  mac_rx_axis_tdata[63:56];
        
    end
    else begin
        ip_length       <= ip_length;     
        ip_idcode       <= ip_idcode;
        ip_flag         <= ip_flag;
        ip_frog_offset  <= ip_frog_offset;    
        ip_ttl      <=  ip_ttl;
        ip_protocol <=  ip_protocol;
        
    end
end



reg [15:0] ip_dst_upper;   // captured in HEADER2
reg [15:0] ip_dst_lower;   // captured on first payload beat
reg        ip_dst_lower_captured;

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        ip_checksum <=  0;
        ip_src_addr <=  0;
        ip_dst_upper <= 0;
    end
    else if (mac_rx_axis_tvalid && (recv_ip_state == RECV_IP_HEADER2)) begin
        ip_checksum <=  {mac_rx_axis_tdata[7:0],mac_rx_axis_tdata[15:8]};
        ip_src_addr <=  {mac_rx_axis_tdata[23:16],mac_rx_axis_tdata[31:24],mac_rx_axis_tdata[39:32],mac_rx_axis_tdata[47:40]};
        ip_dst_upper<= {mac_rx_axis_tdata[55:48], mac_rx_axis_tdata[63:56]};
    end
    else begin
        ip_src_addr <=  ip_src_addr;
        ip_checksum <=  ip_checksum;  
        ip_dst_upper <= ip_dst_upper;
    end
end

// Capture lower half of destination IP on the very first payload beat
always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        ip_dst_lower <= 16'h0;
        ip_dst_lower_captured  <= 1'b0;
    end 
    if (mac_rx_axis_tvalid && recv_ip_state == RECV_IP_HEADER2)
        ip_dst_lower_captured <= 1'b0;
    else if (mac_rx_axis_tvalid && (recv_ip_state == RECV_IP_PAYLOAD) && !ip_dst_lower_captured) begin
        ip_dst_lower <= {mac_rx_axis_tdata[7:0],mac_rx_axis_tdata[15:8]}; 
        ip_dst_lower_captured  <= 1'b1;
    end
    // Packet end → prepare for next packet
    if (mac_rx_axis_tlast && mac_rx_axis_tvalid) begin
        ip_dst_lower_captured <= 1'b0;
    end
end

// Assemble final destination address once per packet
always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn)
        ip_dst_addr <= 32'h0;
    // else if (recv_ip_state == RECV_IP_GOOD || recv_ip_state == RECV_IP_FAIL)
    else if (mac_rx_axis_tlast && mac_rx_axis_tvalid)
        ip_dst_addr <= {ip_dst_upper, ip_dst_lower};   // a8c0_7b01
end


assign recv_dst_ip_addr = ip_dst_addr;
assign recv_src_ip_addr = ip_src_addr;
assign ip_type          = ip_protocol;

/* **********************************************************************
 * 3. Calculate checksum
 **********************************************************************/
function    [15:0]  checksum_gen
  (
    input       [15:0]  dataina,
    input       [15:0]  datainb
  );
  
    reg [16:0]  sum ;

  begin
    sum = dataina[15:0] + datainb[15:0];
    checksum_gen = sum[16] ? sum[15:0] + 1 : sum[15:0];
  end
  
endfunction

function    [15:0]  checksum_plus
  (
    input       [15:0]  dataina,
    input       [15:0]  datainb,
    input       [15:0]  datainc,
    input       [15:0]  dataind
  );
  
  reg [15:0]  sum0;
  reg [15:0]  sum1;

  begin
    sum0 = checksum_gen(dataina , datainb);
    sum1 = checksum_gen(sum0    , datainc);
    checksum_plus = checksum_gen(sum1    , dataind);
  end
  
endfunction

reg [15:0]  checksum_header0    =   0;
reg [15:0]  checksum_header1    =   0;
reg [15:0]  checksum_header     =   0;


always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        checksum_header0 <= 0;
        checksum_header1 <= 0;
        checksum_header  <= 0;
    end
    else if (mac_rx_axis_tvalid && (recv_ip_state == RECV_IP_HEADER0)) begin
        checksum_header0 <= checksum_plus({mac_rx_axis_tdata[7:0]   , mac_rx_axis_tdata[15:8]},
                                          {mac_rx_axis_tdata[23:16] , mac_rx_axis_tdata[31:24]},
                                          {mac_rx_axis_tdata[39:32] , mac_rx_axis_tdata[47:40]},
                                          {mac_rx_axis_tdata[55:48] , mac_rx_axis_tdata[63:56]});
    end
    else if (mac_rx_axis_tvalid && (recv_ip_state == RECV_IP_HEADER1)) begin
        checksum_header1 <= checksum_plus({mac_rx_axis_tdata[7:0]   , mac_rx_axis_tdata[15:8]},
                                          {mac_rx_axis_tdata[23:16] , mac_rx_axis_tdata[31:24]},
                                          {mac_rx_axis_tdata[39:32] , mac_rx_axis_tdata[47:40]},
                                          {mac_rx_axis_tdata[55:48] , mac_rx_axis_tdata[63:56]});
    end  
    else if (mac_rx_axis_tvalid && (recv_ip_state == RECV_IP_HEADER2)) begin
        checksum_header  <= checksum_plus({mac_rx_axis_tdata[7:0]   , mac_rx_axis_tdata[15:8]},
                                          {mac_rx_axis_tdata[23:16] , mac_rx_axis_tdata[31:24]},
                                           checksum_header1,
                                           checksum_header0);
    end  
    // else if(mac_rx_axis_tlast)begin
    //     checksum_header0 <= 0;
    //     checksum_header1 <= 0;
    //     checksum_header  <= 0;        
    // end   
    else begin
        checksum_header0 <= checksum_header0;
        checksum_header1 <= checksum_header1;
        checksum_header  <= checksum_header;
    end 
end

/* **********************************************************************
 * 4. read ip data packet
 **********************************************************************/
reg     [63:0]  rx_tdata_reg=   0;
reg     [7:0]   rx_tkeep_reg=   0;
reg             rx_tuser_reg=   0;

reg     [63:0]  ip_tdata    =   0;
reg     [7:0]   ip_tkeep    =   0;
reg             ip_tvalid   =   0;
reg             ip_tlast    =   0;
reg             ip_tuser    =   0;

always @(posedge rx_axis_aclk) begin
    rx_tdata_reg <= mac_rx_axis_tdata;
    rx_tkeep_reg <= mac_rx_axis_tkeep;
    rx_tuser_reg <= mac_rx_axis_tuser;   
end


always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        ip_tdata <= 0;
    end
    else if (recv_ip_state == RECV_IP_PAYLOAD & mac_rx_axis_tvalid) begin
        // ip_tdata <= {mac_rx_axis_tdata[31:0], rx_tdata_reg[63:32]};
        ip_tdata <= mac_rx_axis_tdata;
    end
    else begin
        ip_tdata <= ip_tdata;
    end
end

always @(posedge rx_axis_aclk) begin
    if (~rx_axis_aresetn) begin
        ip_tvalid <= 0;
        ip_tlast  <= 0;
        ip_tuser  <= 0;
        ip_tkeep  <= 0;
    end
    else if(local_ip_addr != recv_dst_ip_addr || local_mac_addr != recv_dst_mac_addr)begin
        ip_tvalid <= 0;
        ip_tlast  <= 0;
        ip_tuser  <= 0;
        ip_tkeep  <= 0;        
    end
    else if (recv_ip_state == RECV_IP_PAYLOAD) begin
        if ((mac_rx_axis_tkeep[7:4] == 0) && (mac_rx_axis_tkeep[3:0] != 0)) begin
            ip_tvalid <= 1;
            ip_tlast  <= 1;
            ip_tkeep  <= {mac_rx_axis_tkeep[3:0],4'b1111};
            if (checksum_header == 16'hffff) begin
                ip_tuser <= mac_rx_axis_tuser;
            end
            else begin
                ip_tuser <= 1;
            end
        end
        else if (mac_rx_axis_tkeep[7:4] != 4'b0) begin
            ip_tvalid <= 1;
            ip_tlast  <= 0;    
            ip_tkeep  <= 8'hff;   
            ip_tuser  <= 0;     
        end
        else begin

        end
    end
    else if (recv_ip_state == RECV_IP_GOOD || recv_ip_state == RECV_IP_FAIL) begin
        if (ip_tlast) begin
            ip_tvalid <= 0;
            ip_tlast  <= 0;
            ip_tuser  <= 0;
            ip_tkeep  <= 0;                
        end
        else begin
            ip_tvalid  <= 1;
            ip_tlast   <= 1;
            ip_tkeep   <= {4'b0000, rx_tkeep_reg[7:4]};
            if (checksum_header == 16'hffff) begin
                ip_tuser <= rx_tuser_reg;
            end
            else begin
                ip_tuser <= 1;
            end           
        end
     
    end
    else begin
        ip_tvalid <= 0;
        ip_tlast  <= 0;
        ip_tuser  <= 0;
        ip_tkeep  <= 0;        
    end
end

/* **********************************************************************
 * 5. Delay all the data by a few beats and then output it
 **********************************************************************/

localparam  DLY_LENGTH  =   3;

reg     [63:0]  ip_tdata_reg    [0 : DLY_LENGTH - 1];
reg     [7:0]   ip_tkeep_reg    [0 : DLY_LENGTH - 1];
reg             ip_tvalid_reg   [0 : DLY_LENGTH - 1];
reg             ip_tuser_reg    [0 : DLY_LENGTH - 1];
reg             ip_tlast_reg    [0 : DLY_LENGTH - 1];

genvar i;

generate
    for (i = 0; i < DLY_LENGTH ; i = i + 1) begin : shifter
        always @(posedge rx_axis_aclk) begin
            if (~rx_axis_aresetn) begin
                ip_tdata_reg[i]    <= 0;
                ip_tkeep_reg[i]    <= 0;
                ip_tvalid_reg[i]   <= 0;
                ip_tuser_reg[i]    <= 0;
                ip_tlast_reg[i]    <= 0;
            end
            else begin
                ip_tdata_reg[i]  <= (i == 0) ? ip_tdata  : ip_tdata_reg[i - 1];
                ip_tkeep_reg[i]  <= (i == 0) ? ip_tkeep  : ip_tkeep_reg[i - 1];
                ip_tvalid_reg[i] <= (i == 0) ? ip_tvalid : ip_tvalid_reg[i - 1];
                ip_tuser_reg[i]  <= (i == 0) ? ip_tuser  : ip_tuser_reg[i - 1];
                ip_tlast_reg[i]  <= (i == 0) ? ip_tlast  : ip_tlast_reg[i - 1];
            end
        end
    end
endgenerate

assign ip_rx_axis_tdata  = ip_tdata_reg[DLY_LENGTH - 1];
assign ip_rx_axis_tkeep  = ip_tkeep_reg[DLY_LENGTH - 1];
assign ip_rx_axis_tvalid = ip_tvalid_reg[DLY_LENGTH - 1];
assign ip_rx_axis_tuser  = ip_tuser_reg[DLY_LENGTH - 1];
assign ip_rx_axis_tlast  = ip_tlast_reg[DLY_LENGTH - 1];

endmodule


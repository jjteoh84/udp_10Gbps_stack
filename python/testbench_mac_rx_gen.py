from pathlib import Path
import struct

# ==========================
# FPGA 配置（接收端为主机）
# ==========================
SRC_MAC = bytes([0xAC, 0x70, 0x12, 0x56, 0x41, 0x23])  # 主机 MAC
DST_MAC = bytes([0xAC, 0x14, 0x45, 0xFF, 0xAF, 0xC4])  # FPGA MAC
SRC_IP  = bytes([192, 168, 1, 149])
DST_IP  = bytes([192, 168, 1, 144])
UDP_SRC_PORT = 0x4554
UDP_DST_PORT = 0x8080

OUTPUT_FILE = Path("./mac-rx-reply.bin")

def ip_checksum(header: bytes) -> int:
    """计算 IP 校验和"""
    header = header[:10] + b'\x00\x00' + header[12:]
    if len(header) % 2 != 0:
        header += b'\x00'
    s = 0
    for i in range(0, len(header), 2):
        s += (header[i] << 8) + header[i+1]
        s = (s & 0xFFFF) + (s >> 16)
    return (~s) & 0xFFFF

def udp_checksum(src_ip, dst_ip, udp_header, payload):
    """计算 UDP 校验和"""
    pseudo = src_ip + dst_ip + bytes([0]) + bytes([17]) + struct.pack("!H", len(udp_header)+len(payload))
    total = pseudo + udp_header + payload
    if len(total) % 2 != 0:
        total += b'\x00'
    s = 0
    for i in range(0, len(total), 2):
        s += (total[i] << 8) + total[i+1]
        s = (s & 0xFFFF) + (s >> 16)
    return (~s) & 0xFFFF

# ==========================
# payload 列表（主机要回复 FPGA 的数据）
# ==========================
frames_payload = [
    b"Welcome ",
    b"to the Xilinx Wi",
    b"ki! Xilinx is now part",
    b" of AMD!\n\nThe purp",
    b"ose of the wiki is to ",
    b"provide you with the tools",
    b" you need to complete projects",
    b" and tasks which use Xilinx products.",
    b"\n\nIf there are any technical questions",
    b" on the subjects contained in this Wiki please",
    b" ask them on the boards located at the AMD Adaptive Support Community.",
    b"\nThere are multiple boards on the Xilinx Community Forums.",
    b" Please try to select the best one to fit your topic.",
    b"\nIf there are any issues with this Wiki itself or its infrastructure please report them here.",
    b"\nClick on any of the pictures or links to get started and find more information on the topic you are looking for.",
    b"\nPlease help us improve the depth and quality of information on this wiki.",
    b" You may provide us feedback by sending email to wiki-help @ xilinx.com."
]

with OUTPUT_FILE.open("wb") as f:
    for payload in frames_payload:
        # ========== 构建 UDP 头 ==========
        udp_len = 8 + len(payload)
        udp_hdr = struct.pack(">HHHH", UDP_SRC_PORT, UDP_DST_PORT, udp_len, 0)
        udp_chk = udp_checksum(SRC_IP, DST_IP, udp_hdr[:6]+b'\x00\x00', payload)
        udp_hdr = struct.pack(">HHHH", UDP_SRC_PORT, UDP_DST_PORT, udp_len, udp_chk)

        # ========== 构建 IP 头 ==========
        version_ihl = 0x45
        tos = 0
        total_len = 20 + udp_len
        identification = 0x0000
        flags_fragment = 0x4000  # Don't Fragment
        ttl = 64
        protocol = 17  # UDP
        hdr_checksum = 0
        ip_hdr = struct.pack(">BBHHHBBH4s4s",
                             version_ihl, tos, total_len, identification,
                             flags_fragment, ttl, protocol, hdr_checksum,
                             SRC_IP, DST_IP)
        ip_chk = ip_checksum(ip_hdr)
        ip_hdr = struct.pack(">BBHHHBBH4s4s",
                             version_ihl, tos, total_len, identification,
                             flags_fragment, ttl, protocol, ip_chk,
                             SRC_IP, DST_IP)

        # ========== 构建 MAC 头 ==========
        eth_type = struct.pack(">H", 0x0800)
        mac_hdr = DST_MAC + SRC_MAC + eth_type

        # ========== 拼接完整帧 ==========
        frame = mac_hdr + ip_hdr + udp_hdr + payload

        # 64-bit 对齐，不足补零
        if len(frame) % 8 != 0:
            frame += b'\x00' * (8 - len(frame) % 8)

        f.write(frame)

print(f"Generated MAC reply frames in {OUTPUT_FILE.resolve()}")

#!/usr/bin/env python3
"""
FPGA 10G UDP Payload Generator Remote Control
AXI-Lite over UDP — Port 0xC0DE (49406)
Now 100% robust — no crashes, no NoneType errors
"""

import socket
import struct
import sys
import time
from typing import Optional

FPGA = "192.168.1.123"
PORT = 49406  # 0xC0DE

# =============================================
# REGISTER MAP
# =============================================
REGISTERS = {
    0:  ("mode",               True,  "0=idle,1=hello,2=inc64,3=prbs31,4=stability,5=sweep,6=random_gap,7=min_ipg,8=jumbo,9=tiny"),
    1:  ("pkt_len_bytes",      True,  "UDP payload length in bytes"),
    2:  ("ipg_cycles",         True,  "Inter-packet gap in clock cycles"),
    3:  ("total_packets",      True,  "0 = infinite"),
    4:  ("reset_counters",     True,  "Write any value to reset pkt_sent/seq_num"),
    10: ("pkt_sent",           False, "Packets transmitted"),
    11: ("seq_num_low",        False, "Sequence number [31:0]"),
    12: ("seq_num_high",       False, "Sequence number [63:32]"),
}

MODE_NAMES = {v: k for k, v in enumerate("idle hello inc64 prbs31 stability sweep random_gap min_ipg jumbo tiny".split())}

def crc16(data: bytes) -> int:
    crc = 0xFFFF
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = (crc << 1) ^ 0x1021 if crc & 0x8000 else crc << 1
            crc &= 0xFFFF
    return crc

def udp_write(addr: int, value: int) -> bool:
    payload = struct.pack(">HHHL", 0xC0DE, addr, 0, value)
    crc = crc16(payload[:6])
    pkt = struct.pack(">HHHLH", 0xC0DE, addr, 0, value, crc)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(0.2)
    try:
        s.sendto(pkt, (FPGA, PORT))
        return True
    except Exception:
        return False
    finally:
        s.close()

def udp_read(addr: int) -> Optional[int]:
    payload = struct.pack(">HHHL", 0xC0DE, addr, 0, 0)
    crc = crc16(payload[:6])
    pkt = struct.pack(">HHHLH", 0xC0DE, addr, 0, 0, crc)
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(0.2)
    try:
        s.sendto(pkt, (FPGA, PORT))
        data, _ = s.recvfrom(1500)
        if len(data) >= 8 and struct.unpack(">H", data[:2])[0] == 0xC0DE:
            return struct.unpack(">L", data[4:8])[0]
    except socket.timeout:
        return None
    except Exception:
        return None
    finally:
        s.close()
    return None

# =============================================
# High-level functions
# =============================================
def write_reg(addr: int, value: int, name: str = "") -> None:
    print(f"Writing {name or addr}: {value} ... ", end="", flush=True)
    if not udp_write(addr, value):
        print("SEND FAILED")
        return

    # Read-back with retry
    for _ in range(3):
        time.sleep(0.01)
        readback = udp_read(addr)
        if readback is not None:
            expected = value & 0xFFFFFFFF
            if readback == expected:
                print("PASS")
                return
            else:
                print(f"FAIL (got 0x{readback:08X}, expected 0x{expected:08X})")
                return
        time.sleep(0.02)
    print("READBACK TIMEOUT")

def read_reg(addr: int, name: str = "") -> None:
    val = udp_read(addr)
    if val is None:
        print(f"Reading {name or addr}: TIMEOUT")
        return

    if addr == 0:
        mode_num = val & 0xF
        mode_str = next((k for k, v in MODE_NAMES.items() if v == mode_num), "UNKNOWN")
        print(f"{name or addr}: 0x{val:08X} → {mode_str.upper()} (mode {mode_num})")
    elif addr in (11, 12):
        low = udp_read(11) or 0
        high = udp_read(12) or 0
        seq = (high << 32) | low
        print(f"seq_num: {seq:,} (0x{seq:016X})")
    else:
        print(f"{name or addr}: 0x{val:08X} ({val:,})")

def set_mode(mode_str: str) -> None:
    mode_str = mode_str.lower()
    if mode_str not in MODE_NAMES:
        print(f"Unknown mode: {mode_str}")
        print("Available:", ", ".join(MODE_NAMES.keys()))
        return
    write_reg(0, MODE_NAMES[mode_str], f"mode → {mode_str.upper()}")

# =============================================
# CLI
# =============================================
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 firmware_control.py set mode inc64")
        print("  python3 firmware_control.py set pkt_len_bytes 1472")
        print("  python3 firmware_control.py set total_packets 1000")
        print("  python3 firmware_control.py get pkt_sent")
        print("  python3 firmware_control.py monitor")
        sys.exit(1)

    cmd = sys.argv[1].lower()

    if cmd == "set":
        if len(sys.argv) != 4:
            print("Usage: set <reg> <value>")
            sys.exit(1)
        reg_name = sys.argv[2].lower()
        arg = sys.argv[3]

        if reg_name == "mode":
            set_mode(arg)
            sys.exit(0)

        try:
            value = int(arg)
        except:
            print("Value must be integer")
            sys.exit(1)

        found = False
        for addr, (name, writable, _) in REGISTERS.items():
            if name == reg_name and writable:
                write_reg(addr, value, name)
                found = True
                break
        if not found:
            print(f"Unknown or read-only register: {reg_name}")

    elif cmd == "get":
        if len(sys.argv) != 3:
            print("Usage: get <reg>")
            sys.exit(1)
        reg_name = sys.argv[2].lower()
        for addr, (name, _, _) in REGISTERS.items():
            if name == reg_name:
                read_reg(addr, name)
                sys.exit(0)
        print(f"Unknown register: {reg_name}")

    elif cmd == "monitor":
        print("Live packet counter (Ctrl+C to stop)")
        try:
            while True:
                val = udp_read(10)
                if val is not None:
                    print(f"\rPackets sent: {val:,}     ", end="", flush=True)
                time.sleep(0.2)
        except KeyboardInterrupt:
            print("\nStopped.")

    else:
        print("Unknown command. Use: set, get, monitor")
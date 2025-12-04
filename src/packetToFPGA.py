#!/usr/bin/env python3
import socket
import time

DEST_IP   = "192.168.1.123"
DEST_PORT = 8080                  # whatever port your FPGA listens on
INTERVAL  = 0.1                 # change this: 0.0001 sec = 10 kHz, 0.000001 sec = 1 MHz, etc.

# Exact 8 bytes of 0xAA → 0xAAAAAAAAAAAAAAAA (64 bits)
#PAYLOAD = b"\xAA\xAA\xAA\xAA\xAA\xAA\xAA\xAA"   # this is exactly 64h'AAAAAAAAAAAAAAAA in Verilog notation
PAYLOAD = b"\xAA" * 12        # try 9, 10, 11, 12, 16, 32 bytes


sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

print(f"Sending 8 bytes of 0xAAAAAAAAAAAAAAAA to {DEST_IP}:{DEST_PORT}")
print(f"Interval: {INTERVAL*1_000_000:.1f} µs → {1/INTERVAL:,.0f} packets/sec")
print("Ctrl+C to stop")

count = 0
try:
    while True:
        count += 1
        sock.sendto(PAYLOAD, (DEST_IP, DEST_PORT))
        # optional: add counter after the pattern if you need packet numbering
        # sock.sendto(PAYLOAD + count.to_bytes(4, 'little'), (DEST_IP, DEST_PORT))

        if count % 10 == 0:
            print(f"Sent {count:,} packets")

        time.sleep(INTERVAL)
except KeyboardInterrupt:
    print("\nStopped")
finally:
    sock.close()
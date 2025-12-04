// udp_throughput_rawSocket_with_debug.cpp
// Compile: g++ -std=c++17 -O3 -Wall udp_throughput_rawSocket_with_debug.cpp -o udp_raw_debug
// Run:    sudo ./udp_raw_debug

#include <iostream>
#include <iomanip>
#include <chrono>
#include <vector>
#include <cstring>
#include <unistd.h>
#include <arpa/inet.h>
#include <net/ethernet.h>
#include <net/if.h>
#include <sys/socket.h>
#include <linux/if_packet.h>

constexpr const char* IF_NAME   = "enp1s0f0";
constexpr uint16_t    DST_PORT  = 32775;

struct Stats {
    uint64_t bytes   = 0;
    uint64_t packets = 0;
    std::chrono::steady_clock::time_point last_print;
};

// Helper: print hex dump
void hex_dump(const uint8_t* data, size_t len, const char* prefix = "") {
    std::cout << prefix;
    for (size_t i = 0; i < len; ++i) {
        std::cout << std::hex << std::setw(2) << std::setfill('0') << (int)data[i] << ' ';
        if ((i + 1) % 16 == 0) std::cout << "\n" << prefix;
    }
    if (len % 16) std::cout << "\n";
    std::cout << std::dec;
}

int main() {
    int sock = socket(AF_PACKET, SOCK_RAW, htons(ETH_P_ALL));
    if (sock < 0) { perror("socket"); return 1; }

    struct sockaddr_ll sll{};
    sll.sll_family   = AF_PACKET;
    sll.sll_ifindex  = if_nametoindex(IF_NAME);
    sll.sll_protocol = htons(ETH_P_ALL);

    if (bind(sock, (struct sockaddr*)&sll, sizeof(sll)) < 0) {
        perror("bind"); close(sock); return 1;
    }

    std::cout << "FPGA → Linux raw packet debugger + throughput\n"
              << "Interface: " << IF_NAME << " | Filter port: " << DST_PORT << "\n\n";

    std::vector<uint8_t> buf(65536);
    Stats total, window;
    window.last_print = std::chrono::steady_clock::now();

    while (true) {
        int len = recv(sock, buf.data(), buf.size(), 0);
        if (len < 42) continue;

        uint16_t dst_port = ntohs(*(uint16_t*)(buf.data() + 36));
        if (dst_port != DST_PORT) continue;

        uint16_t ip_total_len = ntohs(*(uint16_t*)(buf.data() + 16));
        uint16_t udp_len      = ntohs(*(uint16_t*)(buf.data() + 38));
        uint16_t payload_len  = udp_len - 8;

        const uint8_t* eth_hdr = buf.data();
        const uint8_t* ip_hdr  = buf.data() + 14;
        const uint8_t* udp_hdr = buf.data() + 34;
        const uint8_t* payload = buf.data() + 42;

        // Print full raw packet in hex
        std::cout << "\n=== RAW PACKET RECEIVED (len=" << len << " bytes) ===\n";
        hex_dump(buf.data(), len, "    ");

        // Decode key fields
        std::cout << "    Ethernet Src MAC : "
                  << std::hex << std::setw(2) << std::setfill('0')
                  << (int)eth_hdr[6] << ':' << (int)eth_hdr[7] << ':' << (int)eth_hdr[8]
                  << ':' << (int)eth_hdr[9] << ':' << (int)eth_hdr[10] << ':' << (int)eth_hdr[11]
                  << std::dec << "\n";

        std::cout << "    IP Src  : " << (int)ip_hdr[12] << '.' << (int)ip_hdr[13]
                  << '.' << (int)ip_hdr[14] << '.' << (int)ip_hdr[15] << "\n";
        std::cout << "    IP Dst  : " << (int)ip_hdr[16] << '.' << (int)ip_hdr[17]
                  << '.' << (int)ip_hdr[18] << '.' << (int)ip_hdr[19] << "\n";

        std::cout << "    UDP Src Port : " << ntohs(*(uint16_t*)(udp_hdr + 0)) << "\n";
        std::cout << "    UDP Dst Port : " << ntohs(*(uint16_t*)(udp_hdr + 2)) << "\n";
        std::cout << "    IP Total Len : " << ip_total_len << " bytes\n";
        std::cout << "    UDP Length   : " << udp_len << " bytes\n";
        std::cout << "    Payload Len  : " << payload_len << " bytes\n";

        // Print payload as ASCII if printable
        std::cout << "    Payload (ASCII): \"";
        for (size_t i = 0; i < payload_len && i < 64; ++i) {
            char c = payload[i];
            std::cout << (c >= 32 && c <= 126 ? c : '.');
        }
        if (payload_len > 64) std::cout << "...";
        std::cout << "\"\n";

        // Update stats
        total.bytes += payload_len;
        total.packets++;
        window.bytes += payload_len;
        window.packets++;

        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>
                       (now - window.last_print).count();

        if (elapsed >= 1000) {
            double sec = elapsed / 1000.0;
            double mbps = (window.bytes * 8.0) / (sec * 1e6);
            double kpps = window.packets / (sec * 1000.0);
            std::cout << "\n↑ THROUGHPUT: " << std::fixed << std::setprecision(3)
                      << mbps << " Mbps | " << kpps << " kpps | "
                      << window.packets << " pkts | avg "
                      << (window.bytes / (double)window.packets) << " B/pkt\n\n";

            window.bytes = window.packets = 0;
            window.last_print = now;
        }
    }

    close(sock);
    return 0;
}
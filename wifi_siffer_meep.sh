#!/bin/bash

# Wi-Fi Tools Script for Raspberry Pi Zero W
# Includes automatic package installation

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Required packages
REQUIRED_PKGS=("aircrack-ng" "tshark" "wireless-tools" "iw")

# Function to check and install packages
install_dependencies() {
    echo "[*] Checking for required packages..."
    NEEDED_PKGS=()
    
    for pkg in "${REQUIRED_PKGS[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg "; then
            NEEDED_PKGS+=("$pkg")
        fi
    done
    
    if [ ${#NEEDED_PKGS[@]} -ne 0 ]; then
        echo "[*] Installing missing packages: ${NEEDED_PKGS[*]}"
        apt-get update
        apt-get install -y "${NEEDED_PKGS[@]}"
        
        # Verify installation
        for pkg in "${NEEDED_PKGS[@]}"; do
            if ! dpkg -l | grep -q "^ii  $pkg "; then
                echo "[-] Failed to install $pkg"
                exit 1
            fi
        done
        echo "[+] All required packages installed"
    else
        echo "[+] All required packages are already installed"
    fi
}

# Default values
INTERFACE="wlan0"
CHANNEL=6
DURATION=30
OUTPUT_FILE="wifi_capture.pcap"
SSID_TO_PROBE=""

# Function to set monitor mode
set_monitor_mode() {
    echo "[*] Configuring $INTERFACE in monitor mode..."
    
    # Check if interface exists
    if ! iwconfig $INTERFACE 2>/dev/null | grep -q "IEEE 802.11"; then
        echo "[-] Error: Interface $INTERFACE not found or not a WiFi interface"
        exit 1
    fi
    
    # Bring down interface
    ifconfig $INTERFACE down
    
    # Set monitor mode
    if ! iwconfig $INTERFACE mode monitor 2>/dev/null; then
        echo "[-] Failed to set monitor mode on $INTERFACE"
        ifconfig $INTERFACE up
        exit 1
    fi
    
    # Bring interface up
    ifconfig $INTERFACE up
    
    # Set channel
    iwconfig $INTERFACE channel $CHANNEL
    
    echo "[+] $INTERFACE now in monitor mode on channel $CHANNEL"
}

# Function to restore managed mode
restore_managed_mode() {
    echo "[*] Restoring $INTERFACE to managed mode..."
    ifconfig $INTERFACE down
    iwconfig $INTERFACE mode managed
    ifconfig $INTERFACE up
    echo "[+] $INTERFACE restored to managed mode"
}

# Function to send probe requests
send_probes() {
    if [ -z "$SSID_TO_PROBE" ]; then
        return
    fi
    
    echo "[*] Sending probe requests for SSID: $SSID_TO_PROBE"
    
    # Create a temporary MAC address
    FAKE_MAC=$(printf '00:00:%02X:%02X:%02X:%02X\n' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
    
    # Change MAC address temporarily
    ifconfig $INTERFACE down
    ifconfig $INTERFACE hw ether $FAKE_MAC
    ifconfig $INTERFACE up
    
    # Send probe requests using aireplay-ng
    aireplay-ng -9 -e "$SSID_TO_PROBE" $INTERFACE
    
    # Restore original MAC (will be restored fully when returning to managed mode)
}

# Function to capture packets
capture_packets() {
    echo "[*] Starting packet capture for $DURATION seconds..."
    echo "[*] Output will be saved to $OUTPUT_FILE"
    
    # Capture with tshark if available, otherwise use airodump-ng
    if command -v tshark &>/dev/null; then
        tshark -i $INTERFACE -a duration:$DURATION -w $OUTPUT_FILE \
            -Y "wlan.fc.type_subtype == 0x08 || wlan.fc.type_subtype == 0x05 || wlan.fc.type_subtype == 0x04"
    else
        airodump-ng $INTERFACE --channel $CHANNEL --write $OUTPUT_FILE --output-format pcap &
        AIRODUMP_PID=$!
        sleep $DURATION
        kill $AIRODUMP_PID
    fi
    
    echo "[+] Capture completed"
}

# Main execution
cleanup() {
    restore_managed_mode
    exit
}

trap cleanup EXIT INT TERM

# Install dependencies first
install_dependencies

# Parse arguments
while getopts "i:c:d:o:s:h" opt; do
    case $opt in
        i) INTERFACE="$OPTARG" ;;
        c) CHANNEL="$OPTARG" ;;
        d) DURATION="$OPTARG" ;;
        o) OUTPUT_FILE="$OPTARG" ;;
        s) SSID_TO_PROBE="$OPTARG" ;;
        h) 
            echo "Usage: $0 [-i interface] [-c channel] [-d duration] [-o output] [-s ssid]"
            echo "  -i: Wireless interface (default: wlan0)"
            echo "  -c: Channel to monitor (default: 6)"
            echo "  -d: Capture duration in seconds (default: 30)"
            echo "  -o: Output file (default: wifi_capture.pcap)"
            echo "  -s: SSID to send probe requests for"
            exit 0
            ;;
        *) 
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Main execution
set_monitor_mode
send_probes
capture_packets

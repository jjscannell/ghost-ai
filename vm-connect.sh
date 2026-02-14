#!/bin/bash
#
# Ghost AI - VM Connection Helper
# Run this on macOS HOST to connect and manage the VM
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[VM-CONNECT]${NC} $1"; }
log_success() { echo -e "${GREEN}[VM-CONNECT] ✓${NC} $1"; }
log_error() { echo -e "${RED}[VM-CONNECT] ✗${NC} $1"; }
log_warning() { echo -e "${YELLOW}[VM-CONNECT] ⚠${NC} $1"; }

VM_USER="${1:-ubuntu}"  # Default to 'ubuntu', or pass username as arg
VM_IP=""

# Banner
echo -e "${CYAN}"
cat << 'EOF'
  ____  _               _      _    ___
 / ___|| |__   ___  ___| |_   / \  |_ _|
| |  _ | '_ \ / _ \/ __| __| / _ \  | |
| |_| || | | | (_) \__ \ |_ / ___ \ | |
 \____||_| |_|\___/|___/\__/_/   \_\___|

       VM Connection & Management
EOF
echo -e "${NC}"

# Find VM IP
log "Searching for Linux VM IP address..."
echo ""

# Try to find IP via arp (if VM has been on network)
log "Checking network for Ubuntu VM..."

# Common Ubuntu VM IP patterns for UTM (usually 192.168.64.x)
for ip in 192.168.64.{2..50}; do
    if ping -c 1 -W 1 $ip &>/dev/null; then
        # Check if SSH is available
        if nc -z -w 1 $ip 22 2>/dev/null; then
            log_success "Found VM at: $ip (SSH port 22 open)"
            VM_IP=$ip
            break
        fi
    fi
done

if [ -z "$VM_IP" ]; then
    log_warning "Could not auto-detect VM IP"
    echo ""
    echo "Please find your VM's IP manually:"
    echo "  1. Inside VM terminal, run: ip addr show"
    echo "  2. Look for inet address (usually 192.168.64.x)"
    echo ""
    read -p "Enter VM IP address: " VM_IP

    if [ -z "$VM_IP" ]; then
        log_error "No IP provided. Exiting."
        exit 1
    fi
fi

echo ""
echo "========================================"
echo "  Connection Details"
echo "========================================"
echo "VM IP:   $VM_IP"
echo "User:    $VM_USER"
echo "========================================"
echo ""

# Menu
while true; do
    echo "What would you like to do?"
    echo ""
    echo "  1) SSH into VM"
    echo "  2) Run vm-quick-install.sh in VM (automated)"
    echo "  3) Check VM status"
    echo "  4) Copy files to VM"
    echo "  5) Start OpenClaw in VM"
    echo "  6) View Ollama models in VM"
    echo "  7) Exit"
    echo ""
    read -p "Select option [1-7]: " choice

    case $choice in
        1)
            log "Connecting to VM..."
            ssh "${VM_USER}@${VM_IP}"
            ;;
        2)
            log "Running automated installation in VM..."
            echo ""
            log_warning "This will install: Ollama, OpenClaw, Whisper, and AI models"
            read -p "Continue? [y/N]: " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                # Copy script to VM if needed
                scp ~/Dev/Ghost-AI/vm-quick-install.sh "${VM_USER}@${VM_IP}:/tmp/"

                # Run installation
                ssh "${VM_USER}@${VM_IP}" "chmod +x /tmp/vm-quick-install.sh && /tmp/vm-quick-install.sh"

                log_success "Installation complete!"
            fi
            ;;
        3)
            log "Checking VM status..."
            echo ""
            ssh "${VM_USER}@${VM_IP}" "uname -a && free -h && df -h / && systemctl --user status ollama --no-pager 2>/dev/null || echo 'Ollama not installed yet'"
            echo ""
            ;;
        4)
            log "Copy files to VM..."
            read -p "Source path (local): " src
            read -p "Destination path (VM): " dst
            scp -r "$src" "${VM_USER}@${VM_IP}:${dst}"
            log_success "Files copied"
            ;;
        5)
            log "Starting OpenClaw in VM..."
            ssh "${VM_USER}@${VM_IP}" "cd ~/Dev/openclaw && npm start"
            ;;
        6)
            log "Checking Ollama models..."
            ssh "${VM_USER}@${VM_IP}" "ollama list 2>/dev/null || echo 'Ollama not installed yet'"
            echo ""
            ;;
        7)
            log "Goodbye!"
            exit 0
            ;;
        *)
            log_error "Invalid option"
            ;;
    esac

    echo ""
done

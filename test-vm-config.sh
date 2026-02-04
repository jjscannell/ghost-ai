#!/bin/bash
#
# Ghost AI System - VM Test Configuration
#
# This script creates and manages a QEMU virtual machine for testing
# the Ghost AI installation process without affecting real hardware.
#
# Requirements:
# - QEMU installed (apt install qemu-system-x86 qemu-utils)
# - ~300GB free disk space
# - 16GB+ RAM recommended (8GB minimum)
#
# Usage:
#   ./test-vm-config.sh create    - Create a new test VM disk
#   ./test-vm-config.sh boot-iso  - Boot from Ubuntu ISO for installation
#   ./test-vm-config.sh boot      - Boot the installed system
#   ./test-vm-config.sh snapshot  - Create a snapshot of current state
#   ./test-vm-config.sh restore   - Restore from latest snapshot
#   ./test-vm-config.sh clean     - Remove all VM files
#

set -e

# Configuration
VM_DIR="$HOME/ghost-ai-test-vm"
VM_DISK="$VM_DIR/ghost-ai-test.qcow2"
VM_SNAPSHOT="$VM_DIR/ghost-ai-snapshot.qcow2"
DISK_SIZE="256G"
RAM_SIZE="8G"
CPU_CORES="4"
UBUNTU_ISO="$VM_DIR/ubuntu-24.04-desktop-amd64.iso"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[VM]${NC} $1"; }
log_success() { echo -e "${GREEN}[VM] ✓${NC} $1"; }
log_error() { echo -e "${RED}[VM] ✗${NC} $1"; }
log_warning() { echo -e "${YELLOW}[VM] ⚠${NC} $1"; }

# Check dependencies
check_deps() {
    local missing=()

    command -v qemu-system-x86_64 &>/dev/null || missing+=("qemu-system-x86")
    command -v qemu-img &>/dev/null || missing+=("qemu-utils")

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing[*]}"
        log "Install with: sudo apt install ${missing[*]}"
        exit 1
    fi
}

# Create VM disk
create_vm() {
    check_deps
    mkdir -p "$VM_DIR"

    if [ -f "$VM_DISK" ]; then
        log_warning "VM disk already exists: $VM_DISK"
        read -p "Delete and recreate? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
        rm -f "$VM_DISK"
    fi

    log "Creating VM disk ($DISK_SIZE)..."
    qemu-img create -f qcow2 "$VM_DISK" "$DISK_SIZE"
    log_success "VM disk created: $VM_DISK"

    # Download Ubuntu ISO if not present
    if [ ! -f "$UBUNTU_ISO" ]; then
        log "Ubuntu ISO not found. Downloading..."
        wget -O "$UBUNTU_ISO" "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso"
        log_success "Ubuntu ISO downloaded"
    fi

    log ""
    log "VM created successfully!"
    log "Next: Run './test-vm-config.sh boot-iso' to install Ubuntu"
}

# Boot from ISO (for initial installation)
boot_iso() {
    check_deps

    if [ ! -f "$VM_DISK" ]; then
        log_error "VM disk not found. Run './test-vm-config.sh create' first"
        exit 1
    fi

    if [ ! -f "$UBUNTU_ISO" ]; then
        log_error "Ubuntu ISO not found at: $UBUNTU_ISO"
        log "Download it or run './test-vm-config.sh create'"
        exit 1
    fi

    log "Booting VM from Ubuntu ISO..."
    log "RAM: $RAM_SIZE, CPUs: $CPU_CORES"
    log ""
    log "=== INSTALLATION INSTRUCTIONS ==="
    log "1. Select 'Install Ubuntu' when prompted"
    log "2. Choose 'Erase disk and install Ubuntu'"
    log "3. Create user 'ghost' with your chosen password"
    log "4. After installation, shutdown and run './test-vm-config.sh boot'"
    log "================================="
    log ""

    qemu-system-x86_64 \
        -enable-kvm \
        -m "$RAM_SIZE" \
        -smp "$CPU_CORES" \
        -drive file="$VM_DISK",format=qcow2 \
        -cdrom "$UBUNTU_ISO" \
        -boot d \
        -vga virtio \
        -display gtk \
        -usb \
        -device usb-tablet \
        -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080,hostfwd=tcp::8188-:8188,hostfwd=tcp::11434-:11434 \
        -device virtio-net-pci,netdev=net0
}

# Boot installed system
boot() {
    check_deps

    if [ ! -f "$VM_DISK" ]; then
        log_error "VM disk not found. Run './test-vm-config.sh create' first"
        exit 1
    fi

    log "Booting Ghost AI test VM..."
    log "RAM: $RAM_SIZE, CPUs: $CPU_CORES"
    log ""
    log "Port forwarding:"
    log "  SSH:     localhost:2222  -> VM:22"
    log "  Kiwix:   localhost:8080  -> VM:8080"
    log "  ComfyUI: localhost:8188  -> VM:8188"
    log "  Ollama:  localhost:11434 -> VM:11434"
    log ""
    log "To SSH into VM: ssh -p 2222 ghost@localhost"
    log ""

    qemu-system-x86_64 \
        -enable-kvm \
        -m "$RAM_SIZE" \
        -smp "$CPU_CORES" \
        -drive file="$VM_DISK",format=qcow2 \
        -vga virtio \
        -display gtk \
        -usb \
        -device usb-tablet \
        -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080,hostfwd=tcp::8188-:8188,hostfwd=tcp::11434-:11434 \
        -device virtio-net-pci,netdev=net0
}

# Create snapshot
snapshot() {
    check_deps

    if [ ! -f "$VM_DISK" ]; then
        log_error "VM disk not found"
        exit 1
    fi

    log "Creating snapshot..."
    cp "$VM_DISK" "$VM_SNAPSHOT"
    log_success "Snapshot created: $VM_SNAPSHOT"
}

# Restore snapshot
restore() {
    if [ ! -f "$VM_SNAPSHOT" ]; then
        log_error "No snapshot found"
        exit 1
    fi

    log "Restoring from snapshot..."
    cp "$VM_SNAPSHOT" "$VM_DISK"
    log_success "VM restored from snapshot"
}

# Headless mode (for CI/automated testing)
boot_headless() {
    check_deps

    if [ ! -f "$VM_DISK" ]; then
        log_error "VM disk not found"
        exit 1
    fi

    log "Booting in headless mode..."
    log "Connect via SSH: ssh -p 2222 ghost@localhost"
    log "Or VNC: localhost:5900"

    qemu-system-x86_64 \
        -enable-kvm \
        -m "$RAM_SIZE" \
        -smp "$CPU_CORES" \
        -drive file="$VM_DISK",format=qcow2 \
        -nographic \
        -vnc :0 \
        -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080,hostfwd=tcp::8188-:8188,hostfwd=tcp::11434-:11434 \
        -device virtio-net-pci,netdev=net0 \
        -daemonize

    log_success "VM started in background"
    log "PID file: /tmp/ghost-ai-vm.pid"
}

# Clean up
clean() {
    log_warning "This will delete all VM files!"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$VM_DIR"
        log_success "VM files cleaned"
    fi
}

# Show usage
usage() {
    echo "Ghost AI System - VM Test Configuration"
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  create      Create a new test VM disk and download Ubuntu ISO"
    echo "  boot-iso    Boot from Ubuntu ISO (for initial installation)"
    echo "  boot        Boot the installed system"
    echo "  headless    Boot in headless mode (SSH/VNC access)"
    echo "  snapshot    Create a snapshot of current VM state"
    echo "  restore     Restore VM from latest snapshot"
    echo "  clean       Remove all VM files"
    echo ""
    echo "Typical workflow:"
    echo "  1. $0 create      # Create VM and download Ubuntu"
    echo "  2. $0 boot-iso    # Install Ubuntu (create 'ghost' user)"
    echo "  3. $0 boot        # Boot installed system"
    echo "  4. Copy orchestrator.sh to VM and run it"
    echo "  5. $0 snapshot    # Save working state"
    echo ""
}

# Main
case "${1:-}" in
    create)     create_vm ;;
    boot-iso)   boot_iso ;;
    boot)       boot ;;
    headless)   boot_headless ;;
    snapshot)   snapshot ;;
    restore)    restore ;;
    clean)      clean ;;
    *)          usage ;;
esac

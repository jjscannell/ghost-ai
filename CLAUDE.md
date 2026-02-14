# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ghost AI System is an automated installer for creating offline, air-gapped AI systems. It supports both ARM64 (Apple Silicon) and x86_64 (Intel/AMD) architectures with hardware auto-detection. The system installs a complete local AI stack including Ollama, various LLM models, speech-to-text, text-to-speech, and optional image generation capabilities.

**Primary use case:** Create bootable USB drives or VM installations for offline AI assistance with network isolation ("ghost mode").

## Architecture

### Installation Flow

```
install.sh (main entry point)
    ↓
detect-hardware.sh (auto-detect CPU, RAM, GPU)
    ↓
orchestrator-{arm64,x86}.sh (architecture-specific installation)
    ↓
Complete offline AI system
```

### Key Design Decisions

1. **Dual Architecture Support**
   - `orchestrator-arm64.sh`: Optimized for Apple Silicon (M1/M2/M3/M4), ARM servers
     - Metal acceleration, efficient models (3B-14B), no CUDA
   - `orchestrator-x86.sh`: Intel/AMD with full GPU support
     - NVIDIA CUDA, AMD ROCm, full model range (3B-70B), ComfyUI for image generation

2. **RAM-Based Model Selection**
   - < 8GB: Minimal tier (llama3.2:3b only)
   - 8-16GB: Basic tier (3B, phi3:mini, codestral)
   - 16-32GB: Standard tier (adds llama3.1:8b, mistral:7b)
   - 32GB+: Performance tier (adds vision:11b, qwen2.5:14b)

3. **Hardware Detection**
   - Auto-detects CPU arch, RAM, GPU, disk space
   - Outputs to `/tmp/ghost-hardware.env` for consumption by orchestrators
   - Supports JSON output with `--json` flag

4. **Security Architecture**
   - Network isolation by default ("ghost mode")
   - Ollama listens only on localhost (127.0.0.1:11434)
   - Firewall configured to block all traffic
   - Network toggle scripts: `~/tools/network-{on,off}.sh`

## Common Development Commands

### Testing

```bash
# VM testing (recommended before USB creation)
# Platform-specific VM scripts:
./test-vm-config-linux.sh create      # Create VM on Linux (QEMU/KVM)
./test-vm-config-linux.sh boot-iso    # Install Ubuntu in VM
./test-vm-config-linux.sh boot        # Test installation
./test-vm-config-linux.sh snapshot    # Save working state
./test-vm-config-linux.sh restore     # Rollback to snapshot

# macOS variant
./test-vm-config-macos.sh create      # Uses Homebrew QEMU

# Windows variant (PowerShell)
.\test-vm-config-windows.ps1 create
```

### Installation

```bash
# Run unified installer (auto-detects hardware)
sudo ./install.sh

# Run architecture-specific orchestrator directly
sudo ./orchestrator-arm64.sh [config.json]
sudo ./orchestrator-x86.sh [config.json]

# Hardware detection only
./detect-hardware.sh              # Human-readable output
./detect-hardware.sh --json       # JSON output
```

### USB Creation (Legacy/Traditional Method)

```bash
# Prepare USB with Ubuntu and orchestrator
sudo ./preflight.sh /dev/sdX      # WARNING: Erases USB drive
```

## File Structure

### Core Scripts
- `install.sh` - Main installer with hardware detection (START HERE)
- `detect-hardware.sh` - Hardware detection utility
- `orchestrator-arm64.sh` - ARM64/Apple Silicon setup orchestrator
- `orchestrator-x86.sh` - x86_64/Intel/AMD setup orchestrator
- `orchestrator.sh` - Legacy orchestrator (kept for compatibility)
- `preflight.sh` - USB preparation for bootable Ghost AI system

### VM Testing Scripts
- `test-vm-config-linux.sh` - Linux VM testing (QEMU/KVM)
- `test-vm-config-macos.sh` - macOS VM testing (QEMU + HVF)
- `test-vm-config-windows.ps1` - Windows VM testing (PowerShell/QEMU)

### Documentation
- `README.md` - Comprehensive documentation
- `QUICKSTART.md` - Quick start guide (READ THIS FIRST for new users)
- `VM-TESTING.md` - Virtual machine testing guide
- `setup-guide.md` - Detailed manual setup instructions

### Configuration
- `sample-config.json` - Example configuration for installation customization

## Key Implementation Details

### Orchestrator Scripts

Both orchestrator scripts follow this pattern:
1. System package installation and updates
2. Ollama installation (architecture-specific binaries)
3. Parallel AI model downloads (3-4 at a time)
4. Node.js and OpenClaw (AI assistant) setup
5. Whisper (speech-to-text) installation
6. Piper TTS (text-to-speech, architecture-specific binary)
7. ComfyUI + Stable Diffusion (x86_64 only)
8. Wikipedia offline copy (optional, ~96GB, 1-3 hours)
9. Security configuration (firewall, network isolation)
10. Helper scripts and documentation creation

### Parallel Downloads

Model downloads use background processes:
```bash
# Pattern used in orchestrators
download_model() {
    ollama pull "$1" &
}
# Wait for all background downloads
wait
```

This reduces total installation time from 4-6 hours to 2-4 hours.

### Environment Variables

Hardware info passed to orchestrators:
- `DETECTED_ARCH` - CPU architecture (arm64 or x86_64)
- `DETECTED_RAM` - RAM in GB
- `DETECTED_GPU` - GPU type (nvidia, amd, apple, cpu)
- `DETECTED_DISK` - Available disk space in GB
- `RECOMMENDED_TIER` - Recommended installation tier

## Testing Strategy

**Always test in VMs before creating physical USB drives.**

VM testing workflow:
1. Create VM with 256GB virtual disk
2. Boot from Ubuntu ISO, install to virtual disk
3. SSH into VM (port 2222: `ssh -p 2222 ghost@localhost`)
4. Run orchestrator script inside VM
5. Verify all components: Ollama, models, services
6. Create snapshot for easy rollback
7. Test network isolation and "ghost mode"

Port forwarding in VMs:
- SSH: `localhost:2222`
- Ollama API: `localhost:11434`
- ComfyUI: `localhost:8188`
- Kiwix (Wikipedia): `localhost:8080`

## Modifying Installation

### Adding/Removing Models

Edit the orchestrator script (around line 200-300):
```bash
download_model "llama3.3:70b" "Llama 3.3 70B"
```

### Skipping Components

Comment out step sections:
```bash
# Skip ComfyUI installation
# step "Install ComfyUI and Stable Diffusion"
# ... (comment out entire section)
```

### Environment Variables for Customization

```bash
sudo PERF_TIER=standard INSTALL_WIKIPEDIA=false ./install.sh
```

## Important Notes

- **Script execution**: All main scripts must run as root (use `sudo`)
- **Logging**: Orchestrators log to `~/ghost-ai-setup-{arm64,x86}.log`
- **Error handling**: Scripts use `set -e` and exit on first error
- **Parallel safety**: Model downloads are parallelized but orchestrator steps are sequential
- **Architecture detection**: Uses `uname -m` (returns x86_64, aarch64, or arm64)
- **Config format**: JSON config files follow structure in `sample-config.json`

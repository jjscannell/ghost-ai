# Offline AI Survivalist USB Setup Guide

## Overview
This guide will walk you through creating a fully offline, bootable USB drive with a complete AI assistant system including multiple models for reasoning, coding, vision, voice, and image generation.

**Total time estimate:** 4-6 hours (mostly download time)  
**Storage required:** 256GB USB drive minimum  
**Internet required:** Only during initial setup

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Phase 1: Create Bootable USB](#phase-1-create-bootable-usb)
3. [Phase 2: Initial Linux Setup](#phase-2-initial-linux-setup)
4. [Phase 3: Install Ollama & Models](#phase-3-install-ollama--models)
5. [Phase 4: Install OpenClaw](#phase-4-install-openclaw)
6. [Phase 5: Voice & Image Generation](#phase-5-voice--image-generation)
7. [Phase 6: Offline Reference Data](#phase-6-offline-reference-data)
8. [Phase 7: Network Isolation & Security](#phase-7-network-isolation--security)
9. [Phase 8: User Acceptance Testing](#phase-8-user-acceptance-testing)
10. [Phase 9: Create Backup ISO](#phase-9-create-backup-iso)

---

## Prerequisites

### Hardware
- **USB Drive:** 256GB+ USB 3.1/3.2 drive (recommended brands: SanDisk Extreme, Samsung BAR Plus)
- **Host Computer:** Any computer with 8GB+ RAM, USB 3.0 port
- **Internet Connection:** For initial downloads only

### Software (to download before starting)
- **Ubuntu 24.04 LTS Desktop ISO:** https://ubuntu.com/download/desktop
- **Rufus** (Windows) or **balenaEtcher** (Mac/Linux): For creating bootable USB
- A second USB drive or external storage for temporary files (optional but helpful)

### Knowledge Level
- Basic Linux command line familiarity
- Patience for large downloads

---

## Phase 1: Create Bootable USB

### Step 1.1: Download Ubuntu
```bash
# Download Ubuntu 24.04 LTS Desktop (64-bit)
# Direct link: https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso
# Size: ~5.7GB
# SHA256: Verify on Ubuntu's website
```

### Step 1.2: Prepare USB Drive
**⚠️ WARNING: This will erase ALL data on the USB drive**

#### On Windows (using Rufus):
1. Download Rufus: https://rufus.ie/
2. Insert your 256GB USB drive
3. Launch Rufus
4. Settings:
   - Device: Select your USB drive
   - Boot selection: Select Ubuntu ISO
   - Partition scheme: GPT
   - Target system: UEFI
   - Volume label: "UBUNTU"
   - File system: FAT32 (Rufus will use this for the boot partition)
   - **IMPORTANT:** Click "Show advanced format options"
     - Check "Quick format"
     - Uncheck "Create extended label and icon files"
5. Click START
6. When prompted, select "Write in ISO Image mode"
7. Wait for completion (~10 minutes)

#### On Mac/Linux (using dd or balenaEtcher):

**Using balenaEtcher (easier):**
1. Download: https://www.balena.io/etcher/
2. Insert USB drive
3. Select Ubuntu ISO
4. Select USB drive
5. Click "Flash!"

**Using dd (advanced):**
```bash
# Find your USB device
lsblk

# Unmount if mounted (replace sdX with your device)
sudo umount /dev/sdX*

# Write ISO (CAREFUL - wrong device will destroy data)
sudo dd if=ubuntu-24.04-desktop-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync

# This will take 10-20 minutes
```

**Note:** We'll do a full persistent installation in Phase 2, so no need to manually create partitions here.

---

## Phase 2: Initial Linux Setup

### Step 2.1: Boot from USB
1. Insert USB into computer
2. Restart and enter BIOS/Boot menu (usually F2, F12, DEL, or ESC)
3. Select USB drive as boot device
4. Select "Try or Install Ubuntu"
5. Choose "Try Ubuntu" (we'll install to USB later)

### Step 2.2: Install Ubuntu to USB (Persistent)

**IMPORTANT: Encryption Setup**
If you want full disk encryption (RECOMMENDED), you must set it up during installation.
This cannot be easily added later without reinstalling.

```bash
# Launch installer
ubiquity

# Installation steps:
# 1. Language: English (or your preference)
# 2. Keyboard: Your layout
# 3. Updates: "Normal installation" + "Download updates"
# 4. Installation type: "Something else" (for manual partitioning)
# 
# CRITICAL - Manual partitioning:
# - Select your USB drive (usually /dev/sdb or /dev/sdc)
# - Delete existing partitions (if any)
# - Create new partition table (GPT)
# 
# Create partitions:
# 1. EFI partition:
#    - Size: 512MB
#    - Type: EFI System Partition
#    - Mount point: /boot/efi
#    - Location: Beginning
# 
# 2. Boot partition (unencrypted):
#    - Size: 1GB
#    - Type: ext4
#    - Mount point: /boot
#    - Location: Beginning
#
# 3. Encrypted Root partition:
#    - Size: Remaining space (~254GB)
#    - Type: physical volume for encryption
#    - Click "Set up as:" → "physical volume for encryption"
#    - Enter encryption passphrase (WRITE THIS DOWN!)
#    - After encryption setup, select the encrypted volume
#    - Type: ext4
#    - Mount point: /
# 
# - Select "Device for bootloader installation": Your USB drive (/dev/sdb or /dev/sdc)
# 
# 5. Location: Your timezone
# 6. User creation:
#    - Name: ghost
#    - Computer name: ghost-ai
#    - Username: ghost
#    - Password: [CHOOSE STRONG PASSWORD - different from encryption password]
#    - Uncheck "Log in automatically"
# 
# 7. Begin installation (20-30 minutes)
# 8. When complete, restart and boot from USB again
#
# NOTE: You will need to enter the encryption passphrase at every boot
```

### Step 2.3: First Boot Configuration
```bash
# Login with your credentials

# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y \
    build-essential \
    git \
    curl \
    wget \
    vim \
    htop \
    net-tools \
    python3 \
    python3-pip \
    python3-venv \
    ufw \
    gnupg \
    ca-certificates \
    smartmontools \
    macchanger \
    syslinux-utils

# Create tools directory for utility scripts
mkdir -p ~/tools

# Reboot
sudo reboot
```

---

## Phase 3: Install Ollama & Models

### Step 3.1: Install Ollama
```bash
# Download and install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Verify installation
ollama --version

# Start Ollama service
sudo systemctl start ollama
sudo systemctl enable ollama

# Test
ollama list
```

### Step 3.2: Download AI Models
This will take 1-3 hours depending on your connection.

```bash
# Create download script
cat > ~/download-models.sh << 'EOF'
#!/bin/bash

echo "Starting model downloads..."
echo "This will download approximately 50GB of models."
echo "Estimated time: 1-3 hours"
echo ""

# General reasoning models
echo "[1/7] Downloading Llama 3.1 8B..."
ollama pull llama3.1:8b

echo "[2/7] Downloading Qwen 2.5 32B..."
ollama pull qwen2.5:32b

# Coding model
echo "[3/7] Downloading Qwen 2.5 Coder 7B..."
ollama pull qwen2.5-coder:7b

# Vision model
echo "[4/7] Downloading Llama 3.2 Vision 11B..."
ollama pull llama3.2-vision:11b

# Lightweight backup
echo "[5/7] Downloading Mistral 7B..."
ollama pull mistral:7b

# Embedding model (for RAG if needed)
echo "[6/7] Downloading nomic-embed-text..."
ollama pull nomic-embed-text

# Small efficient model
echo "[7/7] Downloading Llama 3.2 3B..."
ollama pull llama3.2:3b

echo ""
echo "All models downloaded successfully!"
echo "Verifying..."
ollama list

# Show disk usage
echo ""
echo "Disk usage:"
du -sh ~/.ollama/models
EOF

# Make executable
chmod +x ~/download-models.sh

# Run download
./download-models.sh
```

### Step 3.3: Test Models
```bash
# Test general reasoning
ollama run llama3.1:8b "What are the first steps to take in a power outage emergency?"

# Test coding
ollama run qwen2.5-coder:7b "Write a Python script to calculate water purification needs for a family of 4"

# Test vision (you'll need an image file)
# ollama run llama3.2-vision:11b "Describe this image" image.jpg

# If all tests pass, continue
```

### Step 3.4: Configure Ollama for Offline Use
```bash
# Create systemd override for Ollama configuration
sudo mkdir -p /etc/systemd/system/ollama.service.d

cat | sudo tee /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_ORIGINS=http://127.0.0.1:*,http://localhost:*"
Environment="OLLAMA_KEEP_ALIVE=5m"
Environment="OLLAMA_MODELS=/home/ghost/.ollama/models"
EOF

# Reload systemd and restart Ollama
sudo systemctl daemon-reload
sudo systemctl restart ollama

# Verify it's only listening locally
sudo netstat -tlnp | grep ollama
# Should show: 127.0.0.1:11434
```

---

## Phase 4: Install OpenClaw

### Step 4.1: Install Node.js (Required for OpenClaw)
```bash
# Install Node.js 20.x (LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify
node --version  # Should be v20.x
npm --version   # Should be 10.x
```

### Step 4.2: Clone and Setup OpenClaw
```bash
# Navigate to home directory
cd ~

# Clone OpenClaw
git clone https://github.com/openclaw/openclaw.git
cd openclaw

# Install dependencies
npm install

# Install additional tools OpenClaw might need
sudo apt install -y \
    xdotool \
    scrot \
    imagemagick \
    xclip \
    wmctrl

# Install Python dependencies for computer vision
pip3 install pillow numpy opencv-python-headless
```

### Step 4.3: Configure OpenClaw for Ollama
```bash
# Create OpenClaw configuration
cat > ~/openclaw/config.json << 'EOF'
{
  "provider": "ollama",
  "baseURL": "http://127.0.0.1:11434",
  "model": "llama3.1:8b",
  "alternateModels": {
    "coding": "qwen2.5-coder:7b",
    "vision": "llama3.2-vision:11b",
    "reasoning": "qwen2.5:32b",
    "fast": "llama3.2:3b"
  },
  "maxTokens": 4096,
  "temperature": 0.7,
  "displayServer": ":0",
  "screenshotTool": "scrot",
  "offline": true,
  "networkEnabled": false
}
EOF
```

### Step 4.4: Create OpenClaw Launcher Script
```bash
cat > ~/start-openclaw.sh << 'EOF'
#!/bin/bash

echo "Starting Ghost AI System..."
echo ""

# Check if Ollama is running
if ! systemctl is-active --quiet ollama; then
    echo "Starting Ollama service..."
    sudo systemctl start ollama
    sleep 3
fi

# Verify Ollama is responding
if ! curl -s http://127.0.0.1:11434/api/tags > /dev/null; then
    echo "ERROR: Ollama is not responding"
    exit 1
fi

echo "Ollama is running ✓"
echo "Available models:"
ollama list
echo ""

# Navigate to OpenClaw directory
cd ~/openclaw

# Set environment variables
export DISPLAY=:0
export OLLAMA_HOST="http://127.0.0.1:11434"

# Start OpenClaw
echo "Starting OpenClaw..."
npm start

EOF

chmod +x ~/start-openclaw.sh
```

---

## Phase 5: Voice & Image Generation

### Step 5.1: Install Whisper (Speech Recognition)
```bash
# Install whisper.cpp for efficient local inference
cd ~
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp

# Build
make

# Download medium model (good balance of size/accuracy)
bash ./models/download-ggml-model.sh medium

# Test (if you have a mic)
./main -m models/ggml-medium.bin -f samples/jfk.wav

# Create convenient alias
echo 'alias whisper="~/whisper.cpp/main -m ~/whisper.cpp/models/ggml-medium.bin"' >> ~/.bashrc
source ~/.bashrc
```

### Step 5.2: Install Piper TTS (Text-to-Speech)
```bash
# Download Piper
cd ~
wget https://github.com/rhasspy/piper/releases/download/v1.2.0/piper_amd64.tar.gz
tar -xzf piper_amd64.tar.gz
mv piper ~/piper-tts
cd ~/piper-tts

# Download voice models (US English, male and female)
mkdir -p voices
cd voices

# Female voice
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json

# Male voice
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx.json

cd ..

# Test
echo "Hello, this is a test of the text to speech system." | ./piper -m voices/en_US-lessac-medium.onnx -f test.wav
aplay test.wav

# Create alias
echo 'alias tts="~/piper-tts/piper -m ~/piper-tts/voices/en_US-lessac-medium.onnx"' >> ~/.bashrc
source ~/.bashrc
```

### Step 5.3: Install Stable Diffusion (Image Generation)

**⚠️ PERFORMANCE WARNING:**
Stable Diffusion on CPU is VERY slow (5-10 minutes per image). This installation uses CPU-only PyTorch.
If you have an NVIDIA GPU, you can install CUDA-enabled PyTorch instead for much faster generation.

```bash
# Install Python dependencies (CPU-only version)
pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Install ComfyUI
cd ~
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI

# Install requirements
pip3 install -r requirements.txt

# Download Stable Diffusion 1.5 model
cd models/checkpoints
wget https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors

cd ~

# Create launcher script
cat > ~/start-comfyui.sh << 'EOF'
#!/bin/bash
cd ~/ComfyUI
python3 main.py --listen 127.0.0.1 --port 8188
EOF

chmod +x ~/start-comfyui.sh

# Test (this will start the server)
# ./start-comfyui.sh
# Then open browser to http://127.0.0.1:8188
```

### Step 5.4: Create Unified Voice/Image Helper Scripts
```bash
# Speech to text helper
cat > ~/tools/transcribe.sh << 'EOF'
#!/bin/bash
# Usage: ./transcribe.sh audio_file.wav

if [ -z "$1" ]; then
    echo "Usage: $0 <audio_file.wav>"
    exit 1
fi

~/whisper.cpp/main -m ~/whisper.cpp/models/ggml-medium.bin -f "$1"
EOF

# Text to speech helper
cat > ~/tools/speak.sh << 'EOF'
#!/bin/bash
# Usage: echo "text" | ./speak.sh
# Or: ./speak.sh "text to speak"

if [ -z "$1" ]; then
    # Read from stdin
    ~/piper-tts/piper -m ~/piper-tts/voices/en_US-lessac-medium.onnx -f /tmp/speech.wav
else
    # Use argument
    echo "$1" | ~/piper-tts/piper -m ~/piper-tts/voices/en_US-lessac-medium.onnx -f /tmp/speech.wav
fi

aplay /tmp/speech.wav
rm /tmp/speech.wav
EOF

chmod +x ~/tools/*.sh
```

---

## Phase 6: Offline Reference Data

### Step 6.1: Install Kiwix (Offline Wikipedia)
```bash
# Install Kiwix
sudo apt install -y kiwix-tools

# Create data directory
mkdir -p ~/offline-data/wikipedia

cd ~/offline-data/wikipedia

# Download Wikipedia (English, no pictures - ~96GB compressed)
# This will take several hours depending on your connection
# Alternative: Use a smaller dated version or different language
wget https://download.kiwix.org/zim/wikipedia/wikipedia_en_all_nopic_2024-01.zim

# Start Kiwix server (for testing)
kiwix-serve --port 8080 wikipedia_en_all_nopic_2024-01.zim
# Access at http://127.0.0.1:8080

# Create launcher
cat > ~/start-kiwix.sh << 'EOF'
#!/bin/bash
kiwix-serve --port 8080 ~/offline-data/wikipedia/*.zim
EOF

chmod +x ~/start-kiwix.sh
```

### Step 6.2: Download Additional Reference Materials
```bash
# Create reference directory structure
mkdir -p ~/offline-data/{medical,legal,survival,technical,maps}

# Medical references (examples - you'll need to source these)
cd ~/offline-data/medical
# Download medical PDFs, first aid guides, etc.
# Example: WHO guides, Red Cross manuals

# Survival guides
cd ~/offline-data/survival
# Download survival PDFs
# Example: SAS Survival Handbook, military survival manuals (public domain)

# Legal codes (US example)
cd ~/offline-data/legal
# Download legal codes for your jurisdiction
# Example: https://www.law.cornell.edu (bulk downloads available)

# Technical references
cd ~/offline-data/technical
# Download electronics, mechanical, construction references
# Example: Arduino reference, Raspberry Pi docs, ham radio manuals

# Maps (OpenStreetMap)
cd ~/offline-data/maps
# Download OSM data for your region
# Example using osmium:
sudo apt install -y osmium-tool
# wget https://download.geofabrik.de/north-america/us-latest.osm.pbf
```

### Step 6.3: Install Offline Documentation Viewer
```bash
# Install Zeal (offline documentation browser)
sudo apt install -y zeal

# Download docsets (programming languages, frameworks)
# Launch Zeal and download:
# - Python
# - JavaScript
# - Linux Man Pages
# - Bash
# - HTML/CSS
# - Git
```

---

## Phase 7: Network Isolation & Security

### Step 7.1: Configure Firewall (UFW)
```bash
# Enable firewall
sudo ufw enable

# Default deny all
sudo ufw default deny incoming
sudo ufw default deny outgoing

# Allow only localhost connections
sudo ufw allow from 127.0.0.1
sudo ufw allow to 127.0.0.1

# Verify rules
sudo ufw status verbose

# Should show:
# Status: active
# Default: deny (incoming), deny (outgoing), disabled (routed)
```

### Step 7.2: Disable Network Services
```bash
# Disable unnecessary network services
sudo systemctl disable NetworkManager
sudo systemctl stop NetworkManager

# Disable Bluetooth
sudo systemctl disable bluetooth
sudo systemctl stop bluetooth

# Create network toggle scripts
cat > ~/tools/network-on.sh << 'EOF'
#!/bin/bash
echo "ENABLING NETWORK - Use with caution!"
sudo systemctl start NetworkManager
sudo ufw allow out to any
echo "Network enabled. Use './network-off.sh' to disable."
EOF

cat > ~/tools/network-off.sh << 'EOF'
#!/bin/bash
echo "DISABLING NETWORK - Ghost mode activated"
sudo ufw deny out to any
sudo systemctl stop NetworkManager

# Disable all network interfaces except loopback
for iface in $(ip link show | grep -E '^[0-9]+:' | cut -d: -f2 | tr -d ' ' | grep -v '^lo$'); do
    echo "Disabling $iface..."
    sudo ip link set $iface down 2>/dev/null
done

echo "Network disabled. System is now offline."
EOF

chmod +x ~/tools/network-*.sh

# Disable network by default
~/tools/network-off.sh
```

### Step 7.3: Create Privacy Scripts
```bash
# MAC address randomization
cat > ~/tools/randomize-mac.sh << 'EOF'
#!/bin/bash
# Randomize MAC address (when network is enabled)
INTERFACE=${1:-wlan0}
sudo ip link set $INTERFACE down
sudo macchanger -r $INTERFACE
sudo ip link set $INTERFACE up
echo "MAC address randomized for $INTERFACE"
EOF

# Secure erase script
cat > ~/tools/secure-erase.sh << 'EOF'
#!/bin/bash
echo "WARNING: This will securely erase specified files/directories"
echo "Usage: ./secure-erase.sh <file_or_directory>"
if [ -z "$1" ]; then
    exit 1
fi

shred -vfz -n 3 "$1"
EOF

chmod +x ~/tools/*.sh
```

---

## Phase 8: User Acceptance Testing

### Step 8.1: Create Test Suite
```bash
cat > ~/test-system.sh << 'EOF'
#!/bin/bash

echo "=== Ghost AI System Test Suite ==="
echo ""

# Test 1: Ollama
echo "[TEST 1/8] Testing Ollama..."
if systemctl is-active --quiet ollama; then
    echo "✓ Ollama service is running"
else
    echo "✗ Ollama service is NOT running"
    exit 1
fi

# Test 2: Models
echo "[TEST 2/8] Testing models..."
MODEL_COUNT=$(ollama list | tail -n +2 | wc -l)
if [ $MODEL_COUNT -ge 5 ]; then
    echo "✓ Found $MODEL_COUNT models"
    ollama list
else
    echo "✗ Expected at least 5 models, found $MODEL_COUNT"
    exit 1
fi

# Test 3: Model inference
echo "[TEST 3/8] Testing model inference..."
RESPONSE=$(ollama run llama3.2:3b "Say only 'OK' and nothing else" 2>/dev/null)
if [[ $RESPONSE == *"OK"* ]]; then
    echo "✓ Model inference working"
else
    echo "✗ Model inference failed"
    exit 1
fi

# Test 4: OpenClaw
echo "[TEST 4/8] Testing OpenClaw installation..."
if [ -d ~/openclaw ] && [ -f ~/openclaw/package.json ]; then
    echo "✓ OpenClaw installed"
else
    echo "✗ OpenClaw not found"
    exit 1
fi

# Test 5: Whisper
echo "[TEST 5/8] Testing Whisper..."
if [ -f ~/whisper.cpp/main ] && [ -f ~/whisper.cpp/models/ggml-medium.bin ]; then
    echo "✓ Whisper installed"
else
    echo "✗ Whisper not installed correctly"
    exit 1
fi

# Test 6: Piper TTS
echo "[TEST 6/8] Testing Piper TTS..."
if [ -f ~/piper-tts/piper ] && [ -f ~/piper-tts/voices/en_US-lessac-medium.onnx ]; then
    echo "✓ Piper TTS installed"
else
    echo "✗ Piper TTS not installed correctly"
    exit 1
fi

# Test 7: ComfyUI
echo "[TEST 7/8] Testing ComfyUI..."
if [ -d ~/ComfyUI ] && [ -f ~/ComfyUI/models/checkpoints/v1-5-pruned-emaonly.safetensors ]; then
    echo "✓ ComfyUI and SD model installed"
else
    echo "✗ ComfyUI not installed correctly"
    exit 1
fi

# Test 8: Network isolation
echo "[TEST 8/8] Testing network isolation..."
UFW_STATUS=$(sudo ufw status | grep -i "Status: active")
if [ -n "$UFW_STATUS" ]; then
    echo "✓ Firewall is active"
else
    echo "✗ Firewall is not active"
    exit 1
fi

# Test 9: Offline Wikipedia
echo "[TEST 9/9] Testing offline Wikipedia..."
if [ -f ~/offline-data/wikipedia/*.zim ]; then
    echo "✓ Wikipedia data found"
else
    echo "⚠ Wikipedia data not found (optional)"
fi

echo ""
echo "=== All Tests Passed! ==="
echo ""
echo "System is ready for offline use."
echo ""
echo "Quick start commands:"
echo "  ./start-openclaw.sh    - Start AI assistant"
echo "  ./start-kiwix.sh       - Start offline Wikipedia"
echo "  ./start-comfyui.sh     - Start image generation"
echo "  ./tools/network-off.sh - Ensure network is disabled"
echo ""

EOF

chmod +x ~/test-system.sh
```

### Step 8.2: Run Tests
```bash
# Run the test suite
./test-system.sh

# If all tests pass, proceed to documentation
```

### Step 8.3: Create User Documentation
```bash
cat > ~/USAGE.md << 'EOF'
# Ghost AI System - User Guide

## Quick Start

### Start the AI Assistant
```bash
./start-openclaw.sh
```

This launches OpenClaw connected to local Ollama models.

### Switch Models
Models are configured in `~/openclaw/config.json`:
- General tasks: llama3.1:8b (default)
- Coding: qwen2.5-coder:7b
- Vision: llama3.2-vision:11b
- Deep reasoning: qwen2.5:32b
- Fast responses: llama3.2:3b

### Voice Features

**Speech to Text:**
```bash
~/tools/transcribe.sh recording.wav
```

**Text to Speech:**
```bash
echo "Hello world" | ~/tools/speak.sh
# Or
~/tools/speak.sh "Hello world"
```

### Image Generation
```bash
./start-comfyui.sh
# Then open browser to http://127.0.0.1:8188
```

### Offline Wikipedia
```bash
./start-kiwix.sh
# Then open browser to http://127.0.0.1:8080
```

### Network Control

**Disable Network (Ghost Mode):**
```bash
~/tools/network-off.sh
```

**Enable Network (for updates):**
```bash
~/tools/network-on.sh
```

**Remember to disable network again after updates!**

## Emergency Scenarios

### Power Outage / Grid Down
1. Boot from USB
2. System is already configured for offline use
3. Access Wikipedia for information
4. Use AI models for problem-solving

### Privacy / Surveillance Concerns
1. Boot from USB in ghost mode (network disabled)
2. All processing is local
3. No telemetry, no cloud connections
4. Use voice/image generation for anonymity needs

### Communication Needs
- Use TTS to create voice messages
- Use SD to generate images
- All generation is local and private

## Disk Usage
Check current usage:
```bash
df -h
du -sh ~/.ollama/models
du -sh ~/offline-data
```

## Troubleshooting

### Ollama not responding
```bash
sudo systemctl restart ollama
curl http://127.0.0.1:11434/api/tags
```

### Out of memory
Close other applications. The 32B model needs ~20GB RAM.
Switch to smaller models if needed.

### USB is slow
- Ensure USB 3.0+ connection
- Check drive health: `sudo smartctl -a /dev/sdX`

## Maintenance

### Update models (requires network)
```bash
~/tools/network-on.sh
ollama pull llama3.1:8b
~/tools/network-off.sh
```

### Backup important data
Copy to external drive regularly.

## Security Reminders
- Network is disabled by default (ghost mode)
- Only enable when necessary
- Full disk encryption recommended
- Use strong passwords
- Keep USB physically secure
EOF
```

---

## Phase 9: Create Backup ISO

### Step 9.1: Prepare for Backup
```bash
# Clean up temporary files
sudo apt clean
sudo apt autoclean
rm -rf ~/.cache/*
rm -rf /tmp/*

# Create backup directory
mkdir -p ~/backup-staging
```

### Step 9.2: Create System Image
```bash
# Install required tools
sudo apt install -y squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools

# Create the backup script
cat > ~/create-backup.sh << 'EOF'
#!/bin/bash

echo "=== Creating Ghost AI System Backup ISO ==="
echo ""
echo "This will create a bootable ISO image of your current system."
echo "The ISO can be used to restore or duplicate this setup."
echo ""
echo "Estimated time: 30-60 minutes"
echo "Estimated size: 80-120GB"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Set variables
WORK_DIR=~/backup-staging
ISO_NAME="ghost-ai-system-$(date +%Y%m%d).iso"

echo "Creating working directory..."
sudo mkdir -p $WORK_DIR/{iso,squashfs,iso/live,iso/boot/grub}

# Create filesystem copy
echo "Creating filesystem snapshot..."
sudo rsync -aAXv / $WORK_DIR/squashfs \
    --exclude=/dev \
    --exclude=/proc \
    --exclude=/sys \
    --exclude=/tmp \
    --exclude=/run \
    --exclude=/mnt \
    --exclude=/media \
    --exclude=/lost+found \
    --exclude=$WORK_DIR

# Create squashfs filesystem (compressed)
echo "Creating compressed filesystem (this will take a while)..."
sudo mksquashfs $WORK_DIR/squashfs $WORK_DIR/iso/live/filesystem.squashfs \
    -comp xz -b 1M -Xdict-size 100%

# Copy kernel and initrd
echo "Copying boot files..."
sudo cp /boot/vmlinuz-* $WORK_DIR/iso/live/vmlinuz
sudo cp /boot/initrd.img-* $WORK_DIR/iso/live/initrd

# Create grub configuration for UEFI
echo "Creating bootloader configuration..."
cat | sudo tee $WORK_DIR/iso/boot/grub/grub.cfg << 'GRUBEOF'
set timeout=10
set default=0

menuentry "Ghost AI System - Live Boot" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd
}

menuentry "Ghost AI System - Safe Mode" {
    linux /live/vmlinuz boot=live nomodeset
    initrd /live/initrd
}
GRUBEOF

# Create UEFI bootable ISO using xorriso
echo "Creating UEFI bootable ISO image..."
sudo grub-mkrescue -o ~/$ISO_NAME $WORK_DIR/iso \
    -- \
    -volid "GHOST-AI" \
    -r -J

# Cleanup
echo "Cleaning up..."
sudo rm -rf $WORK_DIR

# Calculate checksum
echo "Calculating SHA256 checksum..."
sha256sum ~/$ISO_NAME > ~/$ISO_NAME.sha256

echo ""
echo "=== Backup Complete! ==="
echo ""
echo "ISO file: ~/$ISO_NAME"
echo "Size: $(du -h ~/$ISO_NAME | cut -f1)"
echo "SHA256: $(cat ~/$ISO_NAME.sha256)"
echo ""
echo "You can now:"
echo "1. Copy this ISO to another drive for safekeeping"
echo "2. Write it to a new USB drive using dd or balenaEtcher"
echo "3. Store it offline for disaster recovery"
echo ""

EOF

chmod +x ~/create-backup.sh
```

### Step 9.3: Create the Backup
```bash
# Run the backup script
./create-backup.sh

# This will create an ISO file in your home directory
# The ISO is a complete bootable image of your system
```

### Step 9.4: Alternative: Clone USB Directly
```bash
# For a faster duplication (if you have two USB drives)

# Install cloning tool
sudo apt install -y partclone

# Clone script
cat > ~/clone-usb.sh << 'EOF'
#!/bin/bash

echo "=== USB Drive Cloning Tool ==="
echo ""
echo "This will clone your current USB to another USB drive."
echo "WARNING: Target drive will be completely erased!"
echo ""

# List available drives
lsblk -d -o NAME,SIZE,MODEL

echo ""
read -p "Enter SOURCE device (e.g., sdb): " SOURCE
read -p "Enter TARGET device (e.g., sdc): " TARGET

echo ""
echo "SOURCE: /dev/$SOURCE"
echo "TARGET: /dev/$TARGET"
echo ""
echo "This will ERASE ALL DATA on /dev/$TARGET"
read -p "Are you ABSOLUTELY sure? (type 'YES'): " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    echo "Cancelled."
    exit 1
fi

# Unmount drives
sudo umount /dev/${SOURCE}* 2>/dev/null
sudo umount /dev/${TARGET}* 2>/dev/null

# Clone
echo "Cloning... this will take 1-2 hours for 256GB"
sudo dd if=/dev/$SOURCE of=/dev/$TARGET bs=4M status=progress conv=fsync

# Verify
echo "Verifying..."
sudo cmp -n $(blockdev --getsize64 /dev/$SOURCE) /dev/$SOURCE /dev/$TARGET

echo ""
echo "Clone complete!"
echo "You now have two identical Ghost AI systems."

EOF

chmod +x ~/clone-usb.sh
```

---

## Phase 10: Final Setup & Documentation

### Step 10.1: Create Desktop Shortcuts
```bash
# Create desktop directory
mkdir -p ~/Desktop

# OpenClaw shortcut
cat > ~/Desktop/start-ghost-ai.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Ghost AI Assistant
Comment=Start the offline AI assistant
Exec=/home/ghost/start-openclaw.sh
Icon=utilities-terminal
Terminal=true
Categories=System;
EOF

# Kiwix shortcut
cat > ~/Desktop/offline-wikipedia.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Offline Wikipedia
Comment=Access offline Wikipedia
Exec=/home/ghost/start-kiwix.sh
Icon=web-browser
Terminal=true
Categories=Network;
EOF

# ComfyUI shortcut
cat > ~/Desktop/image-generation.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Image Generation
Comment=Start ComfyUI for image generation
Exec=/home/ghost/start-comfyui.sh
Icon=applications-graphics
Terminal=true
Categories=Graphics;
EOF

# Make executable
chmod +x ~/Desktop/*.desktop

# Trust desktop files
gio set ~/Desktop/*.desktop metadata::trusted true
```

### Step 10.2: Create System Info Script
```bash
cat > ~/system-info.sh << 'EOF'
#!/bin/bash

echo "==================================="
echo "   Ghost AI System Information"
echo "==================================="
echo ""
echo "System: $(lsb_release -ds)"
echo "Kernel: $(uname -r)"
echo "Hostname: $(hostname)"
echo ""
echo "--- AI Models ---"
ollama list
echo ""
echo "--- Disk Usage ---"
df -h / | tail -n 1
echo "Models: $(du -sh ~/.ollama/models 2>/dev/null | cut -f1)"
echo "Wikipedia: $(du -sh ~/offline-data/wikipedia 2>/dev/null | cut -f1)"
echo "ComfyUI: $(du -sh ~/ComfyUI 2>/dev/null | cut -f1)"
echo ""
echo "--- Network Status ---"
if systemctl is-active --quiet NetworkManager; then
    echo "Status: ONLINE ⚠️"
else
    echo "Status: OFFLINE (Ghost Mode) ✓"
fi
echo ""
echo "--- Services ---"
echo -n "Ollama: "
systemctl is-active ollama
echo ""
echo "==================================="

EOF

chmod +x ~/system-info.sh
```

### Step 10.3: Create README
```bash
cat > ~/README.md << 'EOF'
# Ghost AI System

An offline, privacy-focused AI assistant system for emergency preparedness and complete privacy.

## What's Included

### AI Models
- **Llama 3.1 8B** - General reasoning and knowledge
- **Qwen 2.5 32B** - Deep reasoning tasks
- **Qwen 2.5 Coder 7B** - Programming assistance
- **Llama 3.2 Vision 11B** - Image analysis
- **Mistral 7B** - Alternative general model
- **Llama 3.2 3B** - Fast, lightweight model

### Capabilities
- **Text Generation** - Answer questions, write documents, solve problems
- **Code Generation** - Write and debug code in multiple languages
- **Image Analysis** - Understand and describe images
- **Image Generation** - Create images with Stable Diffusion
- **Speech Recognition** - Transcribe audio with Whisper
- **Text-to-Speech** - Generate natural speech with Piper
- **Offline Wikipedia** - Complete Wikipedia without internet
- **Computer Control** - OpenClaw for desktop automation

### Privacy Features
- ✓ 100% offline operation (network disabled by default)
- ✓ No API keys or cloud services
- ✓ No telemetry or data collection
- ✓ Firewall configured to block all traffic
- ✓ MAC address randomization available
- ✓ Secure erase tools included

## Quick Start

1. **Boot from USB**
   - Restart computer with USB inserted
   - Select USB in BIOS boot menu
   - Login: `ghost` / [your password]

2. **Verify System**
   ```bash
   ./system-info.sh
   ```

3. **Start AI Assistant**
   ```bash
   ./start-openclaw.sh
   ```

4. **Ensure Ghost Mode**
   ```bash
   ~/tools/network-off.sh
   ```

## Use Cases

### Scenario 1: Grid Down / Internet Outage
- Access offline Wikipedia for information
- Use AI for problem-solving (medical, mechanical, etc.)
- Generate code for automation tasks
- No dependency on cloud services

### Scenario 2: Privacy / Surveillance Concerns
- All processing happens locally
- No network traffic
- Generate anonymous content (voice, images)
- Complete control over your data

### Scenario 3: Research / Learning
- Deep technical assistance without internet
- Programming help completely offline
- Access to world knowledge via Wikipedia
- Educational content generation

## Important Files

- `/home/ghost/USAGE.md` - Detailed usage guide
- `/home/ghost/test-system.sh` - System verification
- `/home/ghost/create-backup.sh` - Create ISO backup
- `/home/ghost/clone-usb.sh` - Clone to another USB
- `/home/ghost/tools/` - Utility scripts

## Network Control

**Disable (Ghost Mode):**
```bash
~/tools/network-off.sh
```

**Enable (for updates only):**
```bash
~/tools/network-on.sh
# Do updates
~/tools/network-off.sh  # IMPORTANT: Disable again!
```

## Maintenance

### Update AI Models
```bash
~/tools/network-on.sh
ollama pull llama3.1:8b
~/tools/network-off.sh
```

### Check Disk Space
```bash
df -h
du -sh ~/.ollama/models
```

### Create Backup
```bash
./create-backup.sh
```

## Troubleshooting

### Ollama Not Working
```bash
sudo systemctl restart ollama
ollama list
```

### Slow Performance
- Close unused applications
- Use smaller models (llama3.2:3b)
- Check available RAM with `free -h`

### USB Issues
- Ensure USB 3.0 connection
- Check for errors: `dmesg | tail`

## Technical Specs

- **OS:** Ubuntu 24.04 LTS
- **AI Runtime:** Ollama
- **Agent:** OpenClaw
- **Storage:** ~150GB used (models ~50GB + Wikipedia ~96GB + system/apps ~4GB)
- **RAM:** 8GB minimum, 16GB+ recommended for large models

## Security Notes

- Keep USB physically secure
- Use strong passwords
- Enable full disk encryption if possible
- Regular backups to offline storage
- Verify system integrity with `./test-system.sh`

## Credits

Built using:
- Ollama - https://ollama.com
- OpenClaw - https://github.com/openclaw/openclaw
- Whisper.cpp - https://github.com/ggerganov/whisper.cpp
- Piper TTS - https://github.com/rhasspy/piper
- ComfyUI - https://github.com/comfyanonymous/ComfyUI
- Kiwix - https://www.kiwix.org

## License

This system combines various open-source projects.
Refer to individual component licenses.

---

**Stay safe. Stay private. Stay prepared.**

EOF
```

---

## Complete Setup Verification

### Final Checklist

Run through this checklist to ensure everything is set up correctly:

```bash
# Create verification script
cat > ~/final-verification.sh << 'EOF'
#!/bin/bash

echo "========================================="
echo "  Ghost AI System - Final Verification"
echo "========================================="
echo ""

PASS=0
FAIL=0

check() {
    if [ $? -eq 0 ]; then
        echo "✓ $1"
        ((PASS++))
    else
        echo "✗ $1"
        ((FAIL++))
    fi
}

# 1. Check Ollama
systemctl is-active --quiet ollama
check "Ollama service running"

# 2. Check models
[ $(ollama list | tail -n +2 | wc -l) -ge 5 ]
check "AI models installed (5+)"

# 3. Check OpenClaw
[ -d ~/openclaw ] && [ -f ~/openclaw/config.json ]
check "OpenClaw installed"

# 4. Check Whisper
[ -f ~/whisper.cpp/models/ggml-medium.bin ]
check "Whisper model installed"

# 5. Check Piper
[ -f ~/piper-tts/voices/en_US-lessac-medium.onnx ]
check "Piper TTS installed"

# 6. Check ComfyUI
[ -f ~/ComfyUI/models/checkpoints/v1-5-pruned-emaonly.safetensors ]
check "Stable Diffusion model installed"

# 7. Check Wikipedia
[ -f ~/offline-data/wikipedia/*.zim ]
check "Wikipedia data installed"

# 8. Check firewall
sudo ufw status | grep -q "Status: active"
check "Firewall enabled"

# 9. Check network disabled
! systemctl is-active --quiet NetworkManager
check "Network disabled (Ghost Mode)"

# 10. Check scripts
[ -f ~/start-openclaw.sh ] && [ -x ~/start-openclaw.sh ]
check "Launcher scripts present"

# 11. Check tools
[ -d ~/tools ] && [ -f ~/tools/network-off.sh ]
check "Utility scripts present"

# 12. Check documentation
[ -f ~/README.md ] && [ -f ~/USAGE.md ]
check "Documentation present"

echo ""
echo "========================================="
echo "  Results: $PASS passed, $FAIL failed"
echo "========================================="
echo ""

if [ $FAIL -eq 0 ]; then
    echo "🎉 System is fully operational!"
    echo ""
    echo "Next steps:"
    echo "1. Run './create-backup.sh' to create ISO backup"
    echo "2. Test all features with './test-system.sh'"
    echo "3. Read USAGE.md for detailed instructions"
    echo "4. Keep USB secure and backed up"
    echo ""
    echo "Your Ghost AI System is ready for offline use."
else
    echo "⚠️  Some components failed verification."
    echo "Review failed items and reinstall if needed."
fi

EOF

chmod +x ~/final-verification.sh

# Run it
./final-verification.sh
```

---

## Appendix A: Customization Ideas

### Add More Languages (Whisper)
```bash
cd ~/whisper.cpp
# Download large model for better accuracy
bash ./models/download-ggml-model.sh large-v3
```

### Add More TTS Voices
```bash
cd ~/piper-tts/voices
# Download additional voices from:
# https://huggingface.co/rhasspy/piper-voices/tree/main
```

### Add More Offline Content
```bash
# Project Gutenberg (free books)
mkdir ~/offline-data/books
cd ~/offline-data/books
wget -r -l1 -np -A.epub https://www.gutenberg.org/

# Stack Overflow offline
# Download via: https://archive.org/details/stackexchange
```

### Add Ham Radio Software
```bash
sudo apt install -y fldigi qsstv

# For emergency communications
```

---

## Appendix B: Troubleshooting Guide

### Issue: Models won't download
```bash
# Check disk space
df -h

# Check Ollama logs
journalctl -u ollama -n 50

# Manual download
cd ~/.ollama/models
# Download from HuggingFace manually
```

### Issue: Out of memory
```bash
# Check memory usage
free -h

# Kill memory-heavy processes
killall chrome firefox

# Use smaller models
ollama run llama3.2:3b
```

### Issue: USB drive slow
```bash
# Check USB version
lsusb -t

# Check drive health
sudo smartctl -a /dev/sdX

# Optimize ext4
sudo tune2fs -O fast_commit /dev/sdX2
```

### Issue: OpenClaw not connecting to Ollama
```bash
# Verify Ollama is running
curl http://127.0.0.1:11434/api/tags

# Check OpenClaw config
cat ~/openclaw/config.json

# Restart Ollama
sudo systemctl restart ollama
```

---

## Appendix C: Recommended External Resources

### To Download While Online:
1. **Survival Manuals** (PDF)
   - SAS Survival Handbook
   - US Army Survival Manual (FM 21-76)
   - Wilderness Medicine textbooks

2. **Technical References** (PDF)
   - Electronics repair manuals
   - Mechanical engineering handbooks
   - First aid guides

3. **Legal Documents**
   - Your jurisdiction's legal codes
   - Constitutional documents
   - Emergency procedures

4. **Maps**
   - Offline OpenStreetMap data
   - Topographic maps
   - Infrastructure maps

5. **Communication Protocols**
   - Ham radio frequencies
   - Emergency broadcast information
   - Communication encryption guides

---

## Document End

**Congratulations!** You now have a complete, offline AI system ready for any scenario.

**Final Steps:**
1. Run `./final-verification.sh`
2. Create backup with `./create-backup.sh`
3. Store backup in secure, offline location
4. Test all features regularly
5. Keep system updated (when network is enabled)

**Remember:**
- This system prioritizes privacy and offline capability
- Network is disabled by default (Ghost Mode)
- All AI processing happens locally
- No data leaves your USB drive
- You have complete control

Stay safe, stay private, stay prepared.

EOF

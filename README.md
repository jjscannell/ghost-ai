# Ghost AI System - Automated Setup

This automation harness reduces the manual setup time from 4-6 hours to approximately 30 minutes of active work, with 2-4 hours of unattended downloads and installation.

## Overview

The automation consists of three main components:

1. **ghost-ai-preflight.sh** - Runs on your host machine to prepare the USB
2. **ghost-ai-orchestrator.sh** - Runs on the USB to automate the entire installation
3. **offline-ai-usb-setup-guide.md** - Complete manual for reference

## Quick Start (Automated)

### Prerequisites
- 256GB+ USB 3.0 drive
- Host computer with internet connection
- 2-4 hours for downloads and installation
- Basic terminal familiarity

### Step 1: Prepare USB (Host Machine)

```bash
# Download the automation scripts
wget https://[your-location]/ghost-ai-preflight.sh
wget https://[your-location]/ghost-ai-orchestrator.sh
chmod +x ghost-ai-preflight.sh ghost-ai-orchestrator.sh

# Run pre-flight (this will write Ubuntu to USB)
sudo ./ghost-ai-preflight.sh /dev/sdX  # Replace sdX with your USB device

# ⚠️  WARNING: This will erase ALL data on the USB!
```

The pre-flight script will:
- Download Ubuntu 24.04 ISO (~6GB)
- Write ISO to USB drive
- Copy orchestrator script to USB
- Optionally pre-download large files

### Step 2: Boot and Install (Target Machine)

1. **Boot from USB:**
   - Insert USB into target computer
   - Restart and access boot menu (usually F2, F12, DEL, or ESC)
   - Select your USB drive
   - Choose "Try Ubuntu" (don't install yet)

2. **Run automated setup:**
   ```bash
   # Open Terminal (Ctrl+Alt+T)
   cd /media/ubuntu/*
   sudo bash ghost-ai-orchestrator.sh
   ```

3. **Wait for completion:**
   - Total time: 2-4 hours (mostly unattended)
   - Script will show progress for each step
   - Grab a coffee ☕

4. **Reboot and enjoy:**
   ```bash
   # After completion, reboot
   sudo reboot
   
   # Boot from USB again
   # Login as: ghost / [your password]
   
   # Verify installation
   ./test-system.sh
   
   # Enable ghost mode
   ~/tools/network-off.sh
   
   # Start AI
   ./start-openclaw.sh
   ```

## What Gets Automated

### ✅ Fully Automated (Zero Interaction)
- [x] System updates and package installation
- [x] Ollama installation and configuration
- [x] All 7 AI model downloads (parallel)
- [x] Node.js and OpenClaw setup
- [x] Whisper installation and model download
- [x] Piper TTS installation and voice models
- [x] ComfyUI and Stable Diffusion setup
- [x] Firewall configuration
- [x] Network isolation scripts
- [x] All helper scripts and documentation
- [x] Desktop shortcuts

### ⚠️ Semi-Automated (Requires Confirmation)
- [ ] Wikipedia download (optional, ~96GB, 1-3 hours)
- [ ] USB device selection (safety check)
- [ ] Partition layout (during Ubuntu install)

### ❌ Manual Steps Required
- [ ] Physical USB insertion
- [ ] BIOS boot menu access
- [ ] Ubuntu installation wizard (5 minutes)
- [ ] Encryption password (if using LUKS)
- [ ] User password creation

## Automation Architecture

```
┌─────────────────────────────────────────────────────┐
│ Phase 1: Pre-flight (Host Machine)                 │
│ - Download Ubuntu ISO                               │
│ - Write to USB                                      │
│ - Copy orchestrator script                          │
│ - Optional: Pre-download large files                │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ Phase 2: Boot and Manual Install                   │
│ - Boot from USB (manual)                            │
│ - Run Ubuntu installer (manual, 5 min)              │
│ - Partition and encrypt (manual)                    │
│ - Create user (manual)                              │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ Phase 3: Automated Setup (ghost-ai-orchestrator.sh)│
│ - Install packages (5 min)                          │
│ - Install Ollama (2 min)                            │
│ - Download models (1-2 hours, parallel)             │
│ - Install OpenClaw (5 min)                          │
│ - Install Whisper (10 min)                          │
│ - Install Piper TTS (5 min)                         │
│ - Install ComfyUI + SD (15 min)                     │
│ - Download Wikipedia (optional, 1-3 hours)          │
│ - Configure security (2 min)                        │
│ - Create documentation (1 min)                      │
└─────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────┐
│ Phase 4: Verification and Finalization             │
│ - Run test suite                                    │
│ - Enable ghost mode                                 │
│ - Create backup ISO (optional)                      │
└─────────────────────────────────────────────────────┘
```

## Time Breakdown

| Phase | Active Time | Unattended Time | Total |
|-------|-------------|-----------------|-------|
| Pre-flight | 5 min | 20 min | 25 min |
| Ubuntu Install | 15 min | 20 min | 35 min |
| Automated Setup | 5 min | 90-180 min | 95-185 min |
| Wikipedia (opt) | 1 min | 60-180 min | 61-181 min |
| **Total** | **26 min** | **190-400 min** | **216-426 min** |

**Manual method:** ~4-6 hours of active work
**Automated method:** ~30 minutes of active work + 3-7 hours unattended

## Customization

### Modify Models to Download

Edit `ghost-ai-orchestrator.sh`, around line 200:

```bash
# Add or remove models
download_model "llama3.3:70b" "Llama 3.3 70B"
download_model "codestral:22b" "Codestral 22B"
```

### Skip Components

You can comment out entire steps in the orchestrator:

```bash
# Skip ComfyUI installation
# step "Install ComfyUI and Stable Diffusion"
# ... (comment out entire section)
```

### Pre-download Files

To speed up setup, pre-download large files:

```bash
# Run pre-flight with downloads
sudo ./ghost-ai-preflight.sh /dev/sdX
# Select "yes" when prompted for pre-downloads

# Files will download to ~/ghost-ai-preflight/downloads/
# Copy to external drive for transfer to USB during setup
```

## Troubleshooting

### Orchestrator Fails to Start

**Problem:** Script not found after booting
**Solution:** The USB partition may have a different mount point

```bash
# Find the USB mount
mount | grep "^/dev/sd"

# Navigate to correct location
cd /media/ubuntu/[TAB for autocomplete]
sudo bash ghost-ai-orchestrator.sh
```

### Downloads Are Slow

**Problem:** Model downloads taking too long
**Solution:** The script downloads 3-4 models in parallel

```bash
# Check progress
tail -f ~/ghost-ai-setup.log

# Continue in background if needed
nohup sudo bash ghost-ai-orchestrator.sh &
```

### Out of Disk Space

**Problem:** USB fills up during installation
**Solution:** 256GB is minimum, 512GB recommended

```bash
# Check space
df -h

# Skip Wikipedia if space is low
# Edit orchestrator and comment out Wikipedia section
```

### Network Issues During Setup

**Problem:** Can't download packages or models
**Solution:** Ensure internet connection is active

```bash
# Test connectivity
ping -c 3 google.com

# Check NetworkManager
systemctl status NetworkManager

# Restart if needed
sudo systemctl restart NetworkManager
```

### Ollama Models Not Downloading

**Problem:** Ollama pull commands failing
**Solution:** Check Ollama service and connectivity

```bash
# Check Ollama service
systemctl status ollama

# Test Ollama API
curl http://127.0.0.1:11434/api/tags

# Manual download
ollama pull llama3.1:8b
```

## Advanced Usage

### Fully Unattended Installation (Experimental)

For completely hands-off installation, you can use Ubuntu's autoinstall feature:

1. Create `autoinstall.yaml` configuration
2. Add to USB during pre-flight
3. Boot and installation runs automatically

**Note:** This requires careful configuration and testing.

### Parallel USB Creation

Create multiple USB drives in parallel:

```bash
# Terminal 1
sudo ./ghost-ai-preflight.sh /dev/sdb

# Terminal 2
sudo ./ghost-ai-preflight.sh /dev/sdc

# Both will run independently
```

### Remote Installation

Set up over SSH after initial Ubuntu install:

```bash
# On target machine (after Ubuntu install)
sudo apt install openssh-server
ip addr show

# From remote machine
scp ghost-ai-orchestrator.sh ghost@[IP]:/home/ghost/
ssh ghost@[IP]
sudo bash ghost-ai-orchestrator.sh
```

## Files Generated

After setup completion, you'll have:

```
/home/ghost/
├── openclaw/                 # OpenClaw installation
├── whisper.cpp/              # Whisper installation
├── piper-tts/                # Piper TTS installation
├── ComfyUI/                  # ComfyUI installation
├── offline-data/             # Reference data
│   ├── wikipedia/            # Wikipedia ZIM files
│   ├── medical/              # Medical references
│   ├── legal/                # Legal documents
│   ├── survival/             # Survival guides
│   └── technical/            # Technical manuals
├── tools/                    # Utility scripts
│   ├── network-on.sh         # Enable network
│   ├── network-off.sh        # Disable network (ghost mode)
│   ├── transcribe.sh         # Speech-to-text
│   ├── speak.sh              # Text-to-speech
│   ├── randomize-mac.sh      # MAC randomization
│   └── secure-erase.sh       # Secure file deletion
├── start-openclaw.sh         # Start AI assistant
├── start-kiwix.sh            # Start Wikipedia
├── start-comfyui.sh          # Start image generation
├── system-info.sh            # System information
├── test-system.sh            # Verify installation
├── README.md                 # Quick reference
└── ghost-ai-setup.log        # Installation log
```

## Security Considerations

The automated setup:
- ✅ Configures firewall to block all traffic by default
- ✅ Sets Ollama to listen only on localhost
- ✅ Disables NetworkManager by default
- ✅ Creates network toggle scripts
- ✅ Includes MAC randomization
- ✅ Provides secure erase tools

**Important:** 
- Use strong passwords during setup
- Enable LUKS encryption during Ubuntu install
- Keep USB physically secure
- Regularly create backups

## Performance Tips

### Speed Up Model Downloads
- Use wired connection instead of WiFi
- Close other bandwidth-heavy applications
- Consider pre-downloading models

### Optimize for Speed
```bash
# Use faster models by default
# Edit ~/openclaw/config.json
{
  "model": "llama3.2:3b",  # Changed from llama3.1:8b
  ...
}
```

### Reduce Disk Usage
```bash
# Skip Wikipedia (saves ~96GB)
# Comment out Step 8 in orchestrator

# Use smaller models only
# Edit model download section, remove 32B model
```

## Validation

After setup completes, validate everything:

```bash
# Run comprehensive test
./test-system.sh

# Check disk space
df -h

# Verify models
ollama list

# Test inference
ollama run llama3.1:8b "Test message"

# Test network isolation
ping google.com  # Should fail if ghost mode enabled
```

## Support and Debugging

### Logs
All operations are logged to `~/ghost-ai-setup.log`

```bash
# View full log
less ~/ghost-ai-setup.log

# Watch live
tail -f ~/ghost-ai-setup.log

# Search for errors
grep -i error ~/ghost-ai-setup.log
```

### Common Issues

1. **Script stops unexpectedly**
   - Check log file for last error
   - Ensure adequate disk space
   - Verify internet connection

2. **Ollama service won't start**
   - Check system logs: `journalctl -u ollama`
   - Restart: `sudo systemctl restart ollama`

3. **Models missing after install**
   - Check `~/.ollama/models` directory
   - Re-run download script manually

4. **OpenClaw won't connect**
   - Verify Ollama is running: `systemctl status ollama`
   - Check config: `cat ~/openclaw/config.json`
   - Test API: `curl http://127.0.0.1:11434/api/tags`

## Contributing

To improve the automation:

1. Test on different hardware configurations
2. Add error recovery for common failures
3. Optimize download parallelization
4. Add more pre-flight checks
5. Create GUI wrapper for less technical users

## License

This automation harness is provided as-is for the Ghost AI System setup.
Refer to individual component licenses for their respective terms.

---

**Automation Level:** ~85% of setup process
**Time Saved:** ~3-5 hours of manual work
**Recommended For:** Anyone setting up Ghost AI System

For manual installation, see `offline-ai-usb-setup-guide.md`

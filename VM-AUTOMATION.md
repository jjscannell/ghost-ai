# Ghost AI - Complete VM Automation Guide

## 🎯 Goal
Get OpenClaw + Ollama running in your UTM Ubuntu VM with maximum automation.

---

## 📦 What I've Created For You

### 1. **vm-quick-install.sh** (Run INSIDE VM)
   - Fully automated installer
   - Installs: Ollama, OpenClaw, Whisper, AI models
   - Stores everything in shared ~/Dev folder
   - Creates helper commands: `start-openclaw`, `test-ollama`, `system-info`
   - Time: 30-60 minutes (mostly downloads)

### 2. **vm-connect.sh** (Run on macOS HOST)
   - Auto-detects VM IP address
   - Menu-driven interface
   - Can trigger remote installation
   - Monitor VM status from macOS
   - Start/stop services remotely

### 3. **verify-vm-setup.sh** (Run INSIDE VM first)
   - Checks all prerequisites
   - Verifies shared folder is mounted
   - Validates RAM/disk space
   - Shows what's already installed

### 4. **VM-QUICKSTART.md**
   - Complete guide for VM installation
   - Troubleshooting tips
   - Manual installation fallback

---

## 🚀 Three Ways to Install (Pick One)

### Option A: Inside VM (Direct) ⭐ RECOMMENDED
```bash
# 1. Open terminal INSIDE your UTM Ubuntu VM
# 2. Run:
cd ~/Dev/Ghost-AI
./vm-quick-install.sh

# 3. Wait 30-60 minutes
# 4. Done! Type: start-openclaw
```

### Option B: From macOS (Remote)
```bash
# 1. Open terminal on macOS HOST
# 2. Run:
cd ~/Dev/Ghost-AI
./vm-connect.sh ubuntu

# 3. Choose option 2: "Run vm-quick-install.sh in VM"
# 4. Wait for completion
```

### Option C: Manual Control (Advanced)
```bash
# 1. SSH into VM: ssh ubuntu@<VM-IP>
# 2. Run commands manually from VM-QUICKSTART.md
```

---

## 📋 Pre-Flight Checklist

Before running the installer, verify your VM setup:

```bash
# Inside VM terminal:
cd ~/Dev/Ghost-AI
./verify-vm-setup.sh
```

This checks:
- ✅ Shared folder mounted correctly
- ✅ Internet connection
- ✅ Sufficient RAM (8GB+)
- ✅ Sufficient disk (50GB+)
- ✅ Required packages

---

## 🎬 Complete Walkthrough

### Step 1: Verify Shared Folder (INSIDE VM)
```bash
ls ~/Dev/Ghost-AI/
# Should see: vm-quick-install.sh, vm-connect.sh, etc.
```

If not visible, check UTM:
- Right-click VM → Edit
- Sharing → Ensure `/Users/vs7/Dev` is shared as `Dev`

### Step 2: Run Pre-Flight Check (INSIDE VM)
```bash
cd ~/Dev/Ghost-AI
./verify-vm-setup.sh
```

Fix any ✗ REQUIRED errors before continuing.

### Step 3: Run Automated Install (INSIDE VM)
```bash
./vm-quick-install.sh
```

**This will:**
- Update system packages (2 min)
- Enable SSH (1 min)
- Install Ollama (2 min)
- Download AI models (30-45 min) ⏱️ **LONGEST STEP**
- Install Node.js (2 min)
- Clone and setup OpenClaw (5 min)
- Install Whisper (5 min)
- Create helper scripts (1 min)

**Total time:** ~50 minutes (grab coffee ☕)

### Step 4: Test Installation (INSIDE VM)
```bash
# Check system info
system-info

# Test Ollama
test-ollama

# Start OpenClaw
start-openclaw
```

---

## 🔧 What Gets Installed

### Core Components:
- **Ollama** - Local LLM engine (systemd user service)
- **OpenClaw** - AI assistant interface
- **Whisper** - Speech-to-text (optional, for future use)
- **Node.js 20 LTS** - Runtime for OpenClaw

### AI Models (in ~/Dev/ollama-models/):
- **llama3.2:3b** - Fast, small model (~2GB)
- **llama3.1:8b** - Balanced model (~4.7GB)
- **phi3:mini** - Efficient alternative (~2.3GB)

### Helper Scripts (in ~/bin/):
- `start-openclaw` - Launch OpenClaw
- `test-ollama` - Verify Ollama status
- `system-info` - Show system details

---

## 🎯 After Installation

### Test OpenClaw:
```bash
start-openclaw

# Or manually:
cd ~/Dev/openclaw
npm start
```

### Test Ollama directly:
```bash
ollama run llama3.2:3b "Write me a haiku about AI"
```

### SSH from macOS:
```bash
# Get VM IP (shown at end of installation)
# Then from macOS:
ssh ubuntu@192.168.64.X

# Or use helper:
./vm-connect.sh ubuntu
```

---

## 🐛 Troubleshooting

### "Shared folder not found"
```bash
# Check mount inside VM
mount | grep Dev

# If not mounted, update UTM settings:
# VM → Edit → Sharing → Add Directory
# Path: /Users/vs7/Dev
# Name: Dev
# Restart VM
```

### "Permission denied"
```bash
chmod +x ~/Dev/Ghost-AI/vm-quick-install.sh
```

### "Ollama not responding"
```bash
systemctl --user status ollama
systemctl --user restart ollama
curl http://127.0.0.1:11434/api/tags
```

### "npm not found"
```bash
# Run this part manually:
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs
```

### "Out of disk space"
```bash
# Check space
df -h /

# Solutions:
# 1. Increase VM disk in UTM settings
# 2. Remove unnecessary files
# 3. Edit vm-quick-install.sh to skip some models
```

---

## 📊 Resource Usage

**Minimum Requirements:**
- RAM: 8GB
- Disk: 50GB free
- Internet: Required during install

**Installed Size:**
- System packages: ~2GB
- Ollama: ~500MB
- AI Models: ~9GB (3 models)
- OpenClaw: ~200MB
- Whisper: ~1GB
- **Total: ~13GB**

**Recommended:**
- RAM: 16GB+ (for larger models)
- Disk: 100GB+ (for more models)

---

## 🔄 Next Steps

After successful VM installation:

1. **Test thoroughly** in VM before USB creation
2. **Try different models** (ollama pull llama3.1:70b)
3. **Configure network isolation** (for ghost mode)
4. **Create bootable USB** with same config
5. **Document any issues** for production setup

---

## 🆘 Emergency Manual Install

If automation fails completely:

```bash
# Minimal working setup (5 minutes)
curl -fsSL https://ollama.com/install.sh | sh
ollama serve &
sleep 3
ollama pull llama3.2:3b
ollama run llama3.2:3b "Hello world"
```

This gets you a working Ollama in under 5 minutes for testing.

---

**Ready to begin? Start here:**
```bash
cd ~/Dev/Ghost-AI
./verify-vm-setup.sh
./vm-quick-install.sh
```

Good luck! 🚀

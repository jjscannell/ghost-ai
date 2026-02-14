# Ghost AI - VM Quick Start Guide

## 🚀 Fastest Path to Running OpenClaw in UTM VM

This guide gets you from a fresh Ubuntu VM to a running OpenClaw system in under 1 hour (mostly automated downloads).

---

## Prerequisites

- ✅ UTM VM running Ubuntu
- ✅ Shared folder mounted (`~/Dev` in VM points to your macOS `~/Dev`)
- ✅ Internet connection in VM
- ✅ At least 8GB RAM allocated to VM
- ✅ At least 50GB disk space for AI models

---

## Option 1: Fully Automated (Recommended)

### Inside the VM Terminal:

```bash
# Navigate to shared folder
cd ~/Dev/Ghost-AI

# Run automated installer
./vm-quick-install.sh
```

**That's it!** The script will:
- ✅ Install all system packages
- ✅ Enable SSH for remote access
- ✅ Install and configure Ollama
- ✅ Download AI models (llama3.2:3b, llama3.1:8b, phi3:mini)
- ✅ Install OpenClaw
- ✅ Install Whisper (speech-to-text)
- ✅ Create helper scripts
- ✅ Store everything in shared folder (accessible from host)

**Installation time:** 30-60 minutes (mostly downloading models)

---

## Option 2: Host-Controlled (Remote)

### From macOS Terminal:

```bash
cd ~/Dev/Ghost-AI

# Run connection helper
./vm-connect.sh ubuntu  # Replace 'ubuntu' with your VM username
```

The helper will:
- 🔍 Auto-detect VM IP address
- 📋 Show menu of options:
  1. SSH into VM
  2. **Run automated install remotely**
  3. Check VM status
  4. Copy files to VM
  5. Start OpenClaw
  6. View installed models

**Tip:** Choose option 2 to run the full automated install from your host!

---

## After Installation

### Quick Commands (inside VM):

```bash
# Start OpenClaw AI assistant
start-openclaw

# Test Ollama and list models
test-ollama

# View system information
system-info

# Manual Ollama test
ollama run llama3.2:3b "Hello, tell me a joke"
```

### File Locations:

All installations are in your **shared Dev folder**:
- 📁 OpenClaw: `~/Dev/openclaw/`
- 📁 AI Models: `~/Dev/ollama-models/`
- 📁 Whisper: `~/Dev/whisper.cpp/`

**Benefit:** Models are stored in shared folder, so they're accessible from macOS too!

---

## SSH Access from macOS

After installation, the VM will display its IP address. To connect from macOS:

```bash
# SSH into VM
ssh ubuntu@192.168.64.X  # Replace with your VM IP

# Or use the helper
./vm-connect.sh ubuntu
```

---

## Troubleshooting

### Can't find vm-quick-install.sh

Make sure the shared folder is mounted:
```bash
# Inside VM
ls ~/Dev/Ghost-AI/
# Should show: vm-quick-install.sh and other files
```

If not mounted, check UTM settings:
1. Right-click VM → Edit
2. Sharing → Shared Directory
3. Path: `/Users/vs7/Dev` → Mount as `Dev`

### Installation fails

Check logs:
```bash
# Inside VM, during install, open another terminal
journalctl -f
```

### Ollama won't start

```bash
# Inside VM
systemctl --user status ollama
systemctl --user restart ollama

# Check if port is listening
curl http://127.0.0.1:11434/api/tags
```

### Out of disk space

Models are large! Check space:
```bash
df -h /
```

If low:
- Increase VM disk size in UTM
- Install fewer models (edit vm-quick-install.sh)

---

## Manual Installation (If Script Fails)

If the automated script doesn't work, here's the manual process:

```bash
# 1. Update system
sudo apt update && sudo apt upgrade -y

# 2. Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# 3. Start Ollama
ollama serve &

# 4. Download a model
ollama pull llama3.2:3b

# 5. Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 6. Clone OpenClaw
cd ~/Dev
git clone https://github.com/ckreiling/openclaw.git
cd openclaw
npm install

# 7. Create config
cat > config.json << EOF
{
  "model": "llama3.2:3b",
  "ollamaHost": "http://127.0.0.1:11434",
  "temperature": 0.7,
  "stream": true
}
EOF

# 8. Start OpenClaw
npm start
```

---

## Next Steps

After OpenClaw is running:
- ✅ Test different models (llama3.1:8b, phi3:mini)
- ✅ Try speech-to-text with Whisper
- ✅ Configure network isolation (ghost mode)
- ✅ Create bootable USB with the same setup

---

## Performance Tips

### For faster responses:
```bash
# Use the small, fast model
ollama run llama3.2:3b "Your question here"
```

### For better quality:
```bash
# Use the larger model
ollama run llama3.1:8b "Your question here"
```

### Check model sizes:
```bash
ollama list
```

---

## Get Help

If you encounter issues:
1. Check `~/Dev/Ghost-AI/README.md` for detailed docs
2. View logs: `journalctl -u ollama` or `systemctl --user status ollama`
3. Test connection: `curl http://127.0.0.1:11434/api/tags`

---

**Ready to go? Run this inside your VM:**
```bash
cd ~/Dev/Ghost-AI && ./vm-quick-install.sh
```

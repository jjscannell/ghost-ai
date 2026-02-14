#!/bin/bash
#
# Ghost AI - VM Quick Install
# Run this INSIDE the VM to install everything automatically
#
# This script assumes:
# - Running inside Ubuntu VM
# - /home/[user]/Dev is mounted from host (shared folder)
# - Internet connection available
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${BLUE}[VM-INSTALL]${NC} $1"; }
log_success() { echo -e "${GREEN}[VM-INSTALL] ✓${NC} $1"; }
log_error() { echo -e "${RED}[VM-INSTALL] ✗${NC} $1"; }
log_warning() { echo -e "${YELLOW}[VM-INSTALL] ⚠${NC} $1"; }

# Determine current user
CURRENT_USER=$(whoami)
VM_HOME="/home/${CURRENT_USER}"
SHARED_DEV="${VM_HOME}/Dev"
MODELS_DIR="${SHARED_DEV}/ollama-models"

# Banner
clear
echo -e "${CYAN}"
cat << 'EOF'
  ____  _               _      _    ___
 / ___|| |__   ___  ___| |_   / \  |_ _|
| |  _ | '_ \ / _ \/ __| __| / _ \  | |
| |_| || | | | (_) \__ \ |_ / ___ \ | |
 \____||_| |_|\___/|___/\__/_/   \_\___|

     VM Quick Install - Automated Setup
EOF
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Do NOT run as root. Run as your regular user (will use sudo when needed)"
    exit 1
fi

# Verify shared folder exists
if [ ! -d "$SHARED_DEV" ]; then
    log_error "Shared Dev folder not found at: $SHARED_DEV"
    log_error "Please mount the shared folder first or update SHARED_DEV path"
    exit 1
fi

log_success "Shared Dev folder found: $SHARED_DEV"

# Create models directory in shared space
mkdir -p "$MODELS_DIR"

log "Starting automated installation..."
echo ""

# STEP 1: System Updates
log "STEP 1/8: System updates and package installation..."
sudo apt-get update
sudo apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm \
    jq \
    htop \
    net-tools \
    openssh-server \
    || log_warning "Some packages may have failed to install"

log_success "System packages installed"

# STEP 2: Enable SSH for remote access
log "STEP 2/8: Enabling SSH for remote access..."
sudo systemctl enable ssh
sudo systemctl start ssh

VM_IP=$(hostname -I | awk '{print $1}')
log_success "SSH enabled. VM IP: ${VM_IP}"
log_warning "To connect from host: ssh ${CURRENT_USER}@${VM_IP}"

# STEP 3: Install Ollama
log "STEP 3/8: Installing Ollama..."
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.com/install.sh | sh
    log_success "Ollama installed"
else
    log_success "Ollama already installed"
fi

# Configure Ollama to use shared models directory
log "Configuring Ollama to use shared storage..."
mkdir -p ~/.config/systemd/user/
cat > ~/.config/systemd/user/ollama.service << EOF
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
Type=simple
Environment="OLLAMA_MODELS=${MODELS_DIR}"
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
EOF

# Start Ollama as user service
systemctl --user daemon-reload
systemctl --user enable ollama
systemctl --user restart ollama

# Wait for Ollama to start
sleep 3
log_success "Ollama configured and running (models stored in shared folder)"

# STEP 4: Download AI Models
log "STEP 4/8: Downloading AI models (this may take 30-60 minutes)..."

download_model() {
    local model_name=$1
    local display_name=$2

    log "Downloading: ${display_name}..."
    OLLAMA_MODELS="$MODELS_DIR" ollama pull "$model_name" &
}

# Download models in parallel (3 at a time for VM)
log "Starting parallel downloads..."

download_model "llama3.2:3b" "Llama 3.2 3B (fast)"
download_model "llama3.1:8b" "Llama 3.1 8B (general)"
download_model "phi3:mini" "Phi-3 Mini (efficient)"

# Wait for first batch
wait

log_success "Core models downloaded to shared folder: ${MODELS_DIR}"

# STEP 5: Install Node.js LTS (if needed)
log "STEP 5/8: Ensuring Node.js LTS..."
if ! node --version | grep -q "v20" 2>/dev/null; then
    log "Installing Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi
log_success "Node.js $(node --version) ready"

# STEP 6: Clone and Install OpenClaw
log "STEP 6/8: Installing OpenClaw..."

OPENCLAW_DIR="${SHARED_DEV}/openclaw"
if [ ! -d "$OPENCLAW_DIR" ]; then
    log "Cloning OpenClaw..."
    cd "$SHARED_DEV"
    git clone https://github.com/ckreiling/openclaw.git
    cd openclaw
else
    log "OpenClaw already exists, updating..."
    cd "$OPENCLAW_DIR"
    git pull
fi

# Install dependencies
log "Installing OpenClaw dependencies..."
npm install

# Create basic config
cat > config.json << EOF
{
  "model": "llama3.2:3b",
  "ollamaHost": "http://127.0.0.1:11434",
  "temperature": 0.7,
  "stream": true
}
EOF

log_success "OpenClaw installed at: ${OPENCLAW_DIR}"

# STEP 7: Install Whisper (speech-to-text)
log "STEP 7/8: Installing Whisper..."

WHISPER_DIR="${SHARED_DEV}/whisper.cpp"
if [ ! -d "$WHISPER_DIR" ]; then
    cd "$SHARED_DEV"
    git clone https://github.com/ggerganov/whisper.cpp.git
    cd whisper.cpp
    make

    # Download small model
    bash ./models/download-ggml-model.sh small
    log_success "Whisper installed with small model"
else
    log_success "Whisper already installed"
fi

# STEP 8: Create helper scripts
log "STEP 8/8: Creating helper scripts..."

mkdir -p ~/bin

# Start OpenClaw script
cat > ~/bin/start-openclaw << 'EOFSCRIPT'
#!/bin/bash
cd ~/Dev/openclaw
echo "Starting OpenClaw..."
echo "Model: llama3.2:3b"
echo "Config: config.json"
echo ""
npm start
EOFSCRIPT
chmod +x ~/bin/start-openclaw

# Test Ollama script
cat > ~/bin/test-ollama << 'EOFSCRIPT'
#!/bin/bash
echo "Testing Ollama connection..."
curl http://127.0.0.1:11434/api/tags | jq .
echo ""
echo "Available models:"
ollama list
EOFSCRIPT
chmod +x ~/bin/test-ollama

# System info script
cat > ~/bin/system-info << 'EOFSCRIPT'
#!/bin/bash
echo "=== Ghost AI System Info ==="
echo "User: $(whoami)"
echo "VM IP: $(hostname -I | awk '{print $1}')"
echo "RAM: $(free -h | awk '/^Mem:/ {print $2}')"
echo "Disk: $(df -h / | awk 'NR==2 {print $4 " available"}')"
echo ""
echo "=== Ollama Status ==="
systemctl --user status ollama --no-pager -l | head -10
echo ""
echo "=== Available Models ==="
ollama list
echo ""
echo "=== OpenClaw Location ==="
ls -lh ~/Dev/openclaw/ | head -5
EOFSCRIPT
chmod +x ~/bin/system-info

# Add to PATH if not already
if ! grep -q '~/bin' ~/.bashrc; then
    echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
fi

log_success "Helper scripts created in ~/bin/"

# Final summary
echo ""
echo "========================================"
echo -e "${GREEN}Installation Complete!${NC}"
echo "========================================"
echo ""
echo "Quick Start Commands:"
echo "  start-openclaw    - Launch OpenClaw AI assistant"
echo "  test-ollama       - Test Ollama and list models"
echo "  system-info       - Show system information"
echo ""
echo "Locations:"
echo "  OpenClaw: ${OPENCLAW_DIR}"
echo "  Models:   ${MODELS_DIR}"
echo "  Whisper:  ${WHISPER_DIR}"
echo ""
echo "VM IP Address: ${VM_IP}"
echo "SSH Access: ssh ${CURRENT_USER}@${VM_IP}"
echo ""
echo -e "${CYAN}To start using Ghost AI, run: start-openclaw${NC}"
echo ""

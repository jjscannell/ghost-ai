#!/bin/bash
#
# Ghost AI System - Automated Setup Orchestrator
# 
# This script automates the bulk of the Ghost AI USB setup process.
# It will download, install, and configure everything needed for an
# offline AI assistant system.
#
# Usage: sudo ./ghost-ai-orchestrator.sh [config-file.json]
#
# Requirements:
# - Fresh Ubuntu 24.04 installation on USB drive
# - Internet connection (will be disabled at end)
# - 256GB+ USB drive
# - Sudo privileges
#

set -e  # Exit on error

# Configuration
GHOST_USER="ghost"
GHOST_HOME="/home/${GHOST_USER}"
LOG_FILE="${GHOST_HOME}/ghost-ai-setup.log"
PARALLEL_DOWNLOADS=4
CONFIG_FILE="$1"

# Default configuration
PERF_TIER="standard"
INSTALL_WIKIPEDIA=true
INSTALL_ENCRYPTION=true
INSTALL_DOCS=true
INSTALL_BOOKS=false
GPU_TYPE="cpu"  # cpu, nvidia, amd, apple

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $1" | tee -a "$LOG_FILE"
}

# Progress tracker
TOTAL_STEPS=10
CURRENT_STEP=0

step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    log ""
    log "========================================="
    log "STEP $CURRENT_STEP/$TOTAL_STEPS: $1"
    log "========================================="
}

# Error handler
error_exit() {
    log_error "Setup failed at step $CURRENT_STEP: $1"
    log_error "Check log file: $LOG_FILE"
    exit 1
}

# ============================================================================
# DISK SPACE CHECK FUNCTION
# ============================================================================
check_disk_space() {
    local required_gb=$1
    local path=${2:-"/"}
    local available_gb=$(df -BG "$path" | awk 'NR==2 {gsub(/G/, "", $4); print $4}')

    if [ "$available_gb" -lt "$required_gb" ]; then
        log_error "Insufficient disk space!"
        log_error "Required: ${required_gb}GB, Available: ${available_gb}GB"
        return 1
    fi
    log_success "Disk space check passed: ${available_gb}GB available (need ${required_gb}GB)"
    return 0
}

# Calculate required space based on tier
calculate_required_space() {
    local base_space=40  # Base system + essential tools

    case "$PERF_TIER" in
        basic)      base_space=$((base_space + 30)) ;;   # ~30GB models
        standard)   base_space=$((base_space + 45)) ;;   # ~45GB models
        performance) base_space=$((base_space + 60)) ;;  # ~60GB models
    esac

    if [ "$INSTALL_WIKIPEDIA" = "true" ]; then
        base_space=$((base_space + 100))  # ~96GB Wikipedia + buffer
    fi

    echo "$base_space"
}

# ============================================================================
# CONFIG VALIDATION FUNCTION
# ============================================================================
validate_config() {
    local config_file=$1

    if [ ! -f "$config_file" ]; then
        log_error "Config file not found: $config_file"
        return 1
    fi

    # Check if it's valid JSON
    if ! jq empty "$config_file" 2>/dev/null; then
        log_error "Invalid JSON in config file"
        return 1
    fi

    # Validate required fields
    local tier=$(jq -r '.tier // empty' "$config_file")
    if [ -z "$tier" ]; then
        log_warning "No tier specified in config, using default: standard"
    elif [[ ! "$tier" =~ ^(basic|standard|performance)$ ]]; then
        log_error "Invalid tier: $tier. Must be basic, standard, or performance"
        return 1
    fi

    # Validate options structure
    if ! jq -e '.options' "$config_file" > /dev/null 2>&1; then
        log_warning "No options section in config, using defaults"
    fi

    log_success "Configuration validated successfully"
    return 0
}

# ============================================================================
# PROGRESS BAR FUNCTION
# ============================================================================
show_progress() {
    local current=$1
    local total=$2
    local label=${3:-"Progress"}
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    printf "\r${BLUE}[%s]${NC} [" "$label"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %3d%%" "$percentage"

    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    log_error "Please run as root (use sudo)"
    exit 1
fi

# Check if we're on Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    log_error "This script is designed for Ubuntu 24.04"
    exit 1
fi

# Load configuration file if provided
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    log "Loading configuration from $CONFIG_FILE..."
    
    # Parse JSON config (requires jq)
    if command -v jq &> /dev/null; then
        PERF_TIER=$(jq -r '.tier // "standard"' "$CONFIG_FILE")
        INSTALL_WIKIPEDIA=$(jq -r '.options.wikipedia // true' "$CONFIG_FILE")
        INSTALL_ENCRYPTION=$(jq -r '.options.encryption // true' "$CONFIG_FILE")
        INSTALL_DOCS=$(jq -r '.options.docs // true' "$CONFIG_FILE")
        INSTALL_BOOKS=$(jq -r '.options.books // false' "$CONFIG_FILE")
        
        # Detect GPU type from hardware info
        GPU_NAME=$(jq -r '.hardware.gpu // "Unknown"' "$CONFIG_FILE")
        if [[ "$GPU_NAME" == *"NVIDIA"* ]] || [[ "$GPU_NAME" == *"RTX"* ]] || [[ "$GPU_NAME" == *"GTX"* ]]; then
            GPU_TYPE="nvidia"
        elif [[ "$GPU_NAME" == *"AMD"* ]] || [[ "$GPU_NAME" == *"Radeon"* ]]; then
            GPU_TYPE="amd"
        elif [[ "$GPU_NAME" == *"Apple"* ]] || [[ "$GPU_NAME" == *"M1"* ]] || [[ "$GPU_NAME" == *"M2"* ]] || [[ "$GPU_NAME" == *"M3"* ]]; then
            GPU_TYPE="apple"
        else
            GPU_TYPE="cpu"
        fi
        
        log_success "Configuration loaded: Tier=$PERF_TIER, GPU=$GPU_TYPE"
    else
        log_warning "jq not found, using default configuration"
    fi
else
    log_warning "No config file provided, using default configuration"
    
    # Auto-detect GPU if possible
    if lspci 2>/dev/null | grep -qi "nvidia\|geforce\|rtx\|gtx"; then
        GPU_TYPE="nvidia"
        PERF_TIER="performance"
        log "Detected NVIDIA GPU"
    elif lspci 2>/dev/null | grep -qi "amd.*radeon\|radeon.*amd"; then
        GPU_TYPE="amd"
        PERF_TIER="standard"
        log "Detected AMD GPU"
    # Apple Silicon detection for Linux (Asahi Linux / Ubuntu on Apple Silicon)
    elif [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
        # Check for Apple Silicon identifiers
        if grep -qi "apple" /proc/cpuinfo 2>/dev/null || \
           [ -d /sys/firmware/devicetree/base ] && grep -qi "apple" /sys/firmware/devicetree/base/compatible 2>/dev/null || \
           dmesg 2>/dev/null | grep -qi "Apple M[0-9]"; then
            GPU_TYPE="apple"
            PERF_TIER="standard"
            log "Detected Apple Silicon (ARM64)"
        fi
    fi

    log "Auto-detected: GPU=$GPU_TYPE, Tier=$PERF_TIER"
fi

# Create log file
mkdir -p "$GHOST_HOME"
touch "$LOG_FILE"
chown ${GHOST_USER}:${GHOST_USER} "$LOG_FILE"

log "========================================="
log "Ghost AI System - Automated Setup"
log "========================================="
log ""
log "This will install and configure:"
log "- Ollama + 7 AI models (~50GB)"
log "- OpenClaw AI agent"
log "- Whisper (speech recognition)"
log "- Piper TTS (text-to-speech)"
log "- ComfyUI + Stable Diffusion"
log "- Offline Wikipedia (~96GB)"
log "- Security hardening"
log ""
log "Total download: ~150GB"
log "Estimated time: 2-4 hours"
log ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Setup cancelled by user"
    exit 0
fi

# ============================================================================
# PRE-FLIGHT: Validate config and check disk space
# ============================================================================
log ""
log "Running pre-flight checks..."

# Validate config if provided
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    if command -v jq &> /dev/null; then
        validate_config "$CONFIG_FILE" || error_exit "Configuration validation failed"
    fi
fi

# Check available disk space
REQUIRED_SPACE=$(calculate_required_space)
log "Checking disk space (need ${REQUIRED_SPACE}GB for selected configuration)..."
check_disk_space "$REQUIRED_SPACE" "/" || error_exit "Not enough disk space"

log ""

# ============================================================================
# STEP 1: System Update and Essential Packages
# ============================================================================
step "System Update and Essential Packages"

log "Updating package lists..."
apt update >> "$LOG_FILE" 2>&1 || error_exit "apt update failed"

log "Upgrading existing packages..."
DEBIAN_FRONTEND=noninteractive apt upgrade -y >> "$LOG_FILE" 2>&1 || error_exit "apt upgrade failed"

log "Installing essential tools..."
DEBIAN_FRONTEND=noninteractive apt install -y \
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
    syslinux-utils \
    xdotool \
    scrot \
    imagemagick \
    xclip \
    wmctrl \
    kiwix-tools \
    rsync \
    squashfs-tools \
    xorriso \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    jq \
    lshw \
    pciutils \
    >> "$LOG_FILE" 2>&1 || error_exit "Essential packages installation failed"

# Create tools directory
su - $GHOST_USER -c "mkdir -p ~/tools ~/offline-data/{medical,legal,survival,technical,maps,wikipedia,books}"

log_success "System updated and essential packages installed"

# ============================================================================
# STEP 2: Install Ollama
# ============================================================================
step "Install Ollama"

log "Downloading and installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh >> "$LOG_FILE" 2>&1 || error_exit "Ollama installation failed"

log "Starting Ollama service..."
systemctl start ollama || error_exit "Failed to start Ollama"
systemctl enable ollama || error_exit "Failed to enable Ollama"

# Wait for Ollama to be ready
log "Waiting for Ollama to be ready..."
for i in {1..30}; do
    if curl -s http://127.0.0.1:11434/api/tags > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Configure Ollama for offline use
log "Configuring Ollama for offline use..."
mkdir -p /etc/systemd/system/ollama.service.d
cat > /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_HOST=127.0.0.1:11434"
Environment="OLLAMA_ORIGINS=http://127.0.0.1:*,http://localhost:*"
Environment="OLLAMA_KEEP_ALIVE=5m"
EOF

systemctl daemon-reload
systemctl restart ollama

log_success "Ollama installed and configured"

# ============================================================================
# STEP 3: Download AI Models (Parallel)
# ============================================================================
step "Download AI Models"

log "Starting parallel model downloads..."
log "Performance tier: $PERF_TIER"

# Create download script for parallel execution based on tier
cat > /tmp/download-models.sh << 'MODELEOF'
#!/bin/bash

# Colors for model download output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

download_model() {
    MODEL=$1
    NAME=$2
    MAX_RETRIES=3
    RETRY_COUNT=0

    echo -e "[$(date +'%H:%M:%S')] Downloading $NAME..."

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        # Run ollama pull and capture exit code
        # Ollama shows progress and returns 0 on success
        if ollama pull "$MODEL" 2>&1; then
            # Verify model was actually downloaded by checking ollama list
            if ollama list 2>/dev/null | grep -q "^${MODEL}"; then
                echo -e "[$(date +'%H:%M:%S')] ${GREEN}✓${NC} $NAME downloaded successfully"
                return 0
            fi
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo -e "[$(date +'%H:%M:%S')] ${YELLOW}⚠${NC} $NAME download failed, retry $RETRY_COUNT/$MAX_RETRIES..."
            sleep $((RETRY_COUNT * 5))  # Exponential backoff
        fi
    done

    echo -e "[$(date +'%H:%M:%S')] ${RED}✗${NC} $NAME failed after $MAX_RETRIES attempts"
    return 1
}

export -f download_model
export GREEN RED YELLOW NC

MODELEOF

# Append tier-specific models
case "$PERF_TIER" in
    basic)
        cat >> /tmp/download-models.sh << 'BASICEOF'
# Basic tier - CPU only, lightweight models
download_model "llama3.2:3b" "Llama 3.2 3B (fast)" &
PID1=$!
sleep 5

download_model "llama3.1:8b" "Llama 3.1 8B (general)" &
PID2=$!
sleep 5

download_model "qwen2.5-coder:7b" "Qwen 2.5 Coder 7B" &
PID3=$!

wait $PID1 $PID2 $PID3

download_model "mistral:7b" "Mistral 7B (alternative)"
download_model "nomic-embed-text" "Nomic Embed Text (RAG)"

echo ""
echo "Basic tier models downloaded!"
ollama list
BASICEOF
        ;;
    
    standard)
        cat >> /tmp/download-models.sh << 'STANDARDEOF'
# Standard tier - AMD GPU / Apple Silicon
download_model "llama3.2:3b" "Llama 3.2 3B (fast)" &
PID1=$!
sleep 5

download_model "llama3.1:8b" "Llama 3.1 8B (general)" &
PID2=$!
sleep 5

download_model "qwen2.5-coder:7b" "Qwen 2.5 Coder 7B" &
PID3=$!
sleep 5

download_model "mistral:7b" "Mistral 7B (alternative)" &
PID4=$!

wait $PID1 $PID2 $PID3 $PID4

download_model "llama3.2-vision:11b" "Llama 3.2 Vision 11B"
download_model "nomic-embed-text" "Nomic Embed Text (RAG)"

echo ""
echo "Standard tier models downloaded!"
ollama list
STANDARDEOF
        ;;
    
    performance)
        cat >> /tmp/download-models.sh << 'PERFEOF'
# Performance tier - NVIDIA GPU, all models
download_model "llama3.2:3b" "Llama 3.2 3B (fast)" &
PID1=$!
sleep 5

download_model "llama3.1:8b" "Llama 3.1 8B (general)" &
PID2=$!
sleep 5

download_model "mistral:7b" "Mistral 7B (alternative)" &
PID3=$!
sleep 5

download_model "qwen2.5-coder:7b" "Qwen 2.5 Coder 7B" &
PID4=$!

wait $PID1 $PID2 $PID3 $PID4

download_model "llama3.2-vision:11b" "Llama 3.2 Vision 11B"
download_model "qwen2.5:32b" "Qwen 2.5 32B (reasoning)"
download_model "nomic-embed-text" "Nomic Embed Text (RAG)"

echo ""
echo "Performance tier models downloaded!"
ollama list
PERFEOF
        ;;
esac

chmod +x /tmp/download-models.sh
su - $GHOST_USER -c "bash /tmp/download-models.sh" | tee -a "$LOG_FILE" || error_exit "Model download failed"

log_success "AI models downloaded"

# ============================================================================
# STEP 4: Install Node.js and OpenClaw
# ============================================================================
step "Install Node.js and OpenClaw"

log "Installing Node.js 20.x..."
curl -fsSL https://deb.nodesource.com/setup_20.x | bash - >> "$LOG_FILE" 2>&1 || error_exit "Node.js repository setup failed"
DEBIAN_FRONTEND=noninteractive apt install -y nodejs >> "$LOG_FILE" 2>&1 || error_exit "Node.js installation failed"

log "Cloning OpenClaw..."
su - $GHOST_USER -c "git clone https://github.com/openclaw/openclaw.git ~/openclaw" >> "$LOG_FILE" 2>&1 || error_exit "OpenClaw clone failed"

log "Installing OpenClaw dependencies..."
su - $GHOST_USER -c "cd ~/openclaw && npm install" >> "$LOG_FILE" 2>&1 || error_exit "OpenClaw dependencies installation failed"

# Create OpenClaw configuration
log "Creating OpenClaw configuration..."
su - $GHOST_USER -c 'cat > ~/openclaw/config.json << '\''EOF'\''
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
EOF'

# Create launcher script
su - $GHOST_USER -c 'cat > ~/start-openclaw.sh << '\''EOF'\''
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

cd ~/openclaw
export DISPLAY=:0
export OLLAMA_HOST="http://127.0.0.1:11434"

echo "Starting OpenClaw..."
npm start
EOF'

chmod +x "$GHOST_HOME/start-openclaw.sh"

log_success "OpenClaw installed and configured"

# ============================================================================
# STEP 5: Install Whisper (Speech Recognition)
# ============================================================================
step "Install Whisper (Speech Recognition)"

log "Cloning whisper.cpp..."
su - $GHOST_USER -c "git clone https://github.com/ggerganov/whisper.cpp.git ~/whisper.cpp" >> "$LOG_FILE" 2>&1 || error_exit "Whisper clone failed"

log "Building whisper.cpp..."
su - $GHOST_USER -c "cd ~/whisper.cpp && make" >> "$LOG_FILE" 2>&1 || error_exit "Whisper build failed"

log "Downloading Whisper medium model..."
su - $GHOST_USER -c "cd ~/whisper.cpp && bash ./models/download-ggml-model.sh medium" >> "$LOG_FILE" 2>&1 || error_exit "Whisper model download failed"

# Create transcribe helper
su - $GHOST_USER -c 'cat > ~/tools/transcribe.sh << '\''EOF'\''
#!/bin/bash
# Usage: ./transcribe.sh audio_file.wav

if [ -z "$1" ]; then
    echo "Usage: $0 <audio_file.wav>"
    exit 1
fi

~/whisper.cpp/main -m ~/whisper.cpp/models/ggml-medium.bin -f "$1"
EOF'

chmod +x "$GHOST_HOME/tools/transcribe.sh"

log_success "Whisper installed"

# ============================================================================
# STEP 6: Install Piper TTS (Text-to-Speech)
# ============================================================================
step "Install Piper TTS (Text-to-Speech)"

log "Downloading Piper..."
# Get latest Piper release dynamically
PIPER_VERSION="v1.2.0"  # Fallback version
if command -v curl &> /dev/null; then
    LATEST_PIPER=$(curl -sI "https://github.com/rhasspy/piper/releases/latest" 2>/dev/null | grep -i "^location:" | grep -oP 'v[\d.]+' | head -1)
    if [ -n "$LATEST_PIPER" ]; then
        PIPER_VERSION="$LATEST_PIPER"
    fi
fi
log "Using Piper version: $PIPER_VERSION"
su - $GHOST_USER -c "cd ~ && wget -c -q --show-progress https://github.com/rhasspy/piper/releases/download/${PIPER_VERSION}/piper_amd64.tar.gz" || error_exit "Piper download failed"
su - $GHOST_USER -c "cd ~ && tar -xzf piper_amd64.tar.gz && mv piper piper-tts && rm piper_amd64.tar.gz" || error_exit "Piper extraction failed"

log "Downloading Piper voice models..."
su - $GHOST_USER -c "mkdir -p ~/piper-tts/voices && cd ~/piper-tts/voices && \
    wget -c -q --show-progress https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx && \
    wget -c -q --show-progress https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json && \
    wget -c -q --show-progress https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx && \
    wget -c -q --show-progress https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx.json" || error_exit "Piper voices download failed"

# Create speak helper
su - $GHOST_USER -c 'cat > ~/tools/speak.sh << '\''EOF'\''
#!/bin/bash
# Usage: echo "text" | ./speak.sh
# Or: ./speak.sh "text to speak"

if [ -z "$1" ]; then
    ~/piper-tts/piper -m ~/piper-tts/voices/en_US-lessac-medium.onnx -f /tmp/speech.wav
else
    echo "$1" | ~/piper-tts/piper -m ~/piper-tts/voices/en_US-lessac-medium.onnx -f /tmp/speech.wav
fi

aplay /tmp/speech.wav 2>/dev/null
rm /tmp/speech.wav
EOF'

chmod +x "$GHOST_HOME/tools/speak.sh"

log_success "Piper TTS installed"

# ============================================================================
# STEP 7: Install ComfyUI and Stable Diffusion (Conditional)
# ============================================================================
step "Install ComfyUI and Stable Diffusion"

if [ "$PERF_TIER" = "basic" ]; then
    log_warning "Skipping image generation for Basic tier (CPU-only is too slow)"
    log "Image generation requires GPU acceleration for practical use"
else
    log "Installing ComfyUI for $GPU_TYPE..."
    
    # Install PyTorch based on GPU type
    case "$GPU_TYPE" in
        nvidia)
            log "Installing CUDA-enabled PyTorch for NVIDIA GPU..."
            su - $GHOST_USER -c "pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cu121" >> "$LOG_FILE" 2>&1 || log_warning "PyTorch CUDA installation had issues"
            ;;
        amd)
            log "Installing ROCm-enabled PyTorch for AMD GPU..."
            su - $GHOST_USER -c "pip3 install torch torchvision --index-url https://download.pytorch.org/whl/rocm5.7" >> "$LOG_FILE" 2>&1 || log_warning "PyTorch ROCm installation had issues"
            ;;
        apple)
            log "Installing Metal-accelerated PyTorch for Apple Silicon..."
            su - $GHOST_USER -c "pip3 install torch torchvision" >> "$LOG_FILE" 2>&1 || log_warning "PyTorch Metal installation had issues"
            ;;
        *)
            log "Installing CPU-only PyTorch..."
            su - $GHOST_USER -c "pip3 install torch torchvision --index-url https://download.pytorch.org/whl/cpu" >> "$LOG_FILE" 2>&1 || log_warning "PyTorch installation had issues"
            ;;
    esac

    log "Cloning ComfyUI..."
    su - $GHOST_USER -c "git clone https://github.com/comfyanonymous/ComfyUI.git ~/ComfyUI" >> "$LOG_FILE" 2>&1 || error_exit "ComfyUI clone failed"

    log "Installing ComfyUI dependencies..."
    su - $GHOST_USER -c "cd ~/ComfyUI && pip3 install -r requirements.txt" >> "$LOG_FILE" 2>&1 || log_warning "Some ComfyUI dependencies may have failed"

    log "Downloading Stable Diffusion 1.5 model (~4GB)..."
    log "Using resume-capable download (will continue if interrupted)"
    su - $GHOST_USER -c "cd ~/ComfyUI/models/checkpoints && wget -c --show-progress --tries=5 --timeout=60 https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.safetensors" || error_exit "SD model download failed"

    # Create launcher
    su - $GHOST_USER -c 'cat > ~/start-comfyui.sh << '\''EOF'\''
#!/bin/bash
cd ~/ComfyUI
python3 main.py --listen 127.0.0.1 --port 8188
EOF'

    chmod +x "$GHOST_HOME/start-comfyui.sh"

    log_success "ComfyUI and Stable Diffusion installed"
    
    case "$GPU_TYPE" in
        nvidia)
            log_success "NVIDIA GPU detected - expect 2-5 seconds per image"
            ;;
        apple)
            log_success "Apple Silicon detected - expect 10-30 seconds per image"
            ;;
        amd)
            log_warning "AMD GPU - expect 15-60 seconds per image (ROCm support varies)"
            ;;
        *)
            log_warning "CPU-only mode - expect 5-10 minutes per image"
            ;;
    esac
fi

# ============================================================================
# STEP 8: Download Offline Wikipedia (Conditional)
# ============================================================================
step "Download Offline Wikipedia"

if [ "$INSTALL_WIKIPEDIA" = "true" ]; then
    log "Wikipedia download enabled - this will take 1-3 hours (~96GB)"

    read -p "Download Wikipedia now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Finding latest Wikipedia ZIM file..."

        # Dynamic lookup of latest Wikipedia ZIM file
        WIKI_BASE_URL="https://download.kiwix.org/zim/wikipedia"
        WIKI_FILENAME=""

        # Try to find the latest nopic English Wikipedia
        if command -v curl &> /dev/null; then
            # Get directory listing and find latest nopic file
            WIKI_FILENAME=$(curl -sL "$WIKI_BASE_URL/" | \
                grep -oP 'wikipedia_en_all_nopic_\d{4}-\d{2}\.zim(?=")' | \
                sort -V | tail -1)
        fi

        # Fallback to known recent version if dynamic lookup fails
        if [ -z "$WIKI_FILENAME" ]; then
            log_warning "Could not determine latest version, using fallback"
            # Try common recent versions
            for version in "2024-06" "2024-03" "2024-01" "2023-12"; do
                WIKI_FILENAME="wikipedia_en_all_nopic_${version}.zim"
                if curl -sI "${WIKI_BASE_URL}/${WIKI_FILENAME}" | grep -q "200 OK"; then
                    break
                fi
                WIKI_FILENAME=""
            done
        fi

        if [ -z "$WIKI_FILENAME" ]; then
            log_error "Could not find Wikipedia ZIM file"
            log "You can download manually later from: $WIKI_BASE_URL"
        else
            WIKI_URL="${WIKI_BASE_URL}/${WIKI_FILENAME}"
            log "Downloading: $WIKI_FILENAME"
            log "URL: $WIKI_URL"
            log "Using resume-capable download (will continue if interrupted)"

            # Download with resume capability
            su - $GHOST_USER -c "cd ~/offline-data/wikipedia && wget -c --show-progress --tries=10 --timeout=120 --waitretry=30 '$WIKI_URL'" || {
                log_warning "Wikipedia download failed or incomplete"
                log "To resume later, run:"
                log "  cd ~/offline-data/wikipedia && wget -c '$WIKI_URL'"
            }

            # Verify download
            if [ -f "$GHOST_HOME/offline-data/wikipedia/$WIKI_FILENAME" ]; then
                WIKI_SIZE=$(du -h "$GHOST_HOME/offline-data/wikipedia/$WIKI_FILENAME" | cut -f1)
                log_success "Wikipedia downloaded: $WIKI_SIZE"
            fi
        fi

        # Create launcher (works with any .zim file)
        su - $GHOST_USER -c 'cat > ~/start-kiwix.sh << '\''EOF'\''
#!/bin/bash
ZIM_FILE=$(ls ~/offline-data/wikipedia/*.zim 2>/dev/null | head -1)
if [ -z "$ZIM_FILE" ]; then
    echo "No Wikipedia ZIM file found in ~/offline-data/wikipedia/"
    exit 1
fi
echo "Starting Kiwix server with: $(basename $ZIM_FILE)"
echo "Open http://localhost:8080 in your browser"
kiwix-serve --port 8080 "$ZIM_FILE"
EOF'
        chmod +x "$GHOST_HOME/start-kiwix.sh"

        log_success "Wikipedia configured"
    else
        log_warning "Wikipedia download skipped (you can download it later)"
        log "To download later, run the start script which will provide instructions"

        # Create download helper script
        su - $GHOST_USER -c 'cat > ~/download-wikipedia.sh << '\''EOF'\''
#!/bin/bash
echo "Downloading offline Wikipedia..."
echo "This will download ~96GB and may take several hours."
echo ""
cd ~/offline-data/wikipedia

# Find latest version
LATEST=$(curl -sL "https://download.kiwix.org/zim/wikipedia/" | \
    grep -oP '\''wikipedia_en_all_nopic_\d{4}-\d{2}\.zim(?=")'\'' | \
    sort -V | tail -1)

if [ -z "$LATEST" ]; then
    echo "Could not find latest version, using fallback..."
    LATEST="wikipedia_en_all_nopic_2024-01.zim"
fi

echo "Downloading: $LATEST"
wget -c --show-progress "https://download.kiwix.org/zim/wikipedia/${LATEST}"

echo ""
echo "Download complete! Run ./start-kiwix.sh to start the server."
EOF'
        chmod +x "$GHOST_HOME/download-wikipedia.sh"
    fi
else
    log_warning "Wikipedia download disabled in configuration"
fi

# Install offline docs if enabled
if [ "$INSTALL_DOCS" = "true" ]; then
    log "Installing offline programming documentation..."
    DEBIAN_FRONTEND=noninteractive apt install -y zeal >> "$LOG_FILE" 2>&1 || log_warning "Zeal installation failed"
    log_success "Offline documentation viewer (Zeal) installed"
fi

# ============================================================================
# STEP 9: Security and Network Isolation
# ============================================================================
step "Security and Network Isolation"

log "Configuring firewall..."
ufw --force enable >> "$LOG_FILE" 2>&1
ufw default deny incoming >> "$LOG_FILE" 2>&1
ufw default deny outgoing >> "$LOG_FILE" 2>&1
ufw allow from 127.0.0.1 >> "$LOG_FILE" 2>&1
ufw allow to 127.0.0.1 >> "$LOG_FILE" 2>&1

log "Creating network control scripts..."

# Network on script
su - $GHOST_USER -c 'cat > ~/tools/network-on.sh << '\''EOF'\''
#!/bin/bash
echo "ENABLING NETWORK - Use with caution!"
sudo systemctl start NetworkManager
sudo ufw default allow outgoing
echo "Network enabled. Use '\''./network-off.sh'\'' to disable."
EOF'

# Network off script
su - $GHOST_USER -c 'cat > ~/tools/network-off.sh << '\''EOF'\''
#!/bin/bash
echo "DISABLING NETWORK - Ghost mode activated"
sudo ufw default deny outgoing
sudo systemctl stop NetworkManager

# Disable all network interfaces except loopback
for iface in $(ip link show | grep -E '\''^[0-9]+:'\'' | cut -d: -f2 | tr -d '\'' '\'' | grep -v '\''^lo$'\''); do
    echo "Disabling $iface..."
    sudo ip link set $iface down 2>/dev/null
done

echo "Network disabled. System is now offline."
EOF'

# MAC randomization script
su - $GHOST_USER -c 'cat > ~/tools/randomize-mac.sh << '\''EOF'\''
#!/bin/bash
INTERFACE=${1:-wlan0}
sudo ip link set $INTERFACE down
sudo macchanger -r $INTERFACE
sudo ip link set $INTERFACE up
echo "MAC address randomized for $INTERFACE"
EOF'

# Secure erase script
su - $GHOST_USER -c 'cat > ~/tools/secure-erase.sh << '\''EOF'\''
#!/bin/bash
echo "WARNING: This will securely erase specified files/directories"
echo "Usage: ./secure-erase.sh <file_or_directory>"
if [ -z "$1" ]; then
    exit 1
fi
shred -vfz -n 3 "$1"
EOF'

chmod +x "$GHOST_HOME/tools/"*.sh

log_success "Security configured"

# ============================================================================
# STEP 10: Create Documentation and Scripts
# ============================================================================
step "Create Documentation and Scripts"

log "Creating user documentation..."

# System info script
su - $GHOST_USER -c 'cat > ~/system-info.sh << '\''EOF'\''
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
EOF'

chmod +x "$GHOST_HOME/system-info.sh"

# Test system script
su - $GHOST_USER -c 'cat > ~/test-system.sh << '\''EOF'\''
#!/bin/bash

echo "=== Ghost AI System Test Suite ==="
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

# Test Ollama
systemctl is-active --quiet ollama
check "Ollama service running"

# Test models
[ $(ollama list | tail -n +2 | wc -l) -ge 5 ]
check "AI models installed (5+)"

# Test OpenClaw
[ -d ~/openclaw ] && [ -f ~/openclaw/config.json ]
check "OpenClaw installed"

# Test Whisper
[ -f ~/whisper.cpp/models/ggml-medium.bin ]
check "Whisper model installed"

# Test Piper
[ -f ~/piper-tts/voices/en_US-lessac-medium.onnx ]
check "Piper TTS installed"

# Test ComfyUI
[ -f ~/ComfyUI/models/checkpoints/v1-5-pruned-emaonly.safetensors ]
check "Stable Diffusion model installed"

# Test Wikipedia
if [ -f ~/offline-data/wikipedia/*.zim ]; then
    check "Wikipedia data found"
else
    echo "⚠ Wikipedia data not found (optional)"
fi

# Test firewall
sudo ufw status | grep -q "Status: active"
check "Firewall enabled"

# Test scripts
[ -f ~/start-openclaw.sh ] && [ -x ~/start-openclaw.sh ]
check "Launcher scripts present"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
echo ""

if [ $FAIL -eq 0 ]; then
    echo "🎉 System is fully operational!"
else
    echo "⚠️  Some components failed verification."
fi
EOF'

chmod +x "$GHOST_HOME/test-system.sh"

# README
su - $GHOST_USER -c 'cat > ~/README.md << '\''EOF'\''
# Ghost AI System

An offline, privacy-focused AI assistant system.

## Quick Start

1. **Verify System**
   ```bash
   ./system-info.sh
   ./test-system.sh
   ```

2. **Start AI Assistant**
   ```bash
   ./start-openclaw.sh
   ```

3. **Enable Ghost Mode**
   ```bash
   ~/tools/network-off.sh
   ```

## Key Commands

- `./start-openclaw.sh` - Start AI assistant
- `./start-kiwix.sh` - Start offline Wikipedia
- `./start-comfyui.sh` - Start image generation
- `~/tools/network-off.sh` - Disable network (ghost mode)
- `~/tools/network-on.sh` - Enable network (for updates only)
- `./system-info.sh` - Show system information
- `./test-system.sh` - Test all components

## Models Available

- **llama3.1:8b** - General reasoning (default)
- **qwen2.5-coder:7b** - Programming help
- **llama3.2-vision:11b** - Image analysis
- **qwen2.5:32b** - Deep reasoning
- **llama3.2:3b** - Fast responses

## Important Notes

- Network is DISABLED by default for privacy
- All AI processing is local (no cloud)
- System requires 8GB+ RAM (16GB recommended)
- SD image generation is slow on CPU (5-10 min per image)

## Maintenance

Update models (requires network):
```bash
~/tools/network-on.sh
ollama pull llama3.1:8b
~/tools/network-off.sh
```

For detailed documentation, see the full setup guide.

**Stay safe. Stay private. Stay prepared.**
EOF'

log_success "Documentation created"

# ============================================================================
# FINAL STEPS
# ============================================================================

log ""
log "========================================="
log "Setup Complete!"
log "========================================="
log ""
log_success "Ghost AI System is ready!"
log ""
log "Next steps:"
log "1. Run: su - $GHOST_USER -c './test-system.sh'"
log "2. Run: su - $GHOST_USER -c './system-info.sh'"
log "3. Enable ghost mode: su - $GHOST_USER -c '~/tools/network-off.sh'"
log "4. Start AI: su - $GHOST_USER -c './start-openclaw.sh'"
log ""
log "Documentation:"
log "- ~/README.md - Quick reference"
log "- ~/system-info.sh - System information"
log "- ~/test-system.sh - Verify installation"
log ""
log "Setup log saved to: $LOG_FILE"
log ""

# Create desktop shortcuts
if [ -d "$GHOST_HOME/Desktop" ]; then
    log "Creating desktop shortcuts..."
    
    su - $GHOST_USER -c 'cat > ~/Desktop/start-ghost-ai.desktop << '\''EOF'\''
[Desktop Entry]
Version=1.0
Type=Application
Name=Ghost AI Assistant
Comment=Start the offline AI assistant
Exec=/home/ghost/start-openclaw.sh
Icon=utilities-terminal
Terminal=true
Categories=System;
EOF'

    su - $GHOST_USER -c 'cat > ~/Desktop/system-info.desktop << '\''EOF'\''
[Desktop Entry]
Version=1.0
Type=Application
Name=System Info
Comment=Show Ghost AI system information
Exec=/home/ghost/system-info.sh
Icon=utilities-system-monitor
Terminal=true
Categories=System;
EOF'
    
    chmod +x "$GHOST_HOME/Desktop/"*.desktop
    chown $GHOST_USER:$GHOST_USER "$GHOST_HOME/Desktop/"*.desktop
fi

# Set proper permissions
chown -R $GHOST_USER:$GHOST_USER "$GHOST_HOME"

log ""
log "🎉 Ghost AI System setup complete!"
log ""

exit 0

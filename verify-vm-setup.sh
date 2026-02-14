#!/bin/bash
#
# Verify VM Setup - Run this INSIDE the VM to check prerequisites
#

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Ghost AI - VM Setup Verification${NC}"
echo "=================================="
echo ""

ERRORS=0
WARNINGS=0

check() {
    local name=$1
    local command=$2
    local required=${3:-true}

    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC} $name"
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}✗${NC} $name (REQUIRED)"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${YELLOW}⚠${NC} $name (optional)"
            WARNINGS=$((WARNINGS + 1))
        fi
        return 1
    fi
}

echo "System Checks:"
check "Ubuntu/Debian system" "[ -f /etc/debian_version ]"
check "Internet connection" "ping -c 1 8.8.8.8"
check "sudo access" "sudo -n true"
check "curl installed" "command -v curl"
check "git installed" "command -v git"

echo ""
echo "Shared Folder Checks:"
check "~/Dev exists" "[ -d ~/Dev ]"
check "~/Dev/Ghost-AI exists" "[ -d ~/Dev/Ghost-AI ]"
check "vm-quick-install.sh exists" "[ -f ~/Dev/Ghost-AI/vm-quick-install.sh ]"
check "vm-quick-install.sh is executable" "[ -x ~/Dev/Ghost-AI/vm-quick-install.sh ]"

echo ""
echo "Resources:"
RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')

if [ "$RAM_GB" -ge 8 ]; then
    echo -e "${GREEN}✓${NC} RAM: ${RAM_GB}GB (sufficient)"
else
    echo -e "${YELLOW}⚠${NC} RAM: ${RAM_GB}GB (8GB+ recommended)"
    WARNINGS=$((WARNINGS + 1))
fi

if [ "$DISK_GB" -ge 50 ]; then
    echo -e "${GREEN}✓${NC} Disk: ${DISK_GB}GB available (sufficient)"
else
    echo -e "${RED}✗${NC} Disk: ${DISK_GB}GB available (50GB+ required)"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "Already Installed (optional):"
check "Ollama" "command -v ollama" false
check "Node.js" "command -v node" false
check "npm" "command -v npm" false
check "OpenClaw" "[ -d ~/Dev/openclaw ]" false

echo ""
echo "=================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Ready to install!${NC}"
    echo ""
    echo "Run this command to start:"
    echo "  cd ~/Dev/Ghost-AI && ./vm-quick-install.sh"
else
    echo -e "${RED}✗ $ERRORS critical issues found${NC}"
    echo ""
    echo "Please fix the errors above before installing."
fi

if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}⚠ $WARNINGS warnings (non-critical)${NC}"
fi

echo "=================================="
echo ""

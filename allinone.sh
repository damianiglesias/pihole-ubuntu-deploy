#!/bin/bash

# ==========================================
# PI-HOLE All-In-One Installer
# Author: [Damian Iglesias]
# Version: 2.0
# ==========================================

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' 

# Fixed Password for the Web Interface
ADMIN_PASS="password123"

# --- SILENT EXECUTION FUNCTION ---
execute_silent() {
    local message="$1"
    shift
    local command="$@"
    echo -ne "${BLUE}⏳ ${message}...${NC}"
    if eval "$command" > /tmp/deploy_log.txt 2>&1; then
        echo -e "\r${GREEN}✅ ${message}           ${NC}"
    else
        echo -e "\r${RED}❌ ${message} (Failed)${NC}"
        cat /tmp/deploy_log.txt
        exit 1
    fi
}

# --- HEADER ---
clear
echo -e "${BLUE}################################################${NC}"
echo -e "${BLUE}#     UBUNTU SERVER PI-HOLE INSTALLER          #${NC}"
echo -e "${BLUE}################################################${NC}"
echo ""

# 1. ROOT CHECK
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Please run as root (sudo ./allinone.sh)${NC}"
  exit
fi

# 2. UPDATE SYSTEM
echo -e "${YELLOW}❓ Step 1: System Update${NC}"
read -p "   Update OS packages? [y/n]: " choice
if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    execute_silent "Updating list" "apt-get update"
    execute_silent "Upgrading packages" "apt-get upgrade -y"
else
    echo -e "${YELLOW}⏭️  Skipping update...${NC}"
fi
echo ""

# 3. FIX PORT 53
echo -e "${YELLOW}🔧 Step 2: Fixing Port 53${NC}"
if lsof -i :53 | grep -q "systemd-resolve"; then
    sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf > /dev/null 2>&1
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf > /dev/null 2>&1
    execute_silent "Fixing systemd-resolved" "systemctl restart systemd-resolved"
else
    echo -e "${GREEN}✅ Port 53 is clear.${NC}"
fi
echo ""

# 4. INSTALL PI-HOLE
echo -e "${YELLOW}📦 Step 3: Installing Pi-hole${NC}"
execute_silent "Installing dependencies" "apt-get install curl net-tools ufw -y"
echo -e "${YELLOW}   (Follow the blue screens instructions)${NC}"
read -p "   Press [Enter] to start installer..."
curl -sSL https://install.pi-hole.net | bash

echo ""

# 5. CONFIGURE PASSWORD & FIREWALL
echo -e "${YELLOW}🔐 Step 4: Final Configuration${NC}"
# Forzamos la contraseña
execute_silent "Setting Admin Password" "/usr/local/bin/pihole -a -p $ADMIN_PASS"
# Firewall
execute_silent "Opening Ports (22, 53, 80)" "ufw allow 22/tcp && ufw allow 53 && ufw allow 80/tcp"
execute_silent "Enabling Firewall" "echo 'y' | ufw enable"

# --- SMART FINAL REPORT ---
clear
# Detectamos la IP
IP_ADDRESS=$(hostname -I | cut -d' ' -f1)

echo -e "${GREEN}################################################${NC}"
echo -e "${GREEN}#           DEPLOYMENT COMPLETE!               #${NC}"
echo -e "${GREEN}################################################${NC}"
echo ""

# --- LÓGICA INTELIGENTE DE RED ---
# Si la IP empieza por 10.0.2. (Típico de VirtualBox NAT)
if [[ $IP_ADDRESS == 10.0.2.* ]]; then
    echo -e "${RED}⚠️  WARNING: VirtualBox NAT Detected ($IP_ADDRESS)${NC}"
    echo -e "   You cannot access this IP directly from Windows."
    echo ""
    echo -e "${YELLOW}👉 OPTION A (Port Forwarding):${NC}"
    echo -e "   If you configured Port Forwarding in VirtualBox:"
    echo -e "   URL: ${BLUE}http://localhost:8080/admin${NC}"
    echo ""
    echo -e "${YELLOW}👉 OPTION B (Bridge Mode):${NC}"
    echo -e "   Change VM Network to 'Bridged Adapter' to get a real IP."
else
    # Si es una IP normal (Bridged o Host-Only)
    echo -e "${BLUE}📡 Server IP:${NC}      ${IP_ADDRESS}"
    echo -e "${BLUE}💻 Web Interface:${NC}  http://${IP_ADDRESS}/admin"
fi

echo -e "${BLUE}🔑 Password:${NC}       ${ADMIN_PASS}"
echo ""
echo -e "Enjoy your ad-free network!"
echo ""
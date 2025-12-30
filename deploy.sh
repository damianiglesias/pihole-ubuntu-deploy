#!/bin/bash

# ==========================================
# 🛡️ PI-HOLE ALL-IN-ONE DEPLOYMENT KIT
# Author: [Your Name]
# Version: 5.0 (Universal v5/v6 Compatibility)
# ==========================================

# --- COLORS ---
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m' 

# Default password
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
echo -e "${BLUE}#      UBUNTU SERVER PI-HOLE INSTALLER         #${NC}"
echo -e "${BLUE}#                                              #${NC}"
echo -e "${BLUE}################################################${NC}"
echo ""

# 1. ROOT CHECK
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Please run as root (sudo ./deploy.sh)${NC}"
  exit
fi

# 2. SYSTEM UPDATE
echo -e "${YELLOW}❓ Step 1: System Update${NC}"
read -p "   Update OS packages? [y/n]: " choice
if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    execute_silent "Updating list" "apt-get update"
    execute_silent "Upgrading packages" "apt-get upgrade -y"
else
    echo -e "${GRAY}⏭️  Skipping update...${NC}"
fi
echo ""

# 3. FIX PORT 53
echo -e "${YELLOW}🔧 Step 2: Fixing Port 53 conflict${NC}"
if lsof -i :53 | grep -q "systemd-resolve"; then
    sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf > /dev/null 2>&1
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf > /dev/null 2>&1
    execute_silent "Restarting systemd-resolved" "systemctl restart systemd-resolved"
else
    echo -e "${GREEN}✅ Port 53 is clear.${NC}"
fi
echo ""

# 4. INSTALL PI-HOLE
echo -e "${YELLOW}📦 Step 3: Installing Pi-hole${NC}"
execute_silent "Installing dependencies" "apt-get install curl net-tools ufw -y"
echo -e "${GRAY}   The interactive installer will start now.${NC}"
read -p "   Press [Enter] to start..."
curl -sSL https://install.pi-hole.net | bash

echo ""

# 5. SMART PASSWORD CONFIGURATION (v5 vs v6)
echo -e "${YELLOW}🔐 Step 4: Configuring Admin Password${NC}"

# Esperamos 5 segundos a que el servicio arranque del todo
sleep 5

# Detectamos la versión
PIHOLE_VERSION=$(pihole -v | grep "Pi-hole" | cut -d'v' -f2 | cut -d'.' -f1)

if [[ "$PIHOLE_VERSION" == "6" ]]; then
    # Para la v6 usamos sudo y el comando directo sin comillas raras
    sudo pihole setpassword $ADMIN_PASS
    echo -e "${GREEN}✅ Password set for v6${NC}"
else
    # Para la v5
    sudo pihole -a -p $ADMIN_PASS
    echo -e "${GREEN}✅ Password set for v5${NC}"
fi

# 6. FIREWALL
echo -e "${YELLOW}🛡️ Step 5: Securing Firewall${NC}"
execute_silent "Allowing SSH, DNS, HTTP" "ufw allow 22/tcp && ufw allow 53 && ufw allow 80/tcp"
execute_silent "Enabling Firewall" "echo 'y' | ufw enable"
echo ""

# 7. FINAL REPORT
clear
IP_ADDRESS=$(hostname -I | cut -d' ' -f1)
echo -e "${GREEN}################################################${NC}"
echo -e "${GREEN}#           DEPLOYMENT COMPLETE!               #${NC}"
echo -e "${GREEN}################################################${NC}"
echo ""
echo -e "${BLUE}📡 Server IP:${NC}      ${IP_ADDRESS}"

if [[ $IP_ADDRESS == 10.0.2.* ]]; then
    echo -e "${RED}⚠️  VirtualBox NAT Detected!${NC}"
    echo -e "   Use Port Forwarding or Bridge Mode to access."
fi

echo -e "${BLUE}💻 Web Interface:${NC}  http://${IP_ADDRESS}/admin"
echo -e "${BLUE}🔑 Password:${NC}       ${ADMIN_PASS}"
echo ""
echo -e "Enjoy your ad-free network!"
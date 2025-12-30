#!/bin/bash

# Pi-hole all in one script.

# --- COLOR VARIABLES ---
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m' # No Color

# Default password for the Web Interface
DEFAULT_PASS="p@ssw0rd"


# --- SPINNER FUNCTION ---
# Executes a command silently and shows a spinner/status
execute_silent() {
    local message="$1"
    shift
    local command="$@"
    
    # Print loading message without newline
    echo -ne "${BLUE}⏳ ${message}...${NC}"

    # Execute command sending output to a "black hole" (log file)
    if eval "$command" > /tmp/deploy_log.txt 2>&1; then
        # Success: Overwrite line with Green Check
        echo -e "\r${GREEN}✅ ${message}           ${NC}"
    else
        # Failure: Show Red Cross and log
        echo -e "\r${RED}❌ ${message} (Failed)${NC}"
        echo -e "${RED}   Error log:${NC}"
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

# --- 1. ROOT CHECK ---
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}Please run as root (use sudo ./deploy.sh)${NC}"
  exit
fi

# --- 2. SYSTEM UPDATE ---
echo -e "${YELLOW}❓ Step 1: System Update${NC}"
read -p "   Do you want to update the OS packages? (Recommended) [y/n]: " choice

if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
    execute_silent "Updating package lists" "apt-get update"
    
else
    echo -e "${GRAY}⏭️  Skipping update...${NC}"
fi
echo ""

# --- 3. FIX PORT 53 (UBUNTU) ---
echo -e "${YELLOW}🔧 Step 2: Fixing Port 53 conflict${NC}"
if lsof -i :53 | grep -q "systemd-resolve"; then
    echo -e "${GRAY}   Detecting systemd-resolved conflict... Fixing.${NC}"
    # Disable StubListener silently
    sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf > /dev/null 2>&1
    ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf > /dev/null 2>&1
    execute_silent "Restarting DNS service" "systemctl restart systemd-resolved"
else
    echo -e "${GREEN}✅ Port 53 is clear.${NC}"
fi
echo ""

# --- 4. INSTALL DEPENDENCIES ---
echo -e "${YELLOW}📦 Step 3: Installing dependencies${NC}"
execute_silent "Installing curl, net-tools & firewall" "apt-get install curl net-tools ufw -y"
echo ""

# --- 5. INSTALL PI-HOLE ---
echo -e "${YELLOW}🚀 Step 4: Installing Pi-hole${NC}"
echo -e "${GRAY}   The interactive installer will appear now.${NC}"
echo -e "${GRAY}   (Follow the blue screens instructions)${NC}"
read -p "   Press [Enter] to start..."
echo ""

# We cannot hide output here because it is interactive
curl -sSL https://install.pi-hole.net | bash

echo ""

# --- 6. CONFIGURE FIREWALL ---
echo -e "${YELLOW}🛡️ Step 5: Securing Firewall (UFW)${NC}"
execute_silent "Allowing SSH (Port 22)" "ufw allow 22/tcp"
execute_silent "Allowing DNS (Port 53)" "ufw allow 53"
execute_silent "Allowing Web Interface (Port 80)" "ufw allow 80/tcp"
# Force enable firewall
execute_silent "Enabling Firewall" "echo 'y' | ufw enable"
echo ""

# --- 7. FINAL SUMMARY ---
clear
IP_ADDRESS=$(hostname -I | cut -d' ' -f1)
echo -e "${GREEN}################################################${NC}"
echo -e "${GREEN}#           DEPLOYMENT COMPLETE!               #${NC}"
echo -e "${GREEN}################################################${NC}"
echo ""
echo -e "Your Ad-Blocking Server is ready."
echo ""
echo -e "${BLUE}📡 Server IP:${NC}      ${IP_ADDRESS}"
echo -e "${BLUE}💻 Web Interface:${NC}  http://${IP_ADDRESS}/admin"
echo -e "${BLUE}🔑 Password:${NC}       ${DEFAULT_PASS}"
echo ""
echo -e "${GRAY}To change password run: pihole -a -p${NC}"
echo ""
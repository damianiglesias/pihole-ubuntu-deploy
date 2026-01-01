#!/bin/bash

# ==========================================
# PI-HOLE All-In-One Script
# Author: Damian Iglesias
# Version: 2.3 
# ==========================================

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m' 

# Generate Random Password
GENERATED_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)

# --- HEADER ---
clear
echo -e "${BLUE}"
echo "  ____  _       _           _       "
echo " |  _ \(_)     | |         | |      "
echo " | |_) |_      | |__   ___ | | ___  "
echo " |  __/| |_____| '_ \ / _ \| |/ _ \ "
echo " | |   | |_____| | | | (_) | |  __/ "
echo " |_|   |_|     |_| |_|\___/|_|\___| "
echo "           INSTALLER v2.3           "
echo -e "${NC}"

# 1. ROOT CHECK
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}ERROR: Please run as root (sudo ./deploy.sh)${NC}"
  exit 1
fi

# 2. FIX PORT 53 & INTERNET
echo -e "${YELLOW} Step 1: Network Prep...${NC}"
sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf > /dev/null 2>&1
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf > /dev/null 2>&1
echo "nameserver 8.8.8.8" > /etc/resolv.conf
systemctl restart systemd-resolved > /dev/null 2>&1
echo -e "${GREEN}✅ Network ready.${NC}"

# 3. INSTALL DEPENDENCIES
echo -e "${YELLOW} Step 2: Dependencies...${NC}"
apt-get update > /dev/null 2>&1
# We include sqlite3 for database manipulation
apt-get install curl net-tools ufw sqlite3 -y > /dev/null 2>&1
echo -e "${GREEN}✅ Dependencies installed.${NC}"

# 4. INSTALL PI-HOLE
echo -e "${YELLOW} Step 3: Installing Pi-hole Core...${NC}"
echo -e "${GRAY}   (Follow the blue screens - Accept Defaults)${NC}"
read -p "   Press [ENTER] to start..."
curl -sSL https://install.pi-hole.net | bash

# --- INTERACTIVE BLOCKLISTS ---
echo ""
echo -e "${YELLOW} Step 3.5: Advanced Blocklists${NC}"
echo -e "${GRAY}   Do you want to add Pro blocklists? (StevenBlack, Firebog, etc.)${NC}"
echo -e "${GRAY}   This increases blocking from ~100k to ~300k domains.${NC}"
read -p "   Install Advanced Lists? [y/n]: " list_choice

if [[ "$list_choice" == "y" || "$list_choice" == "Y" ]]; then
    echo -e "${BLUE}⏳ Injecting lists into database...${NC}"
    
    # List Definitions
    L1="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    L2="https://v.firebog.net/hosts/AdguardDNS.txt"
    L3="https://v.firebog.net/hosts/Easyprivacy.txt"

    # SQL Injection
    sqlite3 /etc/pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('$L1', 1, 'StevenBlack Unified');"
    sqlite3 /etc/pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('$L2', 1, 'Adguard Mobile');"
    sqlite3 /etc/pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('$L3', 1, 'EasyPrivacy Tracking');"

    echo -e "${BLUE}⏳ Updating Gravity (Downloading domains)...${NC}"
    pihole -g > /dev/null 2>&1
    echo -e "${GREEN}✅ Database updated successfully.${NC}"
else
    echo -e "${GRAY}⏭️  Skipping advanced lists (Default lists kept).${NC}"
fi
# --------------------------------------

# 5. PASSWORD SETUP
echo ""
echo -e "${YELLOW} Step 4: Security Setup${NC}"
sleep 3
pihole setpassword "$GENERATED_PASS"
systemctl restart pihole-FTL
echo -e "${GREEN}✅ Password configured.${NC}"

# 6. FIREWALL
echo -e "${YELLOW} Step 5: Firewall...${NC}"
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 53 > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
echo "y" | ufw enable > /dev/null 2>&1

# --- 7. STATIC IP CONFIGURATION (NUEVO) ---
echo ""
echo -e "${YELLOW} Step 6: Static IP Configuration${NC}"
echo -e "${GRAY}   A server should have a Static IP so it doesn't change on reboot.${NC}"

# Detect current network details
CURRENT_IF=$(ip route | grep default | awk '{print $5}' | head -n1)
CURRENT_IP=$(ip -4 addr show $CURRENT_IF | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' | head -n1)
CURRENT_GW=$(ip route | grep default | awk '{print $3}' | head -n1)

echo -e "   Detected Interface: ${BLUE}$CURRENT_IF${NC}"
echo -e "   Detected IP:        ${BLUE}$CURRENT_IP${NC}"
echo -e "   Detected Gateway:   ${BLUE}$CURRENT_GW${NC}"
echo ""

read -p "   Set this IP as STATIC? (Recommended) [y/n]: " static_choice

if [[ "$static_choice" == "y" || "$static_choice" == "Y" ]]; then
    echo -e "${BLUE}⏳ Writing Netplan configuration...${NC}"
    
    # Backup current config
    mkdir -p /etc/netplan/backup
    cp /etc/netplan/*.yaml /etc/netplan/backup/ 2>/dev/null

    # Create static config file
    cat <<EOF > /etc/netplan/99-pihole-static.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $CURRENT_IF:
      dhcp4: false
      dhcp6: false
      addresses:
        - $CURRENT_IP/24
      routes:
        - to: default
          via: $CURRENT_GW
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF

    echo -e "${BLUE}⏳ Applying changes...${NC}"
    netplan apply > /dev/null 2>&1
    
    # Check connectivity
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Static IP set successfully!${NC}"
    else
        echo -e "${RED}❌ Error: Lost connection! Reverting changes...${NC}"
        rm /etc/netplan/99-pihole-static.yaml
        netplan apply > /dev/null 2>&1
        echo -e "${GRAY}   Reverted to DHCP safe mode.${NC}"
    fi
else
    echo -e "${GRAY}⏭  Skipping Static IP setup.${NC}"
fi
echo ""
# ----------------------------------------

# 8. REPORT FINAL
clear
IP_ADDR=$(hostname -I | cut -d' ' -f1)
echo -e "${GREEN}################################################${NC}"
echo -e "${GREEN}#             DEPLOYMENT SUCCESSFUL!           #${NC}"
echo -e "${GREEN}################################################${NC}"
echo ""
echo -e "${BLUE} Server IP:${NC}      $IP_ADDR"
echo -e "${BLUE} Web Interface:${NC}  http://$IP_ADDR/admin"
echo ""
echo -e "${YELLOW} YOUR ADMIN PASSWORD:${NC}"
echo -e "${RED}   $GENERATED_PASS ${NC}"
echo ""
echo -e "   (Copy this password immediately!)"
echo ""
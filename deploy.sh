#!/bin/bash
#Pi-hole script
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' 

# --- GENERAR CONTRASEÑA ALEATORIA ---
GENERATED_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)

# --- HEADER ---
clear
echo -e "${BLUE}################################################${NC}"
echo -e "${BLUE}#     UBUNTU SERVER PI-HOLE INSTALLER 2.0      #${NC}"
echo -e "${BLUE}################################################${NC}"

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
apt-get install curl net-tools ufw -y > /dev/null 2>&1
echo -e "${GREEN}✅ Dependencies installed.${NC}"

# 4. INSTALL PI-HOLE
echo -e "${YELLOW} Step 3: Installing Pi-hole...${NC}"
echo -e "${YELLOW}   (Follow the blue screens - Accept Defaults)${NC}"
read -p "   Press [ENTER] to start..."
curl -sSL https://install.pi-hole.net | bash

# 5. ASSIGN GENERATED PASSWORD 
echo ""
echo -e "${YELLOW} Step 4: Setting Random Password...${NC}"

sleep 3

pihole setpassword "$GENERATED_PASS"
systemctl restart pihole-FTL

echo -e "${GREEN}✅ Password configured.${NC}"

# 6. FIREWALL
echo -e "${YELLOW}🛡️ Step 5: Firewall...${NC}"
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 53 > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
echo "y" | ufw enable > /dev/null 2>&1

# 7. REPORT FINAL
clear
IP_ADDR=$(hostname -I | cut -d' ' -f1)
echo -e "${GREEN}################################################${NC}"
echo -e "${GREEN}#             DEPLOYMENT SUCCESSFUL!           #${NC}"
echo -e "${GREEN}################################################${NC}"
echo ""
echo -e "${BLUE}📡 Server IP:${NC}      $IP_ADDR"
echo -e "${BLUE}💻 Web Interface:${NC}  http://$IP_ADDR/admin"
echo ""
echo -e "${YELLOW}🔑 YOUR ADMIN PASSWORD:${NC}"
echo -e "${RED}   $GENERATED_PASS ${NC}"
echo ""
echo -e "   (This is the password to enter the Pi-hole interface)"
echo -e "    You can change the password with the following command line: pihole setpassword "
echo ""

#!/bin/bash

# ==========================================
# 🛡️ PI-HOLE DEPLOYMENT KIT (INTERACTIVE)
# Author: [Your Name]
# Version: 7.0 (Interactive Password)
# ==========================================

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' 

# --- HEADER ---
clear
echo -e "${BLUE}################################################${NC}"
echo -e "${BLUE}#     UBUNTU SERVER PI-HOLE INSTALLER v7       #${NC}"
echo -e "${BLUE}#       (Interactive Security Edition)         #${NC}"
echo -e "${BLUE}################################################${NC}"

# 1. ROOT CHECK
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}ERROR: Please run as root (sudo ./deploy.sh)${NC}"
  exit 1
fi

# 2. FIX PORT 53 & RESTORE INTERNET
echo -e "${YELLOW}🔧 Step 1: Configuring Network & DNS...${NC}"
# Desactivamos el conflicto del puerto 53
sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf > /dev/null 2>&1
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf > /dev/null 2>&1
# Forzamos DNS de Google para asegurar que la descarga funciona
echo "nameserver 8.8.8.8" > /etc/resolv.conf
systemctl restart systemd-resolved > /dev/null 2>&1
echo -e "${GREEN}✅ Port 53 cleared & Internet restored.${NC}"

# 3. INSTALL DEPENDENCIES
echo -e "${YELLOW}📦 Step 2: Installing Dependencies...${NC}"
apt-get update > /dev/null 2>&1
apt-get install curl net-tools ufw lighttpd -y > /dev/null 2>&1
echo -e "${GREEN}✅ Dependencies ready.${NC}"

# 4. INSTALL PI-HOLE
echo -e "${YELLOW}🚀 Step 3: Installing Pi-hole Core...${NC}"
echo -e "${YELLOW}   (Follow the blue screens - Accept Defaults)${NC}"
read -p "   Press [ENTER] to start..."
curl -sSL https://install.pi-hole.net | bash

# 5. INTERACTIVE PASSWORD SETUP (Nueva Lógica)
echo ""
echo -e "${YELLOW}🔐 Step 4: Security Setup${NC}"
echo "   Please define your Web Interface Password."

while true; do
    echo -ne "${BLUE}   > Enter New Password: ${NC}"
    read -s PASS_1
    echo ""
    echo -ne "${BLUE}   > Confirm Password:   ${NC}"
    read -s PASS_2
    echo ""

    if [ -z "$PASS_1" ]; then
        echo -e "${RED}❌ Password cannot be empty.${NC}"
    elif [ "$PASS_1" != "$PASS_2" ]; then
        echo -e "${RED}❌ Passwords do not match. Try again.${NC}"
    else
        ADMIN_PASS=$PASS_1
        echo -e "${GREEN}✅ Password matched.${NC}"
        break
    fi
done

# Aplicar contraseña según versión (v5 vs v6)
echo -e "   Applying security settings..."
PI_VERSION=$(pihole -v | grep "Pi-hole" | cut -d'v' -f2 | cut -d'.' -f1)

if [[ "$PI_VERSION" == "6" ]]; then
    # v6
    pihole setpassword "$ADMIN_PASS" > /dev/null 2>&1
    systemctl restart pihole-FTL > /dev/null 2>&1
else
    # v5
    pihole -a -p "$ADMIN_PASS" > /dev/null 2>&1
fi
echo -e "${GREEN}✅ Access configured successfully.${NC}"


# 6. FIREWALL
echo -e "${YELLOW}🛡️ Step 5: Finalizing Firewall...${NC}"
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 53 > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
echo "y" | ufw enable > /dev/null 2>&1
echo -e "${GREEN}✅ Firewall active.${NC}"

# 7. FINAL REPORT
clear
IP_ADDR=$(hostname -I | cut -d' ' -f1)
echo -e "${GREEN}################################################${NC}"
echo -e "${GREEN}#          🎉 DEPLOYMENT SUCCESSFUL!           #${NC}"
echo -e "${GREEN}################################################${NC}"
echo ""
echo -e "${BLUE}📡 Server IP:${NC}      $IP_ADDR"
echo -e "${BLUE}💻 Web Interface:${NC}  http://$IP_ADDR/admin"
echo -e "${BLUE}🔑 Password:${NC}       (The one you just set)"
echo ""
echo -e "${RED}IMPORTANT:${NC} If login fails, open an INCOGNITO window."
echo ""

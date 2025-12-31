#!/bin/bash

# ==========================================
# 🛡️ PI-HOLE SCRIPT
# Author: Damian Iglesias
# Version: 2.0
# ==========================================

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' 

# --- HEADER ---
clear
echo -e "${BLUE}################################################${NC}"
echo -e "${BLUE}#     UBUNTU SERVER PI-HOLE INSTALLER v2.0     #${NC}"
echo -e "${BLUE}################################################${NC}"

# 1. ROOT CHECK
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}ERROR: Please run as root (sudo ./deploy.sh)${NC}"
  exit 1
fi

# 2. FIX PORT 53 & INTERNET
echo -e "${YELLOW}🔧 Step 1: Network Prep...${NC}"
sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf > /dev/null 2>&1
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf > /dev/null 2>&1
echo "nameserver 8.8.8.8" > /etc/resolv.conf
systemctl restart systemd-resolved > /dev/null 2>&1
echo -e "${GREEN}✅ Network ready.${NC}"

# 3. INSTALL DEPENDENCIES (SIN LIGHTTPD)
echo -e "${YELLOW}📦 Step 2: Dependencies...${NC}"
apt-get update > /dev/null 2>&1
# IMPORTANTE: No instalamos lighttpd para evitar el error 403 en v6
apt-get install curl net-tools ufw -y > /dev/null 2>&1
echo -e "${GREEN}✅ Dependencies installed.${NC}"

# 4. INSTALL PI-HOLE
echo -e "${YELLOW}🚀 Step 3: Installing Pi-hole...${NC}"
echo -e "${YELLOW}   (Follow the blue screens - Accept Defaults)${NC}"
read -p "   Press [ENTER] to start..."
curl -sSL https://install.pi-hole.net | bash

# 5. PASSWORD SETUP (MÉTODO INFALIBLE)
echo ""
echo -e "${YELLOW}🔐 Step 4: Security Setup${NC}"
echo "   Please type the password you want to use."

# Bucle para asegurar que no se deja vacía
while true; do
    echo -ne "${BLUE}   > Type Password: ${NC}"
    read -s ADMIN_PASS
    echo ""
    echo -ne "${BLUE}   > Confirm Password: ${NC}"
    read -s ADMIN_PASS_CONFIRM
    echo ""

    if [ -z "$ADMIN_PASS" ]; then
        echo -e "${RED}❌ Password cannot be empty.${NC}"
    elif [ "$ADMIN_PASS" != "$ADMIN_PASS_CONFIRM" ]; then
        echo -e "${RED}❌ Passwords do not match.${NC}"
    else
        break
    fi
done

echo -e "   Applying password..."

# USAMOS EL COMANDO CLÁSICO CON SUDO (Funciona en v5 y v6)
# Esto sobrescribe cualquier cosa que haya hecho el instalador
pihole -a -p "$ADMIN_PASS"

# Reiniciamos el motor para aplicar cambios y limpiar bloqueos
systemctl restart pihole-FTL

echo -e "${GREEN}✅ Password applied successfully.${NC}"

# 6. FIREWALL
echo -e "${YELLOW}🛡️ Step 5: Firewall...${NC}"
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 53 > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
echo "y" | ufw enable > /dev/null 2>&1

# 7. REPORT
clear
IP_ADDR=$(hostname -I | cut -d' ' -f1)
echo -e "${GREEN}################################################${NC}"
echo -e "${GREEN}#             DEPLOYMENT SUCCESSFUL!           #${NC}"
echo -e "${GREEN}################################################${NC}"
echo ""
echo -e "${BLUE}📡 Server IP:${NC}      $IP_ADDR"
echo -e "${BLUE}💻 Web Interface:${NC}  http://$IP_ADDR/admin"
echo -e "${BLUE}🔑 Password:${NC}       (The one you typed)"
echo ""
echo -e "${RED}NOTE:${NC} If login fails, use an INCOGNITO window."
echo ""
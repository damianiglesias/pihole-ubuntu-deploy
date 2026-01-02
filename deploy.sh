#!/bin/bash

# ==========================================
# PI-HOLE All-In-One Script
# Author: Damian Iglesias
# Version: 3.4 (Manual Unbound Config)
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
echo "           INSTALLER v3.4           "
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
apt-get install curl net-tools ufw sqlite3 wget -y > /dev/null 2>&1
echo -e "${GREEN}✅ Dependencies installed.${NC}"

# 4. INSTALL PI-HOLE
echo -e "${YELLOW} Step 3: Installing Pi-hole Core...${NC}"
echo -e "${GRAY}   (Follow the blue screens - Accept Defaults)${NC}"
read -p "   Press [ENTER] to start..."
curl -sSL https://install.pi-hole.net | bash

# --- INTERACTIVE BLOCKLISTS ---
echo ""
echo -e "${YELLOW} Step 3.5: Advanced Blocklists${NC}"
read -p "   Install Advanced Lists? [y/n]: " list_choice

if [[ "$list_choice" == "y" || "$list_choice" == "Y" ]]; then
    echo -e "${BLUE}⏳ Injecting lists into database...${NC}"
    L1="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    L2="https://v.firebog.net/hosts/AdguardDNS.txt"
    L3="https://v.firebog.net/hosts/Easyprivacy.txt"
    sqlite3 /etc/pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('$L1', 1, 'StevenBlack Unified');"
    sqlite3 /etc/pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('$L2', 1, 'Adguard Mobile');"
    sqlite3 /etc/pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('$L3', 1, 'EasyPrivacy Tracking');"
    pihole -g > /dev/null 2>&1
    echo -e "${GREEN}✅ Database updated successfully.${NC}"
else
    echo -e "${GRAY}⏭  Skipping advanced lists.${NC}"
fi

# 5. PASSWORD SETUP
echo ""
echo -e "${YELLOW} Step 4: Security Setup${NC}"
sleep 3
pihole setpassword "$GENERATED_PASS"
echo -e "${GREEN}✅ Password configured.${NC}"

# --- UNBOUND SETUP (INSTALL ONLY) ---
echo ""
echo -e "${YELLOW} Step 4.5: Unbound Recursive DNS${NC}"
read -p "   Install Unbound? [y/n]: " unbound_choice

if [[ "$unbound_choice" == "y" || "$unbound_choice" == "Y" ]]; then
    echo -e "${BLUE}⏳ Installing Unbound...${NC}"
    apt-get install unbound -y > /dev/null 2>&1
    wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root > /dev/null 2>&1
    chown unbound:unbound /var/lib/unbound/root.hints

    cat <<EOF > /etc/unbound/unbound.conf.d/pi-hole.conf
server:
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    do-ip6: no
    prefer-ip6: no
    root-hints: "/var/lib/unbound/root.hints"
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: no
    edns-buffer-size: 1232
    prefetch: yes
    num-threads: 1
    so-rcvbuf: 1m
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8
    private-address: fd00::/8
    private-address: fe80::/10
EOF
    systemctl restart unbound
    echo -e "${GREEN}✅ Unbound installed (See instructions at the end).${NC}"
else
    echo -e "${GRAY}⏭  Skipping Unbound.${NC}"
fi

# 6. FIREWALL
echo -e "${YELLOW} Step 5: Firewall...${NC}"
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 53 > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
echo "y" | ufw enable > /dev/null 2>&1

# 7. STATIC IP CONFIGURATION
echo ""
echo -e "${YELLOW} Step 6: Static IP Configuration${NC}"
echo -e "${BLUE}Available Interfaces:${NC}"
ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"
echo ""

read -p "   Type interface name (e.g. enp0s8): " SELECTED_IF

if [[ -n "$SELECTED_IF" ]]; then
    CURRENT_IP=$(ip -4 addr show $SELECTED_IF 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    CURRENT_GW=$(ip route | grep default | awk '{print $3}' | head -n1)
    if [[ -z "$CURRENT_GW" ]]; then CURRENT_GW="192.168.1.1"; fi

    echo -e "   Selected: ${GREEN}$SELECTED_IF${NC} | IP: ${GREEN}$CURRENT_IP${NC}"
    read -p "   Set this IP as STATIC? [y/n]: " static_choice

    if [[ "$static_choice" == "y" || "$static_choice" == "Y" ]]; then
        echo -e "${BLUE}⏳ Writing Netplan...${NC}"
        mkdir -p /etc/netplan/backup
        cp /etc/netplan/*.yaml /etc/netplan/backup/ 2>/dev/null

        cat <<EOF > /etc/netplan/99-pihole-static.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $SELECTED_IF:
      dhcp4: false
      dhcp6: false
      addresses:
        - $CURRENT_IP/24
      routes:
        - to: default
          via: $CURRENT_GW
      nameservers:
        addresses: [8.8.8.8, 127.0.0.1]
EOF
        chmod 600 /etc/netplan/99-pihole-static.yaml
        netplan apply > /dev/null 2>&1
        FINAL_REPORT_IP=$CURRENT_IP
        echo -e "${GREEN}✅ Static IP applied.${NC}"
    fi
fi
echo ""

# 8. REPORT FINAL
clear
if [[ -z "$FINAL_REPORT_IP" ]]; then
    if [[ -n "$SELECTED_IF" ]]; then
        FINAL_REPORT_IP=$(ip -4 addr show $SELECTED_IF 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    fi
fi
if [[ -z "$FINAL_REPORT_IP" ]]; then
    FINAL_REPORT_IP=$(hostname -I | awk '{print $1}')
fi

echo -e "${GREEN}################################################${NC}"
echo -e "${GREEN}#             DEPLOYMENT SUCCESSFUL!           #${NC}"
echo -e "${GREEN}################################################${NC}"
echo ""
echo -e "${BLUE} Server IP:${NC}      $FINAL_REPORT_IP"
echo -e "${BLUE} Web Interface:${NC}  http://$FINAL_REPORT_IP/admin"
echo ""
echo -e "${YELLOW} YOUR ADMIN PASSWORD:${NC}"
echo -e "${RED}   $GENERATED_PASS ${NC}"
echo -e "   (Copy this password immediately!)"
echo ""

# --- INSTRUCCIONES MANUALES DE UNBOUND ---
if [[ "$unbound_choice" == "y" || "$unbound_choice" == "Y" ]]; then
    echo -e "${YELLOW} IMPORTANT - ENABLE UNBOUND MANUALLY:${NC}"
    echo -e "   1. Login to the Web Interface."
    echo -e "   2. Go to ${BLUE}Settings > DNS${NC}."
    echo -e "   3. Uncheck 'Google' (IPv4)."
    echo -e "   4. Check 'Custom 1 (IPv4)' and type: ${BLUE}127.0.0.1#5335${NC}"
    echo -e "   5. Click 'Save' at the bottom."
    echo ""
fi

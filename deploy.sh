#!/bin/bash

# ==========================================
# PI-HOLE All-In-One Script
# Author: Damian Iglesias
# Version: 3.0
# ==========================================

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m' 

# Generate Random Password
GENERATED_PASS=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 12)

# HEADER
clear
echo -e "${BLUE}"
echo "  ____  _       _           _       "
echo " |  _ \(_)     | |         | |      "
echo " | |_) |_      | |__   ___ | | ___  "
echo " |  __/| |_____| '_ \ / _ \| |/ _ \ "
echo " | |   | |_____| | | | (_) | |  __/ "
echo " |_|   |_|     |_| |_|\___/|_|\___| "
echo "           INSTALLER v2.6           "
echo -e "${NC}"

# 1. ROOT CHECK
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}ERROR: Please run as root (sudo ./deploy.sh)${NC}"
  exit 1
fi

# 2. FIX PORT 53 
echo -e "${YELLOW} Step 1: Network Prep...${NC}"
systemctl stop systemd-resolved
sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
systemctl restart systemd-resolved
echo -e "${GREEN}✅ Port 53 freed & Internet Secured.${NC}"

# 3. INSTALL DEPENDENCIES
echo -e "${YELLOW} Step 2: Dependencies...${NC}"
apt-get update 
# If update fails, script stops
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ ERROR: No internet connection. Check your network settings.${NC}"
    exit 1
fi
apt-get install curl net-tools ufw sqlite3 wget -y 
echo -e "${GREEN}✅ Dependencies installed.${NC}"

# 4. INSTALL PI-HOLE
echo -e "${YELLOW} Step 3: Installing Pi-hole Core...${NC}"
echo -e "${GRAY}   (Follow the blue screens - Accept Defaults)${NC}"
read -p "   Press [ENTER] to start..."

# Lanzamos el instalador
curl -sSL https://install.pi-hole.net | bash

# 5. PASSWORD SETUP
echo ""
echo -e "${YELLOW} Step 4: Security Setup${NC}"
sleep 3
pihole setpassword "$GENERATED_PASS"
systemctl restart pihole-FTL
echo -e "${GREEN}✅ Password configured.${NC}"

# UNBOUND SETUP
echo ""
echo -e "${YELLOW} Step 4.5: Unbound Recursive DNS${NC}"
read -p "   Install Unbound? [y/n]: " unbound_choice

if [[ "$unbound_choice" == "y" || "$unbound_choice" == "Y" ]]; then
    echo -e "${BLUE}⏳ Installing Unbound...${NC}"
    apt-get install unbound -y 
    wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root 
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
    systemctl stop pihole-FTL
    if [ -f /etc/pihole/setupVars.conf ]; then
        sed -i '/^PIHOLE_DNS_/d' /etc/pihole/setupVars.conf
        echo "PIHOLE_DNS_1=127.0.0.1#5335" >> /etc/pihole/setupVars.conf
    fi
    if [ -f /etc/pihole/pihole.toml ]; then
        if grep -q "upstreamServers" /etc/pihole/pihole.toml; then
            sed -i 's/upstreamServers.*/upstreamServers = ["127.0.0.1#5335"]/' /etc/pihole/pihole.toml
        else
            if grep -q "\[dns\]" /etc/pihole/pihole.toml; then
                sed -i '/\[dns\]/a upstreamServers = ["127.0.0.1#5335"]' /etc/pihole/pihole.toml
            else
                echo "" >> /etc/pihole/pihole.toml
                echo "[dns]" >> /etc/pihole/pihole.toml
                echo 'upstreamServers = ["127.0.0.1#5335"]' >> /etc/pihole/pihole.toml
            fi
        fi
    fi
    systemctl start pihole-FTL
    
    echo -e "${GREEN}✅ Unbound integrated.${NC}"
else
    echo -e "${GRAY}⏭  Skipping Unbound.${NC}"
fi

# PADD DASHBOARD 
echo ""
echo -e "${YELLOW} Step 4.8: PADD (Terminal Dashboard)${NC}"
read -p "   Install PADD dashboard? [y/n]: " padd_choice

if [[ "$padd_choice" == "y" || "$padd_choice" == "Y" ]]; then
    wget -N https://raw.githubusercontent.com/pi-hole/PADD/master/padd.sh -O /usr/local/bin/padd > /dev/null 2>&1
    chmod +x /usr/local/bin/padd
    echo -e "${GREEN}✅ PADD installed.${NC}"
    
    read -p "   Auto-start PADD on SSH login? [y/n]: " auto_padd
    if [[ "$auto_padd" == "y" || "$auto_padd" == "Y" ]]; then
        REAL_USER=$SUDO_USER
        if [ -z "$REAL_USER" ]; then REAL_USER=$(logname); fi
        USER_HOME="/home/$REAL_USER"
        if ! grep -q "padd" "$USER_HOME/.bashrc"; then
            echo "if [ \"\$SSH_CONNECTION\" ] && [ -t 1 ]; then /usr/local/bin/padd; fi" >> "$USER_HOME/.bashrc"
            echo -e "${GREEN}✅ Auto-start configured.${NC}"
        fi
    fi
fi

# 6. FIREWALL
echo -e "${YELLOW} Step 5: Firewall...${NC}"
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 53 > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
echo "y" | ufw enable > /dev/null 2>&1

# 7. STATIC IP
echo ""
echo -e "${YELLOW} Step 6: Static IP Configuration${NC}"
ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"
read -p "   Type interface name (e.g. enp0s8): " SELECTED_IF

if [[ -n "$SELECTED_IF" ]]; then
    CURRENT_IP=$(ip -4 addr show $SELECTED_IF 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
    CURRENT_GW=$(ip route | grep default | awk '{print $3}' | head -n1)
    

    if [[ -z "$CURRENT_GW" ]]; then CURRENT_GW="192.168.1.1"; fi

    echo -e "   Selected: ${GREEN}$SELECTED_IF${NC} | IP: ${GREEN}$CURRENT_IP${NC}"
    read -p "   Set this IP as STATIC? [y/n]: " static_choice

    if [[ "$static_choice" == "y" || "$static_choice" == "Y" ]]; then
        mkdir -p /etc/netplan/backup
        cp /etc/netplan/*.yaml /etc/netplan/backup/ 2>/dev/null

        cat <<EOF > /etc/netplan/99-pihole-static.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $SELECTED_IF:
      dhcp4: false
      addresses: [$CURRENT_IP/24]
      routes: [{to: default, via: $CURRENT_GW}]
      nameservers: {addresses: [8.8.8.8, 1.1.1.1]}
EOF
        chmod 600 /etc/netplan/99-pihole-static.yaml
        netplan apply > /dev/null 2>&1
        FINAL_REPORT_IP=$CURRENT_IP
        echo -e "${GREEN}✅ Static IP applied.${NC}"
    fi
fi

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
echo ""
if [[ "$unbound_choice" == "y" || "$unbound_choice" == "Y" ]]; then
    echo -e "${GREEN}✅ DNS is set to Unbound (127.0.0.1#5335)${NC}"
fi
echo -e "   (Copy this password immediately!)"
echo ""
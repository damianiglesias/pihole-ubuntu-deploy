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
echo "           INSTALLER v2.0           "
echo -e "${NC}"

# 1. ROOT CHECK
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}ERROR: Please run as root (sudo ./deploy.sh)${NC}"
  exit 1
fi

# STEP 0: DEPLOYMENT MODE
echo -e "${YELLOW} Step 0: Choose Deployment Mode${NC}"
echo -e "   [1] Docker (Recommended - Isolated)"
echo -e "   [2] OS (Classic - Direct on OS)"
read -p "   Select option [1-2]: " mode_choice

# 2. FIX PORT 53 
echo -e "${YELLOW} Step 1: Network Prep...${NC}"
sed -r -i.orig 's/#?DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf > /dev/null 2>&1
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf > /dev/null 2>&1
systemctl restart systemd-resolved > /dev/null 2>&1
echo -e "${GREEN}✅ Port 53 freed & DNS preserved.${NC}"

# 3. INSTALL COMMON DEPENDENCIES
echo -e "${YELLOW} Step 2: Dependencies...${NC}"
apt-get update > /dev/null 2>&1
apt-get install curl net-tools ufw sqlite3 wget -y > /dev/null 2>&1

if [[ "$mode_choice" == "1" ]]; then
    # DOCKER 
    echo -e "${BLUE}⏳ Installing Docker...${NC}"
    if ! command -v docker &> /dev/null; then
        curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
    fi
    
    echo -e "${BLUE}⏳ Setting up Pi-hole + Unbound Docker Compose...${NC}"
    mkdir -p ~/pihole-docker && cd ~/pihole-docker
    
    cat <<EOF > docker-compose.yml
services:
  pihole:
    container_name: pihole
    image: pihole/pihole:latest
    ports:
      - "53:53/tcp"
      - "53:53/udp"
      - "80:80/tcp"
    environment:
      TZ: 'Europe/Madrid'
      WEBPASSWORD: '$GENERATED_PASS'
      PIHOLE_DNS_1: '172.20.0.5#5335'
    networks:
      pihole_net:
        ipv4_address: 172.20.0.2
    volumes:
      - './etc-pihole:/etc/pihole'
      - './etc-dnsmasq.d:/etc/dnsmasq.d'
    restart: unless-stopped

  unbound:
    container_name: unbound
    image: mvance/unbound:latest
    networks:
      pihole_net:
        ipv4_address: 172.20.0.5
    ports:
      - "5335:5335/udp"
    restart: unless-stopped

networks:
  pihole_net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF
    docker compose up -d > /dev/null 2>&1
    echo -e "${GREEN}✅ Docker containers deployed.${NC}"
    DOCKER_USED=true
else
    #OS PATH
    echo -e "${YELLOW} Step 3: Installing Pi-hole Core...${NC}"
    read -p "   Press [ENTER] to start..."
    curl -sSL https://install.pi-hole.net | bash

    # 3.5. Blocklists
    read -p "   Install Advanced Lists? [y/n]: " list_choice
    if [[ "$list_choice" == "y" || "$list_choice" == "Y" ]]; then
        sqlite3 /etc/pihole/gravity.db "INSERT OR IGNORE INTO adlist (address, enabled, comment) VALUES ('https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts', 1, 'StevenBlack Unified');"
        pihole -g > /dev/null 2>&1
    fi

    # 4. Password
    pihole setpassword "$GENERATED_PASS"
    
    # 4.5 Unbound
    read -p "   Install Unbound? [y/n]: " unbound_choice
    if [[ "$unbound_choice" == "y" || "$unbound_choice" == "Y" ]]; then
        apt-get install unbound -y > /dev/null 2>&1
        wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root > /dev/null 2>&1
        chown unbound:unbound /var/lib/unbound/root.hints
        
        # Unbound config
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
        pihole -a setdns 127.0.0.1#5335 > /dev/null 2>&1
    fi
fi

# 5. PADD (Terminal Console)
read -p "   Install PADD dashboard? [y/n]: " padd_choice
if [[ "$padd_choice" == "y" ]]; then
    wget -N https://raw.githubusercontent.com/pi-hole/PADD/master/padd.sh -O /usr/local/bin/padd > /dev/null 2>&1
    chmod +x /usr/local/bin/padd
fi

# 6. FIREWALL
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
    cat <<EOF > /etc/netplan/99-pihole-static.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    $SELECTED_IF:
      dhcp4: false
      addresses: [$CURRENT_IP/24]
      routes: [{to: default, via: $CURRENT_GW}]
      nameservers: {addresses: [127.0.0.1, 8.8.8.8]}
EOF
    chmod 600 /etc/netplan/99-pihole-static.yaml
    netplan apply > /dev/null 2>&1
fi

# 8. REPORT FINAL
clear
FINAL_IP=$(hostname -I | awk '{print $1}')
echo -e "${GREEN}################################################${NC}"
echo -e "${GREEN}#             DEPLOYMENT SUCCESSFUL!           #${NC}"
echo -e "${GREEN}################################################${NC}"
echo ""
echo -e "${BLUE} Server IP:${NC}      $FINAL_IP"
echo -e "${BLUE} Web Interface:${NC}  http://$FINAL_IP/admin"
echo -e "${YELLOW} PASSWORD:${NC}       $GENERATED_PASS"
echo ""
if [[ "$DOCKER_USED" == "true" ]]; then
    echo -e "${GREEN}✅ Running in Docker Mode (Pi-hole + Unbound).${NC}"
    echo -e "   Container isolated. Host system clean."
fi
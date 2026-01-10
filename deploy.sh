#!/bin/bash

# ==========================================
# PI-HOLE DEPLOYMENT SUITE
# Author: Damian Iglesias
# Version: 4.1
# ==========================================

GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
GRAY='\033[1;30m'
NC='\033[0m' 

# --- HEADER ---
clear
echo -e "${BLUE}"
echo "  ____  _       _           _       "
echo " |  _ \(_)     | |         | |      "
echo " | |_) |_      | |__   ___ | | ___  "
echo " |  __/| |_____| '_ \ / _ \| |/ _ \ "
echo " | |   | |_____| | | | (_) | |  __/ "
echo " |_|   |_|     |_| |_|\___/|_|\___| "
echo "           INSTALLER v4.1           "
echo -e "${NC}"

# 1. ROOT CHECK
if [ "$EUID" -ne 0 ]; then 
  echo -e "${RED}ERROR: Please run as root (sudo ./deploy.sh)${NC}"
  exit 1
fi

# 2. FIX PORT 53 & FORCE INTERNET
echo -e "${YELLOW} Step 1: Network Prep...${NC}"
systemctl stop systemd-resolved > /dev/null 2>&1
systemctl disable systemd-resolved > /dev/null 2>&1
rm -f /etc/resolv.conf
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf
echo -e "${GREEN}✅ Port 53 freed & DNS forced to Google.${NC}"
echo -e "${BLUE}⏳ Checking Internet connection...${NC}"
sleep 2
if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
    echo -e "${RED}❌ FATAL ERROR: No Internet connection detected.${NC}"
    echo -e "${YELLOW}   Please check your VirtualBox Network Settings (Try NAT or Bridged).${NC}"
    echo -e "${YELLOW}   The script cannot continue without Internet.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Internet is ONLINE.${NC}"

# 3. INSTALL DEPENDENCIES
echo -e "${YELLOW} Step 2: Dependencies...${NC}"
apt-get update
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Apt update failed. Check your network.${NC}"
    exit 1
fi
apt-get install curl net-tools ufw sqlite3 wget python3 python3-venv python3-pip git -y
echo -e "${GREEN} Dependencies installed.${NC}"

# 4. INSTALL PI-HOLE
echo -e "${YELLOW} Step 3: Installing Pi-hole Core...${NC}"
echo -e "${GRAY}   (Follow the blue screens - Accept Defaults)${NC}"
read -p "   Press [ENTER] to start..."
curl -sSL https://install.pi-hole.net | bash

# POST INSTALL VERIFY
if ! command -v pihole &> /dev/null; then
    echo -e "${RED}❌ Pi-hole installation FAILED. Please check the logs above.${NC}"
    exit 1
fi

# INTERACTIVE BLOCKLISTS
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
echo -e "${YELLOW}Step 4: Security Setup${NC}"
echo -e "${BLUE}⏳ Please type your Web Admin Password:${NC}"

while true; do
    echo -ne "   > Password: "
    read -s USER_PASS
    echo ""
    echo -ne "   > Confirm:  "
    read -s USER_PASS_CONFIRM
    echo ""
    
    if [ "$USER_PASS" == "$USER_PASS_CONFIRM" ] && [ ! -z "$USER_PASS" ]; then
        break
    else
        echo -e "${RED}❌ Passwords do not match. Try again.${NC}"
    fi
done

echo -e "${BLUE}⏳ Applying password...${NC}"
# Método universal
pihole setpassword "$USER_PASS" > /dev/null 2>&1
systemctl restart pihole-FTL
echo -e "${GREEN}✅ Password configured.${NC}"

# UNBOUND SETUP
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
    echo -e "${GREEN}✅ Unbound installed.${NC}"
else
    echo -e "${GRAY}⏭  Skipping Unbound.${NC}"
fi

#PADD DASHBOARD
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
else
    echo -e "${GRAY}⏭  Skipping PADD.${NC}"
fi

# --- PYTHON DNS MANAGER ---
echo ""
echo -e "${YELLOW}🐍Step 4.9: Python DNS Manager${NC}"
read -p "   Install DNS Manager tool? [y/n]: " dns_tool_choice

if [[ "$dns_tool_choice" == "y" || "$dns_tool_choice" == "Y" ]]; then
    echo -e "${BLUE}⏳ Setting up Python environment...${NC}"
    TARGET_DIR="/opt/pihole-dns-manager"
    mkdir -p $TARGET_DIR
    if [ -d "$TARGET_DIR/.git" ]; then
        cd $TARGET_DIR && git pull > /dev/null 2>&1
    else
        git clone https://codeberg.org/ben/pihole_dns.git $TARGET_DIR > /dev/null 2>&1
    fi
    cd $TARGET_DIR
    python3 -m venv venv
    source venv/bin/activate
    pip install requests > /dev/null 2>&1
    cat <<EOF > run_dns_sync.sh
#!/bin/bash
export PIHOLE_URL="http://127.0.0.1"
export PIHOLE_PASSWORD="$USER_PASS"
echo "Syncing DNS records..."
cd $TARGET_DIR
source venv/bin/activate
python3 pihole_dns.py "\$@"
EOF
    chmod +x run_dns_sync.sh
    if [ ! -f entries.txt ]; then
        echo "# Format: IP Domain" > entries.txt
        echo "127.0.0.1  pihole.local" >> entries.txt
    fi
    echo -e "${GREEN}✅ DNS Tool installed.${NC}"
else
    echo -e "${GRAY}⏭  Skipping DNS Manager.${NC}"
fi

# 6. FIREWALL
echo -e "${YELLOW} Step 5: Firewall...${NC}"
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 53 > /dev/null 2>&1
ufw allow 80/tcp > /dev/null 2>&1
echo "y" | ufw enable > /dev/null 2>&1

# 7. STATIC IP
echo ""
echo -e "${YELLOW}Step 6: Static IP Configuration${NC}"
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
      nameservers: {addresses: [8.8.8.8, 127.0.0.1]}
EOF
        chmod 600 /etc/netplan/99-pihole-static.yaml
        netplan apply > /dev/null 2>&1
        FINAL_REPORT_IP=$CURRENT_IP
        echo -e "${GREEN}✅ Static IP applied.${NC}"
    fi
fi

# 8. FINAL REPORT
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
echo -e "${YELLOW} PASSWORD:${NC}       ${RED}$USER_PASS${NC}"
echo ""
if [[ "$unbound_choice" == "y" || "$unbound_choice" == "Y" ]]; then
    echo -e "${YELLOW} UNBOUND INSTRUCTIONS:${NC}"
    echo -e "   1. Login to Web Interface -> Settings -> DNS"
    echo -e "   2. Uncheck 'Google' & Check 'Custom 1': ${BLUE}127.0.0.1#5335${NC}"
fi
if [[ "$padd_choice" == "y" || "$padd_choice" == "Y" ]]; then
    echo -e "${YELLOW} PADD:${NC} Type ${BLUE}padd${NC} to view dashboard."
fi
if [[ "$DNS_TOOL_INSTALLED" == "true" ]]; then
    echo -e "${YELLOW} DNS MANAGER:${NC}"
    echo -e "   Edit hosts at: ${BLUE}/opt/pihole-dns-manager/entries.txt${NC}"
fi
echo -e "   (ENJOY!)"
echo ""

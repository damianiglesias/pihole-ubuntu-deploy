#!/bin/bash
# ufw config (firewall) for pi-hole
# Required ports: 80 (web), 53 (dns), 22 (ssh)

echo "--- 1. Enabling SSH traffic (Port 22) ---"
sudo ufw allow 22/tcp
echo "--- 2. Enabling DNS traffic (Port 53 TCP/UDP) ---"
sudo ufw allow 53/tcp
sudo ufw allow 53/udp
echo "--- 3. Enabling HTTP web traffic (Port 80) ---"
sudo ufw allow 80/tcp

echo "--- Reloading firewall (Appling changes) ---"
sudo ufw enable
sudo ufw reload

echo "--- Firewall Status ---"
sudo ufw status verbose
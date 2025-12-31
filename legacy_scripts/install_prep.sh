#!/bin/bash
# Script of the preparation of Pi-Hole in Ubuntu Server
echo "--- 1. Updating packages ---"
sudo apt update
echo "--- 2. Installing necessary tools (curl) ---"
sudo apt install curl net-tools -y
echo "--- 3. Preparation complete. Starting the installer of Pi-hole ---"
curl -sSL https://install.pi-hole.net | bash

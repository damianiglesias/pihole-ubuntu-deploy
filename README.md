<div align="center">
  <img src="https://github.com/user-attachments/assets/ea32eb46-31a2-48d9-93c0-587aefecc6f5" width="150">
  <h1>Automated Pi-hole & Unbound Installer for Ubuntu</h1>
</div>
Pihole-ubuntu-deploy
Bash script to automate the installation of Pi-hole v6, Unbound, and Static IP on Ubuntu Server. Features PADD dashboard and auto-configuration. (First project)
This project provides a set of Bash scripts to automate the installation, configuration, and security hardening of a Pi-hole server running on Ubuntu although its pretty basic. It transforms any virtual machine or old PC into a network-wide ad blocker.

# Disclaimer
 Unbound is in the script but not working. Although there are instructions in the script i'm looking forward to fix the issue in the next verisons.
## Prerequisites
*   **Hardware:** Virtual Machine, Raspberry Pi, or an old PC.
*   **OS:** Ubuntu Server 20.04, 22.04, or 24.04 (LTS recommended).
*   **Resources:** Minimum 512MB RAM, 1 CPU Core.
*   **Network:** Internet connection required for installation.
## Network Architecture
This setup has been tested in a Virtual Machine with this two specific network enviroments:
1. **Host-Only Adapter:**
   * For me it was ideal for developing the script via SSH from the host machine.
   * It is isolated from the main LAN.
2. **Bridged-adapter**
* In this V1 of the proyect is easier than doing port forwarding or VPN but i will develop a version with all the possible cases.
## Installation Methods
Choose one that fits for you:
# Method 1: Bash Script
Installs Pi-hole & Unbound directly on the OS. Best for dedicated hardware (Raspberry Pi).
### 1. Download the project
git clone https://github.com/damianiglesias/pihole-ubuntu-deploy
### 2. Get into the folder
cd pihole-ubuntu-deploy
### 3. Run the script
sudo ./deploy.sh
# Method 2: Ansible & Docker
Deploys the stack using Docker Containers
### 1. Download the project
git clone https://github.com/damianiglesias/pihole-ubuntu-deploy
### 2. Get into the folder 
cd pihole-ubuntu-deploy/ansible
### 3. Install ansible
sudo apt update && sudo apt install ansible -y
### 4. Run the playbook
ansible-playbook -i inventory.ini install_pihole.yml
# Extras
## Pi-hole dns
### 1. Enter directory
cd pihole-ubuntu-deploy/tools
### 2. Run the script
sudo ./piholedns

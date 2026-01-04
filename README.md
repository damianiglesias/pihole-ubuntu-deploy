<p align="center">
  <img src="https://github.com/user-attachments/assets/ea32eb46-31a2-48d9-93c0-587aefecc6f5"/> 
</p>

 # Disclaimer
 Unbound is in the script but not working. Although there are instructions in the script i'm looking forward to fix the issue in the next verisons.
# pihole-ubuntu-deploy
Automated deployment of DNS server (Pi-hole) on Ubuntu Server for blocking advertising and telemetry on local network. Student project. (First project)
This project provides a set of Bash scripts to automate the installation, configuration, and security hardening of a Pi-hole server running on Ubuntu although its pretty basic. It transforms any virtual machine or old PC into a network-wide ad blocker.
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
## Quick Start
 1. Clone the repository:
git clone https://github.com/damianiglesias/pihole-ubuntu-deploy.git
 2. Enter the directory:
cd pihole-ubuntu-deploy
 3. Grant exexution permissions (Only if the file can't execute):
chmod +x *.sh
 4. Run the script:
./deploy.sh
 Or: (deprecated)
./install_prep.sh
./firewall_rules.sh

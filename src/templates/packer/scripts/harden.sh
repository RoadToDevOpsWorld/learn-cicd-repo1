#!/bin/bash

# Ensure script runs as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "Starting AMI Hardening..."

# Update and upgrade system
apt update && apt upgrade -y

# Disable root SSH login
sed -i 's/^PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
echo "Root login disabled."

# Set up UFW (Uncomplicated Firewall)
ufw default deny incoming
ufw default allow outgoing
ufw allow 22  # Allow SSH
ufw allow 80  # Allow HTTP
ufw allow 443 # Allow HTTPS
ufw enable
echo "Firewall rules applied."

# Disable unused services
systemctl disable rpcbind
systemctl disable nfs-server
systemctl disable cups
echo "Disabled unused services."

# Enforce strong password policies
echo "password requisite pam_pwquality.so retry=3 minlen=12" >> /etc/pam.d/common-password
echo "Password policy enforced."

# Set file permissions
chmod 700 /root
chmod 600 /etc/shadow /etc/gshadow /etc/passwd
echo "File permissions secured."

# Restart SSH service
systemctl restart sshd

echo "AMI Hardening completed successfully."

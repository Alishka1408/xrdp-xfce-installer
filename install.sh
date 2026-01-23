#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# XRDP + XFCE Remote Desktop Installer (Ubuntu/Debian)
# Usage:
#   sudo -i
#   bash <(curl -fsSL https://raw.githubusercontent.com/USERNAME/REPO/main/install.sh)
# ==================================================

if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root (use sudo -i)" >&2
  exit 1
fi

echo "=================================================="
echo " XRDP + XFCE Remote Desktop Installer"
echo "=================================================="
echo

# --------------------------------------------------
# USER INPUT
# --------------------------------------------------

read -rp "Do you want to restrict RDP access to a specific IP? [y/N]: " LIMIT_RDP
LIMIT_RDP=${LIMIT_RDP:-N}

if [[ "$LIMIT_RDP" =~ ^[Yy]$ ]]; then
  read -rp "Enter allowed public IP for RDP (3389): " ALLOWED_IP
  if [[ -z "$ALLOWED_IP" ]]; then
    echo "ERROR: IP address cannot be empty"
    exit 1
  fi
fi

echo
echo "Enter password for Linux user 'user'"
echo "(minimum 8 characters, strong password recommended)"
read -rsp "Password: " USER_PASSWORD
echo
read -rsp "Confirm password: " USER_PASSWORD_CONFIRM
echo

if [[ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" ]]; then
  echo "ERROR: Passwords do not match"
  exit 1
fi

if [[ "${#USER_PASSWORD}" -lt 8 ]]; then
  echo "ERROR: Password too short"
  exit 1
fi

# --------------------------------------------------
# SYSTEM UPDATE
# --------------------------------------------------

echo "[1/8] Updating system"
apt update
DEBIAN_FRONTEND=noninteractive apt upgrade -y

# --------------------------------------------------
# INSTALL XFCE
# --------------------------------------------------

echo "[2/8] Installing XFCE"
DEBIAN_FRONTEND=noninteractive apt install -y xfce4 xfce4-goodies

# --------------------------------------------------
# INSTALL XRDP
# --------------------------------------------------

echo "[3/8] Installing XRDP"
DEBIAN_FRONTEND=noninteractive apt install -y xrdp
systemctl enable xrdp
systemctl restart xrdp

# --------------------------------------------------
# CREATE USER
# --------------------------------------------------

echo "[4/8] Creating user 'user'"
if ! id user &>/dev/null; then
  adduser --disabled-password --gecos "" user
fi

echo "user:${USER_PASSWORD}" | chpasswd
usermod -aG sudo user

# --------------------------------------------------
# XFCE SESSION FOR XRDP
# --------------------------------------------------

echo "[5/8] Configuring XFCE session"
echo "xfce4-session" > /home/user/.xsession
chown user:user /home/user/.xsession

# --------------------------------------------------
# FIREWALL CONFIGURATION
# --------------------------------------------------

echo "[6/8] Configuring UFW firewall"
apt install -y ufw

# Always allow SSH
ufw allow 22/tcp

# Remove existing RDP rules
while ufw status numbered | grep -q "3389/tcp"; do
  RULE_NUM=$(ufw status numbered | awk '/3389\/tcp/ {gsub(/\[|\]/,"",$1); print $1; exit}')
  yes | env LC_ALL=C ufw delete "$RULE_NUM" || break
done

if [[ "$LIMIT_RDP" =~ ^[Yy]$ ]]; then
  ufw allow from "$ALLOWED_IP" to any port 3389 proto tcp
  echo "RDP access restricted to IP: $ALLOWED_IP"
else
  ufw allow 3389/tcp
  echo "RDP access allowed from any IP"
fi

ufw --force enable

# --------------------------------------------------
# INSTALL BROWSERS
# --------------------------------------------------

echo "[7/8] Installing browsers"
wget -qO /tmp/chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
apt install -y /tmp/chrome.deb || apt -f install -y
rm -f /tmp/chrome.deb

apt install -y firefox

# --------------------------------------------------
# DONE
# --------------------------------------------------

echo "[8/8] Installation completed"
echo
echo "=================================================="
echo " XRDP + XFCE installation finished"
echo " User: user"
if [[ "$LIMIT_RDP" =~ ^[Yy]$ ]]; then
  echo " RDP access: restricted to $ALLOWED_IP"
else
  echo " RDP access: open (all IPs)"
fi
echo "=================================================="
#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# XRDP + XFCE Remote Desktop Installer (Ubuntu/Debian)
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

read -rp "Enter username to create for RDP [user]: " USERNAME
USERNAME=${USERNAME:-user}

# Basic username validation (Linux user rules simplified)
if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "ERROR: Invalid username. Use lowercase letters, numbers, '_' or '-', and start with a letter or '_'." >&2
  exit 1
fi

read -rp "Do you want to restrict RDP access to a specific IP? [y/N]: " LIMIT_RDP
LIMIT_RDP=${LIMIT_RDP:-N}

if [[ "$LIMIT_RDP" =~ ^[Yy]$ ]]; then
  read -rp "Enter allowed public IP for RDP (3389): " ALLOWED_IP
  if [[ -z "$ALLOWED_IP" ]]; then
    echo "ERROR: IP address cannot be empty" >&2
    exit 1
  fi
fi

echo
echo "Enter password for Linux user '$USERNAME'"
echo "(minimum 8 characters, strong password recommended)"
read -rsp "Password: " USER_PASSWORD
echo
read -rsp "Confirm password: " USER_PASSWORD_CONFIRM
echo

if [[ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" ]]; then
  echo "ERROR: Passwords do not match" >&2
  exit 1
fi

if [[ "${#USER_PASSWORD}" -lt 8 ]]; then
  echo "ERROR: Password too short" >&2
  exit 1
fi

# --------------------------------------------------
# SYSTEM UPDATE
# --------------------------------------------------

echo "[1/9] Updating system"
apt update
DEBIAN_FRONTEND=noninteractive apt upgrade -y

# --------------------------------------------------
# INSTALL XFCE
# --------------------------------------------------

echo "[2/9] Installing XFCE"
DEBIAN_FRONTEND=noninteractive apt install -y xfce4 xfce4-goodies

# --------------------------------------------------
# INSTALL XRDP + XORG BACKEND (CRITICAL)
# --------------------------------------------------

echo "[3/9] Installing XRDP and Xorg backend"
DEBIAN_FRONTEND=noninteractive apt install -y xrdp xorgxrdp xserver-xorg-core

# Enable and start XRDP
systemctl enable xrdp
systemctl restart xrdp

# --------------------------------------------------
# XRDP TLS KEY PERMISSIONS (CRITICAL)
# Allows XRDP to access /etc/xrdp/key.pem securely
# --------------------------------------------------

if getent group ssl-cert >/dev/null; then
  chown root:ssl-cert /etc/xrdp/key.pem
  chmod 640 /etc/xrdp/key.pem
  usermod -aG ssl-cert xrdp
fi

# Ensure runtime directory exists with correct permissions
install -d -m 0755 -o xrdp -g xrdp /run/xrdp

# Restart XRDP to apply changes
systemctl restart xrdp xrdp-sesman

# --------------------------------------------------
# (OPTIONAL) Disable Wayland for GDM3 if present
# --------------------------------------------------

if dpkg -l | grep -qE '^ii\s+gdm3\s'; then
  echo "[4/9] Disabling Wayland (gdm3 detected)"
  mkdir -p /etc/gdm3
  cat > /etc/gdm3/custom.conf <<'EOF'
[daemon]
WaylandEnable=false
EOF
else
  echo "[4/9] Skipping Wayland disable (gdm3 not installed)"
fi

# --------------------------------------------------
# CREATE USER
# --------------------------------------------------

echo "[5/9] Creating user '$USERNAME'"
if ! id "$USERNAME" &>/dev/null; then
  adduser --disabled-password --gecos "" "$USERNAME"
fi

echo "${USERNAME}:${USER_PASSWORD}" | chpasswd
usermod -aG sudo "$USERNAME"

# Fix home permissions for XRDP stability (CRITICAL)
if [[ -d "/home/$USERNAME" ]]; then
  chmod 755 "/home/$USERNAME"
fi

# --------------------------------------------------
# XFCE SESSION FOR XRDP (CRITICAL)
# --------------------------------------------------

echo "[6/9] Configuring XFCE session for '$USERNAME'"
echo "exec startxfce4" > "/home/$USERNAME/.xsession"
chown "$USERNAME:$USERNAME" "/home/$USERNAME/.xsession"
chmod 755 "/home/$USERNAME/.xsession"

# --------------------------------------------------
# FIREWALL CONFIGURATION
# --------------------------------------------------

echo "[7/9] Configuring UFW firewall"
DEBIAN_FRONTEND=noninteractive apt install -y ufw

# Always allow SSH to prevent lockout
ufw allow 22/tcp

# Remove existing RDP rules
while ufw status numbered 2>/dev/null | grep -q "3389/tcp"; do
  RULE_NUM=$(ufw status numbered | awk '/3389\/tcp/ {gsub(/\[|\]/,"",$1); print $1; exit}')
  yes | env LC_ALL=C LANG=C ufw delete "$RULE_NUM" || break
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
# INSTALL BROWSER (Google Chrome)
# --------------------------------------------------

echo "[8/9] Installing Google Chrome"
DEBIAN_FRONTEND=noninteractive apt install -y wget ca-certificates gnupg

CHROME_DEB="/tmp/google-chrome-stable_current_amd64.deb"
wget -qO "$CHROME_DEB" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

if ! apt install -y "$CHROME_DEB"; then
  apt -f install -y
  apt install -y "$CHROME_DEB"
fi

rm -f "$CHROME_DEB"

# --------------------------------------------------
# DONE
# --------------------------------------------------

echo "[9/9] Installation completed"
echo
echo "=================================================="
echo " XRDP + XFCE installation finished"
echo " RDP user: $USERNAME"
if [[ "$LIMIT_RDP" =~ ^[Yy]$ ]]; then
  echo " RDP access: restricted to $ALLOWED_IP"
else
  echo " RDP access: open (all IPs)"
fi
echo " Recommended: reboot the server before first RDP login."
echo "=================================================="
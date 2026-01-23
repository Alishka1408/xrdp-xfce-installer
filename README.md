# XRDP + XFCE Installer

One-click installer for XRDP + XFCE on Ubuntu/Debian with firewall hardening and IP-restricted RDP access.

This script installs a lightweight desktop environment, enables Remote Desktop (RDP), creates a sudo user, installs browsers, and secures the server using UFW.

---

## Features

- System update and upgrade
- Lightweight XFCE desktop environment
- XRDP remote desktop access
- Creation of a non-root sudo user
- Firewall hardening with IP-restricted RDP (port 3389)
- Installation of Google Chrome and Firefox
- One-command installer (curl | bash style)

---

## Supported Systems

- Ubuntu 20.04+
- Ubuntu 22.04+
- Debian 11+
- Debian 12+

The script is intended for clean or minimal installations.
Not tested on non–Debian-based distributions.

---

## Installation

Run the installer as root:

```bash
sudo -i
bash <(curl -fsSL https://raw.githubusercontent.com/Alishka1408/xrdp-xfce-installer/refs/heads/main/install.sh)

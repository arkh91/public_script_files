#!/bin/bash
set -euo pipefail

# ===================== CONFIG =====================
UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
UNBOUND_CONF_FILE="$UNBOUND_CONF_DIR/gamedns.conf"
ROOT_KEY="/var/lib/unbound/root.key"
DOH_PORT="3000"
DOH_SERVICE="dohnut"
DOH_USER="dohproxy"
DOMAIN=""
EMAIL=""
# =================================================

# -------------------------
# Helper Functions
# -------------------------
log() { echo -e "\e[32m[+] $1\e[0m"; }
error_exit() { echo -e "\e[31m[!] $1\e[0m"; exit 1; }

# -------------------------
# MUST RUN AS ROOT
# -------------------------
[[ $EUID -eq 0 ]] || { echo "Run as root (sudo)."; exit 1; }

# -------------------------
# GET DOMAIN & EMAIL FIRST
# -------------------------
while [[ -z "$DOMAIN" ]]; do
    read -rp "Enter your domain (e.g. dns.example.com): " DOMAIN
done
while [[ -z "$EMAIL" ]]; do
    read -rp "Enter email for Let's Encrypt: " EMAIL
done
log "Using domain: $DOMAIN | email: $EMAIL"

# -------------------------
# INSTALL DEPENDENCIES
# -------------------------
log "Installing system packages..."
apt-get update -qq
apt-get install -y unbound dnsutils curl wget unzip ufw jq unbound-anchor \
    ca-certificates gnupg lsb-release nginx certbot python3-certbot-nginx \
    build-essential

if ! command -v node >/dev/null; then
    log "Installing Node.js 18..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
    apt-get install -y nodejs
fi

id -u "$DOH_USER" &>/dev/null || useradd -r -s /usr/sbin/nologin "$DOH_USER"

# -------------------------
# UNBOUND
# -------------------------
log "Configuring Unbound..."
mkdir -p "$UNBOUND_CONF_DIR"
rm -f /etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf 2>/dev/null || true

cat > "$UNBOUND_CONF_FILE" <<EOF
server:
    verbosity: 0
    num-threads: 2
    interface: 127.0.0.1
    port: 53
    do-ip4: yes
    do-ip6: no
    do

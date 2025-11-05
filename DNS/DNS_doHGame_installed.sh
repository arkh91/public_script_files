#!/bin/bash
set -euo pipefail

# ===================== CONFIG =====================
UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
UNBOUND_CONF_FILE="$UNBOUND_CONF_DIR/gamedns.conf"
ROOT_KEY="/var/lib/unbound/root.key"
DOH_PORT="3000"
DOH_SERVICE="dohnut"
DOH_USER="dohproxy"
# =================================================

# -------------------------
# Helper Functions
# -------------------------
log() { echo -e "\e[32m[+] $1\e[0m"; }
error_exit() { echo -e "\e[31m[!] $1\e[0m"; exit 1; }

run_as_root() {
    [[ $EUID -eq 0 ]] || error_exit "Run as root (sudo)."
}

# -------------------------
# Install dependencies
# -------------------------
install_dependencies() {
    log "Updating and installing packages..."
    apt-get update -qq
    apt-get install -y unbound dnsutils curl wget unzip ufw jq unbound-anchor \
        ca-certificates gnupg lsb-release nginx certbot python3-certbot-nginx \
        build-essential

    # Node.js 18
    if ! command -v node >/dev/null; then
        log "Installing Node.js 18..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs
    fi

    # Create user
    id -u "$DOH_USER" &>/dev/null || useradd -r -s /usr/sbin/nologin "$DOH_USER"
}

# -------------------------
# Domain & Email (MUST BE FIRST)
# -------------------------
get_domain_email() {
    while [[ -z "${DOMAIN:-}" ]]; do
        read -rp "Enter your domain (e.g. dns.example.com): " DOMAIN
    done
    while [[ -z "${EMAIL:-}" ]]; do
        read -rp "Enter email for Let's Encrypt: " EMAIL
    done
    log "Domain: $DOMAIN | Email: $EMAIL"
}

# -------------------------
# Unbound Setup
# -------------------------
configure_unbound() {
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
    do-udp: yes
    do-tcp: yes
    prefetch: yes
    prefetch-key: yes
    cache-min-ttl: 60
    cache-max-ttl: 86400
    so-reuseport: yes
    harden-dnssec-stripped: yes
    rrset-cache-size: 256m
    msg-cache-size: 128m
    hide-identity: yes
    hide-version: yes
    auto-trust-anchor-file: "$ROOT_KEY"
EOF
}

setup_dnssec() {
    log "Setting up DNSSEC..."
    mkdir -p /var/lib/unbound
    chown unbound:unbound /var/lib/unbound
    unbound-anchor -a "$ROOT_KEY" -v
    chown unbound:unbound "$ROOT_KEY"
}

validate_and_restart_unbound() {
    unbound-checkconf >/dev/null || error_exit "Unbound config failed!"
    systemctl restart unbound
    systemctl enable unbound
    sleep 2
}

# -------------------------
# DoH Proxy (Dohnut)
# -------------------------
setup_doh_proxy() {
    log "Installing Dohnut DoH proxy..."
    npm install -g dohnut

    mkdir -p /etc/dohnut
    cat > /etc/dohnut/config.json <<EOF
{
  "bind": "127.0.0.1:$DOH_PORT",
  "dns": "127.0.0.1:53",
  "path": "/dns-query",
  "timeout": 5000,
  "fake": true
}
EOF
    chown -R "$DOH_USER:$DOH_USER" /etc/dohnut

    cat > "/etc/systemd/system/$DOH_SERVICE.service" <<EOF
[Unit]
Description=Dohnut DoH Proxy
After=network.target unbound.service

[Service]
User=$DOH_USER
ExecStart=/usr/bin/dohnut --config /etc/dohnut/config.json
Restart=always
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now "$DOH_SERVICE"
    sleep 2
}

# -------------------------
# SSL + Nginx
# -------------------------
setup_nginx_and_ssl() {
    log "Setting up Nginx + Let's Encrypt..."

    rm -f /etc/nginx/sites-enabled/default

    # Minimal config for Certbot
    cat > /etc/nginx/sites-available/temp <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location /.well-known/acme-challenge/ { allow all; }
    location / { return 403; }
}
EOF
    ln -sf /etc/nginx/sites-available/temp /etc/nginx/sites-enabled/
    systemctl restart nginx

    # Use --nginx → creates options-ssl-nginx.conf
    log "Obtaining SSL certificate..."
    certbot --nginx -d "$DOMAIN" -m "$EMAIL" --agree-tos --non-interactive --redirect \
        || error_exit "Certbot failed"

    rm -f /etc/nginx/sites-enabled/temp
    rm -f /etc/nginx/sites-available/temp

    # Final DoH config
    cat > /etc/nginx/sites-available/doh <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$

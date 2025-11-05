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

# -------------------------
# Ensure script runs as root
# -------------------------
run_as_root() {
    if [[ $EUID -ne 0 ]]; then
        error_exit "This script must be run as root (use sudo)."
    fi
}

# -------------------------
# Install dependencies
# -------------------------
install_dependencies() {
    log "Updating package index..."
    apt-get update -qq

    log "Installing system packages..."
    apt-get install -y unbound dnsutils curl wget unzip ufw jq unbound-anchor \
        ca-certificates gnupg lsb-release nginx certbot python3-certbot-nginx \
        build-essential || error_exit "Failed to install system packages"

    # Node.js 18 LTS
    if ! command -v node >/dev/null 2>&1; then
        log "Installing Node.js 18 LTS..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs || error_exit "Failed installing Node.js"
    fi

    # Create dohproxy user
    if ! id "$DOH_USER" &>/dev/null; then
        useradd -r -s /usr/sbin/nologin "$DOH_USER"
        log "Created system user: $DOH_USER"
    fi
}

# -------------------------
# Ask for domain/email
# -------------------------
get_domain_email() {
    while [[ -z "${DOMAIN:-}" ]]; do
        read -rp "Enter your domain name (e.g., dns.example.com): " DOMAIN
    done
    while [[ -z "${EMAIL:-}" ]]; do
        read -rp "Enter your email for Let's Encrypt: " EMAIL
    done

    log "Domain: $DOMAIN | Email: $EMAIL"
}

# -------------------------
# Configure Unbound
# -------------------------
configure_unbound() {
    log "Configuring Unbound in $UNBOUND_CONF_FILE"
    mkdir -p "$UNBOUND_CONF_DIR"

    if [ -f /etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf ]; then
        rm -f /etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf
        log "Removed conflicting root-auto-trust-anchor-file.conf"
    fi

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
    outgoing-num-tcp: 64
    incoming-num-tcp: 64
    unwanted-reply-threshold: 10000
    hide-identity: yes
    hide-version: yes
    auto-trust-anchor-file: "$ROOT_KEY"
EOF
    log "Unbound config written."
}

# -------------------------
# Setup DNSSEC trust anchor
# -------------------------
setup_dnssec() {
    log "Initializing DNSSEC root trust anchor..."
    mkdir -p /var/lib/unbound
    chown unbound:unbound /var/lib/unbound
    chmod 755 /var/lib/unbound
    unbound-anchor -a "$ROOT_KEY" -v || error_exit "Failed to fetch root key"
    chown unbound:unbound "$ROOT_KEY"
}

# -------------------------
# Validate and restart Unbound
# -------------------------
validate_and_restart_unbound() {
    log "Validating Unbound configuration..."
    unbound-checkconf >/dev/null || error_exit "Unbound config invalid!"

    log "Restarting Unbound..."
    systemctl restart unbound
    systemctl enable unbound
    sleep 2
    log "Unbound is running and enabled."
}

# -------------------------
# Setup DoH Proxy (Dohnut)
# -------------------------
setup_doh_proxy() {
    log "Setting up DNS-over-HTTPS (DoH) proxy with Dohnut..."

    if ! npm list -g dohnut >/dev/null 2>&1; then
        log "Installing dohnut via npm..."
        npm install -g dohnut || error_exit "Failed to install dohnut"
    fi

    DOH_CONFIG_DIR="/etc/dohnut"
    mkdir -p "$DOH_CONFIG_DIR"
    chown "$DOH_USER":"$DOH_USER" "$DOH_CONFIG_DIR"

    cat > "$DOH_CONFIG_DIR/config.json" <<EOF
{
  "bind": "127.0.0.1:$DOH_PORT",
  "dns": "127.0.0.1:53",
  "path": "/dns-query",
  "timeout": 5000,
  "fake": true,
  "threads": 2
}
EOF
    chown "$DOH_USER":"$DOH_USER" "$DOH_CONFIG_DIR/config.json"

    cat > "/etc/systemd/system/$DOH_SERVICE.service" <<EOF
[Unit]
Description=DoH Proxy (Dohnut) for Unbound
After=network.target unbound.service
Wants=unbound.service

[Service]
Type=simple
User=$DOH_USER
ExecStart=/usr/bin/dohnut --config $DOH_CONFIG_DIR/config.json
Restart=always
RestartSec=5
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable "$DOH_SERVICE"
    systemctl start "$DOH_SERVICE"
    sleep 2
    log "DoH proxy running on 127.0.0.1:$DOH_PORT"
}

# -------------------------
# [FIXED] Obtain SSL Certificate FIRST
# -------------------------
obtain_ssl_certificate() {
    log "Obtaining Let's Encrypt certificate for $DOMAIN..."

    # Remove default site to avoid conflict
    [ -f /etc/nginx/sites-enabled/default ] && rm -f /etc/nginx/sites-enabled/default

    # Minimal HTTP server for certbot
    cat > /etc/nginx/sites-available/certbot <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        return 200 "Certbot validation";
    }
}
EOF
    ln -sf /etc/nginx/sites-available/certbot /etc/nginx/sites-enabled/
    systemctl restart nginx

    # Get cert
    certbot certonly --standalone -d "$DOMAIN" -m "$EMAIL" --agree-tos --non-interactive || \
        error_exit "Failed to obtain certificate"

    # Clean up
    rm -f /etc/nginx/sites-enabled/certbot
    rm -f /etc/nginx/sites-available/certbot
    log "SSL certificate obtained: /etc/letsencrypt/live/$DOMAIN/"
}

# -------------------------
# [FIXED] Setup Nginx AFTER certbot
# -------------------------
setup_nginx_ssl() {
    log "Configuring Nginx for DoH with SSL..."

    # Wait for certbot files
    if [ ! -f "/etc/letsencrypt/options-ssl-nginx.conf" ]; then
        log "Waiting for certbot to generate SSL options..."
        sleep 5
    fi

    cat > /etc/nginx/sites-available/doh <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # Only include if file exists
    include /etc/letsencrypt/options-ssl-nginx.conf || true;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem || true;

    location /dns-query {
        proxy_pass http://127.0.0.1:$DOH_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
    }

    location / {
        return 200 "DoH Endpoint: https://$DOMAIN/dns-query";
        add_header Content-Type text/plain;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/doh /etc/nginx/sites-enabled/doh

    # Test config
    if ! nginx -t 2>/tmp/nginx-test.err; then
        cat /tmp/nginx-test.err
        error_exit "Nginx configuration test failed!"
    fi

    systemctl restart nginx
    log "Nginx configured and running on https://$DOMAIN"
}

# -------------------------
# Final DoH Test
# -------------------------
test_doh_endpoint() {
    log "Testing DoH endpoint..."
    sleep 5

    local doh_query="q80BAAABAAAAAAAABmdvb2dsZQJjb20AAAEAAQ"
    local response=$(curl -s --insecure "https://$DOMAIN/dns-query?dns=$doh_query" -H 'accept: application/dns-message')

    if [[ -z "$response" ]]; then
        error_exit "DoH endpoint returned empty response!"
    fi

    log "DoH test successful! https://$DOMAIN/dns-query is live"
}

# -------------------------
# Open Firewall
# -------------------------
configure_firewall() {
    log "Configuring firewall..."
    ufw allow 22/tcp    comment 'SSH'
    ufw allow 53/udp    comment 'DNS'
    ufw allow 53/tcp    comment 'DNS'
    ufw allow 80/tcp    comment 'HTTP'
    ufw allow 443/tcp   comment 'HTTPS'
    ufw --force enable
    log "Firewall rules applied."
}

# -------------------------
# Main
# -------------------------
main() {
    run_as_root
    install_dependencies
    get_domain_email
    configure_unbound
    setup_dnssec
    validate_and_restart_unbound
    setup_doh_proxy

    # === CRITICAL ORDER ===
    obtain_ssl_certificate   # ← Creates /etc/letsencrypt/options-ssl-nginx.conf
    setup_nginx_ssl          # ← Now safe to reference it
    # =====================

    configure_firewall
    test_doh_endpoint

    log "============================================"
    log " DNS + DoH Server Fully Installed!"
    log " • Plain DNS: 127.0.0.1:53"
    log " • DoH URL:   https://$DOMAIN/dns-query"
    log " • Test: curl 'https://$DOMAIN/dns-query?dns=q80BAAABAAAAAAAABmdvb2dsZQJjb20AAAEAAQ' -H 'accept: application/dns-message'"
    log "============================================"
}

main "$@"

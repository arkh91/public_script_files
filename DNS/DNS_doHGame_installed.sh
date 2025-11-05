#!/bin/bash
set -euo pipefail

# ===================== CONFIG =====================
UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
UNBOUND_CONF_FILE="$UNBOUND_CONF_DIR/gamedns.conf"
ROOT_KEY="/var/lib/unbound/root.key"
DOH_PORT="3000"
DOH_SERVICE="doh-proxy"
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

    # Remove default auto-trust file to prevent duplicate
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
    log "Unbound is running and enabled."
}

# -------------------------
# [NEW] Setup DoH Proxy (Node.js)
# -------------------------
setup_doh_proxy() {
    log "Setting up DNS-over-HTTPS (DoH) proxy..."

    # Install doh-proxy globally
    if ! npm list -g doh-proxy >/dev/null 2>&1; then
        log "Installing doh-proxy via npm..."
        npm install -g doh-proxy || error_exit "Failed to install doh-proxy"
    fi

    # Create config directory
    DOH_CONFIG_DIR="/etc/doh-proxy"
    mkdir -p "$DOH_CONFIG_DIR"

    # Write config
    cat > "$DOH_CONFIG_DIR/config.json" <<EOF
{
  "listen": "127.0.0.1:$DOH_PORT",
  "upstream": "127.0.0.1:53",
  "path": "/dns-query",
  "timeout": 5000,
  "tries": 3,
  "verbose": false
}
EOF

    # Systemd service
    cat > "/etc/systemd/system/$DOH_SERVICE.service" <<EOF
[Unit]
Description=DoH Proxy for Unbound
After=network.target unbound.service
Wants=unbound.service

[Service]
Type=simple
User=$DOH_USER
ExecStart=/usr/bin/doh-proxy --config $DOH_CONFIG_DIR/config.json
Restart=always
RestartSec=5
AmbientCapabilities=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start
    systemctl daemon-reload
    systemctl enable "$DOH_SERVICE"
    systemctl start "$DOH_SERVICE"
    log "DoH proxy running on 127.0.0.1:$DOH_PORT"
}

# -------------------------
# [NEW] Setup Nginx + Let's Encrypt
# -------------------------
setup_nginx_ssl() {
    log "Configuring Nginx for DoH with SSL..."

    # Backup default site
    [ -f /etc/nginx/sites-enabled/default ] && rm -f /etc/nginx/sites-enabled/default

    # Nginx config
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
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location /dns-query {
        proxy_pass http://127.0.0.1:$DOH_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location / {
        return 200 "DoH Endpoint: POST/GET /dns-query";
        add_header Content-Type text/plain;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/doh /etc/nginx/sites-enabled/doh

    # Test config
    nginx -t || error_exit "Nginx configuration test failed!"

    # Obtain certificate
    log "Obtaining Let's Encrypt certificate..."
    certbot --nginx -d "$DOMAIN" -m "$EMAIL" --agree-tos --non-interactive --redirect || \
        error_exit "Failed to obtain SSL certificate"

    # Restart Nginx
    systemctl restart nginx
    log "Nginx configured with SSL on https://$DOMAIN/dns-query"
}

# -------------------------
# [NEW] Final DoH Test
# -------------------------
test_doh_endpoint() {
    log "Testing DoH endpoint..."
    sleep 3

    local test_query=$(curl -s 'https://cloudflare-dns.com/dns-query?dns=q80BAAABAAAAAAAABmdvb2dsZQJjb20AAAEAAQ' -H 'accept: application/dns-message' --insecure)

    local response=$(curl -s --insecure "https://$DOMAIN/dns-query?dns=q80BAAABAAAAAAAABmdvb2dsZQJjb20AAAEAAQ" -H 'accept: application/dns-message')

    if [[ -z "$response" ]]; then
        error_exit "DoH endpoint returned empty response!"
    fi

    log "DoH test successful! Endpoint is live at https://$DOMAIN/dns-query"
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
    setup_nginx_ssl
    configure_firewall
    test_doh_endpoint

    log "============================================"
    log " DNS + DoH Server Fully Installed!"
    log " • Plain DNS: 127.0.0.1:53"
    log " • DoH URL:   https://$DOMAIN/dns-query"
    log " • Test: curl 'https://$DOMAIN/dns-query?dns=...' -H 'accept: application/dns-message'"
    log "============================================"
}

# Run
main "$@"

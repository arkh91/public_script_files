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
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
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

log "Setting up DNSSEC..."
mkdir -p /var/lib/unbound
chown unbound:unbound /var/lib/unbound
unbound-anchor -a "$ROOT_KEY" -v
chown unbound:unbound "$ROOT_KEY"

log "Starting Unbound..."
unbound-checkconf >/dev/null || error_exit "Unbound config failed"
systemctl restart unbound
systemctl enable unbound
sleep 2

# -------------------------
# DOH PROXY (DOHNUT)
# -------------------------
log "Installing Dohnut (DoH proxy)..."
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

# -------------------------
# NGINX + LET'S ENCRYPT
# -------------------------
log "Setting up Nginx + SSL..."

rm -f /etc/nginx/sites-enabled/default

# Temp config for certbot
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

log "Getting SSL certificate (this may take 30s)..."
certbot --nginx -d "$DOMAIN" -m "$EMAIL" --agree-tos --non-interactive --redirect || \
    error_exit "Certbot failed. Check domain DNS and port 80."

rm -f /etc/nginx/sites-enabled/temp
rm -f /etc/nginx/sites-available/temp

# Final DoH config
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
        proxy_buffering off;
    }

    location / {
        return 200 "DoH: https://$DOMAIN/dns-query";
        add_header Content-Type text/plain;
    }
}
EOF

ln -sf /etc/nginx/sites-available/doh /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx || error_exit "Nginx failed"

# -------------------------
# FIREWALL
# -------------------------
log "Opening firewall..."
ufw allow 22/tcp
ufw allow 53
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# -------------------------
# TEST DOH
# -------------------------
log "Testing DoH endpoint..."
sleep 5
response=$(curl -s --insecure "https://$DOMAIN/dns-query?name=example.com&type=A" -H 'accept: application/dns-json')
if echo "$response" | grep -q '"Status":0'; then
    log "DOH IS LIVE: https://$DOMAIN/dns-query"
else
    error_exit "DoH test failed: $response"
fi

# -------------------------
# DONE
# -------------------------
log "============================================"
log " SUCCESS! DNS + DoH Server is READY"
log " • Local DNS: 127.0.0.1:53"
log " • DoH URL:   https://$DOMAIN/dns-query"
log " • Test: curl 'https://$DOMAIN/dns-query?name=google.com' -H 'accept: application/dns-json'"
log "============================================"

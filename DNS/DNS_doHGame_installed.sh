#!/bin/bash
# DNS_doHGame_installed.sh
# Full installer for Unbound Game DNS / DoH

set -euo pipefail
IFS=$'\n\t'

echo "=== DNS over HTTPS / Game DNS Installer ==="

# Defaults
DEFAULT_DOMAIN="example.com"
DEFAULT_EMAIL="admin@example.com"
CONFIG_DIR="/etc/unbound/unbound.conf.d"
ROOT_KEY="/var/lib/unbound/root.key"

# Prompt user for domain and email
read -rp "Enter the domain to use [$DEFAULT_DOMAIN]: " DOMAIN_INPUT
DOMAIN="${DOMAIN_INPUT:-$DEFAULT_DOMAIN}"

read -rp "Enter your email for notifications [$DEFAULT_EMAIL]: " EMAIL_INPUT
EMAIL="${EMAIL_INPUT:-$DEFAULT_EMAIL}"

echo "Using domain: $DOMAIN"
echo "Using email: $EMAIL"

# Function to check and install required packages
install_if_missing() {
    local pkg="$1"
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
        echo "$pkg not found. Installing..."
        apt update -y
        apt install -y "$pkg"
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            echo "Error: failed to install $pkg"
            exit 1
        fi
    else
        echo "$pkg is already installed."
    fi
}

# Ensure required packages
for pkg in unbound dnsutils curl; do
    install_if_missing "$pkg"
done

# Create Unbound config directory if missing
mkdir -p "$CONFIG_DIR"

GAMEDNS_CONF="$CONFIG_DIR/gamedns.conf"

# Write Unbound config
cat > "$GAMEDNS_CONF" <<EOF
# Game DNS / DoH configuration for $DOMAIN
server:
  verbosity: 1
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

stub-zone:
  name: "$DOMAIN"
  forward-addr: 1.1.1.1
  forward-addr: 1.0.0.1
EOF

echo "Unbound configuration written to $GAMEDNS_CONF"

# Ensure root key exists
echo "Updating DNSSEC root trust anchor..."
if ! unbound-anchor -a "$ROOT_KEY"; then
    echo "Error: failed to generate/update $ROOT_KEY"
    exit 1
fi

# Validate configuration
echo "Validating Unbound configuration..."
if ! unbound-checkconf >/dev/null 2>&1; then
    echo "Error: Unbound configuration failed validation!"
    exit 1
fi

# Restart Unbound
echo "Restarting Unbound..."
if ! systemctl restart unbound; then
    echo "Error: failed to restart Unbound"
    exit 1
fi

# Test DNS resolution
echo "Testing DNS resolution for $DOMAIN..."
dig_output=$(dig @"127.0.0.1" "$DOMAIN" +dnssec +short || true)
if [[ -z "$dig_output" ]]; then
    echo "Warning: no A records returned for $DOMAIN"
else
    echo "Success: DNS resolved for $DOMAIN:"
    echo "$dig_output"
fi

echo "=== Installation completed successfully ==="




# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/DNS/DNS_doHGame_installed.sh)

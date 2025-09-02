#!/bin/bash
# DNS_doHGame_installed.sh
# Complete installer for Unbound Game DNS / DoH setup with full error checking

set -euo pipefail
IFS=$'\n\t'

echo "=== DNS over HTTPS / Game DNS Installer ==="

# Default values
DEFAULT_DOMAIN="example.com"
DEFAULT_EMAIL="admin@example.com"
DEFAULT_CONFIG_DIR="/etc/unbound/unbound.conf.d"
DEFAULT_ROOT_KEY="/var/lib/unbound/root.key"

# Prompt for domain
read -rp "Enter the domain to use [$DEFAULT_DOMAIN]: " DOMAIN_INPUT
DOMAIN="${DOMAIN_INPUT:-$DEFAULT_DOMAIN}"

# Prompt for email
read -rp "Enter your email for notifications [$DEFAULT_EMAIL]: " EMAIL_INPUT
EMAIL="${EMAIL_INPUT:-$DEFAULT_EMAIL}"

echo "Using domain: $DOMAIN"
echo "Using email: $EMAIL"

# Check if unbound is installed
if ! command -v unbound >/dev/null 2>&1; then
    echo "Error: unbound is not installed. Install with: sudo apt install unbound"
    exit 1
fi

# Create Unbound config directory if it does not exist
mkdir -p "$DEFAULT_CONFIG_DIR"

GAMEDNS_CONF="$DEFAULT_CONFIG_DIR/gamedns.conf"

# Write full Unbound config
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

# DNSSEC trust anchor
auto-trust-anchor-file: "$DEFAULT_ROOT_KEY"

# Domain-specific stub (example)
stub-zone:
  name: "$DOMAIN"
  forward-addr: 1.1.1.1        # Optional upstream DNS
  forward-addr: 1.0.0.1
EOF

echo "Unbound config written to $GAMEDNS_CONF"

# Ensure root key exists
echo "Updating DNSSEC root trust anchor..."
if ! unbound-anchor -a "$DEFAULT_ROOT_KEY"; then
    echo "Error: failed to generate/update $DEFAULT_ROOT_KEY"
    exit 1
fi

# Validate config
echo "Validating Unbound configuration..."
if ! unbound-checkconf >/dev/null 2>&1; then
    echo "Error: Unbound configuration failed validation!"
    exit 1
fi

# Restart Unbound
echo "Restarting Unbound service..."
if ! systemctl restart unbound; then
    echo "Error: failed to restart Unbound"
    exit 1
fi

# Test DNS resolution
echo "Testing DNS resolution for $DOMAIN..."
if ! dig_output=$(dig @"127.0.0.1" "$DOMAIN" +dnssec +short); then
    echo "Error: dig failed"
    exit 1
fi

if [[ -z "$dig_output" ]]; then
    echo "Warning: no A records returned for $DOMAIN"
else
    echo "Success: DNS resolved for $DOMAIN:"
    echo "$dig_output"
fi

echo "=== DNS over HTTPS / Game DNS installation completed successfully ==="



# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/DNS/DNS_doHGame_installed.sh)

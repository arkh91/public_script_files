#!/bin/bash
set -euo pipefail

UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
UNBOUND_CONF_FILE="$UNBOUND_CONF_DIR/gamedns.conf"
ROOT_KEY="/var/lib/unbound/root.key"

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
      echo "Run as root (sudo)."
      exit 1
fi
}

# -------------------------
# Install dependencies
# -------------------------
install_dependencies() {
    log "Installing dependencies..."
    apt-get update -qq
    
    # Install essential packages including net-tools for netstat
    apt-get install -y \
        unbound \
        dnsutils \
        curl \
        wget \
        unzip \
        ufw \
        jq \
        unbound-anchor \
        ca-certificates \
        gnupg \
        lsb-release \
        nginx \
        certbot \
        python3-certbot-nginx \
        net-tools \
        || error_exit "Failed to install required packages"


    # Node.js 18 LTS
    if ! command -v node >/dev/null 2>&1; then
        log "Installing Node.js 18..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
        apt-get install -y nodejs build-essential || error_exit "Failed installing Node.js"
    fi
}

# -------------------------
# Ask for domain/email
# -------------------------
get_domain_email() {
    read -rp "Enter your domain name: " DOMAIN
    read -rp "Enter your email address: " EMAIL

    if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
        error_exit "Domain and email cannot be empty."
    fi
}
# Function to set default hostname in /etc/hosts
set_default_hostname() {
    local default_name="Default"
    if ! grep -q "127.0.0.1\s\+$default_name" /etc/hosts; then
        echo "127.0.0.1   $default_name" | sudo tee -a /etc/hosts > /dev/null
        echo "Default hostname added to /etc/hosts"
    else
        echo "Default hostname already exists in /etc/hosts"
    fi
}
# -------------------------
# Configure Unbound
# -------------------------
configure_unbound() {
    log "Writing Unbound configuration to $UNBOUND_CONF_FILE"
    mkdir -p "$UNBOUND_CONF_DIR"

    # Prevent duplicate trust anchor declarations
    if [ -f /etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf ]; then
        rm -f /etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf
        log "Removed default root-auto-trust-anchor-file.conf to avoid duplicate trust anchors"
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
    log "Unbound config saved to $UNBOUND_CONF_FILE"
}


# -------------------------
# Configure Public Unbound
# -------------------------
configure_public_unbound() {
    log "[+] Configuring Unbound for public access on 0.0.0.0:53"

    # Create config directory
    mkdir -p "$UNBOUND_CONF_DIR"

    # Stop Unbound first to ensure clean restart
    systemctl stop unbound 2>/dev/null || true

    # Remove any conflicting default configs
    if [ -f "/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf" ]; then
        rm -f "/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf"
        log "[+] Removed conflicting trust anchor config"
    fi

    # Backup existing config
    if [ -f "$UNBOUND_CONF_FILE" ]; then
        backup_file="${UNBOUND_CONF_FILE}.bak.$(date +%s)"
        cp "$UNBOUND_CONF_FILE" "$backup_file"
        log "[+] Backup created: $backup_file"
    fi

    # Ensure root.key exists with proper permissions
    if [ ! -f "$ROOT_KEY" ]; then
        log "[+] Generating root.key..."
        mkdir -p /var/lib/unbound
        unbound-anchor -a "$ROOT_KEY" || {
            log "[!] Failed to generate root.key, creating empty file..."
            touch "$ROOT_KEY"
        }
        chown unbound:unbound "$ROOT_KEY"
        chmod 644 "$ROOT_KEY"
    fi

    # Write comprehensive Unbound configuration
    log "[+] Writing Unbound configuration..."
    cat > "$UNBOUND_CONF_FILE" <<EOF
server:
    # Network settings
    verbosity: 1
    interface: 0.0.0.0
    interface: 127.0.0.1
    port: 53
    access-control: 0.0.0.0/0 allow
    access-control: 127.0.0.0/8 allow
    
    # Protocol settings
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    tcp-upstream: yes
    
    # Performance settings
    num-threads: 2
    msg-cache-size: 128m
    rrset-cache-size: 256m
    outgoing-range: 4096
    incoming-num-tcp: 100
    outgoing-num-tcp: 100
    
    # Cache settings
    cache-min-ttl: 60
    cache-max-ttl: 86400
    prefetch: yes
    prefetch-key: yes
    
    # Security settings
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    use-caps-for-id: yes
    
    # DNSSEC
    auto-trust-anchor-file: "$ROOT_KEY"
    trust-anchor-signaling: yes
    
    # Resource limits
    outgoing-port-permit: 1024-65535
    outgoing-port-avoid: 0-1023
    
    # Additional hardening
    unwanted-reply-threshold: 10000000
    private-address: 10.0.0.0/8
    private-address: 172.16.0.0/12
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: fd00::/8
    private-address: fe80::/10

# Forwarders for better performance (optional)
forward-zone:
    name: "."
    forward-addr: 8.8.8.8
    forward-addr: 8.8.4.4
    forward-addr: 1.1.1.1
    forward-addr: 1.0.0.1
EOF

    # Set proper permissions
    chown unbound:unbound "$UNBOUND_CONF_FILE"
    chmod 644 "$UNBOUND_CONF_FILE"

    # Validate configuration
    log "[+] Validating Unbound configuration..."
    if ! unbound-checkconf; then
        log "[!] Configuration validation failed!"
        log "[!] Checking specific config file..."
        unbound-checkconf "$UNBOUND_CONF_FILE"
        return 1
    fi

    # Reload systemd and restart Unbound
    log "[+] Starting Unbound service..."
    systemctl daemon-reload
    systemctl enable unbound
    systemctl restart unbound

    # Wait a moment for service to start
    sleep 3

    # Verify service is running
    if systemctl is-active --quiet unbound; then
        log "[✓] Unbound is running successfully"
    else
        log "[!] Unbound failed to start"
        systemctl status unbound --no-pager -l
        return 1
    fi

    # Verify listening ports
    log "[+] Checking listening ports..."
    if netstat -tulpn | grep -E ":53.*unbound" > /dev/null; then
        log "[✓] Unbound is listening on port 53"
        netstat -tulpn | grep :53
    else
        log "[!] Unbound is not listening on port 53"
        return 1
    fi

    # Test internal resolution
    log "[+] Testing internal DNS resolution..."
    if dig @127.0.0.1 google.com +short +time=3 +tries=2 > /dev/null 2>&1; then
        log "[✓] Internal DNS resolution working"
    else
        log "[!] Internal DNS resolution failed"
        return 1
    fi

    # Get external IP for testing
    EXTERNAL_IP=$(hostname -I | awk '{print $1}')
    log "[+] Testing external DNS resolution on $EXTERNAL_IP..."
    
    if dig @"$EXTERNAL_IP" google.com +short +time=3 +tries=2 > /dev/null 2>&1; then
        log "[✓] External DNS resolution working"
    else
        log "[!] External DNS resolution test failed (this might be expected from localhost)"
    fi

    log "[✓] Unbound configuration completed successfully"
    log "[+] Unbound is listening on: 0.0.0.0:53 (external) and 127.0.0.1:53 (internal)"
}


# -------------------------
# Setup DNSSEC trust anchor
# -------------------------
setup_dnssec() {
    log "Updating DNSSEC root trust anchor..."
    mkdir -p /var/lib/unbound
    chown unbound:unbound /var/lib/unbound
    chmod 755 /var/lib/unbound
    unbound-anchor -a "$ROOT_KEY" -v || error_exit "Failed to update DNSSEC root key"
}

# -------------------------
# Validate and restart Unbound
# -------------------------
validate_and_restart() {
    log "Validating Unbound configuration..."
    if ! unbound-checkconf; then
        error_exit "Unbound configuration failed validation!"
    fi

    log "Restarting Unbound service..."
    systemctl restart unbound || error_exit "Failed to restart Unbound"
    systemctl enable unbound
}

# -------------------------
# Main
# -------------------------
main() {
    run_as_root
    install_dependencies
    get_domain_email
    set_default_hostname
    #configure_unbound
    configure_public_unbound   # always sets Unbound to public 0.0.0.0:53
    setup_dnssec
    validate_and_restart
    log "Installation complete. Unbound is running with DNSSEC enabled."
}

main "$@"





# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/DNS/DNS_doHGame_installed.sh)

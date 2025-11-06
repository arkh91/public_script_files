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
    apt-get install -y unbound dnsutils curl wget unzip ufw jq unbound-anchor \
        ca-certificates gnupg lsb-release nginx certbot python3-certbot-nginx || \
        error_exit "Failed to install required packages"


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
    log "[+] Configuring Unbound as public DNS server"

    UNBOUND_CONF_DIR="/etc/unbound/unbound.conf.d"
    UNBOUND_CONF_FILE="$UNBOUND_CONF_DIR/gamedns.conf"
    ROOT_KEY="/var/lib/unbound/root.key"

    mkdir -p "$UNBOUND_CONF_DIR"

    # Remove default root trust anchor if exists
    if [ -f /etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf ]; then
        rm -f /etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf
        log "[+] Removed default root-auto-trust-anchor-file.conf to avoid duplicate trust anchors"
    fi

    # Download root.key if missing
    if [ ! -f "$ROOT_KEY" ]; then
        log "[+] root.key not found, downloading..."
        sudo unbound-anchor -a "$ROOT_KEY"
        sudo chown unbound:unbound "$ROOT_KEY"
        sudo chmod 644 "$ROOT_KEY"
        log "[+] root.key downloaded and permissions set"
    fi

    # Backup existing config
    if [ -f "$UNBOUND_CONF_FILE" ]; then
        cp "$UNBOUND_CONF_FILE" "$UNBOUND_CONF_FILE.bak.$(date +%s)"
        log "[+] Backup saved: $UNBOUND_CONF_FILE.bak"
    fi

    # Write public Unbound configuration
    cat > "$UNBOUND_CONF_FILE" <<EOF
server:
    verbosity: 1
    interface: 0.0.0.0
    port: 53
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    access-control: 0.0.0.0/0 allow
    prefetch: yes
    prefetch-key: yes
    cache-min-ttl: 60
    cache-max-ttl: 86400
    rrset-cache-size: 256m
    msg-cache-size: 128m
    so-reuseport: yes
    hide-identity: yes
    hide-version: yes
    harden-dnssec-stripped: yes
    auto-trust-anchor-file: "$ROOT_KEY"
EOF

    # Set correct permissions
    chown -R unbound:unbound /etc/unbound
    chmod 644 "$UNBOUND_CONF_FILE"

    # Test configuration
    if ! unbound-checkconf "$UNBOUND_CONF_FILE"; then
        log "[!] Error: Invalid Unbound config!"
        return 1
    fi

    log "[+] Public Unbound configuration written successfully"
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

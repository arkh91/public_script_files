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
    log "Starting public Unbound configuration..."

    mkdir -p "$UNBOUND_CONF_DIR"

    # Remove default trust anchor file to prevent duplicates
    DEFAULT_ANCHOR="/etc/unbound/unbound.conf.d/root-auto-trust-anchor-file.conf"
    if [ -f "$DEFAULT_ANCHOR" ]; then
        rm -f "$DEFAULT_ANCHOR"
        log "Removed default root-auto-trust-anchor-file.conf to avoid duplicate trust anchors"
    fi

    # Ensure root.key exists and is valid using unbound-anchor
    ROOT_KEY_FILE="/etc/unbound/root.key"
    if [ ! -f "$ROOT_KEY_FILE" ]; then
        log "root.key not found, generating with unbound-anchor..."
        sudo unbound-anchor -a "$ROOT_KEY_FILE"
        sudo chown unbound:unbound "$ROOT_KEY_FILE"
        sudo chmod 644 "$ROOT_KEY_FILE"
        log "root.key generated and permissions set"
    fi

    # Backup existing config if it exists
    if [ -f "$UNBOUND_CONF_FILE" ]; then
        BACKUP_FILE="$UNBOUND_CONF_FILE.bak.$(date +%s)"
        cp "$UNBOUND_CONF_FILE" "$BACKUP_FILE"
        log "Backup saved: $BACKUP_FILE"
    else
        BACKUP_FILE=""
        log "No existing config found, skipping backup"
    fi

    # Write new public Unbound configuration
    cat > "$UNBOUND_CONF_FILE" <<EOF
server:
    verbosity: 1
    num-threads: 2
    interface: 0.0.0.0
    port: 53
    access-control: 0.0.0.0/0 allow
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    prefetch: yes
    prefetch-key: yes
    cache-min-ttl: 300
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
    auto-trust-anchor-file: "$ROOT_KEY_FILE"
EOF

    # Validate configuration and restart
    if sudo unbound-checkconf; then
        log "Configuration valid, restarting Unbound..."
        sudo systemctl restart unbound
        sudo ss -tunlp | grep 53
        log "Public Unbound is now running on 0.0.0.0:53"
    else
        log "Error: Invalid Unbound configuration!"
        if [ -n "$BACKUP_FILE" ] && [ -f "$BACKUP_FILE" ]; then
            log "Restoring backup..."
            cp "$BACKUP_FILE" "$UNBOUND_CONF_FILE"
            sudo systemctl restart unbound
        else
            log "No backup available to restore. Check $UNBOUND_CONF_FILE manually."
        fi
    fi
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

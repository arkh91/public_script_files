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

# Root 
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
    apt-get install -y unbound dnsutils || error_exit "Failed to install required packages"
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

# -------------------------
# Configure Unbound
# -------------------------
configure_unbound() {
    log "Writing Unbound configuration to $UNBOUND_CONF_FILE"
    mkdir -p "$UNBOUND_CONF_DIR"

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
}

# -------------------------
# Setup DNSSEC trust anchor
# -------------------------
setup_dnssec() {
    log "Updating DNSSEC root trust anchor..."
    rm -f "$ROOT_KEY"
    unbound-anchor -a "$ROOT_KEY" || error_exit "Failed to update DNSSEC root key"
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
    configure_unbound
    setup_dnssec
    validate_and_restart
    log "Installation complete. Unbound is running with DNSSEC enabled."
}

main "$@"





# bash <(curl -Ls https://raw.githubusercontent.com/arkh91/public_script_files/refs/heads/main/DNS/DNS_doHGame_installed.sh)

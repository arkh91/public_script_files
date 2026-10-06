#!/bin/bash
# Gaming DNS benchmark: your server vs Cloudflare vs Google.
# Edit with:  vi Test_DNS_fixed.sh
#
# Usage:
#   ./Test_DNS_fixed.sh <server-ip> [port]
#   DNS_SERVER=203.0.113.5 DNS_PORT=5300 ./Test_DNS_fixed.sh
set -uo pipefail

YOUR_DNS="${1:-${DNS_SERVER:-}}"
PORT="${2:-${DNS_PORT:-5300}}"

DOMAINS=(
    activision.com callofduty.com codmobile.com steampowered.com xbox.com
    playstation.com epicgames.com roblox.com minecraft.net discord.com twitch.tv
    netflix.com youtube.com disneyplus.com hulu.com spotify.com amazon.com primevideo.com
)

your_cold=(); your_warm=(); cf=(); goog=()

# Usage: valid_ip <string>   -> returns 0 for a valid IPv4 address
valid_ip() {
    local o
    [[ "$1" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
    for o in ${1//./ }; do (( 10#$o <= 255 )) || return 1; done
}

# Usage: qtime <server> <port> <domain>   -> prints query time in ms (empty on failure)
qtime() { dig @"$1" -p "$2" "$3" +time=2 +tries=1 +stats 2>/dev/null | awk '/Query time/{print $4}'; }

# Usage: avg <numbers...>   -> prints the average, ignoring empty/failed values
avg() {
    printf '%s\n' "$@" | awk 'NF && $1 ~ /^[0-9]+$/ {s+=$1; n++} END {if (n) printf "%.1f", s/n; else print "n/a"}'
}

# Usage: main "$@"   -> validates input, benchmarks each domain, prints averages
main() {
    if [[ -z "$YOUR_DNS" && -t 0 ]]; then
        read -rp "DNS server IP: " YOUR_DNS
        read -rp "Port [$PORT]: " p; PORT="${p:-$PORT}"
    fi
    valid_ip "$YOUR_DNS" || { echo "Usage: $0 <server-ip> [port]"; exit 2; }
    [[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )) || { echo "Invalid port: $PORT"; exit 2; }

    echo "=== Gaming DNS benchmark: $YOUR_DNS:$PORT ==="
    printf '%-22s %10s %10s %10s %10s\n' Domain "Yours cold" "Yours warm" Cloudflare Google

    local d a b c e
    for d in "${DOMAINS[@]}"; do
        a=$(qtime "$YOUR_DNS" "$PORT" "$d")     # first query (may be uncached)
        b=$(qtime "$YOUR_DNS" "$PORT" "$d")     # second query (cached)
        c=$(qtime 1.1.1.1 53 "$d")
        e=$(qtime 8.8.8.8 53 "$d")
        your_cold+=("$a"); your_warm+=("$b"); cf+=("$c"); goog+=("$e")
        printf '%-22s %10s %10s %10s %10s\n' "$d" "${a:-fail}" "${b:-fail}" "${c:-fail}" "${e:-fail}"
    done

    echo
    echo "=== Averages (ms; failed queries excluded) ==="
    echo "Your DNS  cold: $(avg "${your_cold[@]}")   warm: $(avg "${your_warm[@]}")"
    echo "Cloudflare (1.1.1.1): $(avg "${cf[@]}")"
    echo "Google (8.8.8.8):     $(avg "${goog[@]}")"

    local fails=0 x
    for x in "${your_cold[@]}"; do [[ -z "$x" ]] && fails=$((fails + 1)); done
    (( fails > 0 )) && echo "WARNING: $fails queries to your server failed - check port/firewall."
    exit 0
}

main

#!/bin/bash
# DNS security + status check (replaces DNS_Security_Status_Check.sh and
# DNS_Enhanced_Security_Status_Check.sh).  Edit with:  vi DNS_Security_Check_fixed.sh
#
# Usage:
#   ./DNS_Security_Check_fixed.sh <server-ip> [port[,port...]]     e.g.  ... 127.0.0.1 53,5300
#   DNS_SERVER=203.0.113.5 DNS_PORT=53,5300 ./DNS_Security_Check_fixed.sh
#   (no arguments and a terminal attached -> it prompts)
#
# Weekly cron example (non-interactive, exit code 1 on any failure):
#   0 4 * * 1  /root/DNS_Security_Check_fixed.sh 203.0.113.5 53,5300 >> /var/log/dns_check.log 2>&1
set -uo pipefail

DNS="${1:-${DNS_SERVER:-}}"
PORTS="${2:-${DNS_PORT:-53}}"
PORT=""
FAILS=0
WARNS=0

# Usage: pass "message"   -> prints a green OK line
pass() { echo "  [OK]   $1"; }
# Usage: fail "message"   -> prints a FAIL line and counts it
fail() { echo "  [FAIL] $1"; FAILS=$((FAILS + 1)); }
# Usage: warn "message"   -> prints a WARN line and counts it
warn() { echo "  [WARN] $1"; WARNS=$((WARNS + 1)); }

# Usage: valid_ip <string>   -> returns 0 if it is a valid IPv4 address
valid_ip() {
    local ip="$1" o
    [[ "$ip" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]] || return 1
    for o in ${ip//./ }; do (( 10#$o <= 255 )) || return 1; done
}

# Usage: q <dig args...>   -> dig against the target server/port with short timeouts
q() { dig @"$DNS" -p "$PORT" +time=2 +tries=1 "$@" 2>/dev/null; }

# Usage: test_reachable   -> server answers a normal query on the given port
test_reachable() {
    echo "1. Reachability on port $PORT (UDP and TCP)"
    [[ -n "$(q google.com +short | head -1)" ]] && pass "UDP answers" || fail "No UDP answer - wrong port, firewall or service down"
    [[ -n "$(q google.com +short +tcp | head -1)" ]] && pass "TCP answers" || fail "No TCP answer (needed for large replies / DNSSEC)"
}

# Usage: test_version_hidden   -> version.bind / id.server must not leak software info
test_version_hidden() {
    echo "2. Version / identity hiding"
    local v i
    v="$(q version.bind CHAOS TXT +short)"
    i="$(q id.server CHAOS TXT +short)"
    if [[ -z "$v" && -z "$i" ]]; then pass "version.bind and id.server not exposed"
    else fail "Server leaks: ${v} ${i}"; fi
}

# Usage: test_domains   -> resolves a normal domain and the game domains
test_domains() {
    echo "3. Resolution of normal and gaming domains"
    local d r
    for d in google.com callofduty.com steampowered.com xbox.com; do
        r="$(q "$d" +short | head -1)"
        [[ -n "$r" ]] && pass "$d -> $r" || fail "$d did not resolve"
    done
}

# Usage: test_dnssec   -> valid zone must return 'ad', broken-signature zone must SERVFAIL
test_dnssec() {
    echo "4. DNSSEC validation"
    q cloudflare.com +dnssec | grep -q "flags:.* ad" && pass "AD flag set for signed domain" || fail "No AD flag - validation not working"
    q dnssec-failed.org | grep -q SERVFAIL && pass "Bogus DNSSEC domain rejected" || fail "dnssec-failed.org did not SERVFAIL"
}

# Usage: test_ratelimit   -> fires 400 parallel queries; warns if none are limited
# (ip-ratelimit makes Unbound drop the excess, so fewer than 400 answers = protection active)
test_ratelimit() {
    echo "5. Abuse protection (burst of 400 parallel queries)"
    local answered
    answered=$(seq 1 400 | xargs -P 100 -I{} \
        dig @"$DNS" -p "$PORT" +time=2 +tries=1 +noall +comments "rl{}x$RANDOM.google.com" 2>/dev/null \
        | grep -c "status: NXDOMAIN")
    if (( answered < 400 )); then pass "Burst was limited ($answered/400 answered)"
    else warn "All 400 burst queries answered - ip-ratelimit may be off or set very high"; fi
}

# Usage: test_open_resolver   -> tells you whether ANY internet client can use this server
test_open_resolver() {
    echo "6. Open-resolver exposure"
    local status
    status="$(q example.org | grep -o 'status: [A-Z]*' | head -1)"
    warn "Queries from THIS machine return '${status:-no answer}'. If this host is not in ALLOWED_CLIENTS and still answers, the resolver is open to the internet."
}

# Usage: test_performance   -> uncached (random NXDOMAIN label) and cached latency in ms
test_performance() {
    echo "7. Latency"
    local cold warm
    cold="$(q "perf$RANDOM$RANDOM.google.com" | awk '/Query time/{print $4}')"
    warm="$(q google.com >/dev/null; q google.com | awk '/Query time/{print $4}')"
    if [[ -z "$cold" || -z "$warm" ]]; then fail "No timing data"; return; fi
    echo "         uncached: ${cold} ms   cached: ${warm} ms"
    if   (( cold < 100 )); then pass "Uncached latency good"
    elif (( cold < 250 )); then warn "Uncached latency acceptable"
    else fail "Uncached latency slow"; fi
}

# Usage: main "$@"   -> validates input, runs all tests, prints a truthful summary
main() {
    if [[ -z "$DNS" && -t 0 ]]; then
        read -rp "DNS server IP: " DNS
        read -rp "Port(s), comma-separated [$PORTS]: " p; PORTS="${p:-$PORTS}"
    fi
    valid_ip "$DNS" || { echo "Usage: $0 <server-ip> [port[,port...]]"; exit 2; }
    PORTS="${PORTS//,/ }"
    for PORT in $PORTS; do
        [[ "$PORT" =~ ^[0-9]+$ ]] && (( PORT >= 1 && PORT <= 65535 )) || { echo "Invalid port: $PORT"; exit 2; }
    done
    command -v dig >/dev/null || { echo "dig not found (apt install dnsutils)"; exit 2; }

    echo "=== DNS check: $DNS  ports: $PORTS  ($(date '+%F %T')) ==="
    for PORT in $PORTS; do
        echo
        echo "################ PORT $PORT ################"
        test_reachable; test_version_hidden; test_domains; test_dnssec
        test_ratelimit; test_open_resolver; test_performance
    done
    echo

    echo "=== Result: $FAILS failure(s), $WARNS warning(s) ==="
    if (( FAILS == 0 )); then echo "STATUS: PASS"; else echo "STATUS: FAIL"; exit 1; fi
}

main

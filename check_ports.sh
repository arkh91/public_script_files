#!/usr/bin/env bash
#
# check_ports.sh - Check whether any application is listening on given TCP ports.
#
# Usage:
#   ./check_ports.sh                 # check the default Cloudflare HTTPS ports
#   ./check_ports.sh 80 22 3306      # check any ports you specify
#   ./check_ports.sh -u 53 123       # check UDP instead of TCP
#   sudo ./check_ports.sh            # run as root to see process names owned by other users
#
# Default ports: 443 2053 2083 2087 2096 8443

DEFAULT_PORTS=(443 2053 2083 2087 2096 8443)
PROTO="tcp"

# ---------------------------------------------------------------------------
# usage
#   Prints help text.
#   Usage: usage
# ---------------------------------------------------------------------------
usage() {
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
}

# ---------------------------------------------------------------------------
# find_listeners
#   Prints raw listener info for one port using ss, falling back to lsof, then netstat.
#   Usage: find_listeners <port>
#   Output: one line per listening socket (empty if nothing is listening)
# ---------------------------------------------------------------------------
find_listeners() {
    local port="$1"
    local ss_flag="-ltnp"
    local lsof_proto="TCP"
    local lsof_state="-sTCP:LISTEN"
    if [[ "$PROTO" == "udp" ]]; then
        ss_flag="-lunp"
        lsof_proto="UDP"
        lsof_state=""
    fi

    if command -v ss >/dev/null 2>&1; then
        ss -H $ss_flag "sport = :${port}" 2>/dev/null
    elif command -v lsof >/dev/null 2>&1; then
        lsof -nP -i"${lsof_proto}:${port}" $lsof_state 2>/dev/null | tail -n +2
    elif command -v netstat >/dev/null 2>&1; then
        netstat -lnp 2>/dev/null | awk -v p=":${port}" -v pr="$PROTO" '$1 ~ pr && $4 ~ p"$"'
    else
        echo "ERROR: need ss, lsof, or netstat installed" >&2
        return 2
    fi
}

# ---------------------------------------------------------------------------
# check_port
#   Reports whether a port is in use and by which process(es).
#   Usage: check_port <port>
#   Returns: 0 if something is listening, 1 if free, 2 on error
# ---------------------------------------------------------------------------
check_port() {
    local port="$1"

    if ! [[ "$port" =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        echo "Port ${port}: invalid port number" >&2
        return 2
    fi

    local out
    out=$(find_listeners "$port") || return 2

    if [[ -z "$out" ]]; then
        printf "Port %-6s : FREE (nothing listening)\n" "$port"
        return 1
    fi

    printf "Port %-6s : IN USE\n" "$port"
    # ss prints users:(("name",pid=123,fd=6)); extract name and pid
    local procs
    procs=$(echo "$out" | grep -o '"[^"]*",pid=[0-9]*' | sed 's/"\([^"]*\)",pid=\([0-9]*\)/\1 (PID \2)/' | sort -u)

    if [[ -n "$procs" ]]; then
        echo "$procs" | sed 's/^/               -> /'
    elif command -v lsof >/dev/null 2>&1 && [[ "$(echo "$out" | head -1)" =~ ^[A-Za-z] ]]; then
        # lsof fallback output: COMMAND PID USER ...
        echo "$out" | awk '{print "               -> " $1 " (PID " $2 ", user " $3 ")"}' | sort -u
    else
        echo "               -> process unknown (re-run with sudo to see it)"
    fi
    return 0
}

# ---------------------------------------------------------------------------
# main
#   Parses arguments and runs check_port for each requested port.
#   Usage: main [-u] [port ...]
# ---------------------------------------------------------------------------
main() {
    local ports=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -u|--udp)  PROTO="udp" ;;
            *)         ports+=("$1") ;;
        esac
        shift
    done
    (( ${#ports[@]} == 0 )) && ports=("${DEFAULT_PORTS[@]}")

    [[ $EUID -ne 0 ]] && echo "Note: not running as root; some process names may be hidden."
    echo "Checking ${PROTO^^} ports: ${ports[*]}"
    echo "----------------------------------------"

    local p
    for p in "${ports[@]}"; do
        check_port "$p"
    done
}

main "$@"

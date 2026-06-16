#!/usr/bin/env bash
# RDNS - Reverse DNS Scanner
# Author: NeiveZ | github.com/NeiveZ/RDNS


set -euo pipefail

# ── Colors ────────────────────────────────────────────────────────
R="\e[0m"; BOLD="\e[1m"
RD="\e[91m"; GR="\e[92m"; YL="\e[93m"; CY="\e[96m"; DG="\e[90m"

# ── Defaults ──────────────────────────────────────────────────────
TARGET=""        # Single IP or prefix (192.168.1 or 192.168.1.10)
START=""         # Range start (last octet)
END=""           # Range end (last octet)
THREADS=20       # Parallel queries
TIMEOUT=3        # Query timeout in seconds
OUTPUT=""        # Output file
SILENT=false     # Results only

# ================================================================
#  HELP
# ================================================================

usage() {
cat << HELP
${BOLD}Usage:${R}
  $0 -t <target> [options]

${BOLD}Options:${R}
  -t, --target      Single IP or subnet prefix (required)
                    Single:  192.168.1.10
                    Range:   192.168.1  (requires --start and --end)
  -s, --start       Range start — last octet (e.g. 1)
  -e, --end         Range end   — last octet (e.g. 254)
  -T, --timeout     Query timeout in seconds (default: 3)
  -t2, --threads    Parallel queries (default: 20)
  -o, --output      Save results to file
  --silent          Results only — no header or summary
  -h, --help        Show this help

${BOLD}Examples:${R}
  # Single IP
  $0 -t 192.168.1.10

  # Full /24
  $0 -t 192.168.1 -s 1 -e 254

  # Custom range, save results
  $0 -t 37.59.174 -s 224 -e 239 -o results.txt

  # Fast full sweep, silent
  $0 -t 10.0.0 -s 1 -e 254 -t2 50 --silent
HELP
exit 0
}

# ================================================================
#  PTR LOOKUP — with fallback chain: host → dig → nslookup
# ================================================================

ptr_lookup() {
    local ip="$1"
    local result=""

    if command -v host &>/dev/null; then
        result=$(timeout "$TIMEOUT" host -t PTR "$ip" 2>/dev/null \
            | grep -v "not found\|NXDOMAIN\|timed out\|connection refused" \
            | grep "domain name pointer" \
            | awk '{print $NF}' \
            | sed 's/\.$//')
    fi

    if [[ -z "$result" ]] && command -v dig &>/dev/null; then
        result=$(timeout "$TIMEOUT" dig -x "$ip" +short 2>/dev/null \
            | grep -v "^;" \
            | sed 's/\.$//')
    fi

    if [[ -z "$result" ]] && command -v nslookup &>/dev/null; then
        result=$(timeout "$TIMEOUT" nslookup "$ip" 2>/dev/null \
            | grep "name = " \
            | awk '{print $NF}' \
            | sed 's/\.$//')
    fi

    echo "$result"
}

# ================================================================
#  SCAN SINGLE IP
# ================================================================

scan_ip() {
    local ip="$1"
    local hostname
    hostname=$(ptr_lookup "$ip")

    [[ -z "$hostname" ]] && return

    if $SILENT; then
        echo "${ip} -> ${hostname}"
    else
        printf "${BOLD}${GR}[PTR]${R} ${CY}%-18s${R} ${DG}→${R} ${BOLD}%s${R}\n" \
            "$ip" "$hostname"
    fi

    [[ -n "$OUTPUT" ]] && echo "${ip} -> ${hostname}" >> "$OUTPUT"
}

# ================================================================
#  PARALLEL RUNNER
# ================================================================

run_range() {
    local prefix="$1" start="$2" end="$3"
    local -a jobs=()
    local total=$(( end - start + 1 ))
    local count=0

    for octet in $(seq "$start" "$end"); do
        local ip="${prefix}.${octet}"
        scan_ip "$ip" &
        jobs+=($!)
        count=$(( count + 1 ))

        while [[ ${#jobs[@]} -ge $THREADS ]]; do
            local alive=()
            for pid in "${jobs[@]}"; do
                kill -0 "$pid" 2>/dev/null && alive+=("$pid")
            done
            jobs=("${alive[@]}")
            [[ ${#jobs[@]} -ge $THREADS ]] && sleep 0.05
        done
    done

    for pid in "${jobs[@]}"; do wait "$pid" 2>/dev/null || true; done
}

# ================================================================
#  ARGUMENT PARSING
# ================================================================

[[ $# -eq 0 ]] && usage

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--target)   TARGET="$2";  shift 2 ;;
        -s|--start)    START="$2";   shift 2 ;;
        -e|--end)      END="$2";     shift 2 ;;
        -T|--timeout)  TIMEOUT="$2"; shift 2 ;;
        -t2|--threads) THREADS="$2"; shift 2 ;;
        -o|--output)   OUTPUT="$2";  shift 2 ;;
        --silent)      SILENT=true;  shift ;;
        -h|--help)     usage ;;
        *) echo -e "${RD}[!]${R} Unknown option: $1"; usage ;;
    esac
done

# ── Validations ───────────────────────────────────────────────────

[[ -z "$TARGET" ]] && { echo -e "${RD}[!]${R} -t is required"; exit 1; }

# Check at least one lookup tool is available
TOOL=""
for t in host dig nslookup; do
    command -v "$t" &>/dev/null && TOOL="$t" && break
done
[[ -z "$TOOL" ]] && {
    echo -e "${RD}[!]${R} No DNS tool found. Install one: apt install dnsutils"
    exit 1
}

# Determine mode: single IP (3 dots) or range (2 dots)
if echo "$TARGET" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    MODE="single"
elif echo "$TARGET" | grep -qE '^([0-9]{1,3}\.){2}[0-9]{1,3}$'; then
    MODE="range"
    [[ -z "$START" || -z "$END" ]] && {
        echo -e "${RD}[!]${R} Range mode requires --start and --end"
        exit 1
    }
    [[ "$START" -gt "$END" ]] && {
        echo -e "${RD}[!]${R} --start must be less than or equal to --end"
        exit 1
    }
else
    echo -e "${RD}[!]${R} Invalid target: use full IP (192.168.1.10) or prefix (192.168.1)"
    exit 1
fi

# ── Prepare output file ───────────────────────────────────────────

if [[ -n "$OUTPUT" ]]; then
    printf "# RDNS | target: %s | %s\n\n" "$TARGET" "$(date '+%Y-%m-%d %H:%M:%S')" > "$OUTPUT"
fi

# ================================================================
#  RUN
# ================================================================

START_TIME=$(date +%s)

if ! $SILENT; then
    if [[ "$MODE" == "single" ]]; then
        echo -e "${BOLD}${TARGET}${R}  ${DG}tool:${R}${TOOL}  ${DG}mode:${R}single"
    else
        TOTAL=$(( END - START + 1 ))
        echo -e "${BOLD}${TARGET}.${START}-${END}${R}  ${DG}tool:${R}${TOOL}  ${DG}ips:${R}${TOTAL}  ${DG}threads:${R}${THREADS}"
    fi
    echo
fi

if [[ "$MODE" == "single" ]]; then
    scan_ip "$TARGET"
else
    run_range "$TARGET" "$START" "$END"
    wait
fi

END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))

if ! $SILENT; then
    echo
    echo -e "${DG}time:${R} ${ELAPSED}s"
    [[ -n "$OUTPUT" ]] && echo -e "${DG}saved:${R} ${OUTPUT}"
fi

if [[ -n "$OUTPUT" ]]; then
    printf "\n# time: %ss\n" "$ELAPSED" >> "$OUTPUT"
fi

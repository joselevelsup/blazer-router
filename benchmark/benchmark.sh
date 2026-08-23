#!/usr/bin/env bash

# USAGE:
#   ./benchmark.sh <router_a_url> <router_b_url> [reps] [duration] [threads]
#
#   Example:
#     ./benchmark.sh http://localhost:8080 http://localhost:8081 5 20s 4
#
# OPTIONAL ENV VARS (all optional — sensible defaults are used if unset):
#   WRK_CPUS       cores to pin wrk to, e.g. "0,1"      (requires taskset)
#   SERVER_A_PID   pid of router A's process, for pinning to cores 2,3
#   SERVER_B_PID   pid of router B's process, for pinning to cores 2,3
#   SERVER_CPUS    cores to pin the servers to, e.g. "2,3"
#
#   Example with pinning (Linux only):
#     WRK_CPUS="0,1" SERVER_CPUS="2,3" SERVER_A_PID=1234 SERVER_B_PID=5678 \
#       ./benchmark.sh http://localhost:8080 http://localhost:8081
#
# REQUIRES: wrk installed and on PATH. paths.lua in the same directory.
#           taskset (optional, Linux only, for CPU pinning).

set -euo pipefail

ROUTER_A_URL="${1:-}"
ROUTER_B_URL="${2:-}"
REPS="${3:-5}"
DURATION="${4:-20s}"
THREADS="${5:-4}"
CONCURRENCY_LEVELS=(10 50 100 500)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LUA_SCRIPT="$SCRIPT_DIR/paths.lua"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$SCRIPT_DIR/results_${TIMESTAMP}.log"

WRK_CPUS="${WRK_CPUS:-}"
SERVER_CPUS="${SERVER_CPUS:-}"
SERVER_A_PID="${SERVER_A_PID:-}"
SERVER_B_PID="${SERVER_B_PID:-}"

if [[ -z "$ROUTER_A_URL" || -z "$ROUTER_B_URL" ]]; then
  echo "Usage: $0 <router_a_url> <router_b_url> [reps] [duration] [threads]"
  echo "Example: $0 http://localhost:8080 http://localhost:8081 5 20s 4"
  exit 1
fi

if ! command -v wrk >/dev/null 2>&1; then
  echo "Error: wrk is not installed or not on PATH."
  exit 1
fi

if [[ ! -f "$LUA_SCRIPT" ]]; then
  echo "Error: paths.lua not found next to this script ($LUA_SCRIPT)."
  exit 1
fi

HAVE_TASKSET=0
if command -v taskset >/dev/null 2>&1; then
  HAVE_TASKSET=1
fi

# ---- helpers -----------------------------------------------------------

log() {
  echo "$1" | tee -a "$LOG_FILE"
}

# Pin a running PID to given cores, if taskset + pid + cores are all available.
maybe_pin_pid() {
  local pid="$1"
  local cores="$2"
  local label="$3"
  if [[ -n "$pid" && -n "$cores" && "$HAVE_TASKSET" -eq 1 ]]; then
    if taskset -cp "$cores" "$pid" >/dev/null 2>&1; then
      log ">>> Pinned $label (pid $pid) to cores $cores"
    else
      log ">>> WARNING: failed to pin $label (pid $pid) to cores $cores — continuing unpinned"
    fi
  fi
}

# Wraps a wrk invocation with taskset if WRK_CPUS + taskset are available.
wrk_cmd() {
  if [[ -n "$WRK_CPUS" && "$HAVE_TASKSET" -eq 1 ]]; then
    echo "taskset -c $WRK_CPUS wrk"
  else
    echo "wrk"
  fi
}

# Extracts just Requests/sec as a bare number from wrk's raw output.
extract_req_sec() {
  echo "$1" | grep "Requests/sec:" | awk '{print $2}'
}

# Runs one wrk invocation, logs raw output, returns req/sec on stdout.
run_one() {
  local label="$1"
  local url="$2"
  local conns="$3"
  local rep="$4"

  local cmd
  cmd="$(wrk_cmd)"

  local output
  output=$($cmd -t"$THREADS" -c"$conns" -d"$DURATION" --latency -s "$LUA_SCRIPT" "$url" 2>&1)

  {
    echo ""
    echo "[RAW OUTPUT] $label | concurrency=$conns | rep=$rep"
    echo "$output"
  } >> "$LOG_FILE"

  extract_req_sec "$output"
}

# Computes n, mean, median, stdev, min, max, p25, p75 from a space-separated
# list of numbers. Prints them as a single space-separated line.
stats_from_values() {
  local values="$1"
  echo "$values" | tr ' ' '\n' | grep -v '^$' | sort -n | awk '
    { a[NR] = $1; sum += $1 }
    END {
      n = NR
      mean = sum / n
      for (i = 1; i <= n; i++) { d = a[i] - mean; sumsq += d * d }
      stdev = (n > 1) ? sqrt(sumsq / (n - 1)) : 0
      min = a[1]; max = a[n]
      if (n % 2 == 1) { median = a[(n+1)/2] }
      else { median = (a[n/2] + a[n/2 + 1]) / 2 }
      p25_idx = int(0.25 * n); if (p25_idx < 1) p25_idx = 1
      p75_idx = int(0.75 * n); if (p75_idx < 1) p75_idx = 1
      printf "%d %.2f %.2f %.2f %.2f %.2f %.2f %.2f\n", n, mean, median, stdev, min, max, a[p25_idx], a[p75_idx]
    }'
}

# Rough two-sample comparison (Welch-style t-statistic). Not a rigorous
# p-value — treat |t| > 2 as "probably a real difference", anything less
# as "can't distinguish this from noise at this sample size".
compare_groups() {
  local values_a="$1"
  local values_b="$2"
  awk -v a="$values_a" -v b="$values_b" '
    function stats(str, n, mean, var,    i, arr, sum, sumsq, d) {
      n = split(str, arr, " ")
      for (i = 1; i <= n; i++) sum += arr[i]
      mean = sum / n
      for (i = 1; i <= n; i++) { d = arr[i] - mean; sumsq += d * d }
      var = (n > 1) ? sumsq / (n - 1) : 0
      return mean " " var " " n
    }
    BEGIN {
      split(stats(a), sa, " ")
      split(stats(b), sb, " ")
      mean_a = sa[1]; var_a = sa[2]; n_a = sa[3]
      mean_b = sb[1]; var_b = sb[2]; n_b = sb[3]
      se = sqrt(var_a / n_a + var_b / n_b)
      t = (se > 0) ? (mean_a - mean_b) / se : 0
      pct_diff = (mean_b != 0) ? 100 * (mean_a - mean_b) / mean_b : 0
      verdict = (t > 2) ? "A likely faster" : (t < -2) ? "B likely faster" : "no clear difference (within noise)"
      printf "mean_A=%.2f mean_B=%.2f diff=%.2f%% t=%.2f -> %s\n", mean_a, mean_b, pct_diff, t, verdict
    }'
}

# ---- run ----------------------------------------------------------------

declare -A RESULTS   # key: "A_<conns>" or "B_<conns>" -> space-separated req/sec values

log "==================================================================="
log " HTTP Router Benchmark (noise-resistant: interleaved + repeated)"
log " Started:      $(date)"
log " Router A:     $ROUTER_A_URL"
log " Router B:     $ROUTER_B_URL"
log " Reps/combo:   $REPS   Duration/run: $DURATION   Threads: $THREADS"
log " Concurrency levels: ${CONCURRENCY_LEVELS[*]}"
if [[ "$HAVE_TASKSET" -eq 0 ]]; then
  log " NOTE: taskset not found — CPU pinning skipped. For best results on"
  log "       Linux, install it and set WRK_CPUS / SERVER_CPUS env vars."
fi
log "==================================================================="

maybe_pin_pid "$SERVER_A_PID" "$SERVER_CPUS" "Router A"
maybe_pin_pid "$SERVER_B_PID" "$SERVER_CPUS" "Router B"

log ""
log ">>> Warming up both servers (15s each, not recorded)..."
$(wrk_cmd) -t2 -c20 -d15s -s "$LUA_SCRIPT" "$ROUTER_A_URL" > /dev/null 2>&1 || true
$(wrk_cmd) -t2 -c20 -d15s -s "$LUA_SCRIPT" "$ROUTER_B_URL" > /dev/null 2>&1 || true
log ">>> Warmup complete."

for conns in "${CONCURRENCY_LEVELS[@]}"; do
  log ""
  log "=== Concurrency $conns — $REPS interleaved, randomized-order reps ==="
  for ((rep = 1; rep <= REPS; rep++)); do
    # Randomize which router goes first this rep.
    if (( RANDOM % 2 == 0 )); then
      first="A"; second="B"
    else
      first="B"; second="A"
    fi

    for router in "$first" "$second"; do
      if [[ "$router" == "A" ]]; then
        label="Router A (fist)"
        url="$ROUTER_A_URL"
      else
        label="Router B (custom)"
        url="$ROUTER_B_URL"
      fi

      req_sec=$(run_one "$label" "$url" "$conns" "$rep")
      req_sec="${req_sec:-0}"
      key="${router}_${conns}"
      RESULTS["$key"]="${RESULTS[$key]:-} $req_sec"
      log "  rep $rep/$REPS: $label -> ${req_sec} req/sec"
    done
  done
done

# ---- summary table --------------------------------------------------------

log ""
log "==================================================================="
log " SUMMARY (per concurrency level, across $REPS reps)"
log "==================================================================="
printf "%-28s %-6s %-6s %-10s %-10s %-9s %-9s %-9s\n" \
  "Router" "Conns" "N" "Mean" "Median" "Stdev" "Min" "Max" | tee -a "$LOG_FILE"
printf '%.0s-' {1..90} | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

for conns in "${CONCURRENCY_LEVELS[@]}"; do
  for router in A B; do
    label="Router A (fist)"
    [[ "$router" == "B" ]] && label="Router B (custom)"
    key="${router}_${conns}"
    read -r n mean median stdev min max p25 p75 <<< "$(stats_from_values "${RESULTS[$key]}")"
    printf "%-28s %-6s %-6s %-10s %-10s %-9s %-9s %-9s\n" \
      "$label" "$conns" "$n" "$mean" "$median" "$stdev" "$min" "$max" | tee -a "$LOG_FILE"
  done
done

log ""
log "==================================================================="
log " HEAD-TO-HEAD COMPARISON PER CONCURRENCY LEVEL"
log " (rough Welch's-t heuristic: |t| > 2 ~ probably real, else ~ noise)"
log "==================================================================="
for conns in "${CONCURRENCY_LEVELS[@]}"; do
  key_a="A_${conns}"
  key_b="B_${conns}"
  result=$(compare_groups "${RESULTS[$key_a]}" "${RESULTS[$key_b]}")
  log "concurrency=$conns: $result"
done

log ""
log "Full log (including every raw wrk run) saved to: $LOG_FILE"

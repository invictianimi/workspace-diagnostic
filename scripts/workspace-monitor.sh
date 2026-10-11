#!/bin/sh
# workspace-monitor.sh - read-only sampler for Linux and macOS.
# Reads system counters and workspace file metadata. Writes only inside OUT_DIR.
# Usage: sh workspace-monitor.sh WORKSPACE OUT_DIR [DURATION_MIN] [SAMPLE_SEC] [SCAN_SEC]
# Optional environment: TOP_N=10 MAX_LOG_MB=50 EXCLUDE_DIRS="node_modules .venv"
set -u
[ $# -ge 2 ] || { echo "usage: $0 WORKSPACE OUT_DIR [DURATION_MIN] [SAMPLE_SEC] [SCAN_SEC]" >&2; exit 1; }
OS=$(uname -s)
[ "$OS" = Linux ] || [ "$OS" = Darwin ] || { echo "Unsupported OS: $OS" >&2; exit 1; }
WS=$(cd "$1" && pwd -P) || exit 1
OUT=$2
case $OUT in /*) ;; *) OUT="$PWD/$OUT" ;; esac
case "$OUT/" in "$WS"/*) echo "OUT_DIR must be outside the workspace." >&2; exit 1 ;; esac
[ -e "$OUT/system.csv" ] && { echo "OUT_DIR already holds monitor data; choose a new folder." >&2; exit 1; }
mkdir -p "$OUT" || exit 1
OUT=$(cd "$OUT" && pwd -P)
case "$OUT/" in "$WS"/*) echo "OUT_DIR resolves to inside the workspace." >&2; exit 1 ;; esac
DURATION_MIN=${3:-60}; SAMPLE_SEC=${4:-15}; SCAN_SEC=${5:-60}
TOP_N=${TOP_N:-10}; MAX_LOG_MB=${MAX_LOG_MB:-50}; EXCLUDE_DIRS=${EXCLUDE_DIRS:-}

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }
now_ms() {
  if [ "$OS" = Linux ]; then date +%s%3N
  else perl -MTime::HiRes=time -e 'printf "%d\n", time*1000' 2>/dev/null || echo $(( $(date +%s) * 1000 ))
  fi
}

printf '%s\n' 'ts,cpu_pct,mem_used_pct,mem_avail_mb,disk_busy_pct,disk_queue,iowait_pct,load1' > "$OUT/system.csv"
printf '%s\n' 'ts,pid,name,cpu_pct,mem_mb,io_bytes_per_sec' > "$OUT/procs.csv"
printf '%s\n' 'ts,change,path,size_bytes' > "$OUT/changes.csv"
printf '%s\n' 'ts,file_count,total_mb,scan_ms' > "$OUT/scan.csv"
printf '%s\n' 'ts,note' > "$OUT/markers.csv"

if [ "$OS" = Linux ]; then
  mem_total_mb=$(awk '/^MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
else
  mem_total_mb=$(( $(sysctl -n hw.memsize) / 1048576 ))
fi
{
  echo "workspace=$WS"; echo "out_dir=$OUT"; echo "os=$(uname -sr)"
  echo "cpus=$(getconf _NPROCESSORS_ONLN)"; echo "mem_total_mb=$mem_total_mb"
  echo "duration_min=$DURATION_MIN"; echo "sample_sec=$SAMPLE_SEC"; echo "scan_sec=$SCAN_SEC"
  echo "exclude_dirs=$EXCLUDE_DIRS"
  echo "cpu_pct_units=machine-wide in system.csv; per core (100 = one core) in procs.csv"
  echo "start=$(now)"
} > "$OUT/meta.txt"

# Shared awk helper: convert sizes such as 512K, 123M, 1.2G to MiB.
MB_FN='function mb(s,  u, v) { u = tolower(substr(s, length(s))); v = s + 0
  if (u == "k") v /= 1024; else if (u == "g") v *= 1024; else if (u == "t") v *= 1048576
  return v }'

# Linux: second iteration of procps top gives current (not lifetime) CPU figures.
LINUX_TOP_AWK="$MB_FN"'
/^top -/ { blk++; next }
blk < 2 { next }
/^%Cpu\(s\)/ { for (i = 2; i <= NF; i++) { v = $(i-1); sub(/.*,/, "", v)
    if ($i ~ /^id,?$/) id = v; if ($i ~ /^wa,?$/) wa = v }; next }
/^ *[0-9]+ / && c < n { c++; name = $12; gsub(/"/, "\"\"", name)
  printf "%s,%s,\"%s\",%s,%.0f,\n", ts, $1, name, $9, mb($6) >> procs }
END { if (id != "") printf "%.1f %s\n", 100 - id, wa }'

# macOS: second sample of top -l 2 gives current CPU figures.
MAC_TOP_AWK="$MB_FN"'
/^CPU usage/ { cpu = $0 }
/^PID/ { blk++; next }
blk == 2 && NF >= 4 && c < n { c++; m = $3; sub(/[+-]$/, "", m)
  name = $4; for (i = 5; i <= NF; i++) name = name " " $i; gsub(/"/, "\"\"", name)
  printf "%s,%s,\"%s\",%s,%.0f,\n", ts, $1, name, $2, mb(m) >> procs }
END { split(cpu, a, ","); idle = a[3]; gsub(/[^0-9.]/, "", idle); if (idle != "") printf "%.1f\n", 100 - idle }'

sample() {
  ts=$1; cpu=; iow=; mused=; mavail=; load=
  if [ "$OS" = Linux ]; then
    set -- $(top -b -n 2 -d 1 -e m -w 512 2>/dev/null |
      awk -v ts="$ts" -v n="$TOP_N" -v procs="$OUT/procs.csv" "$LINUX_TOP_AWK")
    cpu=${1:-}; iow=${2:-}
    set -- $(awk '/^MemTotal:/ { t = $2 } /^MemAvailable:/ { a = $2 }
      END { if (t) printf "%.1f %d\n", 100 * (1 - a / t), a / 1024 }' /proc/meminfo)
    mused=${1:-}; mavail=${2:-}
    load=$(cut -d' ' -f1 /proc/loadavg)
  else
    cpu=$(top -l 2 -s 1 -n "$TOP_N" -o cpu -stats pid,cpu,mem,command 2>/dev/null |
      awk -v ts="$ts" -v n="$TOP_N" -v procs="$OUT/procs.csv" "$MAC_TOP_AWK")
    mfree=$(memory_pressure 2>/dev/null | awk -F': *' '/free percentage/ { sub(/%/, "", $2); print $2 }')
    [ -n "$mfree" ] && mused=$((100 - mfree))
    load=$(sysctl -n vm.loadavg | awk '{ print $2 }')
  fi
  printf '%s,%s,%s,%s,,,%s,%s\n' "$ts" "$cpu" "$mused" "$mavail" "$iow" "$load" >> "$OUT/system.csv"
}

snapshot() {
  set --
  for d in $EXCLUDE_DIRS; do set -- "$@" -name "$d" -prune -o; done
  if [ "$OS" = Linux ]; then
    find "$WS" "$@" -type f -printf '%P\t%s\t%T@\n' 2>/dev/null
  else
    find "$WS" "$@" -type f -exec stat -f '%N%t%z%t%m' {} + 2>/dev/null |
      awk -v p="$WS/" '{ if (index($0, p) == 1) print substr($0, length(p) + 1); else print }'
  fi
}

scan() {
  ts=$1
  t0=$(now_ms)
  snapshot > "$OUT/.snap.cur"
  t1=$(now_ms)
  awk -F'\t' -v ts="$ts" -v ms="$((t1 - t0))" '{ n++; b += $2 }
    END { printf "%s,%d,%.1f,%s\n", ts, n, b / 1048576, ms }' "$OUT/.snap.cur" >> "$OUT/scan.csv"
  if [ -f "$OUT/.snap.prev" ]; then
    awk -F'\t' -v ts="$ts" '
      function q(s) { gsub(/"/, "\"\"", s); return "\"" s "\"" }
      FILENAME == ARGV[1] { old[$1] = $2 FS $3; next }
      { seen[$1] = 1
        if (!($1 in old)) print ts ",added," q($1) "," $2
        else if (old[$1] != $2 FS $3) print ts ",modified," q($1) "," $2 }
      END { for (k in old) if (!(k in seen)) print ts ",removed," q(k) "," }' \
      "$OUT/.snap.prev" "$OUT/.snap.cur" >> "$OUT/changes.csv"
  fi
  mv "$OUT/.snap.cur" "$OUT/.snap.prev"
}

reason=duration
finish() {
  [ -f "$OUT/.snap.prev" ] && mv "$OUT/.snap.prev" "$OUT/snapshot-end.tsv"
  echo "end=$(now)" >> "$OUT/meta.txt"
  echo "stop_reason=$reason" >> "$OUT/meta.txt"
  echo "Monitor stopped ($reason). Data is in $OUT"
  exit 0
}
trap 'reason=interrupted; finish' INT TERM

scan "$(now)"
end=$(( $(date +%s) + DURATION_MIN * 60 ))
next_scan=$(( $(date +%s) + SCAN_SEC ))
echo "Monitoring $WS for $DURATION_MIN minutes. Stop early: touch \"$OUT/STOP\" or press Ctrl+C."
while [ "$(date +%s)" -lt "$end" ]; do
  [ -f "$OUT/STOP" ] && { reason=stop-file; break; }
  [ "$(du -sk "$OUT" | cut -f1)" -gt $((MAX_LOG_MB * 1024)) ] && { reason=size-cap; break; }
  sample "$(now)"
  if [ "$(date +%s)" -ge "$next_scan" ]; then
    scan "$(now)"
    next_scan=$(( $(date +%s) + SCAN_SEC ))
  fi
  sleep $(( SAMPLE_SEC > 1 ? SAMPLE_SEC - 1 : 1 ))
done
finish

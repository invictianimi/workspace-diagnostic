#!/bin/sh
# workspace-monitor.sh - read-only sampler for Linux and macOS.
# Reads system counters and workspace file metadata. Writes only inside OUT_DIR.
# Usage: sh workspace-monitor.sh WORKSPACE OUT_DIR [DURATION_MIN] [SAMPLE_SEC] [SCAN_SEC]
# Optional environment: TOP_N=10 MAX_LOG_MB=50 EXCLUDE_DIRS="node_modules .venv"
#   PATH_DEPTH=0      0 records full paths; N records only the first N folder levels (no file names)
#   KEEP_FILE_LIST=0  1 keeps a full file list (snapshot-end.tsv) at the end; ignored if PATH_DEPTH > 0
set -u
set -f      # no wildcard expansion of variables
umask 077   # everything this script creates is readable only by the current user
[ $# -ge 2 ] || { echo "usage: $0 WORKSPACE OUT_DIR [DURATION_MIN] [SAMPLE_SEC] [SCAN_SEC]" >&2; exit 1; }
OS=$(uname -s)
[ "$OS" = Linux ] || [ "$OS" = Darwin ] || { echo "Unsupported OS: $OS" >&2; exit 1; }
WS=$(cd "$1" && pwd -P) || exit 1
OUT=$2
case $OUT in /*) ;; *) OUT="$PWD/$OUT" ;; esac
case "$OUT/" in "$WS"/*) echo "OUT_DIR must be outside the workspace." >&2; exit 1 ;; esac
[ -e "$OUT/system.csv" ] && { echo "OUT_DIR already holds monitor data; choose a new folder." >&2; exit 1; }
DURATION_MIN=${3:-60}; SAMPLE_SEC=${4:-15}; SCAN_SEC=${5:-60}
TOP_N=${TOP_N:-10}; MAX_LOG_MB=${MAX_LOG_MB:-50}; EXCLUDE_DIRS=${EXCLUDE_DIRS:-}
PATH_DEPTH=${PATH_DEPTH:-0}; KEEP_FILE_LIST=${KEEP_FILE_LIST:-0}
for v in "$DURATION_MIN" "$SAMPLE_SEC" "$SCAN_SEC" "$TOP_N" "$MAX_LOG_MB" "$PATH_DEPTH" "$KEEP_FILE_LIST"; do
  case $v in ''|*[!0-9]*) echo "Numeric settings must be whole numbers, got: $v" >&2; exit 1 ;; esac
done
mkdir -p "$OUT" || exit 1
OUT=$(cd "$OUT" && pwd -P)
case "$OUT/" in "$WS"/*) echo "OUT_DIR resolves to inside the workspace." >&2; exit 1 ;; esac

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
  echo "exclude_dirs=$EXCLUDE_DIRS"; echo "path_depth=$PATH_DEPTH"; echo "keep_file_list=$KEEP_FILE_LIST"
  echo "cpu_pct_units=machine-wide in system.csv; per core (100 = one core) in procs.csv"
  echo "start=$(now)"
} > "$OUT/meta.txt"

# Shared awk helpers.
# mb(): convert sizes such as 512K, 123M, 1.2G to MiB.
# q(): quote a CSV value, escaping quotes and prefixing values that a spreadsheet
#      program would otherwise run as a formula (=, +, -, @, tab, carriage return).
AWK_FN='function mb(s,  u, v) { u = tolower(substr(s, length(s))); v = s + 0
  if (u == "k") v /= 1024; else if (u == "g") v *= 1024; else if (u == "t") v *= 1048576
  return v }
function q(s) { gsub(/"/, "\"\"", s); if (s ~ /^[-=+@\t\r]/) s = "\047" s; return "\"" s "\"" }'

# Linux: second iteration of procps top gives current (not lifetime) CPU figures.
# Only the program name is kept, never its arguments, which can contain private details.
LINUX_TOP_AWK="$AWK_FN"'
/^top -/ { blk++; next }
blk < 2 { next }
/^%Cpu\(s\)/ { for (i = 2; i <= NF; i++) { v = $(i-1); sub(/.*,/, "", v)
    if ($i ~ /^id,?$/) id = v; if ($i ~ /^wa,?$/) wa = v }; next }
/^ *[0-9]+ / && c < n { c++; name = $12; sub(/.*\//, "", name)
  printf "%s,%s,%s,%s,%.0f,\n", ts, $1, q(name), $9, mb($6) >> procs }
END { if (id != "") printf "%.1f %s\n", 100 - id, wa }'

# macOS: second sample of top -l 2 gives current CPU figures.
MAC_TOP_AWK="$AWK_FN"'
/^CPU usage/ { cpu = $0 }
/^PID/ { blk++; next }
blk == 2 && NF >= 4 && c < n { c++; m = $3; sub(/[+-]$/, "", m)
  name = $4; for (i = 5; i <= NF; i++) name = name " " $i
  printf "%s,%s,%s,%s,%.0f,\n", ts, $1, q(name), $2, mb(m) >> procs }
END { split(cpu, a, ","); idle = a[3]; gsub(/[^0-9.]/, "", idle); if (idle != "") printf "%.1f\n", 100 - idle }'

# Change log: compare two file lists. With PATH_DEPTH > 0, record only the first
# PATH_DEPTH folder levels of each path, so no file names are stored.
DIFF_AWK="$AWK_FN"'
function shown(p,  a, n, keep, i, r) {
  if (depth <= 0) return p
  n = split(p, a, "/"); keep = (depth < n - 1) ? depth : n - 1
  if (keep <= 0) return "*"
  r = a[1]; for (i = 2; i <= keep; i++) r = r "/" a[i]
  return r "/*" }
FILENAME == ARGV[1] { old[$1] = $2 FS $3; next }
{ seen[$1] = 1
  if (!($1 in old)) print ts ",added," q(shown($1)) "," $2
  else if (old[$1] != $2 FS $3) print ts ",modified," q(shown($1)) "," $2 }
END { for (k in old) if (!(k in seen)) print ts ",removed," q(shown(k)) "," }'

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
    awk -F'\t' -v ts="$ts" -v depth="$PATH_DEPTH" "$DIFF_AWK" \
      "$OUT/.snap.prev" "$OUT/.snap.cur" >> "$OUT/changes.csv"
  fi
  mv "$OUT/.snap.cur" "$OUT/.snap.prev"
}

reason=duration
finish() {
  # The working file list holds every file name; keep it only if asked to.
  if [ "$KEEP_FILE_LIST" = 1 ] && [ "$PATH_DEPTH" = 0 ] && [ -f "$OUT/.snap.prev" ]; then
    mv "$OUT/.snap.prev" "$OUT/snapshot-end.tsv"
  else
    rm -f "$OUT/.snap.prev" "$OUT/.snap.cur"
  fi
  echo "end=$(now)" >> "$OUT/meta.txt"
  echo "stop_reason=$reason" >> "$OUT/meta.txt"
  echo "Monitor stopped ($reason). Data is in $OUT"
  exit 0
}
trap 'reason=interrupted; finish' INT TERM HUP

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

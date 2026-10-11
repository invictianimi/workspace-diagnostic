# workspace-monitor.ps1 - read-only sampler for Windows (PowerShell 5.1 or 7+).
# Reads system counters and workspace file metadata. Writes only inside -OutDir.
#   -PathDepth 0      0 records full paths; N records only the first N folder levels (no file names)
#   -KeepFileList     keeps a full file list (snapshot-end.tsv) at the end; ignored if -PathDepth > 0
param(
    [Parameter(Mandatory = $true)][string]$Workspace,
    [Parameter(Mandatory = $true)][string]$OutDir,
    [ValidateRange(1, 1440)][int]$DurationMinutes = 60,
    [ValidateRange(1, 3600)][int]$SampleSeconds = 15,
    [ValidateRange(1, 86400)][int]$ScanSeconds = 60,
    [ValidateRange(1, 100)][int]$TopProcesses = 10,
    [ValidateRange(1, 10240)][int]$MaxLogMB = 50,
    [ValidateRange(0, 50)][int]$PathDepth = 0,
    [switch]$KeepFileList,
    [string[]]$ExcludeDirs = @()
)
$ErrorActionPreference = 'SilentlyContinue'

$Workspace = (Resolve-Path -LiteralPath $Workspace -ErrorAction Stop).Path.TrimEnd('\')
$OutDir = [IO.Path]::GetFullPath($OutDir).TrimEnd('\')
if (($OutDir + '\').StartsWith($Workspace + '\', [StringComparison]::OrdinalIgnoreCase)) {
    Write-Error 'OutDir must be outside the workspace.'; exit 1
}
if (Test-Path -LiteralPath (Join-Path $OutDir 'system.csv')) {
    Write-Error 'OutDir already holds monitor data; choose a new folder.'; exit 1
}
$newFolder = -not (Test-Path -LiteralPath $OutDir)
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# Make a newly created output folder readable only by the current user (and the
# SYSTEM account), whatever the permissions of the folder it was created in.
if ($newFolder) {
    $me = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    & icacls.exe $OutDir /inheritance:r /grant:r "*${me}:(OI)(CI)F" "*S-1-5-18:(OI)(CI)F" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not limit access to $OutDir. Keep it inside your own user folder."
    }
}

$f = @{}
foreach ($n in 'system', 'procs', 'changes', 'scan', 'markers') { $f[$n] = Join-Path $OutDir "$n.csv" }
$stopFile = Join-Path $OutDir 'STOP'
$metaFile = Join-Path $OutDir 'meta.txt'

function Now { (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'") }

# Quote a CSV value, escaping quotes and prefixing values that a spreadsheet
# program would otherwise run as a formula (=, +, -, @, tab, carriage return).
function Q([string]$s) {
    if ($s -match '^[-=+@\t\r]') { $s = "'" + $s }
    '"' + $s.Replace('"', '""') + '"'
}

function Append([string]$path, [string[]]$lines) { [IO.File]::AppendAllLines($path, $lines) }

# With -PathDepth > 0, record only the first N folder levels of a path, so no file names are stored.
function Shown([string]$rel) {
    if ($PathDepth -le 0) { return $rel }
    $parts = $rel.Split('\')
    $keep = [math]::Min($PathDepth, $parts.Count - 1)
    if ($keep -le 0) { return '*' }
    (($parts[0..($keep - 1)]) -join '\') + '\*'
}

Append $f.system  'ts,cpu_pct,mem_used_pct,mem_avail_mb,disk_busy_pct,disk_queue,iowait_pct,load1'
Append $f.procs   'ts,pid,name,cpu_pct,mem_mb,io_bytes_per_sec'
Append $f.changes 'ts,change,path,size_bytes'
Append $f.scan    'ts,file_count,total_mb,scan_ms'
Append $f.markers 'ts,note'

$totalMB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
$os = Get-CimInstance Win32_OperatingSystem
Append $metaFile @(
    "workspace=$Workspace", "out_dir=$OutDir", "os=$($os.Caption) $($os.Version)",
    "cpus=$([Environment]::ProcessorCount)", "mem_total_mb=$totalMB",
    "duration_min=$DurationMinutes", "sample_sec=$SampleSeconds", "scan_sec=$ScanSeconds",
    "exclude_dirs=$($ExcludeDirs -join ' ')", "path_depth=$PathDepth", "keep_file_list=$([int][bool]$KeepFileList)",
    "cpu_pct_units=machine-wide in system.csv; per core (100 = one core) in procs.csv",
    "start=$(Now)")

function Write-Sample([string]$ts) {
    $cpu = [math]::Round((Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average, 1)
    $availMB = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes
    $memUsed = [math]::Round(100 * (1 - $availMB / $totalMB), 1)
    $disk = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk -Filter "Name='_Total'"
    Append $f.system "$ts,$cpu,$memUsed,$availMB,$($disk.PercentDiskTime),$($disk.CurrentDiskQueueLength),,"

    # Process names only (no paths or command lines, which can contain private details).
    $all = @(Get-CimInstance Win32_PerfFormattedData_PerfProc_Process |
        Where-Object { $_.Name -ne '_Total' -and $_.Name -ne 'Idle' })
    $pick = @($all | Sort-Object PercentProcessorTime -Descending | Select-Object -First $TopProcesses) +
            @($all | Sort-Object IODataBytesPersec -Descending | Select-Object -First $TopProcesses)
    $lines = foreach ($p in ($pick | Sort-Object IDProcess -Unique)) {
        "$ts,$($p.IDProcess),$(Q $p.Name),$($p.PercentProcessorTime),$([math]::Round($p.WorkingSetPrivate / 1MB)),$($p.IODataBytesPersec)"
    }
    if ($lines) { Append $f.procs $lines }
}

# The file list is kept in memory only; it is written to disk only with -KeepFileList.
function Get-Snapshot {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $map = @{}
    $bytes = 0
    foreach ($item in (Get-ChildItem -LiteralPath $Workspace -Recurse -File -Force)) {
        $rel = $item.FullName.Substring($Workspace.Length + 1)
        if ($ExcludeDirs.Count -and ($rel.Split('\') | Where-Object { $ExcludeDirs -contains $_ })) { continue }
        $map[$rel] = "$($item.Length)|$($item.LastWriteTimeUtc.Ticks)"
        $bytes += $item.Length
    }
    $sw.Stop()
    @{ Map = $map; Bytes = $bytes; Ms = $sw.ElapsedMilliseconds }
}

function Write-Scan([string]$ts, $snap) {
    Append $f.scan "$ts,$($snap.Map.Count),$([math]::Round($snap.Bytes / 1MB, 1)),$($snap.Ms)"
}

function Write-Diff([string]$ts, $old, $new) {
    $lines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($k in $new.Keys) {
        if (-not $old.ContainsKey($k)) { $lines.Add("$ts,added,$(Q (Shown $k)),$($new[$k].Split('|')[0])") }
        elseif ($old[$k] -ne $new[$k]) { $lines.Add("$ts,modified,$(Q (Shown $k)),$($new[$k].Split('|')[0])") }
    }
    foreach ($k in $old.Keys) { if (-not $new.ContainsKey($k)) { $lines.Add("$ts,removed,$(Q (Shown $k)),") } }
    if ($lines.Count) { Append $f.changes $lines.ToArray() }
}

$reason = 'duration'
$base = Get-Snapshot
Write-Scan (Now) $base
$end = (Get-Date).AddMinutes($DurationMinutes)
$nextScan = (Get-Date).AddSeconds($ScanSeconds)
Write-Host "Monitoring $Workspace until $($end.ToString('t')). Stop early: create $stopFile or press Ctrl+C."
try {
    while ((Get-Date) -lt $end) {
        if (Test-Path -LiteralPath $stopFile) { $reason = 'stop-file'; break }
        $logBytes = (Get-ChildItem -LiteralPath $OutDir -File | Measure-Object -Property Length -Sum).Sum
        if ($logBytes -gt $MaxLogMB * 1MB) { $reason = 'size-cap'; break }
        Write-Sample (Now)
        if ((Get-Date) -ge $nextScan) {
            $cur = Get-Snapshot
            $ts = Now
            Write-Diff $ts $base.Map $cur.Map
            Write-Scan $ts $cur
            $base = $cur
            $nextScan = (Get-Date).AddSeconds($ScanSeconds)
        }
        Start-Sleep -Seconds $SampleSeconds
    }
} finally {
    if ($reason -eq 'duration' -and (Get-Date) -lt $end) { $reason = 'interrupted' }
    if ($KeepFileList -and $PathDepth -le 0) {
        $snapLines = foreach ($k in $base.Map.Keys) {
            $parts = $base.Map[$k].Split('|')
            $epoch = [DateTimeOffset]::new([long]$parts[1], [TimeSpan]::Zero).ToUnixTimeSeconds()
            "$k`t$($parts[0])`t$epoch"
        }
        if ($snapLines) { [IO.File]::WriteAllLines((Join-Path $OutDir 'snapshot-end.tsv'), [string[]]$snapLines) }
    }
    Append $metaFile @("end=$(Now)", "stop_reason=$reason")
    Write-Host "Monitor stopped ($reason). Data is in $OutDir"
}

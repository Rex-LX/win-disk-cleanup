# scan_disk.ps1 - 扫描磁盘空间 + 可清理项 + AppData 详情
# Usage: powershell -ExecutionPolicy Bypass -File scan_disk.ps1
# Output: writes report to $outFile (set below)

param(
    [string]$outFile = ""
)

if (-not $outFile) {
    $outFile = Join-Path $PSScriptRoot "scan_report.txt"
}
Set-Content $outFile "" -Encoding UTF8

function Log($msg) { Add-Content $outFile $msg -Encoding UTF8 }

function DirSizeMB($path) {
    if (-not (Test-Path $path)) { return 0 }
    $s = (Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    return [math]::Round($s / 1MB, 0)
}

# === 1. Disk Overview ===
Log "=== Disk Overview ==="
foreach ($letter in @("C", "D", "E")) {
    if (Test-Path "${letter}:\") {
        $d = New-Object System.IO.DriveInfo($letter)
        Log ("{0}: Total={1}GB  Used={2}GB  Free={3}GB ({4}%)" -f $letter,
            [math]::Round($d.TotalSize/1GB,1),
            [math]::Round(($d.TotalSize - $d.AvailableFreeSpace)/1GB,1),
            [math]::Round($d.AvailableFreeSpace/1GB,1),
            [math]::Round($d.AvailableFreeSpace/$d.TotalSize*100,1))
    }
}

# === 2. C:\ Top-Level ===
Log "`n=== C:\ Top-Level Folders ==="
Get-ChildItem C:\ -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $sz = DirSizeMB $_.FullName
    if ($sz -ge 100) {
        Log ("{0,-35} {1,8} MB" -f $_.Name, $sz)
    }
}

# === 3. User AppData scan (>50MB) ===
function ScanDir($label, $root) {
    Log "`n=== $label ==="
    if (-not (Test-Path $root)) { Log "  [Not found]"; return }
    $items = @()
    Get-ChildItem $root -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
        $sz = DirSizeMB $_.FullName
        if ($sz -ge 50) {
            $isJ = (Get-Item $_.FullName -Force -ErrorAction SilentlyContinue).LinkType -eq "Junction"
            $items += [PSCustomObject]@{ Name=$_.Name; MB=$sz; J=$isJ }
        }
    }
    foreach ($r in ($items | Sort-Object MB -Descending)) {
        $tag = if ($r.J) { " [J]" } else { "" }
        Log ("{0,-35} {1,6} MB{2}" -f $r.Name, $r.MB, $tag)
    }
}

ScanDir "AppData\Local (>50MB)" $env:LOCALAPPDATA
ScanDir "AppData\Roaming (>50MB)" $env:APPDATA
ScanDir "User Profile dotfolders (>50MB)" $env:USERPROFILE

# === 4. Cleanable items ===
Log "`n=== Cleanable Items ==="
$cleanables = @{
    "User Temp" = $env:TEMP
    "Windows Temp" = "C:\Windows\Temp"
    "Chrome Cache" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
    "Edge Cache" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
    "Thumbnails" = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    "pip cache" = "$env:LOCALAPPDATA\pip\cache"
}
foreach ($name in ($cleanables.Keys | Sort-Object)) {
    $sz = DirSizeMB $cleanables[$name]
    Log ("{0,-30} {1,6} MB" -f $name, $sz)
}
try {
    $rb = (New-Object -ComObject Shell.Application).NameSpace(0xa)
    Log ("Recycle Bin: {0} items" -f $rb.Items().Count)
} catch { Log "Recycle Bin: unable to read" }

Log "`nReport saved to: $outFile"

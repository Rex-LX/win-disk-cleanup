# clean_caches.ps1 - 清理临时文件 + 浏览器缓存 + 应用缓存
# Usage: powershell -ExecutionPolicy Bypass -File clean_caches.ps1 [-Mode basic|deep]
#   basic = Phase 1: temp + browser + recycle bin only
#   deep  = Phase 2: + app caches + updaters + logs

param(
    [ValidateSet("basic","deep")]
    [string]$Mode = "basic",
    [string]$outFile = ""
)

if (-not $outFile) {
    $outFile = Join-Path $PSScriptRoot "clean_report.txt"
}
Set-Content $outFile "" -Encoding UTF8

function Log($msg) { Add-Content $outFile $msg -Encoding UTF8 }

function CleanDir($label, $path, $filter) {
    if (-not (Test-Path $path)) { return 0 }
    $before = (Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    if ($filter) {
        Get-ChildItem $path -Filter $filter -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop } catch {}
        }
    } else {
        Get-ChildItem $path -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'qoder-cli' } | ForEach-Object {
            try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop } catch {}
        }
    }
    $after = (Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    $freed = [math]::Round(($before - $after) / 1MB, 0)
    Log ("{0,-35} freed {1,6} MB" -f $label, $freed)
    return ($before - $after)
}

$cBefore = (New-Object System.IO.DriveInfo("C")).AvailableFreeSpace
$dBefore = if (Test-Path "D:\") { (New-Object System.IO.DriveInfo("D")).AvailableFreeSpace } else { 0 }
Log "Mode: $Mode"
Log "C: free=$([math]::Round($cBefore/1GB,2))GB  D: free=$([math]::Round($dBefore/1GB,2))GB"
Log ""

$total = 0

# === Phase 1: Basic cleanup (always runs) ===
Log "=== Temp Files ==="
$total += CleanDir "User Temp" $env:TEMP
$total += CleanDir "Windows Temp" "C:\Windows\Temp"
$total += CleanDir "Thumbnails" "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" "thumbcache_*.db"
$total += CleanDir "CrashDumps" "$env:LOCALAPPDATA\CrashDumps"

Log "`n=== Browser Caches ==="
$chromeDefault = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
$total += CleanDir "Chrome Cache" "$chromeDefault\Cache"
$total += CleanDir "Chrome Code Cache" "$chromeDefault\Code Cache"
$total += CleanDir "Chrome Service Worker" "$chromeDefault\Service Worker\CacheStorage"
$edgeDefault = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
$total += CleanDir "Edge Cache" "$edgeDefault\Cache"
$total += CleanDir "Edge Code Cache" "$edgeDefault\Code Cache"

# pip cache
Log "`n=== pip Cache ==="
pip cache purge 2>&1 | Out-Null
$total += CleanDir "pip cache" "$env:LOCALAPPDATA\pip\cache"

Log "`n=== Recycle Bin ==="
try {
    Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    Log "  Emptied"
} catch { Log "  Skipped" }

# === Phase 2: Deep cleanup (only in deep mode) ===
if ($Mode -eq "deep") {
    Log "`n=== App Caches (Deep) ==="
    $total += CleanDir "NetEase/Cache" "$env:LOCALAPPDATA\NetEase\CloudMusic\Cache"
    $total += CleanDir "NetEase/update" "$env:LOCALAPPDATA\NetEase\CloudMusic\update"
    $total += CleanDir "NetEase/ad" "$env:LOCALAPPDATA\NetEase\CloudMusic\ad"
    $total += CleanDir "Quark/Cache" "$env:LOCALAPPDATA\Quark\User Data\Default\Cache"
    $total += CleanDir "Quark/Code Cache" "$env:LOCALAPPDATA\Quark\User Data\Default\Code Cache"
    $total += CleanDir "Quark/updates" "$env:LOCALAPPDATA\Quark\User Data\updates"
    $total += CleanDir "Quark/Crashpad" "$env:LOCALAPPDATA\Quark\User Data\Crashpad"
    $total += CleanDir "Douyin/Cache" "$env:APPDATA\douyin\Cache"
    $total += CleanDir "Douyin/Code Cache" "$env:APPDATA\douyin\Code Cache"
    $total += CleanDir "Bilibili/Cache" "$env:APPDATA\bilibili\Cache"
    $total += CleanDir "Bilibili/Code Cache" "$env:APPDATA\bilibili\Code Cache"
    $total += CleanDir "Steam/htmlcache" "$env:LOCALAPPDATA\Steam\htmlcache"
    $total += CleanDir "WeChat/log" "$env:APPDATA\Tencent\xwechat\log"
    $total += CleanDir "Zoom/logs" "$env:APPDATA\Zoom\logs"
    $total += CleanDir "ACLOS/Cache" "$env:APPDATA\ACLOS\Cache"
    $total += CleanDir "ACLOS/logs" "$env:APPDATA\ACLOS\logs"

    Log "`n=== Updater Leftovers (Deep) ==="
    foreach ($u in @("qoder-work-updater","bilibili-updater","tabby-updater")) {
        $total += CleanDir $u "$env:LOCALAPPDATA\$u"
    }
    $total += CleanDir "app_shell_cache" "$env:LOCALAPPDATA\app_shell_cache_6383"
}

# Summary
Log "`n============================================"
$cAfter = (New-Object System.IO.DriveInfo("C")).AvailableFreeSpace
$dAfter = if (Test-Path "D:\") { (New-Object System.IO.DriveInfo("D")).AvailableFreeSpace } else { 0 }
Log "CLEANUP COMPLETE ($Mode mode)"
Log "C: $([math]::Round($cBefore/1GB,2))GB -> $([math]::Round($cAfter/1GB,2))GB (+$([math]::Round(($cAfter-$cBefore)/1GB,2))GB)"
Log "D: $([math]::Round($dBefore/1GB,2))GB -> $([math]::Round($dAfter/1GB,2))GB (+$([math]::Round(($dAfter-$dBefore)/1GB,2))GB)"
Log "============================================"

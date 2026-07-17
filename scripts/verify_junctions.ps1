# verify_junctions.ps1 - 验证所有 Junction 完整性
# Usage: powershell -ExecutionPolicy Bypass -File verify_junctions.ps1

param(
    [string]$outFile = ""
)

if (-not $outFile) {
    $outFile = Join-Path $PSScriptRoot "verify_report.txt"
}
Set-Content $outFile "" -Encoding UTF8

function Log($msg) { Add-Content $outFile $msg -Encoding UTF8 }

$drive = New-Object System.IO.DriveInfo("C")
Log "C: Free=$([math]::Round($drive.AvailableFreeSpace/1GB,2))GB  Used=$([math]::Round(($drive.TotalSize-$drive.AvailableFreeSpace)/1GB,2))GB"
Log ""

function CheckJunction($name, $path) {
    if (-not (Test-Path $path)) {
        Log "[MISSING] $name"
        return
    }
    $item = Get-Item $path -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq "Junction") {
        Log "[OK] $name -> $($item.Target)"
    } else {
        Log "[NOT-JUNCTION] $name"
    }
}

Log "=== AppData\Local Junctions ==="
$localNames = @(
    "Google", "Yarn", "NetEase", "Quark", "JetBrains", "ima.copilot",
    "MathWorks", "Qianwen", "Steam", "Doubao", "OpenAI", "R",
    "EpicGamesLauncher", "qoder-work-updater", "bilibili-updater",
    "tabby-updater", "CrashDumps"
)
foreach ($n in $localNames) {
    CheckJunction $n "$env:LOCALAPPDATA\$n"
}

Log "`n=== AppData\Roaming Junctions ==="
$roamingNames = @(
    "Tencent", "kingsoft", "Trae CN", "npm", "ACLOS", "Zoom", "Code",
    "douyin", "bilibili", "JetBrains", "QQ", "Cursor", "obsidian",
    "Qoder", "QoderWork", "cxstudy"
)
foreach ($n in $roamingNames) {
    CheckJunction $n "$env:APPDATA\$n"
}

Log "`n=== User Profile Junctions ==="
$profileNames = @(".vscode", ".cache", ".codegeex", ".qoder", ".trae-cn", ".claude", ".codex")
foreach ($n in $profileNames) {
    CheckJunction $n "$env:USERPROFILE\$n"
}

Log "`n=== Cache Env Vars ==="
Log "YARN_CACHE_FOLDER = $([Environment]::GetEnvironmentVariable('YARN_CACHE_FOLDER','User'))"
Log "PIP_CACHE_DIR = $([Environment]::GetEnvironmentVariable('PIP_CACHE_DIR','User'))"
$npmCache = npm config get cache 2>&1
Log "npm cache = $npmCache"

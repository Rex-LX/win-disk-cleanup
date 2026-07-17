# check_running.ps1 - 检查目标应用是否正在运行
# Usage: powershell -ExecutionPolicy Bypass -File check_running.ps1

param(
    [string]$outFile = ""
)

if (-not $outFile) {
    $outFile = Join-Path $PSScriptRoot "running_check.txt"
}
Set-Content $outFile "" -Encoding UTF8

function Log($msg) { Add-Content $outFile $msg -Encoding UTF8 }

$targetApps = @{
    "WeChat" = "WeChat,WeChatAppEx"
    "QQ" = "QQ,TIM"
    "Chrome" = "chrome"
    "Edge" = "msedge"
    "NetEase CloudMusic" = "cloudmusic"
    "Quark" = "quark"
    "Bilibili" = "bilibili"
    "Douyin" = "douyin"
    "Zoom" = "Zoom"
    "JetBrains" = "idea64,pycharm64"
    "VS Code" = "Code"
    "Cursor" = "Cursor"
    "Trae CN" = "Trae"
    "WPS" = "wps,et,wpp"
    "Tencent Meeting" = "WeMeet"
    "Qianwen" = "Qianwen"
    "Doubao" = "Doubao"
    "Steam" = "steam"
    "MathWorks" = "MathWorksServiceHost"
    "ima.copilot" = "imacopilot"
    "Tabby" = "tabby"
    "OpenAI Codex" = "codex"
}

$allProcs = Get-Process -ErrorAction SilentlyContinue | Select-Object ProcessName, Id

Log "=== Running Process Check ==="
Log ""

$running = @(); $closed = @()
foreach ($app in ($targetApps.Keys | Sort-Object)) {
    $patterns = $targetApps[$app] -split ","
    $found = $false
    foreach ($p in $allProcs) {
        foreach ($pat in $patterns) {
            if ($p.ProcessName -like "*$pat*") { $found = $true; break }
        }
        if ($found) { break }
    }
    if ($found) {
        $running += $app
        Log "[RUNNING] $app"
    } else {
        $closed += $app
        Log "[CLOSED]  $app"
    }
}

Log ""
Log "Running: $($running.Count) apps need to be closed before migration"
Log "Closed: $($closed.Count) apps are safe to migrate"

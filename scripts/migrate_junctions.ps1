# migrate_junctions.ps1 - 批量迁移文件夹并创建 Junction
# Usage: powershell -ExecutionPolicy Bypass -File migrate_junctions.ps1 [-targetRoot "D:\AppData"]

param(
    [string]$targetRoot = "D:\AppData",
    [string]$outFile = ""
)

if (-not $outFile) {
    $outFile = Join-Path $PSScriptRoot "migration_report.txt"
}
Set-Content $outFile "" -Encoding UTF8

function Log($msg) { Add-Content $outFile $msg -Encoding UTF8 }

function Migrate-Folder($source, $target) {
    $name = Split-Path $source -Leaf

    # Skip if already junction
    $item = Get-Item $source -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType -eq "Junction") {
        Log "[SKIP-JUNCTION] $source"
        return $false
    }
    if (-not (Test-Path $source)) {
        Log "[SKIP] $source not found"
        return $false
    }

    $srcSize = (Get-ChildItem $source -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    $srcMB = [math]::Round($srcSize / 1MB, 0)
    Log "[MIGRATE] $name ($srcMB MB): $source -> $target"

    # Copy via robocopy
    $rArgs = @($source, $target, "/E", "/COPYALL", "/R:1", "/W:1", "/NFL", "/NDL", "/NP", "/NS", "/NC", "/MT:8", "/XJ")
    $proc = Start-Process robocopy -ArgumentList $rArgs -Wait -NoNewWindow -PassThru

    # Fallback to xcopy if robocopy failed (exit >= 16)
    if ($proc.ExitCode -ge 8) {
        xcopy $source $target /E /I /H /Y /Q /R 2>&1 | Out-Null
    }

    # Verify target size
    $tgtSize = (Get-ChildItem $target -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
    $tgtMB = [math]::Round($tgtSize / 1MB, 0)
    if ($tgtMB -lt ($srcMB * 0.9)) {
        Log "  [FAIL] Target too small ($tgtMB vs $srcMB MB)"
        if (Test-Path $target) { Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue }
        return $false
    }

    # Remove original
    cmd /c "rmdir /S /Q `"$source`"" 2>&1 | Out-Null
    if (Test-Path $source) {
        takeown /F $source /R /D Y 2>&1 | Out-Null
        icacls $source /grant Everyone:F /T /Q 2>&1 | Out-Null
        cmd /c "rmdir /S /Q `"$source`"" 2>&1 | Out-Null
    }
    if (Test-Path $source) {
        Log "  [FAIL] Could not remove original"
        return $false
    }

    # Create junction
    cmd /c "mklink /J `"$source`" `"$target`"" 2>&1 | Out-Null
    if ((Get-Item $source -Force -ErrorAction SilentlyContinue).LinkType -eq "Junction") {
        Log "  [OK] Junction created, freed $srcMB MB"
        return $true
    } else {
        Log "  [FAIL] Junction creation failed"
        return $false
    }
}

# === Setup ===
$cBefore = (New-Object System.IO.DriveInfo("C")).AvailableFreeSpace
Log "Free before: $([math]::Round($cBefore/1GB,2)) GB"
Log ""

# Create target dirs
foreach ($sub in @("Local","Roaming","UserProfile")) {
    $p = Join-Path $targetRoot $sub
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

# === Define migrations ===
$migrations = @()

# AppData\Local (common large folders)
$localFolders = @(
    "Google", "Yarn", "NetEase", "Quark", "JetBrains", "ima.copilot",
    "MathWorks", "Qianwen", "Steam", "Doubao", "OpenAI", "R",
    "EpicGamesLauncher", "qoder-work-updater", "bilibili-updater",
    "tabby-updater", "CrashDumps", "app_shell_cache_6383"
)
foreach ($f in $localFolders) {
    $migrations += @{ src="$env:LOCALAPPDATA\$f"; dst="$targetRoot\Local\$f" }
}

# AppData\Roaming
$roamingFolders = @(
    "Tencent", "kingsoft", "Trae CN", "npm", "ACLOS", "Zoom", "Code",
    "douyin", "bilibili", "JetBrains", "QQ", "Cursor", "obsidian",
    "Qoder", "QoderWork", "cxstudy"
)
foreach ($f in $roamingFolders) {
    $migrations += @{ src="$env:APPDATA\$f"; dst="$targetRoot\Roaming\$f" }
}

# User profile dotfolders
$profileFolders = @(".vscode", ".cache", ".codegeex", ".qoder", ".trae-cn", ".claude", ".codex")
foreach ($f in $profileFolders) {
    $migrations += @{ src="$env:USERPROFILE\$f"; dst="$targetRoot\UserProfile\$f" }
}

# === Execute ===
$ok = 0; $fail = 0
foreach ($m in $migrations) {
    if (Migrate-Folder $m.src $m.dst) { $ok++ } else { $fail++ }
}

# === Summary ===
Log ""
Log "============================================"
$cAfter = (New-Object System.IO.DriveInfo("C")).AvailableFreeSpace
$freedGB = [math]::Round(($cAfter - $cBefore) / 1GB, 2)
Log "MIGRATION COMPLETE: $ok success, $fail skipped/failed"
Log "Freed: $freedGB GB | Free now: $([math]::Round($cAfter/1GB,2)) GB"
Log "============================================"

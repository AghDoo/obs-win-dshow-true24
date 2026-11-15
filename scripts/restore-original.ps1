[CmdletBinding()]
param(
    [Parameter()]
    [string] $ObsRoot = "C:\Program Files\obs-studio",

    [Parameter()]
    [string] $BackupPath
)

$ErrorActionPreference = "Stop"

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "請以系統管理員身分開啟 PowerShell 後再執行。"
    }
}

function Assert-ObsStopped {
    $running = @(Get-Process -Name "obs64", "obs32", "obs" -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) {
        $names = ($running | Select-Object -ExpandProperty ProcessName -Unique) -join ", "
        throw "請先完全關閉 OBS Studio（目前仍在執行：$names）。"
    }
}

Assert-Administrator
Assert-ObsStopped

if (-not (Test-Path -LiteralPath $ObsRoot -PathType Container)) {
    throw "找不到 OBS 安裝目錄：$ObsRoot"
}

$target = Join-Path $ObsRoot "core\win-dshow\win-dshow.dll"
if (-not (Test-Path -LiteralPath (Split-Path -Parent $target) -PathType Container)) {
    throw "找不到 OBS DirectShow 模組目錄：$(Split-Path -Parent $target)"
}

if ([string]::IsNullOrWhiteSpace($BackupPath)) {
    $BackupPath = "$target.bak.original"
}

if (-not (Test-Path -LiteralPath $BackupPath -PathType Leaf)) {
    throw "找不到原始 DLL 備份：$BackupPath"
}

$temp = "$target.restore.tmp"
$backupHash = (Get-FileHash -LiteralPath $BackupPath -Algorithm SHA256).Hash

try {
    Copy-Item -LiteralPath $BackupPath -Destination $temp -Force
    $tempHash = (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash
    if ($tempHash -ne $backupHash) {
        throw "備份暫存檔的 SHA-256 驗證失敗。"
    }

    Move-Item -LiteralPath $temp -Destination $target -Force

    $restoredHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($restoredHash -ne $backupHash) {
        throw "還原後 DLL 的 SHA-256 驗證失敗。"
    }
} catch {
    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
    throw
}

Write-Host ""
Write-Host "原始 win-dshow.dll 已還原。" -ForegroundColor Green
Write-Host "目標：$target"
Write-Host "SHA-256：$restoredHash"
Write-Host "備份檔保留於：$BackupPath"

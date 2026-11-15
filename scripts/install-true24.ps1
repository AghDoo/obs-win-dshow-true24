[CmdletBinding()]
param(
    [Parameter()]
    [string] $ObsRoot = "C:\Program Files\obs-studio",

    [Parameter()]
    [string] $DllPath = (Join-Path $PSScriptRoot "win-dshow.dll")
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

if (-not (Test-Path -LiteralPath $DllPath -PathType Leaf)) {
    throw "找不到待安裝的 win-dshow.dll：$DllPath。請先將本腳本與 DLL 解壓縮至同一資料夾。"
}

$target = Join-Path $ObsRoot "core\win-dshow\win-dshow.dll"
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
    throw "找不到 OBS 目標 DLL：$target。此套件僅適用於 OBS 33.0.1 的預期安裝結構。"
}

$backup = "$target.bak.original"
$temp = "$target.true24.tmp"

if (-not (Test-Path -LiteralPath $backup -PathType Leaf)) {
    Copy-Item -LiteralPath $target -Destination $backup
    Write-Host "已建立原始 DLL 備份：$backup"
} else {
    Write-Host "保留既有原始 DLL 備份，不覆寫：$backup"
}

$sourceHash = (Get-FileHash -LiteralPath $DllPath -Algorithm SHA256).Hash

try {
    Copy-Item -LiteralPath $DllPath -Destination $temp -Force
    $tempHash = (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash
    if ($tempHash -ne $sourceHash) {
        throw "暫存 DLL 的 SHA-256 與下載檔案不一致。"
    }

    Move-Item -LiteralPath $temp -Destination $target -Force

    $installedHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    if ($installedHash -ne $sourceHash) {
        throw "安裝後 DLL 的 SHA-256 驗證失敗。"
    }
} catch {
    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path -LiteralPath $backup -PathType Leaf) {
        Copy-Item -LiteralPath $backup -Destination $target -Force
        Write-Warning "安裝未完成，已從原始備份還原。"
    }

    throw
}

Write-Host ""
Write-Host "True 24 DLL 安裝完成。" -ForegroundColor Green
Write-Host "目標：$target"
Write-Host "SHA-256：$installedHash"
Write-Host "原始備份：$backup"

param([string]$InstallPath = 'C:\PedroSystem')
$ErrorActionPreference = 'Stop'
$source = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host 'PEDRO SYSTEM installer' -ForegroundColor Cyan
Write-Host "Source : $source"
Write-Host "Target : $InstallPath"

if (-not (Test-Path $InstallPath)) { New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null }

$sourceResolved = (Resolve-Path $source).Path.TrimEnd('\')
$targetResolved = (Resolve-Path $InstallPath).Path.TrimEnd('\')
if ($sourceResolved -ne $targetResolved) {
    Get-ChildItem -Path $source -Force | ForEach-Object { Copy-Item $_.FullName -Destination $InstallPath -Recurse -Force }
} else {
    Write-Host 'Project is already running from the installation directory; file copy skipped.' -ForegroundColor DarkYellow
}

$userPath = [Environment]::GetEnvironmentVariable('Path','User')
$parts = @($userPath -split ';' | Where-Object { $_ })
if ($parts -notcontains $InstallPath) {
    $newPath = (($parts + $InstallPath) -join ';').Trim(';')
    [Environment]::SetEnvironmentVariable('Path',$newPath,'User')
    Write-Host 'Added installation directory to USER PATH.' -ForegroundColor Green
} else { Write-Host 'Installation directory is already in USER PATH.' -ForegroundColor DarkGreen }

Write-Host ''
Write-Host 'Installation complete.' -ForegroundColor Green
Write-Host 'Close and reopen CMD/PowerShell, then type: pedro'
Write-Host "Installed at: $InstallPath"

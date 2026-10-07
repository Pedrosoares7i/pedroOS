param([string]$InstallPath = 'C:\PedroSystem')
$ErrorActionPreference = 'Stop'
Write-Host 'PEDRO SYSTEM uninstaller' -ForegroundColor Cyan

$userPath = [Environment]::GetEnvironmentVariable('Path','User')
$parts = @($userPath -split ';' | Where-Object { $_ -and $_.TrimEnd('\\') -ne $InstallPath.TrimEnd('\\') })
[Environment]::SetEnvironmentVariable('Path',($parts -join ';'),'User')
Write-Host 'Removed installation directory from USER PATH.' -ForegroundColor Green

if (Test-Path $InstallPath) {
    Write-Host "The folder $InstallPath will be removed." -ForegroundColor Yellow
    $answer = Read-Host 'Continue? [Y/N]'
    if ($answer -match '^(y|yes|s|sim)$') {
        if ((Resolve-Path $InstallPath).Path -eq (Split-Path -Parent $MyInvocation.MyCommand.Path)) {
            $cmd = "Start-Sleep -Seconds 1; Remove-Item -LiteralPath '$InstallPath' -Recurse -Force"
            Start-Process powershell.exe -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-Command',$cmd -WindowStyle Hidden
        } else { Remove-Item -LiteralPath $InstallPath -Recurse -Force }
        Write-Host 'PEDRO SYSTEM removed.' -ForegroundColor Green
    } else { Write-Host 'Folder removal cancelled. PATH entry was already removed.' -ForegroundColor Yellow }
}
Write-Host 'Open a new terminal session to refresh PATH.'

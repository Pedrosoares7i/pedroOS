$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

$modules = @(
    'core\common.ps1',
    'core\system.ps1',
    'core\storage.ps1',
    'core\network.ps1',
    'core\processes.ps1',
    'core\applications.ps1',
    'core\security.ps1',
    'core\monitor.ps1',
    'core\maintenance.ps1',
    'core\gaming.ps1',
    'core\commands.ps1'
)

foreach ($module in $modules) {
    $path = Join-Path $root $module
    if (-not (Test-Path $path)) { Write-Host "[FATAL] Missing module: $path" -ForegroundColor Red; exit 1 }
    . $path
}

Initialize-PedroDirectories
Write-PedroLog 'PEDRO SYSTEM started'
$settings = Get-PedroSettings
$snapshot = Get-PedroSystemSnapshot

Clear-Host
Write-Host ('=' * 60) -ForegroundColor DarkCyan
Write-Host ('                    ' + $settings.systemName) -ForegroundColor Cyan
Write-Host '        Personal Environment & Device Resource Operations' -ForegroundColor DarkCyan
Write-Host ('=' * 60) -ForegroundColor DarkCyan
Write-Host ''
Write-Host "PC: $($snapshot.Computer)"
Write-Host "OS: $($snapshot.OS)"
Write-Host "STATUS: $($snapshot.Internet)" -ForegroundColor $(if ($snapshot.Internet -eq 'ONLINE') {'Green'} else {'Yellow'})
Write-Host ''
Write-Host ('CPU : ' + (New-PedroBar $snapshot.CPUUsage))
Write-Host ('RAM : ' + (New-PedroBar $snapshot.RAMUsage))
Write-Host ('GPU : ' + (New-PedroBar $snapshot.GPUUsage))
Write-Host ('DISK: ' + (New-PedroBar $snapshot.DiskUsage))
Write-Host ''
Write-Host 'Type "help" to view commands.' -ForegroundColor DarkGray

$running = $true
while ($running) {
    try {
        $line = Read-Host 'pedro>'
        $running = Invoke-PedroCommand $line
    } catch {
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
        Write-PedroLog "Main loop error: $($_.Exception.Message)" 'ERROR'
        $running = $true
    }
}

Write-PedroLog 'PEDRO SYSTEM exited'
Write-Host 'PEDRO SYSTEM closed.' -ForegroundColor Cyan

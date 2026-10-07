function Clear-PedroTemporaryFiles {
    Write-Host 'This removes files from your user TEMP folder that are not currently in use.' -ForegroundColor Yellow
    if (-not (Confirm-PedroAction 'Continue')) { return }
    $deleted = 0; $failed = 0
    try {
        Get-ChildItem -Path $env:TEMP -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop; $deleted++ } catch { $failed++ }
        }
        Write-Host "Temporary items removed: $deleted. Skipped/in use: $failed." -ForegroundColor Green
        Write-PedroLog "Temp cleanup: removed=$deleted skipped=$failed"
    } catch { Write-Host "Cleanup failed: $($_.Exception.Message)" -ForegroundColor Red }
}

function Invoke-PedroAdminTool {
    param([string]$FilePath, [string]$Arguments, [string]$Label)
    Write-Host "$Label may take time and may require administrator privileges." -ForegroundColor Yellow
    if (-not (Confirm-PedroAction 'Continue')) { return }
    try {
        if (Test-PedroAdministrator) {
            Start-Process -FilePath $FilePath -ArgumentList $Arguments -Wait -NoNewWindow
        } else {
            Start-Process -FilePath $FilePath -ArgumentList $Arguments -Verb RunAs -Wait
        }
        Write-PedroLog "Maintenance executed: $Label"
    } catch { Write-Host "Unable to run ${Label}: $($_.Exception.Message)" -ForegroundColor Red }
}

function Show-PedroMaintenance {
    while ($true) {
        Write-PedroHeader 'MAINTENANCE'
        Write-Host '[1] Clean user temporary files'
        Write-Host '[2] Open Windows Disk Cleanup'
        Write-Host '[3] Check storage'
        Write-Host '[4] Run SFC /scannow'
        Write-Host '[5] Run DISM /Online /Cleanup-Image /CheckHealth'
        Write-Host '[0] Back'
        $choice = Read-Host 'Select'
        switch ($choice) {
            '1' { Clear-PedroTemporaryFiles }
            '2' { try { Start-Process cleanmgr.exe } catch { Write-Host $_.Exception.Message -ForegroundColor Red } }
            '3' { Show-PedroDisk }
            '4' { Invoke-PedroAdminTool 'sfc.exe' '/scannow' 'System File Checker' }
            '5' { Invoke-PedroAdminTool 'dism.exe' '/Online /Cleanup-Image /CheckHealth' 'DISM CheckHealth' }
            '0' { return }
            default { Write-Host 'Invalid option.' -ForegroundColor Yellow }
        }
        if ($choice -ne '0') { Read-Host 'Press Enter to continue' | Out-Null }
    }
}

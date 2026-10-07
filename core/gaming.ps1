function Show-PedroGaming {
    param([string[]]$InputArgs)
    if ($InputArgs.Count -ge 2 -and $InputArgs[0] -eq 'close') { Close-PedroApp $InputArgs[1]; return }
    while ($true) {
        $s = Get-PedroSystemSnapshot
        Write-PedroHeader 'PEDRO GAMING MODE'
        Write-Host ("CPU: {0}" -f $(if ($null -ne $s.CPUUsage) { "$([Math]::Round($s.CPUUsage,1))%" } else {'N/A'}))
        Write-Host ("RAM: {0}" -f $(if ($null -ne $s.RAMUsage) { "$([Math]::Round($s.RAMUsage,1))%" } else {'N/A'}))
        Write-Host ("GPU: {0}" -f $(if ($null -ne $s.GPUUsage) { "$([Math]::Round($s.GPUUsage,1))%" } else {'N/A'}))
        Write-Host ''
        Write-Host '[1] Launch configured game (valorant)'
        Write-Host '[2] Launch Steam'
        Write-Host '[3] Launch Discord'
        Write-Host '[4] Monitor system'
        Write-Host '[5] Show gaming settings'
        Write-Host '[0] Exit'
        $choice = Read-Host 'Select'
        switch ($choice) {
            '1' { Open-PedroApp 'valorant' }
            '2' { Open-PedroApp 'steam' }
            '3' { Open-PedroApp 'discord' }
            '4' { Start-PedroMonitor }
            '5' {
                $settings = Get-PedroSettings
                if ($settings.PSObject.Properties.Name -contains 'gaming') { $settings.gaming | Format-List } else { Write-Host 'No gaming settings configured.' }
            }
            '0' { return }
            default { Write-Host 'Invalid option.' -ForegroundColor Yellow }
        }
    }
}

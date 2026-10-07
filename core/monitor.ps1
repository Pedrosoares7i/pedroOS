function Get-PedroNetworkRate {
    try {
        $counter = Get-Counter '\Network Interface(*)\Bytes Received/sec','\Network Interface(*)\Bytes Sent/sec' -ErrorAction Stop
        $recv = 0.0; $sent = 0.0
        foreach ($s in $counter.CounterSamples) {
            if ($s.Path -match 'Bytes Received/sec') { $recv += [double]$s.CookedValue }
            elseif ($s.Path -match 'Bytes Sent/sec') { $sent += [double]$s.CookedValue }
        }
        return [pscustomobject]@{ DownloadMbps=[Math]::Round(($recv * 8 / 1MB),2); UploadMbps=[Math]::Round(($sent * 8 / 1MB),2) }
    } catch { return [pscustomobject]@{ DownloadMbps=$null; UploadMbps=$null } }
}

function Show-PedroAsciiHistory {
    param([System.Collections.ArrayList]$CpuHistory)
    if ($CpuHistory.Count -lt 2) { return }
    $chars = @(' ','_','.',':','-','=','+','*','#','@')
    $line = ''
    foreach ($v in $CpuHistory) {
        $idx = [int][Math]::Round(([Math]::Max(0,[Math]::Min(100,[double]$v)) / 100) * ($chars.Count - 1))
        $line += $chars[$idx]
    }
    Write-Host ('CPU HISTORY: ' + $line) -ForegroundColor DarkCyan
}

function Start-PedroMonitor {
    $settings = Get-PedroSettings
    $interval = [Math]::Max(1, [int]$settings.monitorInterval)
    $historySize = [Math]::Max(10, [int]$settings.historySize)
    $cpuHistory = New-Object System.Collections.ArrayList
    Write-PedroLog 'Real-time monitor started'

    while ($true) {
        try {
            $s = Get-PedroSystemSnapshot
            $rate = Get-PedroNetworkRate
            if ($null -ne $s.CPUUsage) {
                [void]$cpuHistory.Add([double]$s.CPUUsage)
                while ($cpuHistory.Count -gt $historySize) { $cpuHistory.RemoveAt(0) }
            }
            $sample = [pscustomobject]@{ timestamp=(Get-Date).ToString('o'); cpu=$s.CPUUsage; ram=$s.RAMUsage; gpu=$s.GPUUsage; disk=$s.DiskUsage; downloadMbps=$rate.DownloadMbps; uploadMbps=$rate.UploadMbps }
            Write-PedroMetricHistory $sample

            Clear-Host
            Write-PedroHeader 'REAL-TIME MONITOR'
            Write-Host ('CPU  ' + (New-PedroBar $s.CPUUsage 24))
            Write-Host ('RAM  ' + (New-PedroBar $s.RAMUsage 24))
            Write-Host ('GPU  ' + (New-PedroBar $s.GPUUsage 24))
            Write-Host ('DISK ' + (New-PedroBar $s.DiskUsage 24))
            Write-Host ''
            Write-Host ('DOWNLOAD: {0}' -f $(if ($null -ne $rate.DownloadMbps) { "$($rate.DownloadMbps) Mbps" } else { 'N/A' }))
            Write-Host ('UPLOAD  : {0}' -f $(if ($null -ne $rate.UploadMbps) { "$($rate.UploadMbps) Mbps" } else { 'N/A' }))
            Write-Host ('UPTIME  : {0:00}d {1:00}:{2:00}:{3:00}' -f $s.Uptime.Days,$s.Uptime.Hours,$s.Uptime.Minutes,$s.Uptime.Seconds)
            Write-Host ''
            Show-PedroAsciiHistory $cpuHistory
            Write-Host ''
            Write-Host 'Press Q to exit. Metrics are sampled locally.' -ForegroundColor DarkGray

            $elapsed = 0
            while ($elapsed -lt ($interval * 10)) {
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if ($key.Key -eq [ConsoleKey]::Q) { Write-PedroLog 'Real-time monitor stopped'; return }
                }
                Start-Sleep -Milliseconds 100
                $elapsed++
            }
        } catch {
            Write-Host "[ERROR] Monitor update failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-PedroLog "Monitor update failed: $($_.Exception.Message)" 'ERROR'
            Start-Sleep -Seconds 1
        }
    }
}

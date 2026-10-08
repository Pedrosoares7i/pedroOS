$script:ProtectedProcesses = @('system','idle','registry','smss','csrss','wininit','services','lsass','winlogon','fontdrvhost','dwm','svchost','explorer')

function Get-PedroProcessMetrics {
    try {
        $logical = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
        if (-not $logical -or $logical -lt 1) { $logical = 1 }
        $perf = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -ErrorAction Stop | Where-Object { $_.Name -notmatch '^(_Total|Idle)$' }
        return $perf | ForEach-Object {
            [pscustomobject]@{
                Process = ($_.Name + '.exe')
                CPU = [Math]::Round(([double]$_.PercentProcessorTime / $logical), 1)
                RAMBytes = [double]$_.WorkingSetPrivate
                PID = $_.IDProcess
            }
        }
    } catch { return @() }
}

function Show-PedroProcesses {
    Write-PedroHeader 'TOP PROCESSES'
    $items = @(Get-PedroProcessMetrics)
    if ($items.Count -eq 0) {
        Write-Host 'Performance data unavailable. Falling back to memory ranking.' -ForegroundColor DarkYellow
        Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 @{N='Process';E={$_.ProcessName+'.exe'}}, Id, @{N='RAM';E={Format-PedroBytes $_.WorkingSet64}} | Format-Table -AutoSize
        return
    }
    $top = $items | Sort-Object CPU, RAMBytes -Descending | Select-Object -First 10 Process, PID, @{N='CPU %';E={$_.CPU}}, @{N='RAM';E={Format-PedroBytes $_.RAMBytes}}
    $top | Format-Table -AutoSize
}

function Show-PedroProcessDetail {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { Write-Host 'Usage: process <name>'; return }
    $clean = [IO.Path]::GetFileNameWithoutExtension($Name)
    Write-PedroHeader "PROCESS $clean"
    try {
        $p = @(Get-Process -Name $clean -ErrorAction Stop)
        $p | Select-Object ProcessName, Id, @{N='RAM';E={Format-PedroBytes $_.WorkingSet64}}, CPU, StartTime, Path | Format-Table -AutoSize
    } catch { Write-Host "Process not found: $clean" -ForegroundColor Yellow }
}

function Stop-PedroSafeProcess {
    param([string]$Name)

    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }

    $clean = [IO.Path]::GetFileNameWithoutExtension($Name).ToLowerInvariant()
    if ($script:ProtectedProcesses -contains $clean) {
        Write-PedroError "Blocked: '$clean' is protected by PEDRO SYSTEM."
        return $false
    }

    try {
        $targets = @(Get-Process -Name $clean -ErrorAction Stop)
        if ($targets.Count -eq 0) { return $false }
        foreach ($p in $targets) { Stop-Process -Id $p.Id -ErrorAction Stop }
        Write-PedroOk "Closed: $clean"
        Write-PedroLog "Closed process: $clean"
        return $true
    } catch {
        Write-PedroWarn "Unable to close '$clean': $($_.Exception.Message)"
        return $false
    }
}

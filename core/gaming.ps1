function Get-PedroRamUsageBytes {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $total = [Int64]$os.TotalVisibleMemorySize * 1KB
        $free = [Int64]$os.FreePhysicalMemory * 1KB
        return [Math]::Max(0, ($total - $free))
    } catch { return $null }
}

function Get-PedroRiotClientState {
    try {
        $riot = Get-Process -Name 'RiotClientServices','RiotClientUx','RiotClientUxRender' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($riot) { return 'RUNNING' }
        $info = Get-PedroAppInfo 'valorant'
        if ($info -and $info.Exists) { return 'FOUND' }
    } catch { }
    return 'N/A'
}

function Get-PedroVanguardState {
    try {
        $service = Get-Service -Name 'vgc' -ErrorAction SilentlyContinue
        if ($service) {
            if ($service.Status -eq 'Running') { return 'RUNNING' }
            return 'STOPPED'
        }
    } catch { }
    return 'N/A'
}

function Show-PedroGamingSystemSummary {
    $s = Get-PedroSystemSnapshot
    Write-PedroSection 'SYSTEM'
    Write-Host ("CPU    {0}" -f $(if ($null -ne $s.CPUUsage) { "$([Math]::Round($s.CPUUsage,1))%" } else { 'N/A' }))
    Write-Host ("RAM    {0}" -f $(if ($null -ne $s.RAMUsage) { "$([Math]::Round($s.RAMUsage,1))%" } else { 'N/A' }))
    Write-Host ("GPU    {0}" -f $(if ($null -ne $s.GPUUsage) { "$([Math]::Round($s.GPUUsage,1))%" } else { 'N/A' }))
}

function Start-PedroGamingProfile {
    param([string]$ProfileName)

    if ([string]::IsNullOrWhiteSpace($ProfileName)) {
        Write-PedroWarn 'Usage: gaming <profile>'
        return
    }

    $existingSession = Get-PedroGamingSession
    if ($existingSession) {
        Write-PedroWarn "A gaming session is already active: $($existingSession.profile)"
        Write-PedroInfo 'Use: gaming status | gaming restore'
        return
    }

    $profileNameNormalized = $ProfileName.ToLowerInvariant()
    $profile = Get-PedroGamingProfile $profileNameNormalized
    if (-not $profile) {
        Write-PedroError "Gaming profile not found: $ProfileName"
        return
    }

    $displayName = $profileNameNormalized
    if ($profile.PSObject.Properties.Name -contains 'displayName' -and -not [string]::IsNullOrWhiteSpace([string]$profile.displayName)) {
        $displayName = [string]$profile.displayName
    }

    $appName = [string]$profile.app
    $appInfo = Get-PedroAppInfo $appName

    Write-PedroHeader ("PEDRO GAMING MODE - " + $displayName.ToUpperInvariant())
    Show-PedroGamingSystemSummary
    Write-PedroSection 'PREPARING SESSION'

    if (-not $appInfo) {
        Write-PedroError "Application is not registered: $appName"
        return
    }
    if (-not $appInfo.Exists) {
        Write-PedroError "Configured executable was not found: $($appInfo.ResolvedPath)"
        return
    }

    Write-PedroOk "$displayName configured"

    if (($profile.PSObject.Properties.Name -contains 'checkRiotClient') -and [bool]$profile.checkRiotClient) {
        $riotState = Get-PedroRiotClientState
        if ($riotState -eq 'RUNNING') { Write-PedroOk 'Riot Client running' }
        elseif ($riotState -eq 'FOUND') { Write-PedroOk 'Riot Client executable found' }
        else { Write-PedroNa 'Riot Client not detected' }
    }

    if (($profile.PSObject.Properties.Name -contains 'checkVanguard') -and [bool]$profile.checkVanguard) {
        $vanguardState = Get-PedroVanguardState
        if ($vanguardState -eq 'RUNNING') { Write-PedroOk 'Vanguard service running' }
        elseif ($vanguardState -eq 'STOPPED') { Write-PedroWarn 'Vanguard service found but stopped' }
        else { Write-PedroNa 'Vanguard service not detected' }
    }

    $memoryBefore = Get-PedroRamUsageBytes
    $closedApps = New-Object System.Collections.ArrayList
    $preservedApps = New-Object System.Collections.ArrayList

    $keepApps = @()
    if ($profile.PSObject.Properties.Name -contains 'keepApps') { $keepApps = @($profile.keepApps) }

    $closeApps = @()
    if ($profile.PSObject.Properties.Name -contains 'closeApps') { $closeApps = @($profile.closeApps) }

    foreach ($app in $keepApps) {
        if (-not [string]::IsNullOrWhiteSpace([string]$app)) {
            [void]$preservedApps.Add(([string]$app).ToLowerInvariant())
        }
    }

    $initialSession = [ordered]@{
        profile = $profileNameNormalized
        displayName = $displayName
        startedAt = (Get-Date).ToUniversalTime().ToString('o')
        closedApps = @()
        preservedApps = @($preservedApps)
        memoryBefore = $memoryBefore
        memoryAfter = $null
        memoryFreed = $null
    }

    if (-not (Save-PedroGamingSession $initialSession)) {
        Write-PedroError 'Unable to save gaming session.'
        return
    }
    Write-PedroOk 'Session saved'

    Write-PedroSection 'BACKGROUND APPS'
    foreach ($app in $closeApps) {
        $appNameToClose = ([string]$app).ToLowerInvariant()
        if ([string]::IsNullOrWhiteSpace($appNameToClose)) { continue }

        if ($keepApps -contains $appNameToClose) {
            Write-PedroSkip "$appNameToClose - allowed"
            continue
        }

        if (-not (Test-PedroAppRunning $appNameToClose)) {
            Write-PedroSkip "$appNameToClose - not running"
            continue
        }

        if (Close-PedroApp $appNameToClose) {
            [void]$closedApps.Add($appNameToClose)
        } else {
            Write-PedroWarn "$appNameToClose was not closed"
        }
    }

    foreach ($app in $keepApps) {
        if (Test-PedroAppRunning ([string]$app)) {
            Write-PedroSkip "$app - allowed"
        }
    }

    Start-Sleep -Milliseconds 500
    $memoryAfter = Get-PedroRamUsageBytes
    $memoryFreed = $null
    if ($null -ne $memoryBefore -and $null -ne $memoryAfter) {
        $memoryFreed = [Math]::Max(0, ([Int64]$memoryBefore - [Int64]$memoryAfter))
    }

    $finalSession = [ordered]@{
        profile = $profileNameNormalized
        displayName = $displayName
        startedAt = $initialSession.startedAt
        closedApps = @($closedApps)
        preservedApps = @($preservedApps)
        memoryBefore = $memoryBefore
        memoryAfter = $memoryAfter
        memoryFreed = $memoryFreed
    }
    if (-not (Save-PedroGamingSession $finalSession)) {
        Write-PedroWarn 'Session details could not be updated.'
    }

    Write-PedroSection 'MEMORY'
    Write-Host ("Before: {0}" -f $(if ($null -ne $memoryBefore) { Format-PedroBytes $memoryBefore } else { 'N/A' }))
    Write-Host ("After : {0}" -f $(if ($null -ne $memoryAfter) { Format-PedroBytes $memoryAfter } else { 'N/A' }))
    Write-Host ("Freed : {0}" -f $(if ($null -ne $memoryFreed) { Format-PedroBytes $memoryFreed } else { 'N/A' }))

    Write-PedroSection ("Launching " + $displayName + '...')
    try {
        $launchArgs = @()
        if ($profile.PSObject.Properties.Name -contains 'launchArgs') { $launchArgs = @($profile.launchArgs) }

        if ($launchArgs.Count -gt 0) {
            Start-Process -FilePath $appInfo.ResolvedPath -ArgumentList $launchArgs | Out-Null
        } else {
            Start-Process -FilePath $appInfo.ResolvedPath | Out-Null
        }

        Write-PedroOk 'Gaming session started'
        Write-PedroLog ("Gaming session started: profile={0}; closedApps={1}; memoryFreed={2}" -f $profileNameNormalized,(@($closedApps) -join ','),$memoryFreed)
    } catch {
        Write-PedroError "Unable to launch $displayName: $($_.Exception.Message)"
        Write-PedroWarn 'The session was kept so closed applications can be restored.'
        Write-PedroLog "Gaming launch failed ($profileNameNormalized): $($_.Exception.Message)" 'ERROR'
    }
}

function Show-PedroGamingStatus {
    $session = Get-PedroGamingSession
    if (-not $session) {
        Write-PedroInfo 'No gaming session is currently active.'
        return
    }

    Write-PedroHeader 'GAMING SESSION'
    Write-Host ("Profile      : {0}" -f $session.profile)
    Write-Host 'Status       : ACTIVE'
    Write-Host ("Started      : {0}" -f $session.startedAt)

    Write-PedroSection 'Apps closed'
    $closedApps = @($session.closedApps)
    if ($closedApps.Count -eq 0) { Write-Host 'None' }
    else { $closedApps | ForEach-Object { Write-Host ("- " + $_) } }

    Write-PedroSection 'Apps preserved'
    $preservedApps = @($session.preservedApps)
    if ($preservedApps.Count -eq 0) { Write-Host 'None' }
    else { $preservedApps | ForEach-Object { Write-Host ("- " + $_) } }

    Write-PedroSection 'Memory'
    Write-Host ("Freed        : {0}" -f $(if ($null -ne $session.memoryFreed) { Format-PedroBytes ([double]$session.memoryFreed) } else { 'N/A' }))
}

function Restore-PedroGamingSession {
    $session = Get-PedroGamingSession
    if (-not $session) {
        Write-PedroInfo 'No gaming session is currently active.'
        return
    }

    Write-PedroHeader 'RESTORING SESSION'
    $closedApps = @($session.closedApps)
    $failures = New-Object System.Collections.ArrayList

    if ($closedApps.Count -eq 0) {
        Write-PedroInfo 'No applications were closed by this session.'
    } else {
        foreach ($app in $closedApps) {
            if (Open-PedroApp ([string]$app)) {
                Write-PedroOk "$app restored"
            } else {
                [void]$failures.Add([string]$app)
                Write-PedroWarn "$app could not be restored"
            }
        }
    }

    foreach ($app in @($session.preservedApps)) {
        Write-PedroSkip "$app was preserved and was not reopened"
    }

    if (Remove-PedroGamingSession) {
        Write-PedroOk 'Gaming session restored and closed'
    } else {
        Write-PedroWarn 'Applications were processed, but the session file could not be removed.'
    }

    if ($failures.Count -gt 0) {
        Write-PedroWarn ("Restore completed with failures: " + ($failures -join ', '))
        Write-PedroLog ("Gaming restore completed with failures: " + ($failures -join ',')) 'WARN'
    } else {
        Write-PedroLog "Gaming session restored: $($session.profile)"
    }
}

function Show-PedroGamingMenu {
    while ($true) {
        $s = Get-PedroSystemSnapshot
        Write-PedroHeader 'PEDRO GAMING MODE'
        Write-Host ("CPU: {0}" -f $(if ($null -ne $s.CPUUsage) { "$([Math]::Round($s.CPUUsage,1))%" } else {'N/A'}))
        Write-Host ("RAM: {0}" -f $(if ($null -ne $s.RAMUsage) { "$([Math]::Round($s.RAMUsage,1))%" } else {'N/A'}))
        Write-Host ("GPU: {0}" -f $(if ($null -ne $s.GPUUsage) { "$([Math]::Round($s.GPUUsage,1))%" } else {'N/A'}))
        Write-Host ''
        Write-Host '[1] Start Valorant profile'
        Write-Host '[2] Gaming session status'
        Write-Host '[3] Restore gaming session'
        Write-Host '[4] Launch Steam'
        Write-Host '[5] Launch Discord'
        Write-Host '[6] Monitor system'
        Write-Host '[0] Exit'
        $choice = Read-Host 'Select'
        switch ($choice) {
            '1' { Start-PedroGamingProfile 'valorant'; Read-Host 'Press Enter to continue' | Out-Null }
            '2' { Show-PedroGamingStatus; Read-Host 'Press Enter to continue' | Out-Null }
            '3' { Restore-PedroGamingSession; Read-Host 'Press Enter to continue' | Out-Null }
            '4' { Open-PedroApp 'steam' | Out-Null; Read-Host 'Press Enter to continue' | Out-Null }
            '5' { Open-PedroApp 'discord' | Out-Null; Read-Host 'Press Enter to continue' | Out-Null }
            '6' { Start-PedroMonitor }
            '0' { return }
            default { Write-PedroWarn 'Invalid option.' }
        }
    }
}

function Show-PedroGaming {
    param([string[]]$InputArgs)

    if ($null -eq $InputArgs -or $InputArgs.Count -eq 0) {
        Show-PedroGamingMenu
        return
    }

    $action = ([string]$InputArgs[0]).ToLowerInvariant()
    switch ($action) {
        'status' { Show-PedroGamingStatus; return }
        'restore' { Restore-PedroGamingSession; return }
        'close' {
            if ($InputArgs.Count -lt 2) { Write-PedroWarn 'Usage: gaming close <app>' }
            else { Close-PedroApp ([string]$InputArgs[1]) | Out-Null }
            return
        }
        default { Start-PedroGamingProfile $action; return }
    }
}

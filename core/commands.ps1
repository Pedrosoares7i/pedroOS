function Show-PedroHelp {
    param([string]$Command)
    if (-not [string]::IsNullOrWhiteSpace($Command)) {
        $details = @{
            'status'='status - Displays OS, CPU, RAM, GPU, disk, network and uptime.'
            'monitor'='monitor - Starts live local monitoring. Press Q to return.'
            'apps'='apps | apps add <name> "<path>" - Lists or registers applications.'
            'alias'='alias | alias add <alias> <app> | alias remove <alias> - Manages direct app aliases.'
            'open'='open <app> - Opens an application registered in config/apps.json.'
            'close'='close <app> - Safely closes a non-critical registered process.'
            'processes'='processes - Shows top processes by current CPU and RAM.'
            'process'='process <name> - Shows details about a process.'
            'network'='network - Shows adapters, IP, gateway, DNS and internet state.'
            'ping'='ping <host> - Tests latency with four ICMP requests.'
            'dns'='dns <domain> - Resolves DNS records using Resolve-DnsName.'
            'disk'='disk - Displays local fixed drives, used/free space and percentage.'
            'security'='security - Reads Defender, firewall, antivirus and latest hotfix status.'
            'clean'='clean - Opens the safe maintenance menu. Destructive actions are not automatic.'
            'gaming'='gaming | gaming <profile> | gaming status | gaming restore | gaming close <app> - Starts and manages gaming profiles.'
            'report'='report - Generates a local TXT system report under reports/.'
            'settings'='settings | settings set <key> <value> - Views or edits basic settings.'
            'diagnostics'='diagnostics - Runs a compact health diagnostic without changing Windows.'
        }
        if ($details.ContainsKey($Command.ToLowerInvariant())) { Write-Host $details[$Command.ToLowerInvariant()]; return }
        Write-Host "No help found for '$Command'." -ForegroundColor Yellow; return
    }

    Write-PedroHeader 'COMMAND CENTER'
    @'
SYSTEM
  status        General computer status
  monitor       Real-time monitor
  processes     Top active processes
  process       Inspect a specific process
  diagnostics   Quick health diagnostic

APPLICATIONS
  apps          Registered applications
  alias         Manage application aliases
  open          Open application
  close         Close application safely

NETWORK
  network       Network information
  ping          Test connection
  dns           DNS lookup

STORAGE
  disk          Storage information

SECURITY
  security      Read-only security checks

MAINTENANCE
  clean         Safe maintenance menu
  repair        Alias for maintenance menu

GAMING
  gaming                Open gaming menu
  gaming <profile>      Start a gaming profile
  gaming status         Show active gaming session
  gaming restore        Reopen apps closed by PEDRO SYSTEM
  gaming close <app>    Close a safe app manually

TOOLS
  report        Generate TXT report
  settings      View/change settings
  clear         Clear terminal
  exit          Exit PEDRO SYSTEM
'@ | Write-Host
    Write-Host 'Use: help <command>' -ForegroundColor DarkGray
}

function Show-PedroSettings {
    param([string[]]$Args)
    $settings = Get-PedroSettings
    if ($Args.Count -eq 0) { Write-PedroHeader 'SETTINGS'; $settings | Format-List; return }
    if ($Args[0] -ne 'set' -or $Args.Count -lt 3) { Write-Host 'Usage: settings set <key> <value>'; return }
    $key = $Args[1]; $valueText = ($Args[2..($Args.Count-1)] -join ' ')
    $allowed = @('systemName','monitorInterval','historySize','theme','logMaxMB','metricHistoryMaxLines')
    if ($allowed -notcontains $key) { Write-Host "Setting not editable here: $key" -ForegroundColor Yellow; return }
    $value = $valueText
    if ($key -in @('monitorInterval','historySize','logMaxMB','metricHistoryMaxLines')) {
        $num = 0
        if (-not [int]::TryParse($valueText, [ref]$num)) { Write-Host 'Value must be an integer.' -ForegroundColor Yellow; return }
        $value = $num
    }
    $map = [ordered]@{}
    foreach ($p in $settings.PSObject.Properties) { $map[$p.Name] = $p.Value }
    $map[$key] = $value
    if (Save-PedroJson $map $script:SettingsFile) { Write-Host "Updated: $key = $value" -ForegroundColor Green; Write-PedroLog "Setting changed: $key" }
}

function Invoke-PedroDiagnostics {
    Write-PedroHeader 'DIAGNOSTICS'
    $s = Get-PedroSystemSnapshot
    $warnings = New-Object System.Collections.ArrayList
    if ($null -ne $s.CPUUsage -and $s.CPUUsage -ge 90) { [void]$warnings.Add('CPU usage is very high.') }
    if ($null -ne $s.RAMUsage -and $s.RAMUsage -ge 90) { [void]$warnings.Add('RAM usage is very high.') }
    if ($null -ne $s.DiskUsage -and $s.DiskUsage -ge 90) { [void]$warnings.Add('System drive is above 90% usage.') }
    if ($s.Internet -ne 'ONLINE') { [void]$warnings.Add('Internet check is offline.') }
    Write-Host "CPU      : $(New-PedroBar $s.CPUUsage)"
    Write-Host "RAM      : $(New-PedroBar $s.RAMUsage)"
    Write-Host "Disk     : $(New-PedroBar $s.DiskUsage)"
    Write-Host "Internet : $($s.Internet)"
    if ($warnings.Count -eq 0) { Write-Host 'No obvious issues detected.' -ForegroundColor Green }
    else { Write-Host ''; $warnings | ForEach-Object { Write-Host "[WARN] $_" -ForegroundColor Yellow } }
}

function New-PedroReport {
    try {
        Initialize-PedroDirectories
        $s = Get-PedroSystemSnapshot
        $path = Join-Path $script:ReportsDir ('report-' + (Get-Date -Format 'yyyy-MM-dd-HHmmss') + '.txt')
        $lines = New-Object System.Collections.Generic.List[string]
        $lines.Add('PEDRO SYSTEM REPORT')
        $lines.Add(('Generated: ' + (Get-Date)))
        $lines.Add(('Computer: ' + $s.Computer))
        $lines.Add(('User: ' + $s.User))
        $lines.Add(('OS: ' + $s.OS + ' ' + $s.Version))
        $lines.Add(('CPU: ' + $s.CPUName + ' | Usage: ' + $(if ($null -ne $s.CPUUsage) { "$($s.CPUUsage)%" } else {'N/A'})))
        $lines.Add(('RAM: ' + $(if ($null -ne $s.RAMTotal) { (Format-PedroBytes $s.RAMTotal) } else {'N/A'}) + ' | Usage: ' + $(if ($null -ne $s.RAMUsage) { ('{0:N1}%' -f $s.RAMUsage) } else {'N/A'})))
        $lines.Add(('GPU: ' + $s.GPUName + ' | Usage: ' + $(if ($null -ne $s.GPUUsage) { "$($s.GPUUsage)%" } else {'N/A'})))
        $lines.Add(('IPv4: ' + $s.IPv4 + ' | Internet: ' + $s.Internet))
        $sec = Get-PedroSecuritySnapshot
        $lines.Add(('Security: Defender={0}; RealTime={1}; Firewall={2}; Antivirus={3}; LatestHotfix={4}' -f $sec.Defender,$sec.RealTimeProtection,$sec.Firewall,$sec.Antivirus,$sec.LatestHotfix))
        $lines.Add(('Uptime: {0:00}d {1:00}:{2:00}:{3:00}' -f $s.Uptime.Days,$s.Uptime.Hours,$s.Uptime.Minutes,$s.Uptime.Seconds))
        $lines.Add('')
        $lines.Add('DRIVES')
        try {
            Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' | ForEach-Object {
                $lines.Add(('{0} Total={1} Free={2}' -f $_.DeviceID,(Format-PedroBytes $_.Size),(Format-PedroBytes $_.FreeSpace)))
            }
        } catch { $lines.Add('N/A') }
        $lines.Add('')
        $lines.Add('TOP PROCESSES')
        $pm = @(Get-PedroProcessMetrics | Sort-Object CPU, RAMBytes -Descending | Select-Object -First 10)
        if ($pm.Count -gt 0) { foreach ($p in $pm) { $lines.Add(('{0} PID={1} CPU={2}% RAM={3}' -f $p.Process,$p.PID,$p.CPU,(Format-PedroBytes $p.RAMBytes))) } } else { $lines.Add('N/A') }
        $lines | Set-Content -Path $path -Encoding UTF8
        Write-Host "Report generated: $path" -ForegroundColor Green
        Write-PedroLog "Report generated: $path"
    } catch { Write-Host "Report generation failed: $($_.Exception.Message)" -ForegroundColor Red; Write-PedroLog "Report failed: $($_.Exception.Message)" 'ERROR' }
}

function Invoke-PedroCommand {
    param([string]$Line)
    if ([string]::IsNullOrWhiteSpace($Line)) { return $true }
    $tokens = @([regex]::Matches($Line, '"[^"]*"|\S+') | ForEach-Object { $_.Value.Trim('"') })
    if ($tokens.Count -eq 0) { return $true }
    $command = $tokens[0].ToLowerInvariant()
    $commandArgs = @()
    if ($tokens.Count -gt 1) {
        $commandArgs = @($tokens | Select-Object -Skip 1)
    }

    $aliases = Get-PedroAliases
    $aliasProp = $aliases.PSObject.Properties[$command]
    if ($aliasProp) {
        Open-PedroApp ([string]$aliasProp.Value) | Out-Null
        return $true
    }

    $dispatcher = @{
        'help'        = { Show-PedroHelp $(if ($commandArgs.Count -gt 0) {$commandArgs[0]} else {$null}) }
        'status'      = { Show-PedroStatus }
        'monitor'     = { Start-PedroMonitor }
        'apps'        = { if ($commandArgs.Count -ge 3 -and $commandArgs[0] -eq 'add') { Add-PedroApp $commandArgs[1] ($commandArgs[2..($commandArgs.Count-1)] -join ' ') } else { Show-PedroApps } }
        'alias'       = { if ($commandArgs.Count -ge 3 -and $commandArgs[0] -eq 'add') { Set-PedroAlias $commandArgs[1] $commandArgs[2] } elseif ($commandArgs.Count -ge 2 -and $commandArgs[0] -eq 'remove') { Remove-PedroAlias $commandArgs[1] } else { Show-PedroAliases } }
        'aliases'     = { Show-PedroAliases }
        'open'        = { if ($commandArgs.Count) { Open-PedroApp $commandArgs[0] | Out-Null } else { Write-Host 'Usage: open <app>' } }
        'close'       = { if ($commandArgs.Count) { Close-PedroApp $commandArgs[0] | Out-Null } else { Write-Host 'Usage: close <app>' } }
        'processes'   = { Show-PedroProcesses }
        'process'     = { Show-PedroProcessDetail $(if ($commandArgs.Count) {$commandArgs[0]} else {$null}) }
        'network'     = { Show-PedroNetwork }
        'ping'        = { Invoke-PedroPing $(if ($commandArgs.Count) {$commandArgs[0]} else {$null}) }
        'dns'         = { Invoke-PedroDns $(if ($commandArgs.Count) {$commandArgs[0]} else {$null}) }
        'disk'        = { Show-PedroDisk }
        'security'    = { Show-PedroSecurity }
        'clean'       = { Show-PedroMaintenance }
        'repair'      = { Show-PedroMaintenance }
        'gaming'      = { Show-PedroGaming $commandArgs }
        'report'      = { New-PedroReport }
        'settings'    = { Show-PedroSettings $commandArgs }
        'diagnostics' = { Invoke-PedroDiagnostics }
        'health'      = { Invoke-PedroDiagnostics }
        'clear'       = { Clear-Host }
        'cls'         = { Clear-Host }
        'exit'        = { return $false }
        'quit'        = { return $false }
    }

    if (-not $dispatcher.ContainsKey($command)) {
        Write-Host "Unknown command: $command. Type 'help'." -ForegroundColor Yellow
        return $true
    }
    try {
        Write-PedroLog "Command: $command"
        $result = & $dispatcher[$command]
        if (($command -eq 'exit' -or $command -eq 'quit') -and $result -eq $false) { return $false }
    } catch {
        Write-Host "[ERROR] Command failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-PedroLog "Command '$command' failed: $($_.Exception.Message)" 'ERROR'
    }
    return $true
}

# Common helpers for PEDRO SYSTEM (PowerShell 5.1 compatible)

$script:PedroRoot = Split-Path -Parent $PSScriptRoot
$script:ConfigDir = Join-Path $script:PedroRoot 'config'
$script:LogsDir = Join-Path $script:PedroRoot 'logs'
$script:ReportsDir = Join-Path $script:PedroRoot 'reports'
$script:HistoryDir = Join-Path $script:PedroRoot 'data\history'
$script:LogFile = Join-Path $script:LogsDir 'system.log'
$script:SettingsFile = Join-Path $script:ConfigDir 'settings.json'
$script:AppsFile = Join-Path $script:ConfigDir 'apps.json'
$script:AliasesFile = Join-Path $script:ConfigDir 'aliases.json'

function Initialize-PedroDirectories {
    @($script:ConfigDir, $script:LogsDir, $script:ReportsDir, $script:HistoryDir) | ForEach-Object {
        if (-not (Test-Path $_)) { New-Item -ItemType Directory -Path $_ -Force | Out-Null }
    }
    if (-not (Test-Path $script:LogFile)) { New-Item -ItemType File -Path $script:LogFile -Force | Out-Null }
}

function Get-PedroSettings {
    try {
        if (Test-Path $script:SettingsFile) {
            return (Get-Content $script:SettingsFile -Raw -ErrorAction Stop | ConvertFrom-Json)
        }
    } catch { }
    return [pscustomobject]@{ systemName='PEDRO SYSTEM'; monitorInterval=1; historySize=60; theme='dark'; logMaxMB=2; metricHistoryMaxLines=5000 }
}

function Save-PedroJson {
    param([Parameter(Mandatory=$true)]$Data, [Parameter(Mandatory=$true)][string]$Path)
    try {
        $Data | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
        return $true
    } catch {
        Write-Host "[ERROR] Unable to save configuration: $($_.Exception.Message)" -ForegroundColor Red
        Write-PedroLog "Save JSON failed ($Path): $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

function Write-PedroLog {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR')][string]$Level='INFO')
    try {
        Initialize-PedroDirectories
        $settings = Get-PedroSettings
        $maxMB = 2
        if ($settings.PSObject.Properties.Name -contains 'logMaxMB') { $maxMB = [double]$settings.logMaxMB }
        if ((Test-Path $script:LogFile) -and ((Get-Item $script:LogFile).Length -gt ($maxMB * 1MB))) {
            $archive = Join-Path $script:LogsDir ('system-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')
            Move-Item $script:LogFile $archive -Force
        }
        $line = "{0} [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
        Add-Content -Path $script:LogFile -Value $line -Encoding UTF8
    } catch { }
}

function Test-PedroAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Confirm-PedroAction {
    param([string]$Message='Continue?')
    $answer = Read-Host "$Message [Y/N]"
    return ($answer -match '^(y|yes|s|sim)$')
}

function Write-PedroHeader {
    param([string]$Title)
    Write-Host ''
    Write-Host ('=' * 60) -ForegroundColor DarkCyan
    Write-Host ('  ' + $Title) -ForegroundColor Cyan
    Write-Host ('=' * 60) -ForegroundColor DarkCyan
}

function Format-PedroBytes {
    param([double]$Bytes)
    if ($Bytes -ge 1TB) { return ('{0:N2} TB' -f ($Bytes / 1TB)) }
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N2} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N2} KB' -f ($Bytes / 1KB)) }
    return ('{0:N0} B' -f $Bytes)
}

function New-PedroBar {
    param([Nullable[double]]$Value, [int]$Width=20)
    if ($null -eq $Value) { return ('[' + ('-' * $Width) + '] N/A') }
    $v = [Math]::Max(0, [Math]::Min(100, [double]$Value))
    $filled = [int][Math]::Round(($v / 100) * $Width)
    return ('[' + ('#' * $filled) + ('-' * ($Width - $filled)) + ('] {0,5:N1}%' -f $v))
}

function Get-PedroInternetState {
    try {
        $ok = Test-Connection -ComputerName '1.1.1.1' -Count 1 -Quiet -ErrorAction Stop
        if ($ok) { return 'ONLINE' }
    } catch { }
    return 'OFFLINE'
}

function Get-PedroGpuUsage {
    try {
        $counter = Get-Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction Stop
        $samples = @($counter.CounterSamples | Where-Object { $_.CookedValue -gt 0 })
        if ($samples.Count -eq 0) { return $null }
        $sum = ($samples | Measure-Object -Property CookedValue -Sum).Sum
        return [Math]::Min(100, [Math]::Round([double]$sum, 1))
    } catch { return $null }
}

function Write-PedroMetricHistory {
    param($Sample)
    try {
        Initialize-PedroDirectories
        $path = Join-Path $script:HistoryDir ('metrics-' + (Get-Date -Format 'yyyy-MM-dd') + '.jsonl')
        ($Sample | ConvertTo-Json -Compress) | Add-Content -Path $path -Encoding UTF8
        $settings = Get-PedroSettings
        $maxLines = 5000
        if ($settings.PSObject.Properties.Name -contains 'metricHistoryMaxLines') { $maxLines = [int]$settings.metricHistoryMaxLines }
        $lines = @(Get-Content $path -ErrorAction SilentlyContinue)
        if ($lines.Count -gt $maxLines) {
            $lines | Select-Object -Last $maxLines | Set-Content $path -Encoding UTF8
        }
    } catch { Write-PedroLog "Metric history write failed: $($_.Exception.Message)" 'WARN' }
}

function Get-PedroUptime {
    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        return (Get-Date) - $os.LastBootUpTime
    } catch { return [TimeSpan]::Zero }
}

function Get-PedroPrimaryIPv4 {
    try {
        $cfg = Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
        if ($cfg -and $cfg.IPv4Address) { return $cfg.IPv4Address.IPAddress }
    } catch { }
    return 'N/A'
}

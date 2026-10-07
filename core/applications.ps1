function Resolve-PedroAppPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $expanded = [Environment]::ExpandEnvironmentVariables($Path)
    try {
        $matches = @(Resolve-Path -Path $expanded -ErrorAction Stop | Sort-Object Path -Descending)
        if ($matches.Count -gt 0) { return $matches[0].Path }
    } catch { }
    return $expanded
}

function Get-PedroApps {
    try {
        if (Test-Path $script:AppsFile) { return (Get-Content $script:AppsFile -Raw | ConvertFrom-Json) }
    } catch { Write-PedroLog "Apps config load failed: $($_.Exception.Message)" 'ERROR' }
    return [pscustomobject]@{}
}

function Show-PedroApps {
    Write-PedroHeader 'APPLICATIONS'
    $apps = Get-PedroApps
    $props = @($apps.PSObject.Properties)
    if ($props.Count -eq 0) { Write-Host 'No applications configured.'; return }
    $props | ForEach-Object { [pscustomobject]@{ Name=$_.Name; Path=$_.Value; Exists=(Test-Path (Resolve-PedroAppPath ([string]$_.Value))) } } | Format-Table -AutoSize
    Write-Host 'Tip: apps add <name> "C:\path\app.exe"' -ForegroundColor DarkGray
}

function Add-PedroApp {
    param([string]$Name, [string]$Path)
    if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Path)) { Write-Host 'Usage: apps add <name> "C:\path\app.exe"'; return }
    $resolvedInput = Resolve-PedroAppPath $Path
    if (-not (Test-Path $resolvedInput)) { Write-Host "Executable not found: $Path" -ForegroundColor Yellow; return }
    $apps = Get-PedroApps
    $map = [ordered]@{}
    foreach ($p in $apps.PSObject.Properties) { $map[$p.Name] = $p.Value }
    $map[$Name.ToLowerInvariant()] = $Path
    if (Save-PedroJson $map $script:AppsFile) { Write-Host "Application saved: $Name" -ForegroundColor Green; Write-PedroLog "App config added: $Name" }
}

function Open-PedroApp {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { Write-Host 'Usage: open <app>'; return }
    $apps = Get-PedroApps
    $prop = $apps.PSObject.Properties[$Name.ToLowerInvariant()]
    if (-not $prop) { Write-Host "Application not registered: $Name" -ForegroundColor Yellow; return }
    $path = Resolve-PedroAppPath ([string]$prop.Value)
    if (-not (Test-Path $path)) { Write-Host "Executable does not exist: $path" -ForegroundColor Red; return }
    $procName = [IO.Path]::GetFileNameWithoutExtension($path)
    if (Get-Process -Name $procName -ErrorAction SilentlyContinue) {
        Write-Host "$Name is already running." -ForegroundColor Yellow
        return
    }
    try {
        Start-Process -FilePath $path | Out-Null
        Write-Host "Opened: $Name" -ForegroundColor Green
        Write-PedroLog "Opened app: $Name"
    } catch { Write-Host "Unable to open '$Name': $($_.Exception.Message)" -ForegroundColor Red }
}

function Close-PedroApp {
    param([string]$Name)
    $apps = Get-PedroApps
    $prop = $apps.PSObject.Properties[$Name.ToLowerInvariant()]
    if ($prop) {
        $resolved = Resolve-PedroAppPath ([string]$prop.Value)
        $Name = [IO.Path]::GetFileNameWithoutExtension($resolved)
    }
    Stop-PedroSafeProcess $Name
}

function Get-PedroAliases {
    try {
        if (Test-Path $script:AliasesFile) { return (Get-Content $script:AliasesFile -Raw | ConvertFrom-Json) }
    } catch { }
    return [pscustomobject]@{}
}

function Save-PedroAliases {
    param($Aliases)
    return (Save-PedroJson $Aliases $script:AliasesFile)
}

function Show-PedroAliases {
    Write-PedroHeader 'ALIASES'
    $aliases = Get-PedroAliases
    $props = @($aliases.PSObject.Properties)
    if ($props.Count -eq 0) { Write-Host 'No aliases configured.'; return }
    $props | ForEach-Object { [pscustomobject]@{ Alias=$_.Name; Application=$_.Value } } | Format-Table -AutoSize
    Write-Host 'Use: alias add <alias> <app> | alias remove <alias>' -ForegroundColor DarkGray
}

function Set-PedroAlias {
    param([string]$AliasName, [string]$AppName)
    if ([string]::IsNullOrWhiteSpace($AliasName) -or [string]::IsNullOrWhiteSpace($AppName)) { Write-Host 'Usage: alias add <alias> <app>'; return }
    $apps = Get-PedroApps
    if (-not $apps.PSObject.Properties[$AppName.ToLowerInvariant()]) { Write-Host "Application not registered: $AppName" -ForegroundColor Yellow; return }
    $aliases = Get-PedroAliases
    $map = [ordered]@{}
    foreach ($p in $aliases.PSObject.Properties) { $map[$p.Name] = $p.Value }
    $map[$AliasName.ToLowerInvariant()] = $AppName.ToLowerInvariant()
    if (Save-PedroAliases $map) { Write-Host "Alias saved: $AliasName -> $AppName" -ForegroundColor Green; Write-PedroLog "Alias added: $AliasName -> $AppName" }
}

function Remove-PedroAlias {
    param([string]$AliasName)
    if ([string]::IsNullOrWhiteSpace($AliasName)) { Write-Host 'Usage: alias remove <alias>'; return }
    $aliases = Get-PedroAliases
    $map = [ordered]@{}
    $found = $false
    foreach ($p in $aliases.PSObject.Properties) {
        if ($p.Name -ieq $AliasName) { $found = $true } else { $map[$p.Name] = $p.Value }
    }
    if (-not $found) { Write-Host "Alias not found: $AliasName" -ForegroundColor Yellow; return }
    if (Save-PedroAliases $map) { Write-Host "Alias removed: $AliasName" -ForegroundColor Green; Write-PedroLog "Alias removed: $AliasName" }
}

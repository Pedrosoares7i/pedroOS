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

function Get-PedroAppInfo {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }

    $apps = Get-PedroApps
    $prop = $apps.PSObject.Properties[$Name.ToLowerInvariant()]
    if (-not $prop) { return $null }

    $path = Resolve-PedroAppPath ([string]$prop.Value)
    $processName = $null
    if (-not [string]::IsNullOrWhiteSpace($path)) {
        $processName = [IO.Path]::GetFileNameWithoutExtension($path)
    }

    return [pscustomobject]@{
        Name = $Name.ToLowerInvariant()
        ConfiguredPath = [string]$prop.Value
        ResolvedPath = $path
        ProcessName = $processName
        Exists = (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path $path))
    }
}

function Test-PedroAppRunning {
    param([string]$Name)
    $info = Get-PedroAppInfo $Name
    if (-not $info -or [string]::IsNullOrWhiteSpace($info.ProcessName)) { return $false }
    return ($null -ne (Get-Process -Name $info.ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1))
}

function Show-PedroApps {
    Write-PedroHeader 'APPLICATIONS'
    $apps = Get-PedroApps
    $props = @($apps.PSObject.Properties)
    if ($props.Count -eq 0) { Write-Host 'No applications configured.'; return }
    $props | ForEach-Object {
        $info = Get-PedroAppInfo $_.Name
        [pscustomobject]@{ Name=$_.Name; Path=$_.Value; Exists=$info.Exists }
    } | Format-Table -AutoSize
    Write-Host 'Tip: apps add <name> "C:\path\app.exe"' -ForegroundColor DarkGray
}

function Add-PedroApp {
    param([string]$Name, [string]$Path)
    if ([string]::IsNullOrWhiteSpace($Name) -or [string]::IsNullOrWhiteSpace($Path)) { Write-Host 'Usage: apps add <name> "C:\path\app.exe"'; return }
    $resolvedInput = Resolve-PedroAppPath $Path
    if (-not (Test-Path $resolvedInput)) { Write-PedroWarn "Executable not found: $Path"; return }
    $apps = Get-PedroApps
    $map = [ordered]@{}
    foreach ($p in $apps.PSObject.Properties) { $map[$p.Name] = $p.Value }
    $map[$Name.ToLowerInvariant()] = $Path
    if (Save-PedroJson $map $script:AppsFile) { Write-PedroOk "Application saved: $Name"; Write-PedroLog "App config added: $Name" }
}

function Open-PedroApp {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { Write-Host 'Usage: open <app>'; return $false }

    $info = Get-PedroAppInfo $Name
    if (-not $info) { Write-PedroWarn "Application not registered: $Name"; return $false }
    if (-not $info.Exists) { Write-PedroError "Executable does not exist: $($info.ResolvedPath)"; return $false }

    if (Test-PedroAppRunning $Name) {
        Write-PedroWarn "$Name is already running."
        return $true
    }

    try {
        Start-Process -FilePath $info.ResolvedPath | Out-Null
        Write-PedroOk "Opened: $Name"
        Write-PedroLog "Opened app: $Name"
        return $true
    } catch {
        Write-PedroError "Unable to open '$Name': $($_.Exception.Message)"
        return $false
    }
}

function Close-PedroApp {
    param([string]$Name)
    $info = Get-PedroAppInfo $Name
    if ($info) {
        return (Stop-PedroSafeProcess $info.ProcessName)
    }
    return (Stop-PedroSafeProcess $Name)
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
    if (-not $apps.PSObject.Properties[$AppName.ToLowerInvariant()]) { Write-PedroWarn "Application not registered: $AppName"; return }
    $aliases = Get-PedroAliases
    $map = [ordered]@{}
    foreach ($p in $aliases.PSObject.Properties) { $map[$p.Name] = $p.Value }
    $map[$AliasName.ToLowerInvariant()] = $AppName.ToLowerInvariant()
    if (Save-PedroAliases $map) { Write-PedroOk "Alias saved: $AliasName -> $AppName"; Write-PedroLog "Alias added: $AliasName -> $AppName" }
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
    if (-not $found) { Write-PedroWarn "Alias not found: $AliasName"; return }
    if (Save-PedroAliases $map) { Write-PedroOk "Alias removed: $AliasName"; Write-PedroLog "Alias removed: $AliasName" }
}

function Initialize-PedroGamingConfig {
    if (Test-Path $script:GamingConfigFile) { return }

    $defaultConfig = [ordered]@{
        profiles = [ordered]@{
            valorant = [ordered]@{
                displayName = 'Valorant'
                app = 'valorant'
                closeApps = @('chrome','vscode')
                keepApps = @('discord')
                checkRiotClient = $true
                checkVanguard = $true
                launchArgs = @('--launch-product=valorant','--launch-patchline=live')
            }
            minecraft = [ordered]@{
                displayName = 'Minecraft'
                app = 'minecraft'
                closeApps = @('chrome')
                keepApps = @()
            }
            cs2 = [ordered]@{
                displayName = 'Counter-Strike 2'
                app = 'steam'
                closeApps = @('chrome','discord')
                keepApps = @()
            }
            fortnite = [ordered]@{
                displayName = 'Fortnite'
                app = 'epic'
                closeApps = @('chrome')
                keepApps = @()
            }
        }
    }

    if (Save-PedroJson $defaultConfig $script:GamingConfigFile) {
        Write-PedroLog 'Default gaming configuration created'
    }
}

function Get-PedroGamingConfig {
    Initialize-PedroGamingConfig
    try {
        return (Get-Content $script:GamingConfigFile -Raw -ErrorAction Stop | ConvertFrom-Json)
    } catch {
        Write-PedroLog "Gaming config load failed: $($_.Exception.Message)" 'ERROR'
        return [pscustomobject]@{ profiles = [pscustomobject]@{} }
    }
}

function Get-PedroGamingProfile {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $null }
    $config = Get-PedroGamingConfig
    if (-not $config -or -not $config.profiles) { return $null }
    return $config.profiles.PSObject.Properties[$Name.ToLowerInvariant()].Value
}

function Get-PedroGamingSession {
    try {
        if (Test-Path $script:GamingSessionFile) {
            return (Get-Content $script:GamingSessionFile -Raw -ErrorAction Stop | ConvertFrom-Json)
        }
    } catch {
        Write-PedroLog "Gaming session load failed: $($_.Exception.Message)" 'ERROR'
    }
    return $null
}

function Save-PedroGamingSession {
    param([Parameter(Mandatory=$true)]$Session)
    Initialize-PedroDirectories
    return (Save-PedroJson $Session $script:GamingSessionFile)
}

function Remove-PedroGamingSession {
    try {
        if (Test-Path $script:GamingSessionFile) {
            Remove-Item -LiteralPath $script:GamingSessionFile -Force -ErrorAction Stop
        }
        return $true
    } catch {
        Write-PedroLog "Gaming session removal failed: $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

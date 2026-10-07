function Get-PedroSecuritySnapshot {
    $defender = 'N/A'; $realtime = 'N/A'; $antivirus = 'N/A'; $firewall = 'N/A'; $latestHotfix = 'N/A'
    try {
        if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
            $mp = Get-MpComputerStatus -ErrorAction Stop
            $defender = if ($mp.AMServiceEnabled) { 'OK' } else { 'OFF' }
            $realtime = if ($mp.RealTimeProtectionEnabled) { 'OK' } else { 'OFF' }
        }
    } catch { }
    try {
        if (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue) {
            $profiles = @(Get-NetFirewallProfile -ErrorAction Stop)
            $firewall = if (($profiles | Where-Object { -not $_.Enabled }).Count -eq 0) { 'OK' } else { 'CHECK' }
        }
    } catch { }
    try {
        $av = @(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop)
        if ($av.Count -gt 0) { $antivirus = ($av.displayName -join ', ') }
    } catch { }
    try {
        $hotfix = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1
        if ($hotfix) { $latestHotfix = ('{0} ({1:d})' -f $hotfix.HotFixID, $hotfix.InstalledOn) }
    } catch { }
    [pscustomobject]@{
        Defender = $defender
        RealTimeProtection = $realtime
        Firewall = $firewall
        Antivirus = $antivirus
        LatestHotfix = $latestHotfix
    }
}

function Show-PedroSecurity {
    Write-PedroHeader 'SECURITY STATUS'
    $s = Get-PedroSecuritySnapshot
    function Write-Check($label, $value) {
        $color = if ($value -eq 'OK') { 'Green' } elseif ($value -in @('OFF','CHECK')) { 'Yellow' } else { 'Gray' }
        Write-Host ('{0,-25} [{1}]' -f $label, $value) -ForegroundColor $color
    }
    Write-Check 'Windows Defender' $s.Defender
    Write-Check 'Real-Time Protection' $s.RealTimeProtection
    Write-Check 'Firewall' $s.Firewall
    Write-Host ('{0,-25} {1}' -f 'Antivirus', $s.Antivirus)
    Write-Host ('{0,-25} {1}' -f 'Latest Hotfix', $s.LatestHotfix)

    $states = @($s.Defender, $s.RealTimeProtection, $s.Firewall) | Where-Object { $_ -ne 'N/A' }
    $overall = if ($states.Count -eq 0) { 'UNKNOWN' } elseif (($states | Where-Object { $_ -ne 'OK' }).Count -eq 0) { 'GOOD' } else { 'REVIEW' }
    Write-Host ''
    Write-Host "Security Status: $overall" -ForegroundColor $(if ($overall -eq 'GOOD') {'Green'} else {'Yellow'})
    Write-Host 'PEDRO SYSTEM only reads these settings; it does not disable protections.' -ForegroundColor DarkGray
}

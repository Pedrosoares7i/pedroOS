function Show-PedroNetwork {
    Write-PedroHeader 'NETWORK CENTER'
    try {
        $configs = Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.NetAdapter.Status -eq 'Up' }
        foreach ($c in $configs) {
            Write-Host $c.InterfaceAlias -ForegroundColor Yellow
            $ipv4 = if ($c.IPv4Address) { ($c.IPv4Address.IPAddress -join ', ') } else { 'N/A' }
            $gateway = if ($c.IPv4DefaultGateway) { ($c.IPv4DefaultGateway.NextHop -join ', ') } else { 'N/A' }
            $dns = if ($c.DNSServer -and $c.DNSServer.ServerAddresses) { ($c.DNSServer.ServerAddresses -join ', ') } else { 'N/A' }
            Write-Host "  IPv4    : $ipv4"
            Write-Host "  Gateway : $gateway"
            Write-Host "  DNS     : $dns"
            Write-Host "  Status  : $($c.NetAdapter.Status)"
            Write-Host ''
        }
        $state = Get-PedroInternetState
        Write-Host "Internet: $state" -ForegroundColor $(if ($state -eq 'ONLINE') {'Green'} else {'Red'})
    } catch {
        Write-Host "[ERROR] Unable to retrieve network information." -ForegroundColor Red
        Write-PedroLog "Network failed: $($_.Exception.Message)" 'ERROR'
    }
}

function Invoke-PedroPing {
    param([string]$Target)
    if ([string]::IsNullOrWhiteSpace($Target)) { Write-Host 'Usage: ping <host>'; return }
    if ($Target -eq 'google') { $Target = 'google.com' }
    Write-PedroHeader "PING $Target"
    try {
        $results = Test-Connection -ComputerName $Target -Count 4 -ErrorAction Stop
        $times = @($results | ForEach-Object { $_.ResponseTime })
        $results | Select-Object Address, ResponseTime | Format-Table -AutoSize
        if ($times.Count -gt 0) {
            Write-Host ('Average latency: {0:N1} ms' -f (($times | Measure-Object -Average).Average))
        }
    } catch {
        Write-Host "[ERROR] Ping failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-PedroDns {
    param([string]$Target)
    if ([string]::IsNullOrWhiteSpace($Target)) { Write-Host 'Usage: dns <domain>'; return }
    Write-PedroHeader "DNS $Target"
    try {
        Resolve-DnsName -Name $Target -ErrorAction Stop | Select-Object Name, Type, IPAddress, NameHost | Format-Table -AutoSize
    } catch {
        Write-Host "[ERROR] DNS lookup failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

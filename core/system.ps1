function Get-PedroSystemSnapshot {
    $cpuObj = $null; $os = $null; $cs = $null; $gpu = $null
    try { $cpuObj = Get-CimInstance Win32_Processor | Select-Object -First 1 } catch { }
    try { $os = Get-CimInstance Win32_OperatingSystem } catch { }
    try { $cs = Get-CimInstance Win32_ComputerSystem } catch { }
    try { $gpu = Get-CimInstance Win32_VideoController | Where-Object { $_.Name } | Select-Object -First 1 } catch { }

    $cpuUsage = $null
    if ($cpuObj -and $null -ne $cpuObj.LoadPercentage) { $cpuUsage = [double]$cpuObj.LoadPercentage }

    $ramTotal = $null; $ramUsed = $null; $ramPct = $null
    if ($os) {
        $ramTotal = [double]$os.TotalVisibleMemorySize * 1KB
        $ramFree = [double]$os.FreePhysicalMemory * 1KB
        $ramUsed = $ramTotal - $ramFree
        if ($ramTotal -gt 0) { $ramPct = ($ramUsed / $ramTotal) * 100 }
    }

    $systemDrive = $env:SystemDrive
    $disk = $null
    try { $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$systemDrive'" } catch { }
    $diskPct = $null
    if ($disk -and $disk.Size -gt 0) { $diskPct = (($disk.Size - $disk.FreeSpace) / $disk.Size) * 100 }

    [pscustomobject]@{
        Computer = $env:COMPUTERNAME
        User = $env:USERNAME
        OS = if ($os) { $os.Caption } else { 'N/A' }
        Version = if ($os) { $os.Version } else { 'N/A' }
        CPUName = if ($cpuObj) { $cpuObj.Name.Trim() } else { 'N/A' }
        CPUUsage = $cpuUsage
        RAMTotal = $ramTotal
        RAMUsed = $ramUsed
        RAMUsage = $ramPct
        GPUName = if ($gpu) { $gpu.Name } else { 'N/A' }
        GPUUsage = Get-PedroGpuUsage
        Disk = $disk
        DiskUsage = $diskPct
        Uptime = Get-PedroUptime
        IPv4 = Get-PedroPrimaryIPv4
        Internet = Get-PedroInternetState
    }
}

function Show-PedroStatus {
    Write-PedroHeader 'SYSTEM STATUS'
    try {
        $s = Get-PedroSystemSnapshot
        Write-Host ("Computer : {0}" -f $s.Computer)
        Write-Host ("User     : {0}" -f $s.User)
        Write-Host ("OS       : {0}" -f $s.OS)
        Write-Host ("Version  : {0}" -f $s.Version)
        Write-Host ''
        Write-Host 'CPU' -ForegroundColor Yellow
        Write-Host $s.CPUName
        Write-Host ("Usage    : {0}" -f (New-PedroBar $s.CPUUsage))
        Write-Host ''
        Write-Host 'MEMORY' -ForegroundColor Yellow
        if ($null -ne $s.RAMTotal) {
            Write-Host ("Total    : {0}" -f (Format-PedroBytes $s.RAMTotal))
            Write-Host ("Used     : {0}" -f (Format-PedroBytes $s.RAMUsed))
        } else { Write-Host 'N/A' }
        Write-Host ("Usage    : {0}" -f (New-PedroBar $s.RAMUsage))
        Write-Host ''
        Write-Host 'GPU' -ForegroundColor Yellow
        Write-Host $s.GPUName
        Write-Host ("Usage    : {0}" -f (New-PedroBar $s.GPUUsage))
        Write-Host ''
        Write-Host 'DISK' -ForegroundColor Yellow
        if ($s.Disk) {
            Write-Host ("Drive    : {0}" -f $s.Disk.DeviceID)
            Write-Host ("Used     : {0}" -f (Format-PedroBytes ($s.Disk.Size - $s.Disk.FreeSpace)))
            Write-Host ("Free     : {0}" -f (Format-PedroBytes $s.Disk.FreeSpace))
            Write-Host ("Usage    : {0}" -f (New-PedroBar $s.DiskUsage))
        } else { Write-Host 'N/A' }
        Write-Host ''
        Write-Host 'NETWORK' -ForegroundColor Yellow
        Write-Host ("IPv4     : {0}" -f $s.IPv4)
        $internetColor = if ($s.Internet -eq 'ONLINE') { 'Green' } else { 'Red' }
        Write-Host ("Internet : {0}" -f $s.Internet) -ForegroundColor $internetColor
        Write-Host ''
        Write-Host 'UPTIME' -ForegroundColor Yellow
        Write-Host ("{0:00}d {1:00}:{2:00}:{3:00}" -f $s.Uptime.Days, $s.Uptime.Hours, $s.Uptime.Minutes, $s.Uptime.Seconds)
    } catch {
        Write-Host "[ERROR] Unable to retrieve system status." -ForegroundColor Red
        Write-Host $_.Exception.Message
        Write-PedroLog "Status failed: $($_.Exception.Message)" 'ERROR'
    }
}

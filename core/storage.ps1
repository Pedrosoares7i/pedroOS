function Show-PedroDisk {
    Write-PedroHeader 'DRIVES'
    try {
        $drives = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop
        foreach ($d in $drives) {
            $used = $d.Size - $d.FreeSpace
            $pct = if ($d.Size -gt 0) { ($used / $d.Size) * 100 } else { 0 }
            Write-Host ("{0}" -f $d.DeviceID) -ForegroundColor Yellow
            Write-Host ("  Total : {0}" -f (Format-PedroBytes $d.Size))
            Write-Host ("  Used  : {0}" -f (Format-PedroBytes $used))
            Write-Host ("  Free  : {0}" -f (Format-PedroBytes $d.FreeSpace))
            Write-Host ("  Usage : {0}" -f (New-PedroBar $pct))
            Write-Host ''
        }
    } catch {
        Write-Host "[ERROR] Unable to retrieve storage information." -ForegroundColor Red
        Write-PedroLog "Disk command failed: $($_.Exception.Message)" 'ERROR'
    }
}

# Get basic system info
$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor
$bios = Get-CimInstance Win32_BIOS
$mb = Get-CimInstance Win32_BaseBoard
$gpu = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
$audio = Get-CimInstance Win32_SoundDevice | Select-Object -ExpandProperty Name
$defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
# Get firewall status for all profiles
$firewallProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled


# Determine if the device is a Laptop or Desktop
$chassis = Get-CimInstance Win32_SystemEnclosure
$type = switch ($chassis.ChassisTypes) {
    { $_ -in 8, 9, 10, 14 } { "Laptop"; break }
    default { "Desktop" }
}

# Determine domain or workgroup
$domainOrWorkgroup = if ($cs.PartOfDomain) { $cs.Domain } else { "WORKGROUP" }

# === Asset Information ===
Write-Host "`n=== Asset Information ===`n"

Write-Host "Hostname:`t$($env:COMPUTERNAME)"
Write-Host "Asset type:`t$($type)"
Write-Host "Last user:`t$($env:USERDOMAIN)\$($env:USERNAME)"
Write-Host "OS:`t`t$($os.Caption)"
Write-Host "Version:`t$($os.Version)"
Write-Host "Build:`t`t$($os.BuildNumber)"
Write-Host "Domain:`t`t$domainOrWorkgroup"
Write-Host "Manufacturer:`t$($cs.Manufacturer)"
Write-Host "Model:`t`t$($cs.Model)"
Write-Host "Serial Number:`t$($bios.SerialNumber)"
Write-Host "Processor:`t$($cpu.Name) ($($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads @ $([math]::Round($cpu.MaxClockSpeed / 1000.0, 2)) GHz)"
Write-Host "Motherboard:`t$($mb.Manufacturer) $($mb.Product)"
Write-Host "Graphics:`t$($gpu -join ', ')"
Write-Host "Audio:`t`t$($audio -join ', ')"
Write-Host "Antivirus:`tWindows Defender (" ($(if ($defender.AntispywareEnabled) { 'Enabled' } else { 'Disabled' }))")"
Write-Host "Firewall:`t"($firewallProfiles | ForEach-Object { "$($_.Name): $($_.Enabled), " })

# === Memory Information ===
Write-Host "`n=== Memory Information ===`n"

function Get-RAMTypeName($type) {
    switch ($type) {
        20 { 'DDR' }
        21 { 'DDR2' }
        22 { 'DDR2 FB-DIMM' }
        24 { 'DDR3' }
        26 { 'DDR4' }
        27 { 'LPDDR' }
        28 { 'LPDDR2' }
        29 { 'LPDDR3' }
        30 { 'LPDDR4' }
        31 { 'Logical Non-Volatile Device' }
        32 { 'HBM' }
        33 { 'HBM2' }
        34 { 'DDR5' }
        35 { 'LPDDR5' }
        default { "Unknown ($type)" }
    }
}

function Get-ModuleTypeName($form) {
    switch ($form) {
        0 { 'Unknown' }
        1 { 'Other' }
        2 { 'SIP' }
        3 { 'DIP' }
        4 { 'ZIP' }
        5 { 'SOJ' }
        6 { 'Proprietary' }
        7 { 'SIMM' }
        8 { 'DIMM' }
        9 { 'TSOP' }
        10 { 'PGA' }
        11 { 'RIMM' }
        12 { 'SODIMM' }
        13 { 'SRIMM' }
        14 { 'SMD' }
        15 { 'SSMP' }
        16 { 'QFP' }
        17 { 'TQFP' }
        18 { 'SOIC' }
        19 { 'LCC' }
        20 { 'PLCC' }
        21 { 'BGA' }
        22 { 'FPBGA' }
        23 { 'LGA' }
        default { "Unknown ($form)" }
    }
}

$ramModules = Get-CimInstance Win32_PhysicalMemory

$ramModules | ForEach-Object {
    [PSCustomObject]@{
        CapacityGB   = [math]::Round($_.Capacity / 1GB, 2)
        SpeedMHz     = $_.Speed
        RAMType      = Get-RAMTypeName $_.SMBIOSMemoryType
        ModuleType   = Get-ModuleTypeName $_.FormFactor
        Manufacturer = $_.Manufacturer
        PartNumber   = $_.PartNumber.Trim()
    }
} | Format-Table -AutoSize

$totalMem = ($ramModules | Measure-Object -Property Capacity -Sum).Sum / 1GB
Write-Host "`nTotal Memory:`t$([math]::Round($totalMem, 2)) GB"

# === Physical Disks ===
Write-Host "`n=== Physical Disks ===`n"

Get-PhysicalDisk | ForEach-Object {
    $volumes = Get-Volume | Where-Object { $_.Path -match "^[A-Z]:" -and $_.ObjectId -match $_.ObjectId }
    [PSCustomObject]@{
        Model         = $_.FriendlyName
        MediaType     = $_.MediaType
        BusType       = $_.BusType
        SizeGB        = [math]::Round($_.Size / 1GB, 2)
        DriveLetters  = ($volumes | Where-Object { $_.DriveLetter } | ForEach-Object { $_.DriveLetter }) -join ', '
    }
} | Format-Table -AutoSize

# === Logical Drive Usage ===
Write-Host "`n=== Logical Drive Usage ===`n"

# Cache volumes and identify all network drives (DriveType = 4)
$allVolumes = Get-Volume
$networkDriveLetters = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 4 } | Select-Object -ExpandProperty DeviceID

Get-PSDrive -PSProvider FileSystem | Where-Object {
    $_.Used -ne $null -and ($networkDriveLetters -notcontains "$($_.Name):")
} | ForEach-Object {
    $vol = $allVolumes | Where-Object { $_.DriveLetter -eq $_.Name }
    if ($vol) {
        $label = if ([string]::IsNullOrWhiteSpace($vol.FileSystemLabel)) { "Drive" } else { $vol.FileSystemLabel }

        [PSCustomObject]@{
            DriveLetter  = $_.Name
            VolumeLabel  = $label
            FileSystem   = $vol.FileSystem
            TotalSizeGB  = [math]::Round(($_.Used + $_.Free) / 1GB, 2)
            UsedSpaceGB  = [math]::Round($_.Used / 1GB, 2)
            FreeSpaceGB  = [math]::Round($_.Free / 1GB, 2)
            UsedPercent  = "{0:N2}" -f (($_.Used / ($_.Used + $_.Free)) * 100)
        }
    }
} | Format-Table -AutoSize



# === Network Interfaces ===
Write-Host "`n=== Network Interfaces ===`n"

# Function to get vendor from MAC address (simplified, using first three bytes)
function Get-VendorFromMac($mac) {
    $macPrefix = $mac -replace '[:-]', '' -replace '^(.{6}).*', '$1'
    $vendorList = @{
        '00163E' = 'Intel'
        '00FF41' = 'Unknown Vendor'
        '00F48D' = 'Realtek'
        '025041' = 'Microsoft'
        '8C1645' = 'Unknown Vendor'
    }
    if ($vendorList.ContainsKey($macPrefix)) {
        return $vendorList[$macPrefix]
    } else {
        return 'Unknown Vendor'
    }
}

Get-NetAdapter | ForEach-Object {
    $ipInfo = Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -ErrorAction SilentlyContinue
    $ipv4 = ($ipInfo | Where-Object { $_.AddressFamily -eq 'IPv4' } | Select-Object -First 1).IPAddress
    $ipv6 = ($ipInfo | Where-Object { $_.AddressFamily -eq 'IPv6' } | Select-Object -First 1).IPAddress
    $vendor = Get-VendorFromMac $_.MacAddress

    [PSCustomObject]@{
        Name        = $_.Name
        Status      = $_.Status
        IPv4        = if ($ipv4 -eq $null) { '' } else { $ipv4 }
        IPv6        = if ($ipv6 -eq $null) { '' } else { $ipv6 }
        MAC         = $_.MacAddress
        Vendor      = $vendor
    }
} | Format-Table -AutoSize

# === Battery Information (only if Laptop) ===
if ($type -eq "Laptop") {
    Write-Host "`n=== Battery Information ===`n"
    
    $battery = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
    $batteryStatic = Get-WmiObject -Namespace "root\wmi" -Class BatteryStaticData -ErrorAction SilentlyContinue
    $batteryStatus = Get-WmiObject -Namespace "root\wmi" -Class BatteryStatus -ErrorAction SilentlyContinue

    if ($battery -and $batteryStatic -and $batteryStatus) {
        $designedCapacity_mWh = $batteryStatic.DesignedCapacity
        $fullChargeCapacity_mWh = $batteryStatus.RemainingCapacity + $batteryStatus.ChargeRate

        $designedWh = [math]::Round($designedCapacity_mWh / 1000, 2)
        $chargeableWh = [math]::Round($fullChargeCapacity_mWh / 1000, 2)

        if ($designedCapacity_mWh -ne 0) {
            $wear = [math]::Round((1 - ($fullChargeCapacity_mWh / $designedCapacity_mWh)) * 100, 2)
        } else {
            $wear = "Unknown"
        }

        switch ($battery.BatteryStatus) {
            1 { $status = "Discharging" }
            2 { $status = "Charging" }
            3 { $status = "Fully Charged" }
            default { $status = "Unknown" }
        }

        if ($battery.EstimatedRunTime -gt 0) {
            $eta = "$($battery.EstimatedRunTime) minutes"
        } else {
            $eta = "Calculating..."
        }

        Write-Host "Battery Model:`t`t$($battery.Name)"
        Write-Host "Manufacturer:`t`t$($battery.Manufacturer)"
        Write-Host "Designed Capacity:`t$designedWh Wh"
        Write-Host "Chargeable Capacity:`t$chargeableWh Wh"
        Write-Host "Battery Wear:`t`t$wear %"
        Write-Host "Current State:`t`t$status"
        Write-Host "ETA to Full/Empty:`t$eta"
    } else {
        Write-Host "Battery information not available."
    }
}
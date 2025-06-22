# Initialize hashtable to store all system information
$SystemInfo = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    OwnerName = ""
    AssetInformation = @{}
    MemoryInformation = @{ Modules = @(); TotalMemoryGB = 0 }
    PhysicalDisks = @()
    LogicalDrives = @()
    NetworkInterfaces = @()
    BatteryInformation = $null
    MonitorInformation = @()
}

# Prompt user for owner name
$ownerName = Read-Host "Please enter the owner name"
$SystemInfo.OwnerName = $ownerName

# Get basic system info
$cs = Get-CimInstance Win32_ComputerSystem
$os = Get-CimInstance Win32_OperatingSystem
$cpu = Get-CimInstance Win32_Processor
$bios = Get-CimInstance Win32_BIOS
$mb = Get-CimInstance Win32_BaseBoard
$gpu = Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name
$audio = Get-CimInstance Win32_SoundDevice | Select-Object -ExpandProperty Name
$defender = Get-MpComputerStatus -ErrorAction SilentlyContinue
$firewallProfiles = Get-NetFirewallProfile | Select-Object Name, Enabled

# Determine if the device is a Laptop or Desktop
$chassis = Get-CimInstance Win32_SystemEnclosure
$assetType = switch ($chassis.ChassisTypes) {
    { $_ -in 8, 9, 10, 14 } { "Laptop"; break }
    default { "Desktop" }
}

# Determine domain or workgroup
$domainOrWorkgroup = if ($cs.PartOfDomain) { $cs.Domain } else { "WORKGROUP" }

# === Asset Information ===
$SystemInfo.AssetInformation = @{
    Hostname = $env:COMPUTERNAME
    AssetType = $assetType
    LastUser = "$($env:USERDOMAIN)\$($env:USERNAME)"
    OS = $os.Caption
    Version = $os.Version
    Build = $os.BuildNumber
    Domain = $domainOrWorkgroup
    Manufacturer = $cs.Manufacturer
    Model = $cs.Model
    SerialNumber = $bios.SerialNumber
    Processor = "$($cpu.Name) ($($cpu.NumberOfCores) cores / $($cpu.NumberOfLogicalProcessors) threads @ $([math]::Round($cpu.MaxClockSpeed / 1000.0, 2)) GHz)"
    Motherboard = "$($mb.Manufacturer) $($mb.Product)"
    Graphics = $gpu
    Audio = $audio
    Antivirus = if ($defender) { "Windows Defender ($(if ($defender.AntispywareEnabled) { 'Enabled' } else { 'Disabled' }))" } else { "Unknown" }
    Firewall = ($firewallProfiles | ForEach-Object { "$($_.Name): $($_.Enabled)" }) -join ", "
}

# === Memory Information ===
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
foreach ($ram in $ramModules) {
    $capacityGB = [math]::Round($ram.Capacity / 1GB, 2)
    $SystemInfo.MemoryInformation.Modules += @{
        CapacityGB = $capacityGB
        SpeedMHz = if ($ram.Speed) { $ram.Speed } else { "Unknown" }
        RAMType = Get-RAMTypeName $ram.SMBIOSMemoryType
        ModuleType = Get-ModuleTypeName $ram.FormFactor
        Manufacturer = if ($ram.Manufacturer) { $ram.Manufacturer } else { "Unknown" }
        PartNumber = if ($ram.PartNumber) { $ram.PartNumber.Trim() } else { "Unknown" }
    }
}
$SystemInfo.MemoryInformation.TotalMemoryGB = [math]::Round(($ramModules | Measure-Object -Property Capacity -Sum).Sum / 1GB, 2)

# === Physical Disks ===
$physicalDisks = Get-PhysicalDisk
foreach ($disk in $physicalDisks) {
    $volumes = Get-Volume | Where-Object { $_.Path -match "^[A-Z]:" -and $_.ObjectId -match $disk.ObjectId }
    $SystemInfo.PhysicalDisks += @{
        Model = $disk.FriendlyName
        MediaType = $disk.MediaType
        BusType = $disk.BusType
        SizeGB = [math]::Round($disk.Size / 1GB, 2)
        DriveLetters = ($volumes | Where-Object { $_.DriveLetter } | ForEach-Object { $_.DriveLetter }) -join ", "
        Status = $disk.HealthStatus  
    }
}


# === Logical Drives ===
$allVolumes = Get-Volume
$networkDriveLetters = Get-CimInstance Win32_LogicalDisk | Where-Object { $_.DriveType -eq 4 } | Select-Object -ExpandProperty DeviceID
$logicalDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null -and ($networkDriveLetters -notcontains "$($_.Name):") }
foreach ($drive in $logicalDrives) {
    $vol = $allVolumes | Where-Object { $_.DriveLetter -eq $drive.Name }
    if ($vol) {
        $label = if ([string]::IsNullOrWhiteSpace($vol.FileSystemLabel)) { "Drive" } else { $vol.FileSystemLabel }
        $SystemInfo.LogicalDrives += @{
            DriveLetter = $drive.Name
            VolumeLabel = $label
            FileSystem = $vol.FileSystem
            TotalSizeGB = [math]::Round(($drive.Used + $drive.Free) / 1GB, 2)
            UsedSpaceGB = [math]::Round($drive.Used / 1GB, 2)
            FreeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
            UsedPercent = [math]::Round(($drive.Used / ($drive.Used + $drive.Free)) * 100, 2)
        }
    }
}

# === Network Interfaces ===
$vendorList = @{
    '00163E' = 'Intel'
    '00FF41' = 'Unknown Vendor'
    '00F48D' = 'Realtek'
    '025041' = 'Microsoft'
    '8C1645' = 'Unknown Vendor'
}
$adapters = Get-NetAdapter | Where-Object { $_.Name -and $_.MacAddress }
foreach ($adapter in $adapters) {
    $ipInfo = Get-NetIPAddress -InterfaceIndex $adapter.InterfaceIndex -ErrorAction SilentlyContinue
    $ipv4 = ($ipInfo | Where-Object { $_.AddressFamily -eq 'IPv4' } | Select-Object -First 1).IPAddress
    $ipv6 = ($ipInfo | Where-Object { $_.AddressFamily -eq 'IPv6' } | Select-Object -First 1).IPAddress
    $macPrefix = $adapter.MacAddress -replace '[:-]', '' -replace '^(.{6}).*', '$1'
    $vendor = if ($vendorList.ContainsKey($macPrefix)) { $vendorList[$macPrefix] } else { 'Unknown Vendor' }
    $SystemInfo.NetworkInterfaces += @{
        Name = $adapter.Name
        Status = $adapter.Status
        IPv4 = if ($ipv4) { $ipv4 } else { "" }
        IPv6 = if ($ipv6) { $ipv6 } else { "" }
        MAC = $adapter.MacAddress
        Vendor = $vendor
    }
}

function Get-BatterySummary {
    $fields = @{
        Model = "Unknown"
        Manufacturer = "Unknown"
        EstimatedChargeRemainingPercent = "Unknown"
        BatteryHealthPercent = "Unknown"
        DesignedCapacityWh = "Unknown"
        FullChargedCapacityWh = "Unknown"
        CycleCount = "Unknown"
    }

    try {
        $cimNamespace = "ROOT\cimv2"
        $wmiNamespace = "ROOT\WMI"

        # Try to get Win32_Battery
        $battery = Get-CimInstance -Namespace $cimNamespace -ClassName Win32_Battery -ErrorAction SilentlyContinue
        if (-not $battery) { $battery = Get-WmiObject -Namespace $cimNamespace -Class Win32_Battery -ErrorAction SilentlyContinue }

        # Battery cycle count, full charged capacity, and static data
        $batteryCycle = Get-CimInstance -Namespace $wmiNamespace -ClassName BatteryCycleCount -ErrorAction SilentlyContinue
        if (-not $batteryCycle) { $batteryCycle = Get-WmiObject -Namespace $wmiNamespace -Class BatteryCycleCount -ErrorAction SilentlyContinue }

        $batteryFullCharged = Get-CimInstance -Namespace $wmiNamespace -ClassName BatteryFullChargedCapacity -ErrorAction SilentlyContinue
        if (-not $batteryFullCharged) { $batteryFullCharged = Get-WmiObject -Namespace $wmiNamespace -Class BatteryFullChargedCapacity -ErrorAction SilentlyContinue }

        $batteryStatic = Get-CimInstance -Namespace $wmiNamespace -ClassName BatteryStaticData -ErrorAction SilentlyContinue
        if (-not $batteryStatic) { $batteryStatic = Get-WmiObject -Namespace $wmiNamespace -Class BatteryStaticData -ErrorAction SilentlyContinue }

        # Assign values safely
        if ($battery) {
            $fields.Model = $battery.Name
            $fields.Manufacturer = $battery.Manufacturer
            $fields.EstimatedChargeRemainingPercent = $battery.EstimatedChargeRemaining
        }
        if ($batteryCycle) {
            $fields.CycleCount = $batteryCycle.CycleCount
        }
        if ($batteryFullCharged) {
            $fields.FullChargedCapacityWh = [math]::Round($batteryFullCharged.FullChargedCapacity / 1000, 2)
        }
        if ($batteryStatic) {
            $fields.DesignedCapacityWh = [math]::Round($batteryStatic.DesignedCapacity / 1000, 2)
            if (-not $fields.Manufacturer) { $fields.Manufacturer = $batteryStatic.ManufactureName }
        }

        # Calculate health percentage if possible
        if (($fields.FullChargedCapacityWh -ne "Unknown") -and ($fields.DesignedCapacityWh -ne "Unknown") -and ($fields.DesignedCapacityWh -gt 0)) {
            $fields.BatteryHealthPercent = [math]::Round(($fields.FullChargedCapacityWh / $fields.DesignedCapacityWh) * 100, 2)
        }
    }
    catch {
        Write-Verbose "Error retrieving battery summary: $_"
    }

    return $fields
}

# Usage example in your main script:
if ($assetType -eq "Laptop") {
    $SystemInfo.BatteryInformation = Get-BatterySummary
}



# === Monitor Information ===
function Convert-ByteArrayToString([byte[]]$bytes) {
    $chars = $bytes | Where-Object { $_ -ne 0 } | ForEach-Object { [char]$_ }
    return (-join $chars).Trim()
}

function Get-FullManufacturerName($code) {
    $map = @{
        "DEL" = "Dell"
        "SAM" = "Samsung"
        "LG " = "LG Electronics"
        "APP" = "Apple"
        "ACR" = "Acer"
        "HWP" = "HP"
        "LEN" = "Lenovo"
        "SNY" = "Sony"
        "ASU" = "Asus"
        "PHL" = "Philips"
        "VSC" = "ViewSonic"
        "CMN" = "Chi Mei Corporation"
    }
    if ($map.ContainsKey($code)) { return $map[$code] } else { return $code }
}

Add-Type -AssemblyName System.Windows.Forms
try {
    $monitorIDs = Get-WmiObject -Namespace root\wmi -Class WmiMonitorID -ErrorAction Stop
} catch {
    $monitorIDs = $null
}

$screens = [System.Windows.Forms.Screen]::AllScreens
if ($monitorIDs) {
    foreach ($id in $monitorIDs) {
        $manufacturerCode = Convert-ByteArrayToString $id.ManufacturerName
        $monitorInfo = @{
            FriendlyName = if ($id.UserFriendlyNameLength -gt 0) { Convert-ByteArrayToString $id.UserFriendlyName } else { "Unknown" }
            Manufacturer = Get-FullManufacturerName $manufacturerCode
            ProductCode = Convert-ByteArrayToString $id.ProductCodeID
            SerialNumber = Convert-ByteArrayToString $id.SerialNumberID
            ScreenSizeInch = "Unknown"
            NativeResolution = "Unknown"
            YearOfManufacture = if ($id.YearOfManufacture) { $id.YearOfManufacture } else { "Unknown" }
        }

        $displayParams = Get-WmiObject -Namespace root\wmi -Class WmiMonitorBasicDisplayParams | Where-Object { $_.InstanceName -eq $id.InstanceName } -ErrorAction SilentlyContinue
        if ($displayParams) {
            $widthCm = $displayParams.MaxHorizontalImageSize
            $heightCm = $displayParams.MaxVerticalImageSize
            if ($widthCm -and $heightCm) {
                $widthInch = [math]::Round($widthCm / 2.54, 2)
                $heightInch = [math]::Round($heightCm / 2.54, 2)
                $monitorInfo.ScreenSizeInch = [math]::Round([math]::Sqrt(($widthInch * $widthInch) + ($heightInch * $heightInch)), 2)
            }
        }

        if ($SystemInfo.MonitorInformation.Count -lt $screens.Count) {
            $screen = $screens[$SystemInfo.MonitorInformation.Count]
            $monitorInfo.NativeResolution = "$($screen.Bounds.Width) x $($screen.Bounds.Height)"
        }

        $SystemInfo.MonitorInformation += $monitorInfo
    }
} else {
    foreach ($screen in $screens) {
        $SystemInfo.MonitorInformation += @{
            FriendlyName = "Unknown"
            Manufacturer = "Unknown"
            ProductCode = "Unknown"
            SerialNumber = "Unknown"
            ScreenSizeInch = "Unknown"
            NativeResolution = "$($screen.Bounds.Width) x $($screen.Bounds.Height)"
            YearOfManufacture = "Unknown"
        }
    }
}

# === Installed Software ===
function Get-InstalledSoftware {
    $softwareList = @()
    $machinePaths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($basePath in $machinePaths) {
        if (Test-Path $basePath) {
            Get-ChildItem -Path $basePath | ForEach-Object {
                try {
                    $props = Get-ItemProperty -Path $_.PSPath
                    if ($props.DisplayName) {
                        $softwareList += [PSCustomObject]@{
                            Name        = $props.DisplayName
                            Version     = $props.DisplayVersion
                            Publisher   = $props.Publisher
                            InstallDate = $props.InstallDate
                            Scope       = "System-wide"
                        }
                    }
                } catch {}
            }
        }
    }
    $userPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    if (Test-Path $userPath) {
        Get-ChildItem -Path $userPath | ForEach-Object {
            try {
                $props = Get-ItemProperty -Path $_.PSPath
                if ($props.DisplayName) {
                    $softwareList += [PSCustomObject]@{
                        Name        = $props.DisplayName
                        Version     = $props.DisplayVersion
                        Publisher   = $props.Publisher
                        InstallDate = $props.InstallDate
                        Scope       = "User-only"
                    }
                }
            } catch {}
        }
    }
    return $softwareList
}

$SystemInfo.InstalledSoftware = Get-InstalledSoftware

# Sanitize owner name for filename (remove invalid characters)
$safeOwnerName = $ownerName -replace '[<>:"/\\|?*]', '_'

# Define remote folder path
$remotePath = "D:\Projects\Windows inventory\wis\Records"

# Output as JSON and save to remote folder
$jsonOutput = $SystemInfo | ConvertTo-Json -Depth 5
$fileName = "SystemInfo_$($safeOwnerName)_$($SystemInfo.Timestamp -replace '[: ]', '_').json"
$fullPath = Join-Path -Path $remotePath -ChildPath $fileName

try {
    $jsonOutput | Out-File -FilePath $fullPath -Encoding UTF8 -ErrorAction Stop
    Write-Host "System information saved to $fullPath"
} catch {
    Write-Host "Error saving to remote folder: $_"
    Write-Host "Please ensure the remote path is accessible and you have write permissions."
}
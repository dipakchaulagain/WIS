function Get-NativeResolutionFromEDID {
    param([byte[]]$edid)

    if ($edid.Length -lt 72) {
        return "Unknown"
    }

    $dtd = $edid[54..71]

    $hActiveLow = $dtd[2]
    $hActiveHigh = ($dtd[4] -band 0xF0) -shr 4
    $hActive = ($hActiveHigh * 256) + $hActiveLow

    $vActiveLow = $dtd[5]
    $vActiveHigh = $dtd[7] -band 0x0F
    $vActive = ($vActiveHigh * 256) + $vActiveLow

    if ($hActive -gt 0 -and $vActive -gt 0) {
        return "$hActive x $vActive"
    } else {
        return "Unknown"
    }
}

function Convert-ByteArrayToString {
    param([byte[]]$bytes)
    $chars = $bytes | ForEach-Object { [char]$_ }
    $str = -join $chars
    return $str.Trim([char]0)
}

function Get-FullManufacturerName {
    param([string]$code)
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
    }
    if ($map.ContainsKey($code)) { return $map[$code] } else { return $code }
}

$monitorIDs = Get-WmiObject -Namespace root\wmi -Class WmiMonitorID

foreach ($id in $monitorIDs) {
    $manufacturerCode = Convert-ByteArrayToString $id.ManufacturerName
    $manufacturerFull = Get-FullManufacturerName $manufacturerCode
    $productCode = Convert-ByteArrayToString $id.ProductCodeID
    $serialNumber = Convert-ByteArrayToString $id.SerialNumberID
    if ($id.UserFriendlyNameLength -gt 0) {
        $friendlyName = Convert-ByteArrayToString $id.UserFriendlyName
    } else {
        $friendlyName = "Unknown"
    }
    $year = $id.YearOfManufacture
    $displayParams = Get-WmiObject -Namespace root\wmi -Class WmiMonitorBasicDisplayParams | Where-Object { $_.InstanceName -eq $id.InstanceName }
    # Extract screen size in cm
    $widthCm = $displayParams.MaxHorizontalImageSize
    $heightCm = $displayParams.MaxVerticalImageSize

    # Convert cm to inches (1 inch = 2.54 cm)
    $widthInch = [math]::Round($widthCm / 2.54, 2)
    $heightInch = [math]::Round($heightCm / 2.54, 2)

    # Calculate diagonal size
    $diagonalInch = [math]::Round(([math]::Sqrt(($widthInch * $widthInch) + ($heightInch * $heightInch))), 2)

    # Get screen resolution using .NET (primary screen)
    Add-Type -AssemblyName System.Windows.Forms
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $screenWidth = $screen.Bounds.Width
    $screenHeight = $screen.Bounds.Height
    
    Write-Output "======================================================"
    Write-Output "Monitor              : $friendlyName"
    Write-Output "Manufacturer         : $manufacturerFull"
    Write-Output "Product Code         : $productCode"
    Write-Output "Serial Number        : $serialNumber"
    Write-Output "Screen Size          : $diagonalInch inches"
    Write-Output "Native Resolution    : ${screenWidth} x ${screenHeight}"
    Write-Output "Year of Manufacture  : $year"
    Write-Output "======================================================="
}

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
    Write-Host $id.InstanceName
    $manufacturerCode = Convert-ByteArrayToString $id.ManufacturerName
    $manufacturerFull = Get-FullManufacturerName $manufacturerCode
    $productCode = Convert-ByteArrayToString $id.ProductCodeID
    $serialNumber = Convert-ByteArrayToString $id.SerialNumberID
    $friendlyName = Convert-ByteArrayToString $id.UserFriendlyName
    $year = $id.YearOfManufacture

    # Get EDID from WmiMonitorDescriptorMethods
    $edidObj = Get-WmiObject -Namespace root\wmi -Class WmiMonitorDescriptorMethods | Where-Object { $_.InstanceName -eq $id.InstanceName }

    $nativeResolution = "Unknown"
    if ($edidObj) {
        $edidResult = $edidObj.WmiGetMonitorRawEEdidV1Block(0)
        if ($edidResult -and $edidResult.Edid) {
            $nativeResolution = Get-NativeResolutionFromEDID $edidResult.Edid
        }
    }

    Write-Output "Monitor:       $friendlyName"
    Write-Output "Manufacturer:  $manufacturerFull"
    Write-Output "Product Code:  $productCode"
    Write-Output "Serial Number: $serialNumber"
    Write-Output "Native Resolution: $nativeResolution"
    Write-Output "Year of Manufacture: $year"
    Write-Output ""
}

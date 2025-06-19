# Get-InstalledSoftware.ps1
# Extract all installed software (system-wide and per-user) with detailed information

function Get-InstalledSoftware {
    param (
        [switch]$IncludeUser = $true,
        [switch]$IncludeSystem = $true
    )

    $results = @()

    function Get-SoftwareFromRegistry {
        param (
            [string]$RegistryPath,
            [string]$InstallScope
        )

        try {
            $keys = Get-ChildItem -Path $RegistryPath -ErrorAction SilentlyContinue
            foreach ($key in $keys) {
                $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue

                if ($props.DisplayName) {
                    $results += [PSCustomObject]@{
                        Name         = $props.DisplayName
                        Version      = $props.DisplayVersion
                        Publisher    = $props.Publisher
                        InstallDate  = $props.InstallDate
                        InstallLocation = $props.InstallLocation
                        Scope        = $InstallScope
                        RegistryPath = $key.PSPath
                    }
                }
            }
        } catch {
            Write-Warning "Error accessing $RegistryPath"
        }
    }

    if ($IncludeSystem) {
        # System-wide installs for all users (both 64-bit and 32-bit)
        Get-SoftwareFromRegistry "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" "System-wide (64-bit)"
        Get-SoftwareFromRegistry "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall" "System-wide (32-bit)"
    }

    if ($IncludeUser) {
        # Current user installs
        Get-SoftwareFromRegistry "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall" "User-only"
    }

    return $results | Sort-Object Name
}

# Export or display the software list
$softwareList = Get-InstalledSoftware

# Output to screen
$softwareList | Format-Table -AutoSize

# Optional: export to CSV
# $softwareList | Export-Csv -Path "InstalledSoftware.csv" -NoTypeInformation -Encoding UTF8

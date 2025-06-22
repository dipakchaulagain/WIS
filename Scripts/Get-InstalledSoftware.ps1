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
                } catch {
                    # Ignore errors silently
                }
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
            } catch {
                # Ignore errors silently
            }
        }
    }

    return $softwareList
}

# Display
Get-InstalledSoftware | Sort-Object Scope, Name | Format-Table -AutoSize

function Get-InstalledProgram {
    <#
    .SYNOPSIS
        Retrieves a list of installed programs from local or remote computers.

    .DESCRIPTION
        Queries the registry on local or remote computers to retrieve a list of installed programs.
        It searches the registry keys that store information about installed x86 and x64 programs.
        The results are returned as a PSCustomObject.

    .PARAMETER FullDetail
        If specified, the function returns full registry details for each installed program.
        Without this switch, only the program name, version, install date, and uninstall string are shown.

    .PARAMETER ComputerName
        Specifies the name(s) of the computer(s) to query for installed programs.
        Defaults to the local machine if not specified.

    .EXAMPLE
        PS C:\> Get-InstalledProgram
        Retrieves installed programs from the local computer.

    .EXAMPLE
        PS C:\> Get-InstalledProgram -FullDetail
        Retrieves installed programs from the local computer with full registry details.

    .EXAMPLE
        PS C:\> Get-InstalledProgram -ComputerName Server1, Server2
        Retrieves installed programs from Server1 and Server2.

    .NOTES
        - This function does not check for programs installed in AppData or other user-specific directories.
        - It only queries `HKEY_LOCAL_MACHINE` and `HKEY_CURRENT_USER`.
        - Remote queries require administrative privileges.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Management.Automation.PSCustomObject[]])]
    param (
        [Parameter(Position = 0)]
        [switch]$FullDetail,

        [Parameter()]
        [string[]]$ComputerName = $env:COMPUTERNAME
    )

    process {
        # Define registry paths
        $RegPaths = @(
            "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )

        foreach ($Comp in $ComputerName) {
            Write-Verbose "Processing: $Comp"

            # Remote system handling
            if ($Comp -ne $env:COMPUTERNAME) {
                try {
                    $RemotePrograms = Invoke-Command -ComputerName $Comp -ScriptBlock {
                        param ($RemoteRegPaths, $RemoteFullDetail, $RemoteComp)

                        $InstalledPrograms = @()
                        foreach ($Path in $RemoteRegPaths) {
                            if (Test-Path $Path) {
                                $InstalledPrograms += Get-ItemProperty -Path $Path | Where-Object { $null -ne $_.DisplayName }
                            }
                        }

                        if (-not $RemoteFullDetail) {
                            $InstalledPrograms = $InstalledPrograms | Select-Object DisplayName, DisplayVersion, InstallDate, InstallSource, UninstallString
                        }

                        $InstalledPrograms | ForEach-Object {
                            [PSCustomObject]@{
                                ComputerName    = $RemoteComp
                                Program         = $_.DisplayName
                                Version         = $_.DisplayVersion
                                InstallSource   = $_.InstallSource
                                InstallDate     = $_.InstallDate
                                UninstallString = $_.UninstallString
                            }
                        }
                    } -ArgumentList $RegPaths, $FullDetail, $Comp -ErrorAction Stop

                    Write-Output $RemotePrograms
                }
                catch {
                    Write-Warning "Failed to retrieve installed programs from ${Comp}: $($_.Exception.Message)"
                }
            }

            # Local system handling
            else {
                $InstalledPrograms = @()
                foreach ($Path in $RegPaths) {
                    if (Test-Path $Path) {
                        $InstalledPrograms += Get-ItemProperty -Path $Path | Where-Object { $null -ne $_.DisplayName }
                    }
                }

                if (-not $FullDetail) {
                    $InstalledPrograms = $InstalledPrograms | Select-Object DisplayName, DisplayVersion, InstallDate, InstallSource, UninstallString
                }

                $InstalledPrograms | ForEach-Object {
                    [PSCustomObject]@{
                        ComputerName    = $env:COMPUTERNAME
                        Program         = $_.DisplayName
                        Version         = $_.DisplayVersion
                        InstallSource   = $_.InstallSource
                        InstallDate     = $_.InstallDate
                        UninstallString = $_.UninstallString
                    }
                }
            }
        }
    }
}
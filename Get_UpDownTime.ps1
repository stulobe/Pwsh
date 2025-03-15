function Get-UpDownTime {
    <#
    .SYNOPSIS
        Retrieves system uptime, last shutdown, and startup events, including user-initiated shutdowns.

    .DESCRIPTION
        This function connects to a local or remote computer, retrieves the current system uptime, and checks the event logs for the last shutdown and startup events.
        Additionally, it retrieves information about the user who initiated the last shutdown or restart.

    .PARAMETER ComputerName
        Specifies the name(s) of the computer(s) to check. Defaults to the local machine if no computer name is provided.
        Accepts an array of computer names and can also accept input via pipeline.

    .INPUTS
        Accepts pipeline input for the ComputerName parameter.

    .OUTPUTS
        System.Management.Automation.PSCustomObject[]

    .EXAMPLE
        PS C:\> Get-UpDownTime -ComputerName localhost
        Retrieves uptime, last shutdown, and startup events for the local computer.

    .EXAMPLE
        PS C:\> "Server1", "Server2" | Get-UpDownTime
        Retrieves uptime and shutdown events for multiple computers using pipeline input.

    .NOTES
        Requires administrative privileges on remote machines to access event logs.
        Uses event IDs:
        - 1074: User-initiated shutdown or restart
        - 6005: System startup
        - 6006: System shutdown
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Management.Automation.PSCustomObject[]])]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [ValidateScript({
            if (Test-Connection -ComputerName $_ -Count 1 -Quiet) {
                $true
            }
            else {
                throw "Unable to contact computer: $_"
            }
        })]
        [Alias('CN', 'PSComputerName')]
        [string[]]$ComputerName = [System.Environment]::MachineName
    )

    process {
        foreach ($Computer in $ComputerName) {
            try {
                if ($PSCmdlet.ShouldProcess($Computer, "Retrieve system uptime and event logs")) {
                    Write-Verbose "Retrieving system uptime for: $Computer"

                    # Get System Uptime
                    $OS = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $Computer -ErrorAction Stop
                    $Uptime = (Get-Date) - $OS.LastBootUpTime

                    Write-Verbose "Retrieving event logs for: $Computer"

                    # Get System Events
                    $Events = Get-WinEvent -ComputerName $Computer -FilterHashtable @{ LogName = 'System'; Id = @(1074, 6005, 6006) } -MaxEvents 20 -ErrorAction Stop

                    # Get most recent shutdown and startup events
                    $StartupTime = ($Events | Where-Object { $_.ID -eq 6005 } | Select-Object -ExpandProperty TimeCreated -First 1 -ErrorAction SilentlyContinue) ?? "Unknown"
                    $ShutdownTime = ($Events | Where-Object { $_.ID -eq 6006 } | Select-Object -ExpandProperty TimeCreated -First 1 -ErrorAction SilentlyContinue) ?? "Unknown"

                    # Calculate downtime
                    $Downtime = if ($StartupTime -is [DateTime] -and $ShutdownTime -is [DateTime]) {
                        $StartupTime - $ShutdownTime
                    }
                    else {
                        "N/A"
                    }

                    # Get user who initiated shutdown
                    $UserSID = $Events | Where-Object { $_.ID -eq 1074 } | Select-Object -First 1
                    $UserName = if ($UserSID.UserID) {
                        (New-Object System.Security.Principal.SecurityIdentifier($UserSID.UserID.Value)).Translate([System.Security.Principal.NTAccount]).Value
                    }
                    else {
                        "Unknown"
                    }

                    # Output results
                    [PSCustomObject]@{
                        ComputerName    = $Computer
                        LastShutdown    = $ShutdownTime
                        LastStartup     = $StartupTime
                        CurrentUptime   = $Uptime.ToString("dd\.hh\:mm\:ss")
                        TotalDowntime   = $Downtime.ToString("dd\.hh\:mm\:ss")
                        UserInformation = "$UserName - $($UserSID.TimeCreated)"
                    }
                }
            }
            catch {
                Write-Warning "Failed to retrieve data for ${$Computer}: $($_.Exception.Message)"
            }
        }
    }
}
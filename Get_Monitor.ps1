function Get-Monitor {
    <#
    .SYNOPSIS
        Retrieves monitor information from local or remote computers.

    .DESCRIPTION
        The Get-Monitor cmdlet retrieves detailed information about monitors connected to specified computers.
        It collects data such as display model, connection type, and serial number using WMI (Windows Management Instrumentation).
        The function supports both local and remote computer queries and includes validation to ensure the target computers
        are reachable before attempting to gather monitor information.

    .PARAMETER ComputerName
        Specifies the name of the computer(s) from which to retrieve monitor information.
        This parameter can accept multiple values, allowing you to query multiple computers at once.
        If not specified, it defaults to the local machine's name.

        Aliases:
        - CN

        Validation:
        - The function validates that the specified computer is reachable using Test-Connection before attempting to gather monitor information.
        - Remote queries require administrative privileges on the target machine.

    .INPUTS
        System.String[]

    .OUTPUTS
        System.Management.Automation.PSCustomObject[]

        Each output object contains the following properties:

        - ComputerName: The name of the computer from which the monitor information was retrieved.
        - DisplayModel: The user-friendly name or model of the monitor.
        - ConnectionType: The type of connection used by the monitor (e.g., HDMI, DVI).
        - Serial: The serial number of the monitor.

    .EXAMPLE
        PS C:\> Get-Monitor

        Retrieves monitor information for the local computer.

    .EXAMPLE
        PS C:\> Get-Monitor -ComputerName 'PC01', 'PC02'

        Retrieves monitor information from the remote computers PC01 and PC02.

    .EXAMPLE
        PS C:\> Get-Monitor -ComputerName $computersList

        Retrieves monitor information for all computers in the $computersList array.

    .EXAMPLE
        PS C:\> Get-Monitor -ComputerName 'DESKTOP-12345' | Where-Object { $_.Serial -eq 'ABC123' }

        Filters the output to show only the monitor with the serial number ABC123 on the computer DESKTOP-12345.

    .EXAMPLE
        PS C:\> Get-Monitor -ComputerName $env:COMPUTERNAME | Sort-Object DisplayModel

        Retrieves monitor information for the local computer and sorts the output by display model.

    .EXAMPLE
        PS C:\> Get-Monitor -ComputerName 'PC01' -Verbose

        Retrieves monitor information for PC01 and displays verbose messages showing the retrieval process.

    .NOTES
        WMI Classes Used:
        - WmiMonitorID: Retrieves the monitor's manufacturer, model, and serial number.
        - WmiMonitorConnectionParams: Retrieves the connection type (e.g., HDMI, VGA, DisplayPort).

        Error Handling:
        - Uses try...catch blocks to prevent the script from stopping due to errors.
        - Skips unreachable computers instead of failing.
        - Provides Write-Verbose output for debugging.

        Requirements:
        - The function must be run with administrative privileges on remote machines.
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
        [Alias('CN')]
        [string[]]$ComputerName = [System.Environment]::MachineName
    )

    process {
        $ConnectionHash = @{
            '-2'         = 'Unknown'
            '-1'         = 'Unknown'
            '0'          = 'VGA'
            '1'          = 'S-Video'
            '2'          = 'Composite'
            '3'          = 'Component'
            '4'          = 'DVI'
            '5'          = 'HDMI'
            '6'          = 'LVDS'
            '8'          = 'D-Jpn'
            '9'          = 'SDI'
            '10'         = 'DisplayPort (external)'
            '11'         = 'DisplayPort (internal)'
            '12'         = 'Unified Display Interface'
            '13'         = 'Unified Display Interface (embedded)'
            '14'         = 'SDTV dongle'
            '15'         = 'Miracast'
            '16'         = 'Internal'
            '2147483648' = 'Internal'
        }

        foreach ($Computer in $ComputerName) {
            if (-not (Test-Connection -ComputerName $Computer -Count 1 -Quiet)) {
                Write-Warning "Skipping ${Computer}: Host is unreachable."
                continue
            }

            try {
                if ($PSCmdlet.ShouldProcess($Computer, "Get monitor connection")) {
                    Write-Verbose "Retrieving monitors for ${Computer}"
                    $Monitors = Get-CimInstance -ComputerName $Computer -Namespace root/wmi -ClassName WmiMonitorID -Verbose:$false

                    if (-not $Monitors) {
                        Write-Verbose "No monitors found for ${Computer}"
                        continue
                    }

                    foreach ($Monitor in $Monitors) {
                        try {
                            $MonitorConnection = Get-CimInstance -ComputerName $Computer -Namespace root/wmi -ClassName WmiMonitorConnectionParams -Verbose:$false | Where-Object { $_.InstanceName -like $Monitor.InstanceName }
                        }
                        catch {
                            Write-Error "Failed to retrieve connection parameters for monitor on ${Computer}: $_"
                            continue
                        }

                        $Serial = ($Monitor.SerialNumberID | Where-Object { $_ -gt 0 } | ForEach-Object { [char]$_ }) -join ''
                        if ([string]::IsNullOrEmpty($Serial)) { $Serial = "N/A" }

                        $DisplayModel = ($Monitor.UserFriendlyName | Where-Object { $_ -gt 0 } | ForEach-Object { [char]$_ }) -join ''
                        if ([string]::IsNullOrEmpty($DisplayModel)) { $DisplayModel = "Unknown Model" }

                        $ConnectionType = $ConnectionHash["$($MonitorConnection.VideoOutputTechnology)"]
                        if (-not $ConnectionType) { $ConnectionType = "Unknown" }

                        [PSCustomObject]@{
                            ComputerName   = $Computer
                            DisplayModel   = $DisplayModel
                            ConnectionType = $ConnectionType
                            Serial         = $Serial
                        } | Write-Output
                    }
                }
            }
            catch {
                Write-Error "Failed to retrieve monitor information for ${Computer}: $_"
            }
        }
    }
}

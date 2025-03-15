function Get-SystemInventory {
    <#
    .SYNOPSIS
    Retrieves system inventory, including hardware, disk space, memory, and network details from local or remote computers.

    .DESCRIPTION
    This function collects system inventory data such as service tag, model, processor, memory, disk space (for all local disks), operating system, and MAC addresses.
    Users can choose to retrieve only specific details using parameters (`-IncludeDisk`, `-IncludeMemory`, `-IncludeNetwork`, or `-IncludeAll`).

    .PARAMETER ComputerName
    The name(s) of the computer(s) to query. Defaults to the local machine if not specified.

    .PARAMETER IncludeDisk
    Retrieves disk space information for **all local disks**, including total size and free space.

    .PARAMETER IncludeMemory
    Retrieves memory details, including free, available, used, and total memory.

    .PARAMETER IncludeNetwork
    Retrieves active network adapter details, including MAC address, IP address, and connection speed.

    .PARAMETER IncludeAll
    Retrieves all available inventory information (equivalent to selecting `-IncludeDisk`, `-IncludeMemory`, and `-IncludeNetwork`).

    .PARAMETER OutputFormat
    Specifies the format of the output. Valid options:
    - `Object` (default) - Returns a PowerShell object.
    - `CSV` - Saves output as a CSV file.
    - `JSON` - Saves output as a JSON file.

    .EXAMPLE
    PS C:\> Get-SystemInventory -ComputerName localhost
    Retrieves hardware inventory for the local computer.

    .EXAMPLE
    PS C:\> Get-SystemInventory -ComputerName Server1, Server2 -IncludeDisk
    Retrieves inventory and disk space details for multiple computers.

    .EXAMPLE
    PS C:\> Get-SystemInventory -ComputerName Workstation1 -IncludeAll -OutputFormat CSV
    Retrieves full inventory for Workstation1 and saves it as a CSV file.

    .NOTES
    - Only **local fixed disks** (DriveType=3) are included when retrieving disk space.
    - Requires administrative privileges on remote machines to retrieve system information.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Management.Automation.PSCustomObject[]])]
    param (
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [ValidateScript({
            if (Test-Connection -ComputerName $_ -Count 1 -Quiet) {
                $true
            } else {
                throw "Unable to contact computer: $_"
            }
        })]
        [Alias('CN')]
        [string[]]$ComputerName = [System.Environment]::MachineName,

        [Parameter()] [switch]$IncludeDisk,
        [Parameter()] [switch]$IncludeMemory,
        [Parameter()] [switch]$IncludeNetwork,
        [Parameter()] [switch]$IncludeAll,

        [Parameter()]
        [ValidateSet("Object", "CSV", "JSON")]
        [string]$OutputFormat = "Object"
    )

    process {
        $InventoryResults = @()

        foreach ($Computer in $ComputerName) {
            try {
                if ($PSCmdlet.ShouldProcess($Computer, "Retrieve system inventory")) {
                    Write-Verbose "Querying inventory for: $Computer"

                    # Retrieve hardware info
                    try {
                        $Bios = Get-CimInstance -Class win32_bios -ComputerName $Computer -ErrorAction Stop
                        $System = Get-CimInstance -Class win32_computersystem -ComputerName $Computer -ErrorAction Stop
                        $OS = Get-CimInstance -Class win32_operatingsystem -ComputerName $Computer -ErrorAction Stop
                        $Processor = Get-CimInstance -Class win32_processor -ComputerName $Computer -ErrorAction Stop
                    }
                    catch {
                        Write-Warning "Failed to retrieve hardware details for ${$Computer}: $($_.Exception.Message)"
                        continue
                    }

                    # Initialize properties
                    $Inventory = [ordered]@{
                        ComputerName = $System.Name
                        ServiceTag   = $Bios.SerialNumber
                        Model        = $System.Model
                        Processor    = $Processor.Name
                        OS           = $OS.Caption
                        Memory       = "$([math]::Round($($System.TotalPhysicalMemory / 1GB), 2)) GB"
                    }

                    # Retrieve disk space for all local disks
                    if ($IncludeDisk -or $IncludeAll) {
                        Write-Verbose "Retrieving disk space for: $Computer"
                        try {
                            $Disks = Get-CimInstance -Class Win32_LogicalDisk -ComputerName $Computer -Filter "DriveType=3" -ErrorAction Stop
                            foreach ($Disk in $Disks) {
                                $Inventory["Disk: $($Disk.DeviceID) Size (GB)"] = [math]::Round($($Disk.Size / 1GB), 2)
                                $Inventory["Disk: $($Disk.DeviceID) Free Space (GB)"] = [math]::Round($($Disk.FreeSpace / 1GB), 2)
                            }
                        }
                        catch {
                            Write-Warning "Failed to retrieve disk space for ${$Computer}: $($_.Exception.Message)"
                        }
                    }

                    # Retrieve memory info
                    if ($IncludeMemory -or $IncludeAll) {
                        Write-Verbose "Retrieving memory usage for: $Computer"
                        try {
                            $OSMemory = Get-CimInstance Win32_OperatingSystem -ComputerName $Computer -ErrorAction Stop
                            $FreeMemPercent = [math]::Round(($OSMemory.FreePhysicalMemory / $OSMemory.TotalVisibleMemorySize) * 100, 2)
                            $UsedMemoryGB = [math]::Round(($OSMemory.TotalVisibleMemorySize - $OSMemory.FreePhysicalMemory) / 1MB, 2)

                            $Inventory['Available Memory'] = "$([math]::Round($OSMemory.FreePhysicalMemory / 1MB, 2)) GB"
                            $Inventory['Used Memory'] = "$UsedMemoryGB GB"
                            $Inventory['Free Memory'] = "$FreeMemPercent %"
                        }
                        catch {
                            Write-Warning "Failed to retrieve memory details for ${$Computer}: $($_.Exception.Message)"
                        }
                    }

                    # Retrieve network details
                    if ($IncludeNetwork -or $IncludeAll) {
                        Write-Verbose "Retrieving network adapters for: $Computer"
                        try {
                            $NetworkAdapters = Get-CimInstance -Class Win32_NetworkAdapterConfiguration -ComputerName $Computer -Filter "IPEnabled=True" -ErrorAction Stop
                            $Inventory["MAC Addresses"] = ($NetworkAdapters.MacAddress -join ", ")
                            $Inventory["IP Addresses"] = ($NetworkAdapters.IPAddress -join ", ")
                        }
                        catch {
                            Write-Warning "Failed to retrieve network details for ${$Computer}: $($_.Exception.Message)"
                        }
                    }

                    $InventoryResults += [PSCustomObject]$Inventory
                }
            }
            catch {
                Write-Warning "Failed to retrieve inventory from ${$Computer}: $($_.Exception.Message)"
            }
        }

        # Handle output formats
        if ($OutputFormat -eq "CSV") { $InventoryResults | Export-Csv -Path "SystemInventory.csv" -NoTypeInformation -Append }
        elseif ($OutputFormat -eq "JSON") { $InventoryResults | ConvertTo-Json -Depth 3 | Out-File "SystemInventory.json" }
        else { $InventoryResults }
    }
}

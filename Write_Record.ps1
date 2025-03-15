function Write-Record {
    <#
    .SYNOPSIS
    Writes structured records to a CSV file and displays them in the console.

    .DESCRIPTION
    The Write-Record function creates structured log entries containing a timestamp, severity level, and message.
    Records are written to both the console and a specified log file in CSV format.

    By default, records are saved to "printerinstall.csv" in the same directory as the script.
    You can specify a custom log file path using the `-RecordPath` parameter.

    .PARAMETER Message
    The message or content to be recorded. This parameter is required and cannot be empty.

    .PARAMETER Severity
    Specifies the severity level of the record.
    Valid values are:
    - Information (default)
    - Warning
    - Error

    This parameter is optional and defaults to 'Information' if not specified.

    .PARAMETER RecordPath
    Specifies the path of the CSV file where records should be saved.
    By default, records are written to "printerinstall.csv" in the script's directory.
    This parameter accepts a full file path to specify a different location.

    Aliases:
    - Path
    - Output

    .INPUTS
    System.String

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    Each record is outputted as a PowerShell object containing:
    - Timestamp: The date and time when the record was created (yyyy-MM-dd HH:mm:ss).
    - Severity: The severity level of the record.
    - Message: The recorded message.

    .EXAMPLE
    PS C:\> Write-Record -Message "Installation started"

    Writes the message "Installation started" with the default severity level (Information) to the default record file.

    .EXAMPLE
    PS C:\> Write-Record -Message "Printer not found" -Severity "Warning"

    Writes a warning message about a missing printer.

    .EXAMPLE
    PS C:\> Write-Record -Message "Driver installation failed!" -Severity "Error" -RecordPath "C:\Logs\printer_errors.csv"

    Writes an error message to a custom record file at "C:\Logs\printer_errors.csv".

    .EXAMPLE
    PS C:\> Write-Record -Message "Task completed successfully" | Export-Csv -Path "C:\Logs\summary.csv" -Append -NoTypeInformation

    Writes a success message and exports the output to a separate summary CSV file.

    .NOTES
    ### Record File Format:
    - Records are written in CSV format for easy parsing.
    - Each record contains a timestamp, severity level, and message.

    ### Error Handling:
    - If the function fails to write to the record file, it displays an error message.
    - The record is always displayed in the console, even if file writing fails.

    ### Requirements:
    - The function must have write access to the specified record file path.
    - If the record file does not exist, it is created automatically.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        # The message or object that is being recorded
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        # The severity level of a record
        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information',

        # Path for where to save the record file
        [Parameter()]
        [Alias('Path', 'Output')]
        [string]$RecordPath = (Join-Path -Path $PSScriptRoot -ChildPath "printerinstall.csv")
    )

    # Create record entry as an object
    $RecordEntry = [PSCustomObject]@{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Severity  = $Severity
        Message   = $Message
    }

    try {
        # Append record entry to CSV file
        $RecordEntry | Export-Csv -Path $RecordPath -Append -NoTypeInformation -Force
    }
    catch {
        Write-Error "Failed to write to record file '$RecordPath': $_"
    }

    # Output record entry to console as well
    $RecordEntry | Format-Table -AutoSize
}
function Write-Log {
    <#
    .SYNOPSIS
    Writes log messages to a CSV file and displays them in the console.

    .DESCRIPTION
    The Write-Log function creates structured log entries containing a timestamp, severity level, and message.
    Log entries are written to both the console and a specified log file in CSV format.

    By default, logs are saved to "printerinstall.csv" in the same directory as the script.
    You can specify a custom log file path using the `-LogPath` parameter.

    .PARAMETER Message
    The log message to be recorded. This parameter is required and cannot be empty.

    .PARAMETER Severity
    Specifies the severity level of the log message.
    Valid values are:
    - Information (default)
    - Warning
    - Error

    This parameter is optional and defaults to 'Information' if not specified.

    .PARAMETER LogPath
    Specifies the path of the CSV log file where log entries should be saved.
    By default, logs are written to "printerinstall.csv" in the script's directory.
    This parameter accepts a full file path to specify a different log file location.

    Aliases:
    - Path
    - Output

    .INPUTS
    System.String

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    Each log entry is outputted as a PowerShell object containing:
    - Timestamp: The date and time when the log entry was recorded (yyyy-MM-dd HH:mm:ss).
    - Severity: The severity level of the log message.
    - Message: The log message content.

    .EXAMPLE
    PS C:\> Write-Log -Message "Installation started"

    Logs the message "Installation started" with the default severity level (Information) to the default log file.

    .EXAMPLE
    PS C:\> Write-Log -Message "Printer not found" -Severity "Warning"

    Logs a warning message about a missing printer.

    .EXAMPLE
    PS C:\> Write-Log -Message "Driver installation failed!" -Severity "Error" -LogPath "C:\Logs\printer_errors.csv"

    Logs an error message to a custom log file at "C:\Logs\printer_errors.csv".

    .EXAMPLE
    PS C:\> Write-Log -Message "Task completed successfully" | Export-Csv -Path "C:\Logs\summary.csv" -Append -NoTypeInformation

    Logs a success message and exports the output to a separate summary CSV file.

    .NOTES
    ### Log File Format:
    - Log entries are written in CSV format for easy parsing.
    - Each log entry contains a timestamp, severity level, and message.

    ### Error Handling:
    - If the function fails to write to the log file, it displays an error message.
    - The log entry is always displayed in the console, even if file writing fails.

    ### Requirements:
    - The function must have write access to the specified log file path.
    - If the log file does not exist, it is created automatically.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        # The message or object that is being logged
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,

        # The severity level of a log message
        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information',

        # Path for where to save the log file
        [Parameter()]
        [Alias('Path', 'Output')]
        [string]$LogPath = (Join-Path -Path $PSScriptRoot -ChildPath "printerinstall.csv")
    )

    # Create log entry as an object
    $LogEntry = [PSCustomObject]@{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Severity  = $Severity
        Message   = $Message
    }

    try {
        # Append log entry to CSV file
        $LogEntry | Export-Csv -Path $LogPath -Append -NoTypeInformation -Force
    }
    catch {
        Write-Error "Failed to write to log file '$LogPath': $_"
    }

    # Output log entry to console as well
    $LogEntry | Format-Table -AutoSize
}

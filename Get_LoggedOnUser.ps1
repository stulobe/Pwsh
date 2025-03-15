<#
.SYNOPSIS
    Retrieves the username of the currently logged-in user on one or more computers.

.DESCRIPTION
    Uses CIM to remotely query which user is currently signed into the specified computer.
    The function can retrieve domain and local accounts logged in via RDP or locally.

.PARAMETER ComputerName
    The name(s) of the computer(s) to query. Defaults to the local machine if not specified.

.PARAMETER IncludeConsoleUsers
    If specified, retrieves users logged into the interactive console session.

.INPUTS
    Accepts pipeline input for the ComputerName parameter.

.OUTPUTS
    System.Management.Automation.PSCustomObject[]

.EXAMPLE
    PS C:\> Get-LoggedOnUser -ComputerName localhost

    ComputerName   LoggedOnUser
    ------------   ------------
    localhost      DOMAIN\username

.EXAMPLE
    PS C:\> "PC1", "PC2" | Get-LoggedOnUser

    Retrieves the logged-in user for multiple computers using pipeline input.

.EXAMPLE
    PS C:\> Get-LoggedOnUser -ComputerName "Server01" -IncludeConsoleUsers

    Retrieves both primary and console users logged into "Server01".

.NOTES
    - Requires administrative privileges on remote machines to retrieve user session details.
    - If querying a remote machine, ensure that WinRM is enabled.
#>
function Get-LoggedOnUser {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Management.Automation.PSCustomObject[]])]
    param (
        # The computer name of the system(s) to check
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

        # Optionally include console session users
        [Parameter()]
        [switch]$IncludeConsoleUsers
    )

    process {
        foreach ($Computer in $ComputerName) {
            try {
                if ($PSCmdlet.ShouldProcess($Computer, "Retrieve logged-on user")) {
                    Write-Verbose "Retrieving logged-on user for: $Computer"

                    # Retrieve the currently logged-in user
                    $User = Get-CimInstance -ClassName win32_computersystem -ComputerName $Computer -ErrorAction Stop

                    $Record = [PSCustomObject]@{
                        ComputerName = $Computer
                        LoggedOnUser = $User.UserName
                    }

                    # Optionally retrieve console session users
                    if ($IncludeConsoleUsers) {
                        try {
                            $ConsoleUsers = (quser /server:$Computer 2>$null) -match "^\s*\S+"
                            if ($ConsoleUsers) {
                                $Usernames = $ConsoleUsers -replace '\s{2,}', ',' | ForEach-Object { ($_ -split ',')[0] }
                                $Record | Add-Member -MemberType NoteProperty -Name "ConsoleUsers" -Value ($Usernames -join ', ')
                            }
                        }
                        catch {
                            Write-Warning "Failed to retrieve console session users for ${$Computer}: $($_.Exception.Message)"
                        }
                    }
                    Write-Output $Record
                }
            }
            catch {
                Write-Warning "Failed to retrieve logged-on user for ${$Computer}: $($_.Exception.Message)"
            }
        }
    }
}

#Requires -RunAsAdministrator
function Set-UAC {
    <#
    .SYNOPSIS
        Manages User Account Control (UAC) settings on Windows systems by modifying the EnableLUA registry key. This function allows enabling or disabling UAC and optionally restarting the system to apply changes.

    .DESCRIPTION
        The Set-UAC function provides a straightforward way to adjust UAC settings, which control user prompts for administrative privileges. By default, the function requires administrative privileges to execute due to the sensitive nature of modifying system-wide security settings.

    .PARAMETER Enable
        A switch parameter that enables User Account Control. When specified, the function sets the registry key value to 1, ensuring UAC is active on the system.

    .PARAMETER Disable
        A switch parameter that disables User Account Control. This option sets the registry key value to 0, turning off UAC prompts for administrative actions.

    .PARAMETER Restart
        An optional switch parameter that triggers an immediate system restart after making changes. If not used, the function informs the user to manually restart the computer for the changes to take effect.

    .INPUTS
        None. This function does not accept pipeline input.

    .OUTPUTS
        None. The function does not return any output; it solely modifies registry settings and may initiate a system restart.

    .EXAMPLE
        # Enable UAC without restarting
        Set-UAC -Enable

        # Disable UAC and restart the computer
        Set-UAC -Disable -Restart

    .NOTES
        - This function must be run with administrative privileges.
        - Modifying UAC settings can affect system security. Disabling UAC may expose the system to potential vulnerabilities by removing user prompts for administrative actions.
        - Always back up your system before making changes to critical registry keys.
        - Changes take effect upon a system restart.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ParameterSetName = "Enable")]
        [switch]$Enable,

        [Parameter(Mandatory, ParameterSetName = "Disable")]
        [switch]$Disable,

        [switch]$Restart
    )

    process {
        $ErrorActionPreference = 'Stop'

        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
        $regName = "EnableLUA"
        $currentValue = Get-ItemProperty -Path $regPath -Name $regName
        Write-Verbose "Current UAC state (EnableLUA): $($currentValue.EnableLUA)"

        if ($PSCmdlet.ShouldProcess($ENV:COMPUTERNAME, "Set User Account Control (UAC)")) {
            if ($Enable) {
                Set-ItemProperty -Path $regPath -Name $regName -Value 1 -Force
            }
            elseif ($Disable) {
                Set-ItemProperty -Path $regPath -Name $regName -Value 0 -Force
            }
            if ($Restart) {
                Write-Verbose -Message "Restarting the system now..." -ForegroundColor Cyan
                Start-Sleep -Seconds 5
                Restart-Computer -Force
            }
            else {
                Write-Verbose "Please restart your computer for the changes to take effect." -ForegroundColor Cyan
            }
        }
    }
}
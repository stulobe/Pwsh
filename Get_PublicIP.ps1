function Get-PublicIP {
    <#
    .SYNOPSIS
    Retrieves the public IP address of the local machine.

    .DESCRIPTION
    This function queries external web services to determine the public IP address.
    If the primary service fails, it automatically falls back to alternative services.

    .PARAMETER Url
    Specifies a custom URL to query for the public IP address.
    If not provided, the function cycles through known reliable services.

    .OUTPUTS
    System.Management.Automation.PSCustomObject

    .EXAMPLE
    PS> Get-PublicIP
    PublicIP
    --------
    203.0.113.45

    .EXAMPLE
    PS> Get-PublicIP -Url "https://api64.ipify.org"
    PublicIP
    --------
    198.51.100.24
    #>
    [CmdletBinding()]
    param (
        [string]$Url
    )

    process {
        $defaultUrls = @(
            'https://ifconfig.me/ip',
            'https://api64.ipify.org',
            'https://checkip.amazonaws.com'
        )

        # If a custom URL is provided, use it. Otherwise, use the default list.
        $urlList = if ($Url) { @($Url) } else { $defaultUrls }

        foreach ($service in $urlList) {
            try {
                Write-Verbose "Querying public IP from: $service"
                $publicIP = Invoke-RestMethod -Uri $service -ErrorAction Stop

                # Ensure the response is not empty or invalid
                if ($publicIP -match '^\d{1,3}(\.\d{1,3}){3}$') {
                    return [PSCustomObject]@{ PublicIP = $publicIP }
                }
                else {
                    Write-Warning "Received unexpected response from ${$service}: '$publicIP'"
                }
            }
            catch {
                Write-Warning "Failed to retrieve public IP from ${$service}: $($_.Exception.Message)"
            }
        }

        # If all services fail, return null
        Write-Error "Could not determine public IP address from any service."
        return $null
    }
}

function Get-RDAPWhois {
    <#
    .SYNOPSIS
        Retrieves WHOIS information for an IP address using RDAP.

    .DESCRIPTION
        Queries the RDAP (Registration Data Access Protocol) API from ARIN to obtain details about an IP address.
        The function returns structured information, including organization details, address, city, and state.

    .PARAMETER IP
        Specifies the IP address to look up. Must be a valid IPv4 or IPv6 address.
        This parameter is mandatory and supports pipeline input.

    .EXAMPLE
        PS C:\> Get-RDAPWhois -IP 8.8.8.8
        Retrieves RDAP WHOIS information for Google's public DNS IP.

    .EXAMPLE
        PS C:\> "8.8.8.8", "1.1.1.1" | Get-RDAPWhois
        Retrieves WHOIS information for multiple IP addresses using pipeline input.

    .OUTPUTS
        System.Management.Automation.PSCustomObject
        The function returns an object with the following properties:
        - IPAddress: The IP address queried.
        - Name: The registered name associated with the IP.
        - Organization: The organization that owns the IP.
        - Address: The full address associated with the organization.
        - City: The city where the organization is located.
        - State: The state or region where the organization is located.

    .NOTES
        - This function queries ARIN RDAP for IP lookups.
        - If no organization details are available, the function will display "Unknown".
        - This function does not perform domain lookups, only IP lookups.
        - Requires internet access to query RDAP.

    .LINK
        https://www.arin.net/reference/research/whois/

    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({ $_ -as [ipaddress] })]
        [string]$IP
    )

    try {
        $rdapBaseUrl = "https://rdap.arin.net/registry"
        $rdapUrl = "$rdapBaseUrl/ip/$IP"
        Write-Verbose "Querying RDAP API for $IP"

        $restRdap = Invoke-RestMethod -Uri $rdapUrl -ErrorAction Stop

        if ($restRdap.entities) {
            $vcard = $restRdap.entities.vcardArray
            $vcardAddress = $vcard[1]

            # Extract organization name
            $organization = ($vcardAddress | Where-Object { $_ -match 'fn' })[3] -as [string]

            # Extract address label (replacing newline characters)
            $addressLabel = ($vcardAddress | Where-Object { $_ -match 'adr' })[1].Label -replace "`n", ", "

            # Ensure address exists before processing
            if (-not $addressLabel) {
                Write-Warning "No address found for $IP"
                $addressLabel = "Unknown"
            }

            $splitAddress = $addressLabel -split ", "

            # Initialize values
            $city, $state = $null, $null

            # Improved parsing of City/State from address
            foreach ($line in $splitAddress) {
                if (-not $city -and $line -match "^[a-zA-Z\s]+$") { $city = $line.Trim() }
                if (-not $state -and $line -match "^[A-Z]{2}$") { $state = $line.Trim() }
            }

            # If city/state are still unknown, default to "Unknown"
            if (-not $city) { $city = "Unknown" }
            if (-not $state) { $state = "Unknown" }

            [PSCustomObject]@{
                IPAddress    = $IP
                Name         = $restRdap.name
                Organization = $organization
                Address      = $addressLabel
                City         = $city
                State        = $state
            }
        }
        else {
            Write-Warning "No entities found for IP $IP"
        }
    }
    catch {
        Write-Error "Error retrieving RDAP data for ${$IP}: $_"
    }
}
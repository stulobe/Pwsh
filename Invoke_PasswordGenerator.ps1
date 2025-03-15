function Invoke-PasswordGenerator {
    <#
    .SYNOPSIS
    Generates a random password.

    .DESCRIPTION
    This function generates a random password of a specified length, with the option to include special characters.

    .PARAMETER Length
    Specifies the length of the password. Default is 15. The minimum allowed length is 6, and the maximum is 128.

    .PARAMETER IncludeSpecialChars
    If specified, includes special characters in the password.

    .OUTPUTS
    System.String

    .EXAMPLE
    PS C:\> Invoke-PasswordGenerator
    Generates a 15-character password using alphanumeric characters.

    .EXAMPLE
    PS C:\> Invoke-PasswordGenerator -Length 20 -IncludeSpecialChars
    Generates a 20-character password including special characters.

    .NOTES
    - Uses Get-Random for character selection.
    - Not intended for cryptographic security.
    #>

    [CmdletBinding()]
    param (
        [Parameter()]
        [ValidateRange(6, 128)]
        [int]$Length = 15,

        [Parameter()]
        [switch]$IncludeSpecialChars
    )

    process {
        # Define character sets
        $BaseChars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
        $SpecialChars = '!@#$%^&*()_+=-{}[]:;<>,.?/~`|'

        if ($IncludeSpecialChars) {
            Write-Verbose "Special characters included in password generation."
            $Chars = $BaseChars + $SpecialChars
        }
        else {
            Write-Verbose "Only alphanumeric characters used in password generation."
            $Chars = $BaseChars
        }

        $CharsArray = $Chars.ToCharArray()

        try {
            # Select $Length random characters, one at a time
            $FinalPW = -join (1..$Length | ForEach-Object { Get-Random -InputObject $CharsArray })
            Write-Output $FinalPW
        }
        catch {
            Write-Error "Failed to generate password: $($_.Exception.Message)"
            return $null
        }
    }
}

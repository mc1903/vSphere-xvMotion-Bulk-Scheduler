<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Set-Securepassword
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Saves a password for the specified vCenter Server host and user, securley, into the current users registry.

.DESCRIPTION
The Set-Securepassword function saves a password for the specified vCenter Server host and user, in an obfuscated way within the current users registry (HKCU:).

.PARAMETER hostName
The vCenter Server FQDN for which the password needs to be saved.

.PARAMETER userName
The vCenter Server username for which the password needs to be saved.

.PARAMETER password
The secure password to be set. If not provided, the function will prompt for input.

.EXAMPLE
$params = @{
    Hostname = "mc-vcsa-v-201.momusconsulting.com"
    Username = "administrator@vsphere.local"
}
Set-SecurePassword @params

#>

Function Set-Securepassword {

    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String] $hostName,

        [Parameter(
            Position = 1,
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String] $userName,

        [Parameter(
            Position = 2,
            Mandatory = $false
        )]
        [SecureString] $password

    )

    Function Get-SHA256Hash {
        
        [CmdletBinding()]

        Param (
            [Parameter(
                ValueFromPipeline = $true,
                Mandatory = $true
            )]
            [ValidateNotNullOrEmpty()]
            [string]$String
        )
    
        Write-Verbose  "Calculating SHA256 Hash."
        $Private:productKey = (Get-WmiObject -Class SoftwareLicensingService).OA3xOriginalProductKey
        $Private:nicMac = (Get-NetAdapter | Select-Object -First 1).MacAddress
        $Private:diskUniqueId = (Get-Disk | Select-Object -First 1).UniqueId
        $Private:String += $($env:COMPUTERNAME), $($env:userName), $productKey, $nicMac, $diskUniqueId -join ""
        $Private:sha256 = [System.Security.Cryptography.SHA256Managed]::Create()
        $Private:hashBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))
        $Private:hashString = [BitConverter]::ToString($hashBytes).Replace("-", "")
        Return $hashString

    }

    Function Get-AES256SecureKey {
    
        [CmdletBinding()]
    
        Param (
            [Parameter(
                ValueFromPipeline = $true,
                Mandatory = $true
            )]
            [ValidateNotNullOrEmpty()]
            [string]$String
        )

        Write-Verbose  "Calculating AES256 Secure Key."
        $Private:sha256 = [System.Security.Cryptography.SHA256]::Create()
        $Private:StringBytes = [System.Text.Encoding]::UTF8.GetBytes($String)
        $Private:StringHash = $sha256.ComputeHash($StringBytes)
        $Private:secureKey = $StringHash[0..31]
        Return $secureKey
    }    

    If (-not $password) {
        #$Private:password = Read-Host -Prompt "Please enter the password for $($userName) on $($hostName)." -AsSecureString#
        # "Enter credentials for vCenter Server $($vCenter.hostname)"
        $Private:credentials = Get-Credential -UserName $userName -Message "Please enter the password for $($userName) on $($hostName)."
        $Private:userName =  $credentials.UserName
        $Private:password = $credentials.Password
    }
    
    $Private:SaltHash = Get-SHA256Hash -String $($($hostName), $($userName) -join "")
    $Private:SecureSaltKey = Get-AES256SecureKey -String $SaltHash
    $Private:EncryptedValue = ConvertFrom-SecureString -SecureString $password -Key $SecureSaltKey
    
    $Private:Output = [PSCustomObject]@{
        'SaltHash' = $SaltHash
    }
    
    $Private:RegPath = "HKCU:\SOFTWARE\Classes\Private\078d5620-5f40-411b-b560-b079438ff9ff\"
    
    If (!(Test-Path $RegPath)) {
        New-Item $RegPath -Force | Out-Null
    }
    
    Set-ItemProperty -Path $RegPath -Name $SaltHash -Value $EncryptedValue -Force
    $Private:RegTest = Get-ItemProperty -Path $RegPath -Name $SaltHash

    If ($null -ne $RegTest) {
        $Output | Add-Member -MemberType NoteProperty -Name "Success" -Value $true
    }
    Else {
        $Output | Add-Member -MemberType NoteProperty -Name "Error" -Value $true
    }

    Return $Output | Format-List

}


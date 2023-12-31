<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Get-SecurePassword (Private)
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
This function retrieves a secure password for a specified host and user.

.DESCRIPTION
The Get-SecurePassword function allows you to obtain a secure password for a specified host and user. The retrieved password is stored as a secure string.

.PARAMETER hostName
The name or IP address of the host for which the password is being retrieved. This parameter is mandatory and cannot be empty.

.PARAMETER userName
The username for which the password is being retrieved. This parameter is mandatory and cannot be empty.

.PARAMETER showPlainTextPassword
By default, the retrieved password is not displayed in plain text. If this switch parameter is used, the plain text password will be shown in the console.

.EXAMPLE
Get-SecurePassword -hostName "192.168.1.1" -userName "admin"

This example retrieves a secure password for the user "admin" on the host with the IP address "192.168.1.1". The password is stored as a secure string.

.EXAMPLE
Get-SecurePassword -hostName "hostname" -userName "user" -showPlainTextPassword

This example retrieves a secure password for the user "user" on the host with the name "hostname". The plain text password will be shown in the console.

#>

Function Get-SecurePassword {

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
        [Switch] $showPlainTextPassword
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

        $Private:sha256 = [System.Security.Cryptography.SHA256]::Create()
        $Private:StringBytes = [System.Text.Encoding]::UTF8.GetBytes($String)
        $Private:StringHash = $sha256.ComputeHash($StringBytes)
        $Private:secureKey = $StringHash[0..31]
        Return $secureKey
        
    }

    $Private:SaltHash = Get-SHA256Hash -String $($($hostName), $($userName) -join "")
    $Private:RegPath = "HKCU:\SOFTWARE\Classes\Private\078d5620-5f40-411b-b560-b079438ff9ff\"
    $Private:EncryptedValue = (Get-ItemProperty -Path $RegPath -Name $SaltHash -ErrorAction SilentlyContinue)."$SaltHash"
    
    If (!$EncryptedValue) {
        $Private:ErrorOut = [PSCustomObject]@{
            'Error'   = $true
            'Message' = "No saved password was found"
        }
        Return $ErrorOut
    }
        
    $Private:SecureSaltKey = Get-AES256SecureKey -String $SaltHash
    $Private:SecureValue = ConvertTo-SecureString -String $EncryptedValue -Key $SecureSaltKey 
    
    $Private:Output = [PSCustomObject]@{
        'Success'        = $true
        'Message'        = "A saved password was found"
        'SecurePassword' = $SecureValue
    }
    
    If ($showPlainTextPassword) {
        $Output | Add-Member -MemberType NoteProperty -Name "ClearPassword" -Value ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)))
    }
    
    Return $Output

}


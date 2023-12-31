<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Connect-xvmSite
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Connects the xvm Fling to a vCenter Server

.DESCRIPTION
The Connect-xvmSite function establishes a connection between the xvm Fling and a vCenter Server. 

.PARAMETER ipAddress
The IP address of xvm Fling. The default value is "127.0.0.1".

.PARAMETER port
The TCP Port number the xvm Fling is using. The default value is 8443.

.PARAMETER siteName
Usually the hostname of the vCenter Server, but must match the sourceSite or targetSite, as specified in the Migration Task CSV file.

.PARAMETER vCenterFQDN
The fully qualified domain name (FQDN) of the vCenter Server.

.PARAMETER vCenterUsername
The username used to authenticate with the vCenter Server. i.e administrator@vsphere.local

.PARAMETER vCenterPassword
The password used to authenticate with the vCenter Server. Must be supplied as a SecureString. If not provided and in the absence of -useSavedPassword, the function will prompt for input.

.PARAMETER useSavedPassword
Specifies whether to use a saved password instead of providing a password.
Use the Set-SecurePassword function to save password in an obfuscated way in the current users registry (HKCU:)

.PARAMETER skipCertificateCheck
Specifies whether the xvm Fling skips the certificate check when connecting to the vCenter Server.

.PARAMETER jsonOut
Specifies to output the result in JSON format. The default is a PowerShell Custom Object.

.EXAMPLE
$params = @{
    siteName = "mc-vcsa-v-201"
    vCenterFQDN = "mc-vcsa-v-201.momusconsulting.com"
    vCenterUsername = "administrator@vsphere.local"
    useSavedPassword = $true
    skipCertificateCheck = $true
    jsonOut = $true
}
Connect-xvmSite @params

#>

Function Connect-xvmSite {

    [CmdletBinding(
        DefaultParameterSetName = 'WithPassword'
    )]

    Param (
        [Parameter(
            Position = 0,
            Mandatory = $false
        )]
        [ValidateNotNullOrEmpty()]
        [String]$ipAddress = "127.0.0.1",

        [Parameter(
            Position = 1,
            Mandatory = $false
        )]
        [ValidateNotNullOrEmpty()]
        [Int]$port = 8443,

        [Parameter(
            Position = 2,
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String]$siteName,

        [Parameter(
            Position = 3,
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String]$vCenterFQDN,

        [Parameter(
            Position = 4,
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String]$vCenterUsername,

        [Parameter(
            Position = 5,
            Mandatory = $false,
            ParameterSetName = "WithPassword"
        )]
        [ValidateNotNullOrEmpty()]
        [SecureString]$vCenterPassword,

        [Parameter(
            Position = 5,
            Mandatory = $false,
            ParameterSetName = "WithSavedPassword"
        )]
        [Switch] $useSavedPassword,

        [Parameter(
            Position = 6,
            Mandatory = $false
        )]
        [Switch] $skipCertificateCheck,

        [Parameter(
            Position = 7,
            Mandatory = $false
        )]
        [Switch] $jsonOut
    )

    Write-LogMessage -message "Function: Connect-xvmSite"

    If ([string]::IsNullOrWhiteSpace($vCenterPassword) -and !$useSavedPassword) {
        Write-LogMessage -message "Requesting username & password are privided interactivly"
        $Credential = Get-Credential -UserName $vCenterUsername -Message "Enter credentials for vCenter: $($vCenterFQDN)"
        $vCenterUsername = $Credential.UserName
        $Private:vCenterPassword = $Credential.Password
    } 
    ElseIf ($useSavedPassword) {
        Write-LogMessage -message "Attempting to retrieve the secure saved password for user $($vCenterUsername) on vCenter Server $($vCenterFQDN)"
        $SavedPassword = Get-SecurePassword -Hostname $vCenterFQDN -Username $vCenterUsername
        If ($SavedPassword.Error) {
            Write-LogMessage -message $($SavedPassword.Message) -isWarning
            Break
        }
        ElseIf ($SavedPassword.Success) {
            Write-LogMessage -message $($SavedPassword.Message)
            $Private:vCenterPassword = $($SavedPassword.SecurePassword)    
        }
    }
   
    If ("TrustAllCertsPolicy" -as [type]) {} 
    Else {
        Add-Type "using System.Net;using System.Security.Cryptography.X509Certificates;public class TrustAllCertsPolicy : ICertificatePolicy {public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {return true;}}"
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    [uri]$url = "https://$($ipAddress):$($port)/api/sites"

    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/json"
    }
    
    $body = @{
        "sitename" = $($siteName)
        "hostname" = $($vCenterFQDN)
        "username" = $($vCenterUsername)
        "password" = $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($vCenterPassword)))
        "insecure" = $($skipCertificateCheck.ToString())
    } | ConvertTo-Json -Depth 5

    Write-LogMessage -message "Attempting to connect xvm to vCenter Server $($vCenterFQDN)"

    Try {
        Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $body
    }
    Catch {
        $errorresponse = [PSCustomObject]@{
            StatusCode = $_.Exception.Response.StatusCode.value__
            Message    = $_.Exception.Message
        }
    
        Write-LogMessage -message "Failed to connect xvm to vCenter Server $($vCenterFQDN)" -isWarning

        If ($jsonOut) {
            Return $errorresponse | ConvertTo-Json -Depth 5
        }
        Else {
            Return $errorresponse
        }
    }

    Write-LogMessage -message "Successfully connected xvm to vCenter Server $($vCenterFQDN)"

    $response = Get-xvmSites -ipAddress $ipAddress -port $port -siteName $siteName -noLogMsgs

    Write-LogMessage -message $($response | ConvertTo-Json -Depth 5) -noConsoleOutput

    If ($jsonOut) {
        Return $response | ConvertTo-Json -Depth 5
    }
    Else {
        Return $response
    }

}

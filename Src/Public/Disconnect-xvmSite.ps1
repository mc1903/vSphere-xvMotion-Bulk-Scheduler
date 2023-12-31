<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Disconnect-xvmSite
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Disconnects the xvm Fling from a vCenter Server

.DESCRIPTION
The Disconnect-xvmSite function is used to disconnect the xvm Fling from a vCenter Server

.PARAMETER ipAddress
The IP address of xvm Fling. The default value is "127.0.0.1".

.PARAMETER port
The TCP Port number the xvm Fling is using. The default value is 8443.

.PARAMETER siteName
Usually the hostname of the vCenter Server.

.PARAMETER jsonOut
Specifies to output the result in JSON format. The default is a PowerShell Custom Object.

.EXAMPLE
Disconnect-xvmSite -Sitename mc-vcsa-v-201

#>

Function Disconnect-xvmSite {

    [CmdletBinding()]

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
            Mandatory = $false
        )]
        [Switch] $jsonOut
    )

    Write-LogMessage -message "Function: Disconnect-xvmSite"
    Write-LogMessage -message "Attempting to disconnect xvm from vCenter Server site: $siteName"

    If ("TrustAllCertsPolicy" -as [type]) {} 
    Else {
        Add-Type "using System.Net;using System.Security.Cryptography.X509Certificates;public class TrustAllCertsPolicy : ICertificatePolicy {public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {return true;}}"
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    [uri]$url = "https://$($ipAddress):$($port)/api/sites/$($siteName)"

    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/json"
    }

    Try {
        Invoke-RestMethod -Method Delete -Uri $url -Headers $headers
    }
    Catch {
        $errorresponse = [PSCustomObject]@{
            StatusCode = $_.Exception.Response.StatusCode.value__
            Message    = $_.Exception.Message
        }
    
        If ($jsonOut) {
            Return $errorresponse | ConvertTo-Json -Depth 5
        }
        Else {
            Return $errorresponse
        }
    }

    If ($jsonOut) {
        Get-xvmSites -ipAddress $ipAddress -port $port -jsonOut
    }
    Else {
        Get-xvmSites -ipAddress $ipAddress -port $port
    }

}

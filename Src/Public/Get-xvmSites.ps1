<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Get-xvmSites
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Retrieves the status of a site (vCenter Server) from the xvm Fling.

.DESCRIPTION
The Get-xvmSites function retrieves the status of a site (or all sites) from the xvm Fling.

.PARAMETER ipAddress
The IP address of xvm Fling. The default value is "127.0.0.1".

.PARAMETER port
The TCP Port number the xvm Fling is using. The default value is 8443.

.PARAMETER siteName
Specifies the name of the xvm site. If not specified, all the status of all registered sites will be returned.

.PARAMETER jsonOut
Specifies to output the result in JSON format. The default is a PowerShell Custom Object.

.EXAMPLE
Get-xvmSites -jsonOut

Get-xvmSites -siteName mc-vcsa-v-201 -jsonOut

#>

Function Get-xvmSites {

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
            Mandatory = $false
        )]
        [ValidateNotNullOrEmpty()]
        [String]$siteName,


        [Parameter(
            Position = 3,
            Mandatory = $false
        )]
        [System.Management.Automation.SwitchParameter] $jsonOut,

        [Parameter(
            Position = 4,
            Mandatory = $false
        )]
        [System.Management.Automation.SwitchParameter] $noLogMsgs
    )

    If (!$noLogMsgs) {
        Write-LogMessage -message "Function: Get-xvmSites"
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
    
    Try {
        $response = Invoke-RestMethod -Method Get -Uri $url -Headers $headers
    }
    Catch {
        $errorresponse = [PSCustomObject]@{
            StatusCode = $_.Exception.Response.StatusCode.value__
            Message    = $_.Exception.Message
        }
    
        Write-LogMessage -message $($errorresponse | ConvertTo-Json -Depth 5) -isWarning -noConsoleOutput

        If ($jsonOut) {
            Return $errorresponse | ConvertTo-Json -Depth 5
        }
        Else {
            Return $errorresponse
        }
    }

    If ($siteName) {
        $response = $response | Where-Object { $_.sitename -eq $siteName }
    }

    If ($noLogMsgs) {
        Write-LogMessage -message $($response | ConvertTo-Json -Depth 5) -noConsoleOutput -noLogfileEntry
    }

    If ($jsonOut) {
        Return $response | ConvertTo-Json -Depth 5
    }
    Else {
        Return $response
    }

}


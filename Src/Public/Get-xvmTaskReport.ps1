<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Get-xvmTaskReport
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Retrieves a summary report of all tasks from the xvm Fling.

.DESCRIPTION
The Get-xvmTaskReport function retrieves a summary report of all tasks from the xvm Fling and converts some values into human readable friendly values.

.PARAMETER ipAddress
The IP address of xvm Fling. The default value is "127.0.0.1".

.PARAMETER port
The TCP Port number the xvm Fling is using. The default value is 8443.

.PARAMETER jsonOut
Indicates whether to output the task report in JSON format. If neither -jsonOut or -csvOut are specified, the default is a PowerShell Custom Object.

.PARAMETER csvOut
Indicates whether to output the task report in CSV format. If neither -jsonOut or -csvOut are specified, the default is a PowerShell Custom Object.

.EXAMPLE
Get-xvmTaskReport -csvOut

#>

Function Get-xvmTaskReport {

    [CmdletBinding()]
    
    Param (
        [Parameter(
            Position = 0,
            Mandatory = $false
        )]
        [ValidateNotNullOrEmpty()]
        [ipAddress]$ipAddress = "127.0.0.1",

        [Parameter(
            Position = 1,
            Mandatory = $false
        )]
        [ValidateNotNullOrEmpty()]
        [int]$port = 8443,

        [Parameter(
            Position = 2,
            Mandatory = $false
        )]
        [switch] $jsonOut,

        [Parameter(
            Position = 3,
            Mandatory = $false
        )]
        [switch] $csvOut
    )

    If ("TrustAllCertsPolicy" -as [type]) {} 
    Else {
        Add-Type "using System.Net;using System.Security.Cryptography.X509Certificates;public class TrustAllCertsPolicy : ICertificatePolicy {public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {return true;}}"
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    [uri]$url = "https://$($ipAddress):$($port)/api/tasks"

    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/json"
    }
    
    $body = @{}

    Try {
        $response = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -Body $body -TimeoutSec 5
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

    $finalResponse = $response | Sort-Object vmName | ForEach-Object {
        $timestamp = [datetimeoffset]::FromUnixTimeMilliseconds($_.timestamp)
        [PSCustomObject]@{
            vmName = $_.vmName
            status = $_.status
            timedate = $timestamp.ToString("dd-MM-yyyy HH:mm:ss")
            sourceSite = $_.sourceSite
            targetSite = $_.targetSite
            durationSec = $_.duration
            durationHMS = '{0:hh\:mm\:ss}' -f [timespan]::fromseconds($_.duration)
            progress = $_.progress
            info = $_.info
            requestId = $_.requestId
        }
    }
    
    If ($jsonOut) {
        Return $finalResponse | ConvertTo-Json -Depth 5
    }
    ElseIf ($csvOut) {
        Return $finalResponse | ConvertTo-Csv -NoTypeInformation | Out-String
    }
    Else {
        Return $finalResponse
    }

}


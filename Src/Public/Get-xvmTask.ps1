<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Get-xvmTask
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Retrieves the status of a task from the xvm Fling.

.DESCRIPTION
The Get-xvmTask function retrieves the status of a task (or all tasks) from the xvm Fling.

.PARAMETER ipAddress
The IP address of xvm Fling. The default value is "127.0.0.1".

.PARAMETER port
The TCP Port number the xvm Fling is using. The default value is 8443.

.PARAMETER requestId
The requestId of the task you want the status returned for. If not specified, the status of all tasks will be returned.

.PARAMETER jsonOut
Specifies to output the result in JSON format. The default is a PowerShell Custom Object.

.EXAMPLE
Get-xvmTask -jsonOut

Get-xvmTask -requestId b72df5e0-4510-4a6c-8d29-3c87a3a2bc14 -jsonOut
#>

Function Get-xvmTask {

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
        [ValidateNotNullOrEmpty()]
        [string]$requestId,

        [Parameter(
            Position = 3,
            Mandatory = $false
        )]
        [switch] $jsonOut,

        [Parameter(
            Position = 4,
            Mandatory = $false
        )]
        [switch] $noLogMsgs
    )

    If (!$noLogMsgs) {
        Write-LogMessage -message "Function: Get-xvmTask"
    }
    
    
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
    
    $body = @{
        "requestId" = $($requestId)
    }

    Try {
        $response = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -Body $body -TimeoutSec 5
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

    If (!$noLogMsgs) {
        Write-LogMessage -message $($response | ConvertTo-Json -Depth 5) -noConsoleOutput
    }

    If ($jsonOut) {
        Return $response | ConvertTo-Json -Depth 5
    }
    Else {
        Return $response
    }

}


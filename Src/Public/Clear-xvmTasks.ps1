<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Clear-xvmTasks
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Clears all completed tasks from the xvm Fling 'Task Information' history.

.DESCRIPTION
The Clear-xvmTasks function clears all completed tasks from the xvm Fling 'Task Information' history.

.PARAMETER ipAddress
The IP address of xvm Fling. The default value is "127.0.0.1".

.PARAMETER port
The TCP Port number the xvm Fling is using. The default value is 8443.

.PARAMETER jsonOut
Specifies to output the result in JSON format. The default is a PowerShell Custom Object.

.EXAMPLE
Clear-xvmTasks

#>

Function Clear-xvmTasks{

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
        [switch] $jsonOut
    )

    Write-LogMessage -message "Function: Clear-xvmTasks"

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
        "requestId" = $($RequestID)
    }

    Try {
        $response = Invoke-RestMethod -Method Delete -Uri $url -Headers $headers -Body $body -TimeoutSec 5
    }
    Catch {
        $errorresponse = [PSCustomObject]@{
            StatusCode = $_.Exception.Response.StatusCode.value__
            Message = $_.Exception.Message
        }
    
        If ($jsonOut) {
            Return $errorresponse | ConvertTo-Json -Depth 5
        }
        Else {
            Return $errorresponse
        }
    }

    If ($jsonOut) {
        Return $response | ConvertTo-Json -Depth 5
    }
    Else {
        Return $response
    }

}


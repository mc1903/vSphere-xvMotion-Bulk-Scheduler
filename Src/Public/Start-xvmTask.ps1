<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Start-xvmTask
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Submits a json task to the xvm Fling to initiate a VM migration. 

.DESCRIPTION
The Start-xvmTask function submits a json task to the xvm Fling to initiate a VM migration. Usually called by the Windows Task Scheduler task, but can be executed on it's own.

.PARAMETER ipAddress
The IP address of xvm Fling. The default value is "127.0.0.1".

.PARAMETER port
The TCP Port number the xvm Fling is using. The default value is 8443.

.PARAMETER MaxSimultaneousTasks
Defailt is 4
The maximum number of simultaneous tasks that can be running and/or queued. Once this limit is reached new tasks will wait to be submitted to xvm.

.PARAMETER jsonOut
Specifies to output the result in JSON format. The default is a PowerShell Custom Object.

.EXAMPLE
$params = @{
    xvmJsonTaskFile = "P:\VMware\Bulk xvMotion\TaskJsonFiles\TestVM01-Win__mc-vcsa-v-201-vcf-m01-vc01.json"
    jsonOut = $true
}

Start-xvmTask @params

#>

Function Start-xvmTask {

    [CmdletBinding(
        DefaultParameterSetName = 'JsonVar'
    )]

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
            Mandatory = $true,
            ParameterSetName = 'jsonVar'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$taskJson,

        [Parameter(
            Position = 2,
            Mandatory = $true,
            ParameterSetName = 'jsonFile'
        )]
        [ValidateNotNullOrEmpty()]
        [string]$taskJsonFile,

        [Parameter(
            Position = 3,
            Mandatory = $false
        )]
        [ValidateNotNullOrEmpty()]
        [int]$maxSimultaneousTasks = 4,

        [Parameter(
            Position = 4,
            Mandatory = $false
        )]
        [switch] $jsonOut
    )

    Write-LogMessage -message "Function: Start-xvmTask"

    If ($taskJsonFile) {
        $taskJson = Confirm-JsonData -FilePath $taskJsonFile
    }

    If ("TrustAllCertsPolicy" -as [type]) {} 
    Else {
        Add-Type "using System.Net;using System.Security.Cryptography.X509Certificates;public class TrustAllCertsPolicy : ICertificatePolicy {public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {return true;}}"
        [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $randomDelay = Get-Random -Minimum 2 -Maximum 10
    Write-LogMessage -message "Random delay is $randomDelay seconds"
    Start-Sleep -Seconds $randomDelay

    $xvmLiveTasks = Get-xvmTask -ipAddress $ipAddress -port $port -noLogMsgs | Where-Object { $_.status -eq 'running' -or $_.status -eq 'queued' -or $_.status -eq 'init' } | Measure-Object | Select-Object -ExpandProperty Count
    If ($xvmLiveTasks -ge $MaxSimultaneousTasks) {
        Write-LogMessage -message "There are currently $xvmLiveTasks running or queued tasks"
        Write-LogMessage -message "This task will not be submitted until one or more existing task has completed"
        While ($xvmLiveTasks -ge $MaxSimultaneousTasks) {
            Start-Sleep -Seconds 5
            $xvmLiveTasks = Get-xvmTask -ipAddress $ipAddress -port $port -noLogMsgs | Where-Object { $_.status -eq 'running' -or $_.status -eq 'queued' } | Measure-Object | Select-Object -ExpandProperty Count
            If ($xvmLiveTasks -ge $MaxSimultaneousTasks) {
                Write-LogMessage -message "There are still $xvmLiveTasks running or queued tasks"
            }
            Else {
                Write-LogMessage -message "There are now $xvmLiveTasks running or queued tasks"
            }
        }
    }
   
    Write-LogMessage -message "Submitting the task into xvm"

    [uri]$url = "https://$($ipAddress):$($Port)/api/tasks"

    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/json"
    }
    
    Write-LogMessage -message "Task Json:"
    Write-LogMessage -message $TaskJson

    $body = $TaskJson

    Try {
        $response = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $body -TimeoutSec 5
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

    Write-LogMessage -message $($response | ConvertFrom-Json | ConvertTo-Json -Depth 5) -noConsoleOutput

    If ($jsonOut) {
        Return $response | ConvertFrom-Json | ConvertTo-Json -Depth 5
    }
    Else {
        Return $response | ConvertFrom-Json
    }

}


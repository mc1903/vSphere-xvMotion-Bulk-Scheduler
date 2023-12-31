<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Invoke-xvmFling
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Invokes the xvm Fling utility.

.DESCRIPTION
The Invoke-xvmFling function is used to start xvm Fling environment.

.PARAMETER jreFile
Specifies the path to the JRE (Java Runtime Environment) executable file.

.PARAMETER jarFile
Specifies the path to the xvm Fling JAR (Java Archive) file.

.PARAMETER port
The TCP Port number the xvm Fling is using. The default value is 8443.

.PARAMETER openBrowser
Indicates whether to automatically open the default web browser. By default, the value is set to false.

.PARAMETER noStatus
Specifies whether to suppress the XVM Fling API status pop-out window. By default, the value is set to false.

.EXAMPLE
$params = @{
    jreFile = "C:\Program Files\Java\jre-1.8\bin\java.exe"
    jarFile = "P:\VMware\Bulk xvMotion\xvm-3.1.jar"
    OpenBrowser = $true
}

Invoke-xvmFling @params

#>

Function Invoke-xvmFling {

    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String] $jreFile,
    
        [Parameter(
            Position = 1,
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String] $jarFile,
    
        [Parameter(
            Position = 2,
            Mandatory = $false
        )]
        [ValidateNotNullOrEmpty()]
        [String] $port = 8443,
    
        [Parameter(
            Position = 3,
            Mandatory = $false
        )]
        [Switch] $openBrowser,

        [Parameter(
            Position = 4,
            Mandatory = $false
        )]
        [Switch] $noStatus
    )

    $logFileDir = "$((Get-ChildItem -Path $jarFile).DirectoryName)\Logs\"
    If (!(Test-Path -Path $logFileDir -PathType Container)) {
        New-Item -ItemType Directory -Path $logFileDir -Force | Out-Null
    }

    $date = (Get-Date).ToString('dd-MM-yyyy_HH-mm-ss')
    $logFile = "$((Get-ChildItem -Path $jarFile).DirectoryName)\Logs\xvmLog_$date.log"
    $env:xvmLogFile = $logFile 
    [System.Environment]::SetEnvironmentVariable("xvmLogFile", $logFile, "User")

    Write-LogMessage -message "Function: Invoke-xvmFling"
    Write-LogMessage -message "Logging to $($logFile)"

    Write-LogMessage -message "Getting Short File Paths"
    $jreFileShort = Get-ShortFilePath $jreFile
    $jarFileShort = Get-ShortFilePath $jarFile

    Write-LogMessage -message "Terminating old xvm Java Process"
    $lastJavaPID = "$($jarFileShort.ShortDirectory)\xvm.pid"
    If (Test-Path -Path $lastJavaPID -PathType Leaf) {
        Stop-ProcessById -ProcessId (Get-Content -Path $lastJavaPID) -ProcessName "java" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
    }
 
    Write-LogMessage -message "Terminating old xvm Status Monitor Process"
    $lastStatusPID = "$($jarFileShort.ShortDirectory)\xvm-status.pid"
    If (Test-Path -Path $lastStatusPID -PathType Leaf) {
        Stop-ProcessById -ProcessId (Get-Content -Path $lastStatusPID) -ProcessName "powershell" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue | Out-Null
    }
    Write-LogMessage -message "Deleting old xvm state files"
    Remove-Item "$($jarFileShort.ShortDirectory)\xvm.dat" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Remove-Item "$($jarFileShort.ShortDirectory)\xvm.ks" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Remove-Item "$($jarFileShort.ShortDirectory)\xvm.pid" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    Remove-Item "$($jarFileShort.ShortDirectory)\xvm-status.pid" -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    
    Start-Sleep -Seconds 3

    $javaProcess = Start-Process -FilePath "$($jreFileShort.ShortFile)" -ArgumentList "-jar -Dserver.port=$($port)", "$($jarFileShort.ShortFile)" -WindowStyle Minimized -PassThru -WorkingDirectory "$($jarFileShort.ShortDirectory)"
    Write-LogMessage -message "Started new xvm Java Process with PID $($javaProcess.id)"
    Out-File -InputObject $javaProcess.id -FilePath "$($jarFileShort.ShortDirectory)\xvm.pid"

    Write-LogMessage -message "Sleeping for 10 seconds to allow xvm to fully initialise"
    Start-Sleep -Seconds 10

    Write-LogMessage -message "Testing that port TCP/$($port) is up"
    
    $counter = 0
    While ($counter -lt 5) {
        $result = Test-NetConnection -ComputerName localhost -port $port

        If ($result.TcpTestSucceeded -eq $false) {
            Write-LogMessage -message "Failed to connect to port $port" -isWarning
            Exit
        }
        $counter++
    }
    Write-LogMessage -message "Successfully connected to port $port"

    If ($openBrowser) {
        Start-Process "https://localhost:$($port)"
    }

    If (!$noStatus) {
        $scriptBlock = {
            
            Param([string]$port)
            
            Import-Module -Name "vSphere-xvMotion-Bulk-Scheduler" -Force

            While ($true) {
                Get-xvmStatus -IpAddress 127.0.0.1 -port $port -jsonOut
                Start-Sleep -Seconds 5
            }
        }
        $statusProcess = Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoLogo -NoProfile -Command & {$scriptBlock} -port $port" -WindowStyle Minimized -PassThru
        Write-LogMessage -message "Started new xvm Status Monitor Process with PID $($statusProcess.id)"
        Out-File -InputObject $statusProcess.id -FilePath "$($jarFileShort.ShortDirectory)\xvm-status.pid"
    }

}


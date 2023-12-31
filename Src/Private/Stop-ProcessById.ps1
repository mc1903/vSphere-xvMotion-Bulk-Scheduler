<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Stop-ProcessById (Private)
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Stops a process by its ID and name.

.DESCRIPTION
This function stops a process by specifying its ID and name.

.PARAMETER ProcessId
The ID of the process to stop. This parameter is mandatory.

.PARAMETER ProcessName
The name of the process to stop. This parameter is mandatory.

.EXAMPLE
Stop-ProcessById -ProcessId 1234 -ProcessName "notepad"

This example stops the process with ID 1234 and name "notepad".

#>

Function Stop-ProcessById {

    [CmdletBinding()]

    Param (
        [Parameter(
            Position = 0,
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [int]$ProcessId,
        
        [Parameter(
            Position = 1,
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [string]$ProcessName
    )

    Process {
        Try {
            $process = Get-Process -Id $ProcessId -ErrorAction Stop
            If ($process.ProcessName -eq $ProcessName) {
                $process.Kill()
                Write-Output "Process with ID '$ProcessId' and name '$ProcessName' has been successfully killed."
            } Else {
                Write-Warning "Mismatch warning: Process ID '$ProcessId' does not match the specified process name '$ProcessName'. No process has been killed."
            }
        } Catch {
            Write-Output "Failed to kill the process with ID '$ProcessId'. Error: $_"
        }
    }
}


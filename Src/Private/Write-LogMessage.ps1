<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Write-LogMessage
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Writes a log message to a file and/or the console.

.DESCRIPTION
This function writes a log message to a specified log file and/or the console.

.PARAMETER message
Specifies the log message to be written.

.PARAMETER isInfo
Indicates that the log message is an informational message. Only one of the "isInfo", "isVerbose", "isWarning", or "isDebug" switches can be included in a command.

.PARAMETER isVerbose
Indicates that the log message is a verbose message. Only one of the "isInfo", "isVerbose", "isWarning", or "isDebug" switches can be included in a command.

.PARAMETER isWarning
Indicates that the log message is a warning message. Only one of the "isInfo", "isVerbose", "isWarning", or "isDebug" switches can be included in a command.

.PARAMETER isDebug
Indicates that the log message is a debug message. Only one of the "isInfo", "isVerbose", "isWarning", or "isDebug" switches can be included in a command.

.PARAMETER logFile
Specifies the log file where the log message will be written. If not specified, the default log file specified by the environment variable "xvmLogFile" will be used.

.PARAMETER noConsoleOutput
Prevents the log message from being displayed on the console.

.PARAMETER noLogFileEntry
Prevents the log message from being written to the log file.

.EXAMPLE
Write-LogMessage -message "This is an informational message" -isInfo

This example writes an informational log message to the default log file and displays it on the console.

.EXAMPLE
Write-LogMessage -message "This is a verbose message" -isVerbose -noLogfileEntry

This example writes a verbose log message to the default log file, but does not display it on the console.

.EXAMPLE
Write-LogMessage -message "This is a warning message" -isWarning -logFile "C:\Logs\MyLogFile.log" -noConsoleOutput

This example writes a warning log message to the specified log file, but does not display it on the console.

#>

Function Write-LogMessage {

    [CmdletBinding(DefaultParameterSetName = 'isInfo')]

    Param (
        [Parameter(
            Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String[]] $message,

        [Parameter(
            Position = 1,
            Mandatory = $false,
            ParameterSetName = 'isInfo'
        )]
        [System.Management.Automation.SwitchParameter] $isInfo,

        [Parameter(
            Position = 1,    
            Mandatory = $false,
            ParameterSetName = 'isVerbose'
        )]
        [System.Management.Automation.SwitchParameter] $isVerbose,

        [Parameter(
            Position = 1,    
            Mandatory = $false,
            ParameterSetName = 'isWarning'
        )]
        [System.Management.Automation.SwitchParameter] $isWarning,
        
        [Parameter(
            Position = 1,    
            Mandatory = $false,
            ParameterSetName = 'isDebug'
        )]
        [System.Management.Automation.SwitchParameter] $isDebug,

        [Parameter(
            Position = 2,
            Mandatory = $false
        )]
        [ValidateNotNullOrEmpty()]
        [String] $logFile = $env:xvmLogFile,

        [Parameter(
            Position = 3,
            Mandatory = $false
        )]
        [System.Management.Automation.SwitchParameter] $noConsoleOutput,

        [Parameter(
            Position = 4,
            Mandatory = $false
        )]
        [System.Management.Automation.SwitchParameter] $noLogfileEntry

    )


    If (!$logFile) {
        Write-Error "No Log File was specified. Use either -logFile or the `$env:logFile` envoronment variable. Quitting"
    }
    
    If (-not ($isInfo -or $isVerbose -or $isWarning -or $isDebug)) {
        $isInfo = $true
    }

    $date = (Get-Date).ToString('dd-MM-yyyy HH:mm:ss:fff')

    foreach ($msgline in $message) {

        If ($isInfo) {
            $infoOut = "INFO:    [ $($date) ] - $($msgline)"
            If (!$noLogfileEntry) {
                Add-Content -Path $logfile -Value $infoOut
            }           
            
            If (!$noConsoleOutput) {
                $infoOut 
            }
        }

        If ($isVerbose -and $PSBoundParameters.ContainsKey('Verbose')) {
            $verbosePreference = "Continue"
            $verboseOut = $(Write-Verbose "[ $($date) ] - $($msgline)") 4>&1
            $verbosePreference = "SilentlyContinue"
            If (!$noLogfileEntry) {
                Add-Content -Path $logfile -Value "VERBOSE: $($verboseOut.ToString())"
            } 
            
            If (!$noConsoleOutput) {
                $verboseOut
            }
        }

        If ($isWarning) {
            $warningOut = $(Write-Warning "[ $($date) ] - $($msgline)") 3>&1
            If (!$noLogfileEntry) {
                Add-Content -Path $logfile -Value "WARNING: $($warningOut.ToString())"
            }            
            
            If (!$noConsoleOutput) {
                $warningOut
            }
        }

        If ($isDebug) {
            $debugPreference = "Continue"
            $debugOut = $(Write-Debug "  [ $($date) ] - $($msgline)") 5>&1
            $debugPreference = "SilentlyContinue"
            If (!$noLogfileEntry) {
                Add-Content -Path $logfile -Value "DEBUG: $($debugOut.ToString())"
            }

            If (!$noConsoleOutput) {
                $debugOut
            }
        }

    }
}



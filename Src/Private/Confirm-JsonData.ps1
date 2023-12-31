<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Confirm-JsonData (Private)
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
This function is used to confirm whether the given JSON data or file path pointing to a JSON file is valid.

.DESCRIPTION
The Confirm-JsonData function is used to confirm whether the provided JSON data or file path pointing to a JSON file is valid. 
It can be used to validate JSON data before processing it further.

.PARAMETER filePath
Specifies the path to the JSON file. Only applicable if the -jsonData parameter is not used.

.PARAMETER jsonData
Specifies the JSON object data to be validated. Only applicable if the -filePath parameter is not used.

.EXAMPLE
Confirm-JsonData -filePath "C:\path\to\json\data.json"

Confirms whether the JSON file located at "C:\path\to\json\data.json" is valid.

.EXAMPLE
Confirm-JsonData -jsonData $jsonObject

Confirms whether the provided JSON object is valid.

#>

Function Confirm-JsonData {
    [CmdletBinding()]
    Param (
        [Parameter(
            ParameterSetName = 'filePath',
            Mandatory = $true, 
            Position = 0
        )]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$filePath,
    
        [Parameter(
            ParameterSetName = 'jsonData', 
            Mandatory = $true, 
            Position = 0
        )]
        [ValidateNotNullOrEmpty()]
        [object]$jsonData
    )
    
    Begin {
        # Check which parameter set is used
        If ($PSCmdlet.ParameterSetName -eq 'filePath') {
            Try {
                #JSON validation successful from file path
                $jsonObject = Get-Content -Path $filePath -Raw | ConvertFrom-Json
            }
            Catch {
                Throw "Invalid JSON format in the provided file"
            }
        }
    
        If ($PSCmdlet.ParameterSetName -eq 'jsonData') {
            Try {
                #JSON validation successful from variable
                $jsonObject = $jsonData | ConvertFrom-Json
            }
            Catch {
                Throw "Invalid JSON format in the provided variable."
            }
        }
    
        Return $jsonObject | ConvertTo-Json -Depth 10
    }
}


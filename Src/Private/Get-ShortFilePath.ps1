<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Get-ShortFilePath (Private)
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Gets the 8.3/short path & file details for the given normal/long file path

.PARAMETER LongFilePath
If the long file path includes spaces, the imput must be single or double commented

.EXAMPLE
Get-ShortFilePath -LongFilePath "C:\Program Files\Java\jre-1.8\bin\java.exe"

File           : C:\Program Files\Java\jre-1.8\bin\java.exe
Directory      : C:\Program Files\Java\jre-1.8\bin
Name           : java.exe
ShortFile      : C:\PROGRA~1\Java\jre-1.8\bin\java.exe
ShortDirectory : C:\PROGRA~1\Java\jre-1.8\bin
ShortName      : java.exe

#>

Function Get-ShortFilePath {

    [CmdletBinding()]

    Param (
        [Parameter(
            ValueFromPipeline = $true,
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String] $LongFilePath
    )

    $fso = New-Object -ComObject Scripting.FileSystemObject
    $file = $fso.GetFile($LongFilePath)
    $fso = $null

    [PSCustomObject]@{
        File = $($file.Path)
        Directory = Split-Path $($file.Path)
        Name = $($file.Name)
        ShortFile   = $($file.ShortPath)
        ShortDirectory = Split-Path $($file.ShortPath)
        ShortName   = $($file.ShortName)
    }

}


<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Get-VMRPPath
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Retrieves the Resource Pool path of a virtual machine in the VMware vSphere environment.

.DESCRIPTION
The Get-VMRPPath function retrieves the Resource Pool path of a virtual machine in the VMware vSphere environment.

.PARAMETER vmName
Specifies the virtual machine for which to retrieve the path. This parameter supports pipeline input.

.PARAMETER vCenter
Specifies the vCenter Server from which to retrieve the virtual machine Resource Pool path.

.PARAMETER showHiddenFolders
A switch parameter that, when specified, includes hidden folders in the returned Resource Pool path.

.EXAMPLE
Get-VMRPPath -vmName "MyVM" -vCenter $vCenterServer

Retrieves the path of the virtual machine named "MyVM" from the specified vCenter Server.

.EXAMPLE
Get-VMRPPath -vmName $vmObject -vCenter $vCenterServer -showHiddenFolders

Retrieves the path of the virtual machine specified by $vmObject from the specified vCenter Server, including hidden folders in the returned path.

#>

Function Get-VMRPPath {

    [CmdletBinding()]

    Param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]$vmName,

        [Parameter(Mandatory = $true)]
        [Object]$vCenter,

        [Parameter(
            Mandatory = $false
        )]
        [System.Management.Automation.SwitchParameter] $showHiddenFolders

    )
    
    $path = $vmName.Name
    $parent = Get-View $vmName.ExtensionData.ResourcePool -Server $vCenter
    
    While($parent){
        $path = $parent.Name + "/" + $path
        If($parent.Parent){
            $parent = Get-View $parent.Parent -Server $vCenter
        }
        Else{$parent = $null}
    }
    
    If (!$showHiddenFolders) {
        $pattern = "^Datacenters|/host|/$($vmName.name)$"
        $path = $path -replace $pattern

    }
    
    Return $path

}


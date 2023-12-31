<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Get-RDMAccess
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
This function retrieves information about Raw Device Mapping (RDM) Access for virtual machines.

.DESCRIPTION
The Get-RDMAccess function is used to check it the VMware ESXi Hosts in the Target Cluster have access to the RDM LUN's the Source VM is using.

.PARAMETER VMName
Specifies the virtual machine objects to retrieve RDMAccess information for.

.PARAMETER SourceVCenter
Specifies the source vCenter server object.

.PARAMETER TargetVCenter
Specifies the target vCenter server object.

.PARAMETER TargetCluster
Specifies the target cluster to retrieve RDMAccess information for.

.EXAMPLE
Get-RDMAccess -VMName "VM1" -SourceVCenter $sourceVCenter -TargetVCenter $targetVCenter -TargetCluster "Cluster1"

This example retrieves RDMAccess information for virtual machine "VM1" from the source vCenter server and target vCenter server in the "Cluster1" cluster.

#>

Function Get-RDMAccess {
    
    [CmdletBinding()]
    
    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VMName,

        [Parameter(Mandatory = $true)]
        [object]$SourceVCenter,

        [Parameter(Mandatory = $true)]
        [object]$TargetVCenter,

        [Parameter(Mandatory = $true)]
        [string]$TargetCluster
    )

    $rdms = $VMName | Get-HardDisk -Server $SourceVCenter -DiskType "RawPhysical", "RawVirtual" | Sort-Object Name
    $targetHosts = Get-VMHost -Server $TargetVCenter -Location $TargetCluster | Sort-Object Name

    ForEach ($rdm in $rdms) {
        
        $allHostsHaveAccess = $true
        $results = @()

        ForEach ($targetHost in $targetHosts) {
            $esxcli = Get-EsxCli -VMHost $targetHost -V2
            $targetHostDevices = $esxcli.storage.core.device.list.invoke() | Select-Object Device | Where-Object { $_.Device -eq $rdm.ScsiCanonicalName }

            If (!$targetHostDevices) {
                $allHostsHaveAccess = $false
                $result = [PSCustomObject]@{
                    Cluster              = $TargetCluster
                    Host                 = $targetHost.Name
                    RDMName              = $rdm.name
                    RDMScsiCanonicalName = $rdm.ScsiCanonicalName
                    HasAccess            = $false
                }
                $results += $result
            }
        }

        If ($allHostsHaveAccess) {
            $result = [PSCustomObject]@{
                Host                 = 'All Hosts'
                Cluster              = $TargetCluster
                RDMName              = $rdm.name
                RDMScsiCanonicalName = $rdm.ScsiCanonicalName
                HasAccess            = $true
            }
            $results += $result
        }

        $results
    }
}


<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Get-DatastoreAvailability
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Retrieves the availability of a VM's datastores in the Target Cluster, for Compute Only xvMotions.

.DESCRIPTION
The Get-DatastoreAvailability function retrieves the availability of a VM's datastores in the Target Cluster. Checks that it is the same storage/LUN that is backing the Datastore.

.PARAMETER VMName
Specifies an array of VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine objects representing the virtual machine for which to retrieve datastore availability.

.PARAMETER SourceVCenter
Specifies the source vCenter server from which to retrieve the virtual machine's datastore availability. This parameter is mandatory.

.PARAMETER TargetVCenter
Specifies the target vCenter server to which to check the virtual machine's datastore availability. This parameter is mandatory.

.PARAMETER TargetCluster
Specifies the target cluster on the target vCenter server for which to check the virtual machine's datastore availability. This parameter is mandatory.

.EXAMPLE
Get-DatastoreAvailability -VMName $vm -SourceVCenter $sourceVCenter -TargetVCenter $targetVCenter -TargetCluster $targetCluster

Retrieves the availability of the virtual machine's datastore across different vCenter servers and clusters.

#>

Function Get-DatastoreAvailability {

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
        [object]$TargetCluster
    )

    Begin {
        $results = @()
    }

    Process {
        ForEach ($vm in $VMName) {

            $VMHDDs = $vm.ExtensionData.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -like "Hard disk *" } | Where-Object { !$_.Backing.CompatibilityMode }
            $VMRDMs = $vm.ExtensionData.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -like "Hard disk *" } | Where-Object { $_.Backing.CompatibilityMode }
            $VMFDDs = $vm.ExtensionData.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -like "Floppy drive *" }
            $VMDVDs = $vm.ExtensionData.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -like "CD/DVD drive *" }
            
            ForEach ($disk in $VMHDDs) {
            
                $result = [PSCustomObject]@{
                    VMName                  = $VM.Name
                    DeviceName              = $disk.DeviceInfo.Label
                    DeviceType              = Switch ($thinProvisioned) {
                        $true { "VMDK (Thin)" }
                        $false {
                            if ($eagerZeroed) {
                                "VMDK (Eager Thick)"
                            }
                            else {
                                "VMDK (Lazy Thick)"
                            }
                        }
                    }
                    DeviceCapacityInGB      = $disk.CapacityInKB / 1MB
                    SourceDatastoreName     = $disk.Backing.FileName.Split('[]', 3)[1]
                    SourceDatastoreFilePath = $disk.Backing.FileName
                    Connected               = $true
                }
                $results += $result
            }
            
            ForEach ($disk in $VMRDMs) {
                $result = [PSCustomObject]@{
                    VMName                  = $VM.Name
                    DeviceName              = $disk.DeviceInfo.Label
                    DeviceType              = Switch ($disk.Backing.CompatibilityMode) {
                        "physicalMode" { "RDM (Physical)" }
                        "virtualMode" { "RDM (Virtual)" }
                    }
                    DeviceCapacityInGB      = $disk.CapacityInKB / 1MB
                    SourceDatastoreName     = switch ($disk.Backing.FileName) {
                        { $_ -eq $null -or $_ -eq '' } { '' }
                        default { $_.Split('[]', 3)[1] }
                    }
                    SourceDatastoreFilePath = $disk.Backing.FileName
                    Connected               = $true
                }
                $results += $result
            }
            
            ForEach ($fdd in $VMFDDs) {
                $result = [PSCustomObject]@{
                    VMName                  = $VM.Name
                    DeviceName              = $fdd.DeviceInfo.Label
                    DeviceType              = 'FDD'
                    DeviceCapacityInGB      = 0
                    SourceDatastoreName     = switch ($fdd.Backing.FileName) {
                        { $_ -eq $null -or $_ -eq '' } { '' }
                        default { $_.Split('[]', 3)[1] }
                    }
                    SourceDatastoreFilePath = switch ($fdd.Backing.FileName) {
                        { $_ -eq $null -or $_ -eq '' } { 'No .flp file is mapped' }
                        default { $_ }
                    }
                    Connected               = $fdd.Connectable.Connected
                }
                $results += $result
            }
                         
            ForEach ($dvd in $VMDVDs) {
                $result = [PSCustomObject]@{
                    VMName                  = $VM.Name
                    DeviceName              = $dvd.DeviceInfo.Label
                    DeviceType              = 'DVD'
                    DeviceCapacityInGB      = 0
                    SourceDatastoreName     = switch ($dvd.Backing.FileName) {
                        { $_ -eq $null -or $_ -eq '' } { '' }
                        default { $_.Split('[]', 3)[1] }
                    }
                    SourceDatastoreFilePath = switch ($dvd.Backing.FileName) {
                        { $_ -eq $null -or $_ -eq '' } { 'No .iso file is mapped' }
                        default { $_ }
                    }
                    Connected               = $dvd.Connectable.Connected
                }
                $results += $result
            }   

        }

        $vmStorageDevices = $results
        
        $results = @()

        ForEach ($vmStorageDevice in $vmStorageDevices) {
           
            #$sourceDatastore = Get-Datastore -Name $vmStorageDevice.SourceDatastoreName -Server $SourcevCenter
            If ($vmStorageDevice.SourceDatastoreName) {
                $sourceDatastore = Get-Datastore -Name $vmStorageDevice.SourceDatastoreName -Server $SourcevCenter
            }
            Else {
                Continue
            }

            $targetDatastore = $TargetCluster | Get-Datastore -Name $vmStorageDevice.SourceDatastoreName -Server $TargetVCenter -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    
            If (!$targetDatastore) {
                $sourceDatastoreUrl = $sourceDatastore.ExtensionData.Info.Url
                $targetDatastoreName = "N/A"
                $targetDatastoreUrl = "N/A"
                $targetDatastoreFreeSpace = "N/A"
                $match = $false
            }
            Else {
                $sourceDatastoreUrl = $sourceDatastore.ExtensionData.Info.Url
                $targetDatastoreUrl = $targetDatastore.ExtensionData.Info.Url
    
                $match = $sourceDatastoreUrl -eq $targetDatastoreUrl
                $targetDatastoreName = $targetDatastore.Name
                $targetDatastoreFreeSpace = $targetDatastore.FreeSpaceGB
            }
    
            $result = [PSCustomObject]@{
                VMName                        = $VM.Name
                #HDDName                       = $disk.Name
                #HDDSize                       = $disk.CapacityGB
                SourceDatastoreName           = $sourceDatastore.Name
                SourceDatastoreURL            = $sourceDatastoreUrl
                TargetDatastoreName           = $targetDatastoreName
                TargetDatastoreURL            = $targetDatastoreUrl
                TargetDatastoreFreeSpace      = $targetDatastoreFreeSpace
                SourceTargetDatastoreURLMatch = $match
            }
    
            $results += $result
        }

    }

    End {
        Return $results | Sort-Object SourceDatastoreName -Unique
    }
}


<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Get-VMStorageInfo
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
This function retrieves storage information for one or more virtual machines.

.DESCRIPTION
The Get-VMStorageInfo function allows you to retrieve storage information for one or more virtual machines. 
It requires the VMware PowerCLI module to be installed and loaded.

.PARAMETER VMName
Specifies the virtual machines from which to retrieve storage information.
This parameter accepts an array of VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine objects.

.EXAMPLE
Get-VMStorageInfo -VMName "VM1"

Retrieves the storage information for the virtual machine named "VM1".

.EXAMPLE
"VM1","VM2" | Get-VMStorageInfo

Retrieves the storage information for the virtual machines named "VM1" and "VM2".

#>

Function Get-VMStorageInfo {
    
    [CmdletBinding()]

    Param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine[]]$VMName
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
                $thinProvisioned = $disk.Backing.ThinProvisioned
                $eagerZeroed = $disk.Backing.EagerlyScrub
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
                    SourceDatastoreName     = Switch ($disk.Backing.FileName) {
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
                    SourceDatastoreName     = Switch ($fdd.Backing.FileName) {
                        { $_ -eq $null -or $_ -eq '' } { '' }
                        default { $_.Split('[]', 3)[1] }
                    }
                    SourceDatastoreFilePath = Switch ($fdd.Backing.FileName) {
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
                    SourceDatastoreName     = Switch ($dvd.Backing.FileName) {
                        { $_ -eq $null -or $_ -eq '' } { '' }
                        default { $_.Split('[]', 3)[1] }
                    }
                    SourceDatastoreFilePath = Switch ($dvd.Backing.FileName) {
                        { $_ -eq $null -or $_ -eq '' } { 'No .iso file is mapped' }
                        default { $_ }
                    }
                    Connected               = $dvd.Connectable.Connected
                }
                $results += $result
            }    
        }
    }

    End {
        Return $results
    }
}


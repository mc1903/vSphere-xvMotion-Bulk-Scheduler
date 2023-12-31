<#
.NOTES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Module: vSphere-xvMotion-Bulk-Scheduler
Function: Invoke-xvmScheduler
Author:	Martin Cooper (@mc1903)
Date: 18-09-2023
GitHub Repo: https://github.com/mc1903/vSphere-xvMotion-Bulk-Scheduler
Version: 1.0.1
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.SYNOPSIS
Performs the same pre-checks as Invoke-xvmDryRun, but on sucessfully completion will add a Windows Task Scheduler task for each VM Migration.

.DESCRIPTION
The Invoke-xvmScheduler function is used create Windows Task Scheduler tasks for each VM Migration.

.PARAMETER ipAddress
The IP address of xvm Fling. The default value is "127.0.0.1".

.PARAMETER port
The TCP Port number the xvm Fling is using. The default value is 8443.

.PARAMETER migrationTasksCSV
The path to the CSV file that contains the migration tasks to be performed.
This file should have one row per VM to migrate and the following columns: 

    sourceSite      required
    vmName          required     
    targetSite      required
    targetCluster   required
    targetPool      optional*
    targetFolder    optional*
    migrationDate   required
    migrationTime   required

* see documentation regarding vCenter Server environments with nested Resource Pools and/or VM Folders.

.PARAMETER networkMappingsCSV
The path to the CSV file that contains the network mappings for the migration tasks.
This file should have one row per mapping and the following columns:

    SourceNetwork       required
    DestinationNetwork  required

.PARAMETER taskJsonFilesOutPath
The path to the output directory where the task JSON files will be saved. This parameter is mandatory.

.PARAMETER useSavedPassword
Indicates whether use previously saved credentials when establishing the PowerCLI vCenter Server connections.
Otherwise, the user will be prompted for a username & password for each Source & Target vCenter Server.

.PARAMETER maxSimultaneousTasks
The maximum number of migration tasks to execute simultaneously. If not specified, the default value is 4.

.EXAMPLE
$params = @{
    migrationTasksCSV = "P:\VMware\Bulk xvMotion\xvm Migration Tasks.csv"
    networkMappingsCSV = "P:\VMware\Bulk xvMotion\xvm Network Mappings.csv"
    taskJsonFilesOutPath = "P:\VMware\Bulk xvMotion\TaskJsonFiles\"
    maxSimultaneousTasks = 3
    useSavedPassword = $true
}
Invoke-xvmScheduler @params

#>

Function Invoke-xvmScheduler {

    [CmdletBinding()]

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
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String] $migrationTasksCSV,

        [Parameter(
            Position = 3,
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String] $networkMappingsCSV,

        [Parameter(
            Position = 4,
            Mandatory = $true
        )]
        [ValidateNotNullOrEmpty()]
        [String] $taskJsonFilesOutPath,

        [Parameter(
            Position = 5,
            Mandatory = $false
        )]
        [Switch] $useSavedPassword,

        [Parameter(
            Position = 6,
            Mandatory = $false
        )]
        [ValidateNotNullOrEmpty()]
        [int]$maxSimultaneousTasks = 4
    )

    Write-LogMessage -message "Function: Invoke-xvmScheduler"

    If (Test-Path $MigrationTasksCSV) {
        Write-LogMessage -message "Migration Tasks CSV file was found at $($MigrationTasksCSV)"
        $migrationTasks = Import-Csv $MigrationTasksCSV | Where-Object { $_.PSObject.Properties.Value -ne '' }
    }
    Else {
        Write-LogMessage -message "Migration Tasks CSV file was NOT found. Exiting" -isWarning
        Exit
    }
    
    If (Test-Path $NetworkMappingsCSV) {
        Write-LogMessage -message "Network Mapping CSV file was found at $($NetworkMappingsCSV)"
        $networkMappings = Import-Csv $NetworkMappingsCSV | Where-Object { $_.PSObject.Properties.Value -ne '' }
    }
    Else {
        Write-LogMessage -message "Network Mapping CSV file was NOT found. Exiting" -isWarning
        Exit
    }

    If (Test-Path $taskJsonFilesOutPath) {}
    Else {
        Write-LogMessage -message "Task Json Output directory not found. Exiting" -isWarning
        Exit
    }


    $sourceSites = $migrationTasks.sourcesite | Select-Object -Unique
    $targetSites = $migrationTasks.targetsite | Select-Object -Unique
    
    $xvmSites = Get-xvmSites -ipAddress $ipAddress -port $port 
    $err = 0

    Write-LogMessage -message "Checking Source vCenter Server(s) are registered & connected to xvm"
    ForEach ($sourceSite in $sourceSites) {
        $xvmSite = $xvmSites | Where-Object { $_.sitename -eq $sourceSite }
        If ($xvmSite.sitename -eq $sourceSite -and $xvmSite.connected -eq $true) {
            Write-LogMessage -message "Source Site $($sourceSite) is connected to xvm"
        }
        ElseIf ($xvmSite.sitename -eq $sourceSite -and $xvmSite.connected -eq $false) {
            Write-LogMessage -message "Source Site $($sourceSite) is registered to xvm but is NOT connected" -isWarning
            $err = + 1
            Break
        }
        Else {
            Write-LogMessage -message "Source Site $($sourceSite) is NOT registered to xvm" -isWarning
            $err = + 1
            Break
        }
    }

    Write-LogMessage -message "Checking Target vCenter Server(s) are registered & connected to xvm"
    ForEach ($targetSite in $targetSites) {
        $xvmSite = $xvmSites | Where-Object { $_.sitename -eq $targetSite }
        If ($xvmSite.sitename -eq $targetSite -and $xvmSite.connected -eq $true) {
            Write-LogMessage -message "Target Site $($targetSite) is connected to xvm"
        }
        ElseIf ($xvmSite.sitename -eq $targetSite -and $xvmSite.connected -eq $false) {
            Write-LogMessage -message "Target Site $($targetSite) is registered to xvm but is NOT connected" -isWarning
            $err = + 1
            Break
        }
        Else {
            Write-LogMessage -message "Target Site $($targetSite) is NOT registered to xvm" -isWarning
            $err = + 1
            Break
        }
    }

    If ($err -gt 0) {
        Write-LogMessage -message "One or more vCenter Server(s) is NOT registered or connected to xvm. Exiting." -isWarning
        Exit
    }

    ForEach ($sourceSite in $sourceSites) {
        Write-LogMessage -message "Establishing PowerCLI session with Source vCenter Server $($sourceSite)"
        $vCenter = $xvmSites | Where-Object { $_.sitename -eq $sourceSite }
        If ($UseSavedPassword) {
            $SavedPassword = Get-SecurePassword -Hostname $($vCenter.hostname) -Username $($vCenter.username)
            If ($SavedPassword.Error) {
                Write-LogMessage -message $($SavedPassword.Message) -isWarning
                Exit
            }
            ElseIf ($SavedPassword.Success) {
                Write-LogMessage -message $($SavedPassword.Message)
                $vCenterCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $($vCenter.username), $($SavedPassword.SecurePassword)
            }
        }
        If (!$UseSavedPassword) {
            $vCenterCred = Get-Credential -UserName $($vCenter.username) -Message "Enter credentials for vCenter Server $($vCenter.hostname)"
        }
        Try {
            Connect-VIServer $($vCenter.hostname) -Credential $vCenterCred -WarningAction SilentlyContinue | Out-Null
        }
        Catch {
            Write-LogMessage -message "Failed to connect to vCenter Server $_.Exception.Message. Exiting." -isWarning
            Exit
        }
    }

    ForEach ($targetSite in $targetSites) {
        Write-LogMessage -message "Establishing PowerCLI session with Target vCenter Server $($targetSite)"
        $vCenter = $xvmSites | Where-Object { $_.sitename -eq $targetSite }
        If ($UseSavedPassword) {
            $SavedPassword = Get-SecurePassword -Hostname $($vCenter.hostname) -Username $($vCenter.username)
            If ($SavedPassword.Error) {
                Write-LogMessage -message $($SavedPassword.Message) -isWarning
                Exit
            }
            ElseIf ($SavedPassword.Success) {
                Write-LogMessage -message $($SavedPassword.Message)
                $vCenterCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $($vCenter.username), $($SavedPassword.SecurePassword)
            }
        }
        If (!$UseSavedPassword) {
            $vCenterCred = Get-Credential -UserName $($vCenter.username) -Message "Enter credentials for vCenter Server $($vCenter.hostname)"
        }
        Try {
            Connect-VIServer $($vCenter.hostname) -Credential $vCenterCred -WarningAction SilentlyContinue | Out-Null
        }
        Catch {
            Write-LogMessage -message "Failed to connect to vCenter Server $_.Exception.Message. Exiting." -isWarning
            Exit
        }
    }

    Write-LogMessage -message " "

    ForEach ($migrationTask in $migrationTasks) {
        
        Write-LogMessage -message "Scheduling migration for virtual machine $($migrationTask.vmName)"

        $sourcevCenter = $xvmSites | Where-Object { $_.sitename -eq $($migrationTask.sourceSite) } | Select-Object -ExpandProperty Hostname
        $targetvCenter = $xvmSites | Where-Object { $_.sitename -eq $($migrationTask.targetSite) } | Select-Object -ExpandProperty Hostname
        
        Try {
            $sourceVM = Get-VM -Server $sourcevCenter -Name $($migrationTask.vmName) -WarningAction Stop -ErrorAction Stop
        }
        Catch {
            Write-LogMessage -message "The VM `'$($migrationTask.vmName)`' was not found on the source vCenter Server. Skipping`n" -isWarning
            Continue
        }
        
        #Collate Source VM Details
        $sourceVMDetails = [PSCustomObject]@{
            PowerState     = $sourceVM.PowerState
            vCPUs          = $sourceVM.NumCpu
            MemoryGB       = $sourceVM.MemoryGB
            NICs           = $sourceVM.ExtensionData.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -like "Network adapter *" } | Measure-Object | Select-Object -ExpandProperty Count
            HDDs           = $sourceVM.ExtensionData.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -like "Hard disk *" } | Where-Object { !$_.Backing.CompatibilityMode } | Measure-Object | Select-Object -ExpandProperty Count
            RDMs           = $sourceVM.ExtensionData.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -like "Hard disk *" } | Select-Object -ExpandProperty Backing | Where-Object { $_.CompatibilityMode } | Measure-Object | Select-Object -ExpandProperty Count
            FTState        = $sourceVM.ExtensionData.Runtime | Where-Object { $_.FaultToleranceState -ne "notConfigured" } | Measure-Object | Select-Object -ExpandProperty Count
            FDDs           = $sourceVM.ExtensionData.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -like "Floppy drive *" }
            CDDVD          = $sourceVM.ExtensionData.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -like "CD/DVD drive *" }
            USB            = $sourceVM.ExtensionData.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -like "USB *" -and $_.DeviceInfo.Label -notlike "*controller*" } | Measure-Object | Select-Object -ExpandProperty Count
            PCI            = $sourceVM.ExtensionData.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -like "PCI *" -and $_.DeviceInfo.Label -notlike "*controller*" } | Measure-Object | Select-Object -ExpandProperty Count
            SharedSCSICont = $sourceVM.ExtensionData.Config.Hardware.Device | Where-Object { $_.DeviceInfo.Label -like "SCSI *" -and $_.SharedBus -notlike "*noSharing*" }  | Measure-Object | Select-Object -ExpandProperty Count
        }
 
        #FT Check
        If ($sourceVMDetails.FTState) {
            Write-LogMessage "`tFault Tolerance is configured. Migration is NOT permitted. Skipping`n" -isWarning
            Continue
        }

        #SharedSCSIController Check
        If ($sourceVMDetails.SharedSCSICont) {
            Write-LogMessage "`tOne or more SCSI Controllers is configured for SCSI Bus Sharing. Migration is NOT permitted. Skipping`n" -isWarning
            Continue
        }

        #USB Device Check
        If ($sourceVMDetails.USB) {
            Write-LogMessage "`tOne or more USB devices is attached to this VM. Migration is NOT permitted. Skipping`n" -isWarning
            Continue
        }

        #PCIe Device Check
        If ($sourceVMDetails.PCI) {
            Write-LogMessage "`tOne or more PCIe devices is attached to this VM. Migration is NOT permitted. Skipping`n" -isWarning
            Continue
        }

        Write-LogMessage "`tPower State: $($sourceVMDetails.PowerState)"
        Write-LogMessage "`tvCPUs: $($sourceVMDetails.vCPUs)"
        Write-LogMessage "`tMemory GB: $($sourceVMDetails.MemoryGB)"
        Write-LogMessage "`tNICs: $($sourceVMDetails.NICs)"
        Write-LogMessage "`tHDDs: $($sourceVMDetails.HDDs)"
        Write-LogMessage "`tRDMs: $($sourceVMDetails.RDMs)"

        $vmStorageInfo = Get-VMStorageInfo -VMName $sourceVM
        ForEach ($device in $vmStorageInfo) {
            If ($($device.DeviceType) -like 'VMDK*') {
                Write-LogMessage "`t$($device.DeviceName) - $($device.DeviceType) - $($device.DeviceCapacityInGB) (GB) - $($device.SourceDatastoreFilePath)"
            }
            ElseIf ($($device.DeviceType) -like 'RDM*') {
                Write-LogMessage "`t$($device.DeviceName) - $($device.DeviceType) - $($device.DeviceCapacityInGB) (GB) - $($device.SourceDatastoreFilePath)"
            }
            ElseIf ($($device.DeviceType) -like 'FDD*') {
                If ($device.Connected) {
                    $fddstate = "Connected"
                }
                Else {
                    $fddstate = "Disconnected"
                }
                Write-LogMessage "`t$($device.DeviceName) - $($fddstate) - $($device.SourceDatastoreFilePath)"
            }
            ElseIf ($($device.DeviceType) -like 'DVD*') {
                If ($device.Connected) {
                    $dvdstate = "Connected"
                }
                Else {
                    $dvdstate = "Disconnected"
                }
                Write-LogMessage "`t$($device.DeviceName) - $($dvdstate) - $($device.SourceDatastoreFilePath)"
            }
        }


        $migrationDate = [DateTime]::ParseExact($migrationTask.migrationDate, 'dd/MM/yyyy', $null)
        $migrationTime = [DateTime]::ParseExact($migrationTask.migrationTime, 'HH:mm:ss', $null)
        $migrationDateTime = $migrationDate.Date.AddTicks($migrationTime.TimeOfDay.Ticks)

        If ($migrationDateTime -lt [DateTime]::Now) {
            Write-LogMessage "`tThe requested migration date/time `'$($migrationDateTime)`' has already passed" -isWarning
        }
        Else {
            Write-LogMessage "`tThe requested migration date/time is `'$($migrationDateTime)`'"
        }

        $sourceVMNetworkPGs = $sourceVM | Get-NetworkAdapter | Select-Object @{Name = 'VM'; Expression = { $_.Parent } }, NetworkName | Sort-Object NetworkName -Unique
        $sourceDatacenter = $sourceVM | Get-Datacenter -Server $sourcevCenter
                
        $targetCluster = Get-Cluster -Server $targetvCenter -Name $($migrationTask.targetCluster) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
        If (!$targetCluster) {
            Write-LogMessage "`tThe target Cluster `'$($migrationTask.targetCluster)`' was not found on the target vCenter Server. Skipping`n" -isWarning
            Continue
        }
        Else {
            $targetDatacenter = Get-Datacenter -Server $targetvCenter -Cluster $targetCluster -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            Write-LogMessage "`tThe target Cluster `'$($migrationTask.targetCluster)`' was found in Datacenter `'$($targetDatacenter)`' on the target vCenter Server"
        }
        
        #Datastore Checks
        Write-LogMessage "`tChecking the required Datastores are available in the target cluster"
        $vmDatastores = $sourceVM | Get-DatastoreAvailability -SourceVCenter $sourcevCenter -TargetVCenter $targetvCenter -TargetCluster $targetCluster
        $err = 0
        ForEach ($vmDatastore in $vmDatastores) {
            
            If ($vmDatastore.SourceTargetDatastoreURLMatch) {
                Write-LogMessage "`tThe source cluster Datastore `'$($vmDatastore.SourceDatastoreName)`' is available in the target cluster"
            }
    
            If (!$vmDatastore.SourceTargetDatastoreURLMatch) {
                Write-LogMessage "`tThe source cluster Datastore `'$($vmDatastore.SourceDatastoreName)`' is NOT available in the target cluster" -isWarning
                $err = + 1
            }
        }

        If ($err -gt 0) {
            Write-LogMessage -message "`tAll source cluster Datastores MUST be available in the target cluster before this VM can be migrated. Skipping`n" -isWarning
            Continue
        }

        #RDM Checks
        If ($sourceVMDetails.RDMs -gt 0) {
            Write-LogMessage "`tChecking the RDM LUNs are available on all hosts in the target cluster"
            $rdmAccess = $sourceVM | Get-RDMAccess -SourceVCenter $sourcevCenter -TargetVCenter $targetvCenter -TargetCluster $targetCluster
            $err = 0
            ForEach ($rdm in $rdmAccess) {
                If ($rdm.HasAccess) {
                    Write-LogMessage "`tAll Hosts in the target cluster have access to the RDM LUN for `'$($rdm.RDMName)`' ($($rdm.RDMScsiCanonicalName))"
                }
        
                If (!$rdm.HasAccess) {
                    Write-LogMessage "`tHost `'$($rdm.Host)`' in the target cluster DOES NOT have access to the RDM LUN for `'$($rdm.RDMName)`' ($($rdm.RDMScsiCanonicalName))" -isWarning
                    $err = + 1
                }
            }

            If ($err -gt 0) {
                Write-LogMessage -message "`tALL Hosts in the target cluster MUST have access to ALL RDM LUNs before this VM can be migrated. Skipping`n" -isWarning
                Continue
            }
        }

        $targetHost = $targetCluster | Get-VMHost -Server $targetvCenter | Where-Object { $_.ConnectionState -eq "Connected" } | Get-Random

        $targetPortGroups = $targetHost | Get-VDswitch | Get-VDPortgroup -Server $targetvCenter
        
        $sourceVMRP = $sourceVM | Get-VMRPPath -vCenter $SourcevCenter
        Write-LogMessage "`tThe source Resource Pool is `'$($sourceVMRP)`'"

        If ($($migrationTask.targetPool)) {
            $targetPool = Get-ResourcePool -Server $targetvCenter -Name $($migrationTask.targetPool) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            If (!$targetPool) {
                Write-LogMessage "`tThe target Resource Pool `'$($migrationTask.targetPool)`' was not found in the target Cluster `'$($migrationTask.targetCluster)`'. Skipping`n" -isWarning
                Continue
            }
            ElseIf ($targetPool.count -gt 1) {
                Write-LogMessage "`tMultiple target Resource Pools called `'$($migrationTask.targetPool)`' were found on the target vCenter Server." -isWarning
                Write-LogMessage "`tA known issue with the xvm fling may cause it to select the wrong RP and the migration may fail." -isWarning
                Write-LogMessage "`tCreate a unique 'Migration_{Cluster Name}' RP in *EACH* target Cluster and specify this in the Migration Task CSV file. Skipping`n" -isWarning
            }
            Else {
                Write-LogMessage "`tThe target Resource Pool `'$($migrationTask.targetPool)`' was found in the target Cluster `'$($migrationTask.targetCluster)`'"
            }
        }
        Else {
            $targetPool = Get-ResourcePool -Server $targetvCenter -Name "Resources"
            If ($targetPool.count -gt 1) {
                Write-LogMessage "`tNo target Resource Pool was specified and there are multiple `'Resources`' default Resource Pools in the target vCenter Server." -isWarning
                Write-LogMessage "`tA known issue with the xvm fling may cause it to select the wrong RP and the migration may fail." -isWarning
                Write-LogMessage "`tCreate a unique 'Migration_{Cluster Name}' RP in *EACH* target Cluster and specify this in the Migration Task CSV file. Skipping`n" -isWarning
            }
            Else {
                Write-LogMessage "`tNo target Resource Pool was specified, using the default target Resource Pool `'Resources`'"
            }
        }
       
        If ($($migrationTask.targetFolder)) {
            $targetFolder = Get-Folder -Server $targetvCenter -Location $targetDatacenter -Name $($migrationTask.targetFolder) -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
 
            If (!$targetFolder) {
                Write-LogMessage "`tThe target VM Folder `'$($migrationTask.targetFolder)`' was not found in the target Datacenter `'$($targetDatacenter.Name)`'. Skipping`n" -isWarning
                Continue
            }
            ElseIf ($targetFolder.count -gt 1) {
                Write-LogMessage "`tMultiple target VM Folders called `'$($migrationTask.targetFolder)`' were found in the target Datacenter `'$($targetDatacenter.Name)`'" -isWarning
                Write-LogMessage "`tThe target VM will be placed in the one that was created last. It may need to be relocated after the migration" -isWarning
                $targetFolder = $targetFolder | Select-Object -First 1
            }
            Else {
                Write-LogMessage "`tThe target VM Folder `'$($migrationTask.targetFolder)`' was found in the target Datacenter `'$($targetDatacenter.Name)`'"
            }

        }
        Else {
            $targetFolder = Get-Folder -Server $targetvCenter -Location $targetDatacenter -Name "Discovered virtual machine"
            Write-LogMessage "`tNo target VM Folder was specified, using the default target VM Folder `'Discovered virtual machine`'"
        }
        
        $vmPGMappings = ForEach ($sourceVMNetworkPG in $sourceVMNetworkPGs) {
            $matchingMapping = $networkMappings | Where-Object { $_.SourcePG -eq $sourceVMNetworkPG.NetworkName -and $targetPortGroups.Name -eq $_.TargetPG }

            [PSCustomObject] @{
                SourcePG = $sourceVMNetworkPG.NetworkName
                TargetPG = $matchingMapping.TargetPG
            }
        }
        
        $sourcePGCount = $vmPGMappings.SourcePG | Where-Object { $_ -ne $null } | Measure-Object | Select-Object -ExpandProperty Count
        $targetPGCount = $vmPGMappings.TargetPG | Where-Object { $_ -ne $null } | Measure-Object | Select-Object -ExpandProperty Count
        
        If (($sourcePGCount -eq $targetPGCount)) {
            Write-LogMessage -message "`tMatched all SourcePG(s) to TargetPG(s)"
        }
        Else {
            Write-LogMessage -message "`tFailed to match all SourcePG(s) to TargetPG(s). Skipping`n" -isWarning
            Continue
        }
        
        $xvmTask = $null
        $xvmJsonTask = $null
        
        $xvmTask = New-Object -TypeName PSCustomObject
        $xvmTask | Add-Member -NotePropertyName operationType -NotePropertyValue "relocate"
        $xvmTask | Add-Member -NotePropertyName sourceSite -NotePropertyValue $($migrationTask.sourceSite)
        $xvmTask | Add-Member -NotePropertyName targetSite -NotePropertyValue $($migrationTask.targetSite)
        $xvmTask | Add-Member -NotePropertyName sourceDatacenter -NotePropertyValue $($sourceDatacenter.Name)
        $xvmTask | Add-Member -NotePropertyName vmList @("$sourceVM")
        $xvmTask | Add-Member -NotePropertyName vmNamePattern -NotePropertyValue $null
        $xvmTask | Add-Member -NotePropertyName targetDatacenter -NotePropertyValue $($targetDatacenter.Name)
        $xvmTask | Add-Member -NotePropertyName targetCluster -NotePropertyValue $null
        $xvmTask | Add-Member -NotePropertyName targetHost -NotePropertyValue $($targetHost.Name)
        $xvmTask | Add-Member -NotePropertyName targetDatastore -NotePropertyValue $null
        
        $xvmTaskvmPGMappings = New-Object -TypeName PSCustomObject 
        ForEach ($vmPGMapping in $vmPGMappings) {
            $xvmTaskvmPGMappings | Add-Member -NotePropertyName "$($vmPGMapping.SourcePG) (DistributedVirtualPortgroup)" -NotePropertyValue "$($vmPGMapping.TargetPG) (DistributedVirtualPortgroup)"
        }

        $xvmTask | Add-Member -NotePropertyName networkMap -NotePropertyValue $xvmTaskvmPGMappings
        $xvmTask | Add-Member -NotePropertyName targetPool -NotePropertyValue $($targetPool.Name)
        $xvmTask | Add-Member -NotePropertyName targetFolder -NotePropertyValue $($targetFolder.Name)
        $xvmTask | Add-Member -NotePropertyName diskFormatConversion -NotePropertyValue $null
        
        $xvmJsonTask = $xvmTask | ConvertTo-Json -Depth 5
        Write-LogMessage -message ("`tTaskJson is :`n {0}" -f ($xvmJsonTask -join "`n")) -noConsoleOutput
        
        $jsonFileName = "$($taskJsonFilesOutPath)\$($sourceVM)__$($migrationTask.sourceSite)-$($migrationTask.targetSite).json"
        Write-LogMessage -message "`tSaving TaskJson File to `'$($jsonFileName)`'"
        $xvmJsonTask | Out-File -FilePath $jsonFileName -Force

        $winSchdtaskName = "$($sourceVM) Migration from $($migrationTask.sourceSite) to $($migrationTask.targetSite)" 
        $winSchdtaskPath = "\vSphere xvMotion Bulk Scheduler\"
        $winSchdtaskDescription = "$($xvmJsonTask)" 

        $startxvmCommand = "Start-xvmTask -taskJsonFile `'$jsonFileName`' -Verbose"
        $winSchdtaskaction = New-ScheduledTaskAction -Execute "powershell.exe" -Argument " -WindowStyle Minimized -Command `"$($startxvmCommand)`"" 
        $winSchdtasktrigger = New-ScheduledTaskTrigger -At $($migrationDateTime) -Once
        $winSchdtaskSettings = New-ScheduledTaskSettingsSet -Hidden

        $winRegSchdtask = Register-ScheduledTask -Action $winSchdtaskaction -Trigger $winSchdtasktrigger -TaskPath $winSchdtaskPath -TaskName $winSchdtaskName -Description $winSchdtaskDescription -Settings $winSchdtaskSettings -Force
       
        If ($winRegSchdtask.State -eq 'Ready') {
            Write-LogMessage -message "`tCreated new Task Scheduler task `'$($winRegSchdtask.TaskPath)$($winRegSchdtask.TaskName)`'"
        }
        
        Write-LogMessage -message " "

    }
    
    Write-LogMessage -message " "

}


# vSphere-xvMotion-Bulk-Scheduler

This PowerShell module provides a convenient way to bulk schedule compute only VM xvMotion migrations between vCenter Servers in different SSO domains.

By leveraging the popular "Cross vCenter Workload Migration Utility" Fling from VMware, this module provides scheduling capabilities and streamlines the migration process.

To ensure a smooth migration process, the module also includes a dry-run option. This option allows users to confirm that each VM is in a state that allows it to be migrated and to check if the target vCenter Server, Cluster, and ESXi hosts are capable of running each VM prior to initiating the migration. The dry-run allows potential issues to be identified and resolved beforehand.

Furthermore, the module leverages the Windows Task Scheduler to initiate each migration task, at the allocated date & time.

Overall, the "vSphere-xvMotion-Bulk-Scheduler" PowerShell module simplifies and automates the process of VM migrations between vCenter Servers in separate SSO domains. With its bulk migration capability, dry-run option, and integration with Windows Task Scheduler, this module provides a good solution for managing and scheduling VM migrations in a reliable and efficient manner.

## Limitations

1. PowerShell 7.x is NOT supported at this time. Only PowerShell 5.1 on Windows is supported.
2. Storage xvMotions are NOT supported at this time. Only ‘Compute Only’ xvMotions are supported. The source & target ESXi hosts MUST be presented the same datastores from the shared storage.
3. vSS (Standard) vSwitches are NOT supported at this time. Only migrations from vDS (Distributed) vSwitch Port Groups to vDS port groups are supported.
4. The xvm Fling does NOT correctly handle Resource Pools with duplicate names. If you have a complex Resource Pool hierarchy, with nested RP’s using the same name; it is suggested to create a Migration RP per cluster (with a unique name) as a temporary target for the migration and then move the VM to the correct target RP as a follow up task.
5. The xvm Fling does NOT correctly handle VM Folders with duplicate names. If you have a complex VM Folder hierarchy, with nested Folders using the same name; it is suggested to create a Migration VM Folder per Datacenter (with a unique name) as a temporary target for the migration and then move the VM to the correct target VM Folder as a follow up task.

## Prerequisites

1. Version 3.1 of the xvm Fling is required. Download this from <https://flings.vmware.com/cross-vcenter-workload-migration-utility>
2. The xvm Fling is a Java based application and requires a minimum of Java Runtime Environment 1.8-10. Download this from <https://www.java.com/en/download/manual.jsp>

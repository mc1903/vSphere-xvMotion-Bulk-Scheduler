$setsecpwdparams = @{
    Hostname = "mc-vcsa-v-201.momusconsulting.com"
    Username = "administrator@vsphere.local"
}
Set-SecurePassword @setsecpwdparams

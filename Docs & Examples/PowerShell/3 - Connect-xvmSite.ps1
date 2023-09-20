$connect1Params = @{
    siteName = "mc-vcsa-v-201"
    vCenterFQDN = "mc-vcsa-v-201.momusconsulting.com"
    vCenterUsername = "administrator@vsphere.local"
    useSavedPassword = $true
    skipCertificateCheck = $true
    jsonOut = $true
}
Connect-xvmSite @connect1Params

$connect2Params = @{
    siteName = "vcf-m01-vc01"
    vCenterFQDN = "vcf-m01-vc01.vcf.momusconsulting.com"
    vCenterUsername = "administrator@vsphere.local"
    useSavedPassword = $true
    skipCertificateCheck = $true
    jsonOut = $true
}
Connect-xvmSite @connect2Params

$connect3Params = @{
    siteName = "mc-vcsa-v-101"
    vCenterFQDN = "mc-vcsa-v-101.momusconsulting.com"
    vCenterUsername = "administrator@vsphere.local"
    useSavedPassword = $true
    skipCertificateCheck = $true
    jsonOut = $true
}
Connect-xvmSite @connect3Params

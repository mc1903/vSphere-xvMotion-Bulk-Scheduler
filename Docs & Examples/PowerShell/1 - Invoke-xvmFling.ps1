Import-Module -Name "vSphere-xvMotion-Bulk-Scheduler"

$xvmFlingparams = @{
    jreFile = "C:\Program Files\Java\jre-1.8\bin\java.exe"
    jarFile = "C:\Source\xvmFling\xvm-3.1.jar"
    OpenBrowser = $true
}
Invoke-xvmFling @xvmFlingparams

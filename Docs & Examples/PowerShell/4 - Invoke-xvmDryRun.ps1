$dryrun = @{
    migrationTasksCSV = "C:\Users\MartinCo\Documents\xvmFling\xvm Migration Tasks.csv"
    networkMappingsCSV = "C:\Users\MartinCo\Documents\xvmFling\xvm Network Mapping.csv"
    useSavedPassword = $true
}
Invoke-xvmDryRun @dryrun

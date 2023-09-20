$scheduler = @{
    migrationTasksCSV = "C:\Users\MartinCo\Documents\xvmFling\xvm Migration Tasks.csv"
    networkMappingsCSV = "C:\Users\MartinCo\Documents\xvmFling\xvm Network Mapping.csv"
    taskJsonFilesOutPath = "C:\Users\MartinCo\Documents\xvmFling\TaskJsonFiles\"
    useSavedPassword = $true
}
Invoke-xvmScheduler @scheduler

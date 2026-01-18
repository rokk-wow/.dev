# Sync dev files to all project .dev folders
# This script copies all files from C:\Projects\.dev to each project's .dev folder

$centralDevPath = "C:\Projects\.dev"
$projectsRoot = "C:\Projects"
$scriptName = $MyInvocation.MyCommand.Name

# Get all files in the central .dev folder except this script
$filesToSync = Get-ChildItem -Path $centralDevPath -File | Where-Object { $_.Name -ne $scriptName }

# Get all directories in C:\Projects except .dev itself
$projectFolders = Get-ChildItem -Path $projectsRoot -Directory | Where-Object { $_.Name -ne ".dev" }

Write-Host "Starting sync of dev files..." -ForegroundColor Cyan
Write-Host "Files to sync: $($filesToSync.Name -join ', ')" -ForegroundColor Gray
Write-Host ""

foreach ($project in $projectFolders) {
    $targetDevFolder = Join-Path $project.FullName ".dev"
    
    # Check if the project has a .dev folder
    if (Test-Path $targetDevFolder) {
        Write-Host "Syncing to: $($project.Name)\.dev" -ForegroundColor Yellow
        
        foreach ($file in $filesToSync) {
            $destPath = Join-Path $targetDevFolder $file.Name
            
            Copy-Item -Path $file.FullName -Destination $destPath -Force
            Write-Host "  Copied $($file.Name)" -ForegroundColor Green
        }
    } else {
        Write-Host "Skipping $($project.Name) - no .dev folder found" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Sync complete!" -ForegroundColor Cyan

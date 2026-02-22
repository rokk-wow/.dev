param(
    [switch]$Uninstall
)

# Array of World of Warcraft base folders to deploy to
$WoWBaseFolders = @(
    "C:\Program Files (x86)\World of Warcraft\_beta_",
    "C:\Program Files (x86)\World of Warcraft\_ptr_",
    "C:\Program Files (x86)\World of Warcraft\_retail_"
)

# Array of files/folders to clean up after deployment
$CleanupItems = @(
    ".vscode",
    ".gitignore",
    ".release",
    ".dev",
    ".git"
)

# Array of subfolders to update via git pull before deployment
$GitUpdateFolders = @(
    "Libs\LibSAdCore"
)

# Define folder variables
$ProjectRoot = Split-Path $PSScriptRoot -Parent

# Get addon name from .toc file
$tocFile = Get-ChildItem -Path $ProjectRoot -Filter "*.toc" -File | Select-Object -First 1
if (-not $tocFile) {
    Write-Error "No .toc file found in project root: $ProjectRoot"
    exit 1
}
$AddonName = $tocFile.BaseName

# Verify addon name matches folder name
$FolderName = Split-Path $ProjectRoot -Leaf
if ($AddonName -ne $FolderName) {
    Write-Error "Addon name '$AddonName' does not match folder name '$FolderName'"
    exit 1
}
Write-Host "Addon name: $AddonName`n"

# Verify all WoW base folders exist and have required subfolders
Write-Host "Verifying WoW installation folders..."
foreach ($folder in $WoWBaseFolders) {
    if (-not (Test-Path $folder)) {
        Write-Error "WoW base folder not found: $folder"
        exit 1
    }
    Write-Host "  Found: $folder"
    
    # Check for Interface\Addons subfolder
    $addonsPath = Join-Path $folder "Interface\Addons"
    if (-not (Test-Path $addonsPath)) {
        Write-Error "Required subfolder not found: $addonsPath"
        exit 1
    }
    Write-Host "    Found: Interface\Addons"
    
    # Check for WTF subfolder
    $wtfPath = Join-Path $folder "WTF"
    if (-not (Test-Path $wtfPath)) {
        Write-Error "Required subfolder not found: $wtfPath"
        exit 1
    }
    Write-Host "    Found: WTF"
}
Write-Host "All WoW folders verified successfully.`n"

# Update git subfolders before deployment
if ($GitUpdateFolders.Count -gt 0) {
    Write-Host "Updating git subfolders...`n"
    
    foreach ($subFolder in $GitUpdateFolders) {
        $subFolderPath = Join-Path $ProjectRoot $subFolder
        
        if (-not (Test-Path $subFolderPath)) {
            Write-Warning "Git subfolder not found: $subFolderPath (skipping)"
            continue
        }
        
        Write-Host "Updating: $subFolder"
        Push-Location $subFolderPath

        try {
            # Fetch latest changes
            Write-Host "  Fetching latest changes..."
            git fetch --all 2>&1 | Out-Null
            
            # Reset to match remote (discards local changes)
            Write-Host "  Resetting to latest remote version..."
            $currentBranch = git rev-parse --abbrev-ref HEAD 2>&1
            if ($LASTEXITCODE -eq 0) {
                git reset --hard "origin/$currentBranch" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "  Updated successfully" -ForegroundColor Green
                }
                else {
                    Write-Warning "  Failed to reset to origin/$currentBranch"
                }
            }
            else {
                Write-Warning "  Failed to determine current branch"
            }
        }
        catch {
            Write-Warning "  Error updating git folder: $_"
        }

        Pop-Location
    }
    
    Write-Host "`nGit subfolder updates complete.`n"
}

# Determine mode based on parameters
if ($Uninstall) {
    Write-Host "Uninstalling $AddonName...`n"
    
    foreach ($folder in $WoWBaseFolders) {
        $addonPath = Join-Path $folder "Interface\Addons\$AddonName"
        
        if (Test-Path $addonPath) {
            Write-Host "Removing: $addonPath"
            Remove-Item -Path $addonPath -Recurse -Force
            Write-Host "  Removed successfully"
        }
        else {
            Write-Host "Not found: $addonPath (skipping)"
        }
        
        # Remove saved variables from WTF folder
        $wtfPath = Join-Path $folder "WTF"
        Write-Host "Searching for saved variables in: $wtfPath"
        
        $luaFiles = Get-ChildItem -Path $wtfPath -Filter "$AddonName.lua" -Recurse -File -ErrorAction SilentlyContinue
        $bakFiles = Get-ChildItem -Path $wtfPath -Filter "$AddonName.lua.bak" -Recurse -File -ErrorAction SilentlyContinue
        
        $allFiles = $luaFiles + $bakFiles
        
        if ($allFiles.Count -gt 0) {
            foreach ($file in $allFiles) {
                Write-Host "  Removing: $($file.FullName)"
                Remove-Item -Path $file.FullName -Force
            }
            Write-Host "  Removed $($allFiles.Count) saved variable file(s)"
        }
        else {
            Write-Host "  No saved variable files found"
        }
    }
    
    Write-Host "`nUninstall complete."
}
else {
    Write-Host "Deploying $AddonName...`n"
    
    foreach ($folder in $WoWBaseFolders) {
        $targetPath = Join-Path $folder "Interface\Addons\$AddonName"
        
        Write-Host "Deploying to: $targetPath"
        
        # Remove existing addon folder if it exists
        if (Test-Path $targetPath) {
            Write-Host "  Removing existing installation..."
            Remove-Item -Path $targetPath -Recurse -Force
        }
        
        # Copy addon folder to target using robocopy with exclusions
        Write-Host "  Copying files (excluding development files)..."
        
        # Prepare robocopy exclusion parameters
        $excludeDirs = $CleanupItems | ForEach-Object { "/XD", $_ }
        $excludeFiles = $CleanupItems | ForEach-Object { "/XF", $_ }
        
        # Build robocopy arguments
        $robocopyArgs = @(
            $ProjectRoot,
            $targetPath,
            "/MIR",          # Mirror directory (copy all subdirectories, including empty ones, and delete files in destination that don't exist in source)
            "/NJH",          # No job header
            "/NJS",          # No job summary
            "/NDL",          # No directory list
            "/NP"            # No progress
        ) + $excludeDirs + $excludeFiles
        
        # Execute robocopy
        $result = robocopy @robocopyArgs 2>&1
        
        # Robocopy exit codes: 0-7 are success, 8+ are errors
        if ($LASTEXITCODE -ge 8) {
            Write-Error "  Failed to copy files (robocopy exit code: $LASTEXITCODE)"
            Write-Host $result
            exit 1
        }
        
        Write-Host "  Deployment complete"
    }
}

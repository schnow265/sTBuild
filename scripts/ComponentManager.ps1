<#
.SYNOPSIS
    Manages component repositories for sTBuild.
.DESCRIPTION
    Handles cloning, updating, and tracking repositories for sTBuild components.
#>

# Platform detection
$script:IsWindows = $PSVersionTable.PSEdition -eq "Desktop" -or 
                   ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows)
$script:IsLinux = $PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux
$script:IsMacOS = $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS

$script:HomeDir = if ($script:IsWindows) { $env:USERPROFILE } else { $env:HOME }
$script:ComponentsRoot = Join-Path $script:HomeDir "sTBuild/repositories"

function Initialize-ComponentRepository {
    [CmdletBinding()]
    param()

    # Create components directory if it doesn't exist
    if (!(Test-Path $script:ComponentsRoot)) {
        New-Item -ItemType Directory -Path $script:ComponentsRoot -Force | Out-Null
        Write-Host "Created component repository directory: $script:ComponentsRoot"
    }

    # Create or update database table for repositories
    $updateTableQuery = @"
CREATE TABLE IF NOT EXISTS Repositories (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Software TEXT NOT NULL,
    RepoUrl TEXT NOT NULL,
    LocalPath TEXT NOT NULL,
    LastUpdated TEXT NOT NULL,
    Branch TEXT NOT NULL DEFAULT 'main',
    CurrentHash TEXT
);
"@

    # Ensure SQLite is available
    if (!(Get-Command -Name 'Invoke-SqliteQuery' -ErrorAction SilentlyContinue)) {
        Write-Error "SQLite module not loaded. Make sure to initialize the build environment first."
        return
    }

    Invoke-SqliteQuery -DataSource $script:DatabasePath -Query $updateTableQuery
    
    Write-Host -ForegroundColor Green "Component repository database initialized."
}

function Update-ComponentRepository {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Software,
        
        [Parameter()]
        [string]$RepoUrl,
        
        [Parameter()]
        [string]$Branch = "main",
        
        [Parameter()]
        [switch]$Force
    )
    
    # Get repository information from template if URL not provided
    if ([string]::IsNullOrEmpty($RepoUrl)) {
        $template = Get-BuildTemplate -Software $Software
        if (!$template) {
            Write-Error "No template found for $Software and no repository URL provided."
            return $null
        }
        $RepoUrl = $template.repository
        
        if ([string]::IsNullOrEmpty($RepoUrl)) {
            Write-Error "No repository URL found in template for $Software."
            return $null
        }
    }
    
    # Check if we already have this repository in the database
    $repo = Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "SELECT * FROM Repositories WHERE Software = @Software" -SqlParameters @{
        Software = $Software
    }
    
    # Get safe directory name
    $repoName = Split-Path -Leaf $RepoUrl -ErrorAction SilentlyContinue
    $repoName = $repoName -replace '\.git$', ''
    if (!$repoName) { $repoName = $Software }
    
    $localPath = Join-Path $script:ComponentsRoot "$Software-$repoName"
    
    # Store current location
    $originalLocation = Get-Location
    
    try {
        # If repository exists in database but Force is specified, delete local copy
        if ($repo -and $Force) {
            Write-Host "Force option specified. Removing existing repository..."
            if (Test-Path $repo.LocalPath) {
                try {
                    Remove-Item -Recurse -Force $repo.LocalPath -ErrorAction Stop
                }
                catch {
                    Write-Warning "Failed to remove repository directory: $_"
                }
            }
            
            # Delete database entry
            Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "DELETE FROM Repositories WHERE Id = @Id" -SqlParameters @{
                Id = $repo.Id
            }
            
            $repo = $null
        }
        
        if ($repo) {
            # Update existing repository
            Write-Host "Updating existing repository for $Software..."
            
            # Check if local path exists
            if (!(Test-Path $repo.LocalPath)) {
                Write-Warning "Local path $($repo.LocalPath) not found. Re-cloning repository..."
                
                # Create directory if parent doesn't exist
                $parentDir = Split-Path -Parent $repo.LocalPath
                if (!(Test-Path $parentDir)) {
                    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                }
                
                # Clone repository
                git clone $RepoUrl $repo.LocalPath
                
                if ($Branch -ne "main" -and $Branch -ne "master") {
                    Set-Location $repo.LocalPath
                    git checkout $Branch
                }
                
                $localPath = $repo.LocalPath
            }
            else {
                # Repository exists, just update it
                Set-Location $repo.LocalPath
                
                # Save current branch
                $currentBranch = git branch --show-current
                
                if ($currentBranch -ne $Branch) {
                    Write-Host "Switching from branch '$currentBranch' to '$Branch'..."
                    git checkout $Branch
                }
                
                # Pull latest changes
                git pull
                git submodule update --init --recursive
            }
            
            # Get current git hash
            Set-Location $repo.LocalPath
            $gitHash = git rev-parse HEAD
            
            # Update database entry
            Invoke-SqliteQuery -DataSource $script:DatabasePath -Query @"
UPDATE Repositories 
SET LastUpdated = @LastUpdated, Branch = @Branch, CurrentHash = @CurrentHash, RepoUrl = @RepoUrl
WHERE Id = @Id
"@ -SqlParameters @{
                Id = $repo.Id
                LastUpdated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                Branch = $Branch
                CurrentHash = $gitHash
                RepoUrl = $RepoUrl
            }
        }
        else {
            # Create new repository
            Write-Host "Creating new repository for $Software..."
            
            # Create directory if it doesn't exist
            $parentDir = Split-Path -Parent $localPath
            if (!(Test-Path $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            
            # Clone repository
            git clone $RepoUrl $localPath
            
            if ($Branch -ne "main" -and $Branch -ne "master") {
                Set-Location $localPath
                git checkout $Branch
            }
            
            # Get current git hash
            Set-Location $localPath
            $gitHash = git rev-parse HEAD
            
            # Insert database entry
            Invoke-SqliteQuery -DataSource $script:DatabasePath -Query @"
INSERT INTO Repositories (Software, RepoUrl, LocalPath, LastUpdated, Branch, CurrentHash)
VALUES (@Software, @RepoUrl, @LocalPath, @LastUpdated, @Branch, @CurrentHash)
"@ -SqlParameters @{
                Software = $Software
                RepoUrl = $RepoUrl
                LocalPath = $localPath
                LastUpdated = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                Branch = $Branch
                CurrentHash = $gitHash
            }
        }
        
        # Return the updated repository information
        $updatedRepo = Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "SELECT * FROM Repositories WHERE Software = @Software" -SqlParameters @{
            Software = $Software
        }
        
        Write-Host "Repository for $Software updated successfully at $($updatedRepo.LocalPath)"
        Write-Host "Current hash: $($updatedRepo.CurrentHash)"
        
        return $updatedRepo
    }
    catch {
        Write-Error "Failed to update repository: $_"
        return $null
    }
    finally {
        # Restore original location
        Set-Location $originalLocation
    }
}

function Get-ComponentRepository {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Software
    )
    
    if ($Software) {
        $repos = Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "SELECT * FROM Repositories WHERE Software = @Software" -SqlParameters @{
            Software = $Software
        }
    }
    else {
        $repos = Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "SELECT * FROM Repositories ORDER BY Software"
    }
    
    return $repos
}

function Remove-ComponentRepository {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Software,
        
        [Parameter()]
        [switch]$RemoveLocalFiles
    )
    
    # Get repository information
    $repo = Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "SELECT * FROM Repositories WHERE Software = @Software" -SqlParameters @{
        Software = $Software
    }
    
    if (!$repo) {
        Write-Warning "No repository found for $Software"
        return $false
    }
    
    # Remove local files if requested
    if ($RemoveLocalFiles -and (Test-Path $repo.LocalPath)) {
        if ($PSCmdlet.ShouldProcess($repo.LocalPath, "Remove local repository files")) {
            try {
                Remove-Item -Recurse -Force $repo.LocalPath
                Write-Host "Removed local repository files at $($repo.LocalPath)"
            }
            catch {
                Write-Warning "Failed to remove repository directory: $_"
            }
        }
    }
    
    # Remove database entry
    if ($PSCmdlet.ShouldProcess($Software, "Remove repository from database")) {
        Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "DELETE FROM Repositories WHERE Id = @Id" -SqlParameters @{
            Id = $repo.Id
        }
        
        Write-Host "Removed $Software repository from database"
        return $true
    }
    
    return $false
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-ComponentRepository',
    'Update-ComponentRepository',
    'Get-ComponentRepository',
    'Remove-ComponentRepository'
)

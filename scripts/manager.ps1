#Requires -Version 5.1

# Platform detection
$script:IsWindows = $PSVersionTable.PSEdition -eq "Desktop" -or 
                   ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows)
$script:IsLinux = $PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux
$script:IsMacOS = $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS

# Constants
$script:HomeDir = if ($script:IsWindows) { $env:USERPROFILE } else { $env:HOME }
$script:BuildSystemRoot = Join-Path $script:HomeDir "sTBuild"
$script:BuildModulesPath = Join-Path $script:BuildSystemRoot "modules"
$script:BuildTemplatesPath = Join-Path $script:BuildSystemRoot "templates"
$script:BuildBinPath = Join-Path $script:BuildSystemRoot "bin"
$script:DatabasePath = Join-Path $script:BuildSystemRoot "builds.db"

# Initialize the build environment
function Initialize-BuildEnvironment {
    [CmdletBinding()]
    param()

    # Create necessary directories
    $dirs = @(
        $script:BuildSystemRoot,
        $script:BuildBinPath,
        "$script:BuildSystemRoot\llvm",
        "$script:BuildSystemRoot\dotnet",
        $script:BuildModulesPath,
        $script:BuildTemplatesPath
    )

    foreach ($dir in $dirs) {
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "Created directory: $dir"
        }
    }

    # Ensure SQLite is available
    Import-SQLiteModule
    
    # Create default templates if they don't exist
    CreateDefaultTemplates
}

function CreateDefaultTemplates {
    $llvmTemplatePath = "$script:BuildTemplatesPath\llvm.json"
    $dotnetTemplatePath = "$script:BuildTemplatesPath\dotnet.json"
    
    if (!(Test-Path $llvmTemplatePath)) {
        $llvmTemplate = @{
            name          = "llvm"
            description   = "LLVM Compiler Infrastructure"
            repository    = "https://github.com/llvm/llvm-project.git"
            buildScript   = "buildscripts\llvm.ps1"
            buildFunction = "Build-LLVM"
            defaultConfiguration = @{
                BuildType = "Release"
                LLvmProjects = "clang; lld; clang-tools-extra"
                llvmTargets = "X86"
                EnableLLD = $false
                BuildTests = $false
                OptimizedTableGen = $true
            }
            configurationSchema = @{
                BuildType = @{
                    type = "string"
                    enum = @("Debug", "Release", "RelWithDebInfo", "MinSizeRel")
                    default = "Release"
                    description = "Build type"
                }
                LLvmProjects = @{
                    type = "string"
                    default = "clang; lld"
                    description = "LLVM projects to build"
                }
                # More configuration options can be added here
            }
            executablePatterns = @("*.exe", "*.cmd", "*.bat")
        }
        ConvertTo-Json $llvmTemplate -Depth 10 | Set-Content $llvmTemplatePath
        Write-Host "Created LLVM template at $llvmTemplatePath"
    }
    
    if (!(Test-Path $dotnetTemplatePath)) {
        $dotnetTemplate = @{
            name = "dotnet"
            description = ".NET Runtime and SDK"
            repository = "https://github.com/dotnet/runtime.git"
            buildScript = "buildscripts\dotnet.ps1"
            buildFunction = "Build-DotNet"
            defaultConfiguration = @{
                Configuration = "Release"
                Architecture = "x64"
                OS = "windows"
                BuildRuntime = $true
                BuildSdk = $false
                SkipTests = $true
            }
            configurationSchema = @{
                Configuration = @{
                    type = "string"
                    enum = @("Debug", "Release", "RelWithDebInfo")
                    default = "Release"
                    description = "Build configuration"
                }
                Architecture = @{
                    type = "string"
                    enum = @("x64", "x86", "arm", "arm64")
                    default = "x64"
                    description = "Target architecture"
                }
                # More configuration options can be added here
            }
            executablePatterns = @("*.exe", "*.cmd", "*.bat")
        }
        ConvertTo-Json $dotnetTemplate -Depth 10 | Set-Content $dotnetTemplatePath
        Write-Host "Created .NET template at $dotnetTemplatePath"
    }
}

function Import-SQLiteModule {
    # Check if SQLite module is installed
    if (!(Get-Module -ListAvailable -Name PSSQLite)) {
        Write-Host -ForegroundColor Cyan "Installing PSSQLite module..."
        Install-Module PSSQLite -Scope CurrentUser -Force
    }
    
    # Import the module
    Import-Module PSSQLite

    # Create or verify the database
    Initialize-BuildDatabase
}

function Initialize-BuildDatabase {
    [CmdletBinding()]
    param()
    
    # Create database and tables if they don't exist
    $createTableQuery = @"
CREATE TABLE IF NOT EXISTS Builds (
    Id INTEGER PRIMARY KEY AUTOINCREMENT,
    Software TEXT NOT NULL,
    GitHash TEXT NOT NULL,
    BuildDateTime TEXT NOT NULL,
    Configuration TEXT NOT NULL,
    InstallPath TEXT NOT NULL,
    IsActive INTEGER DEFAULT 0
);
"@

    Invoke-SqliteQuery -DataSource $script:DatabasePath -Query $createTableQuery
    
    Write-Host -ForegroundColor Green "Build database initialized at $script:DatabasePath"
    return $script:DatabasePath
}

function Register-Build {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Software,
        
        [Parameter(Mandatory=$true)]
        [string]$GitHash,
        
        [Parameter(Mandatory=$true)]
        [string]$Configuration,
        
        [Parameter(Mandatory=$true)]
        [string]$InstallPath
    )
    
    # Check if this exact build already exists
    $existingBuild = Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "SELECT * FROM Builds WHERE Software = @Software AND GitHash = @GitHash AND Configuration = @Configuration" -SqlParameters @{
        Software = $Software
        GitHash = $GitHash
        Configuration = $Configuration
    }
    
    if ($existingBuild) {
        # Update the build date/time and path
        Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "UPDATE Builds SET BuildDateTime = @BuildDateTime, InstallPath = @InstallPath WHERE Id = @Id" -SqlParameters @{
            Id = $existingBuild.Id
            BuildDateTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            InstallPath = $InstallPath
        }
        Write-Host "Updated build information for $Software ($GitHash)"
        return $existingBuild.Id
    } else {
        # Insert new build
        Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "INSERT INTO Builds (Software, GitHash, BuildDateTime, Configuration, InstallPath) VALUES (@Software, @GitHash, @BuildDateTime, @Configuration, @InstallPath)" -SqlParameters @{
            Software = $Software
            GitHash = $GitHash
            BuildDateTime = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
            Configuration = $Configuration
            InstallPath = $InstallPath
        }
        
        $newId = Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "SELECT last_insert_rowid() as Id" | Select-Object -ExpandProperty Id
        Write-Host "Registered new build for $Software ($GitHash)"
        return $newId
    }
}

function Set-ActiveBuild {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Software,
        
        [Parameter(Mandatory=$true)]
        [string]$GitHash
    )
    
    # Reset active flag for all builds of this software
    Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "UPDATE Builds SET IsActive = 0 WHERE Software = @Software" -SqlParameters @{
        Software = $Software
    }
    
    # Set the specified build as active
    $result = Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "UPDATE Builds SET IsActive = 1 WHERE Software = @Software AND GitHash = @GitHash" -SqlParameters @{
        Software = $Software
        GitHash = $GitHash
    }
    
    if ($result -ne -1) {
        # Get the install path for the active build
        $build = Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "SELECT InstallPath FROM Builds WHERE Software = @Software AND GitHash = @GitHash" -SqlParameters @{
            Software = $Software
            GitHash = $GitHash
        }
        
        if ($build) {
            $currentSymlinkPath = "$script:BuildSystemRoot\$Software\current"
            
            # Remove existing symlink if it exists
            if (Test-Path $currentSymlinkPath) {
                Remove-Item $currentSymlinkPath -Force
            }
            
            # Create symlink to the active build
            New-SymbolicLink -Path $currentSymlinkPath -Target $build.InstallPath -Type Directory
            Write-Host "Set $GitHash as the active build for $Software"
            
            # Update binary symlinks
            Update-BinarySymlinks -Software $Software -InstallPath $build.InstallPath
            
            return $true
        }
    }
    
    Write-Error "Failed to set active build for $Software ($GitHash)"
    return $false
}

function Get-ActiveBuild {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Software
    )
    
    $activeBuild = Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "SELECT * FROM Builds WHERE Software = @Software AND IsActive = 1" -SqlParameters @{
        Software = $Software
    }
    
    return $activeBuild
}

function Get-BuildHistory {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Software
    )
    
    if ($Software) {
        $builds = Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "SELECT * FROM Builds WHERE Software = @Software ORDER BY BuildDateTime DESC" -SqlParameters @{
            Software = $Software
        }
    } else {
        $builds = Invoke-SqliteQuery -DataSource $script:DatabasePath -Query "SELECT * FROM Builds ORDER BY Software, BuildDateTime DESC"
    }
    
    return $builds
}

function New-SymbolicLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$Target,
        
        [Parameter()]
        [ValidateSet('File', 'Directory')]
        [string]$Type = 'File'
    )

    # Remove existing link if it exists
    if (Test-Path -Path $Path) {
        Remove-Item -Path $Path -Force
    }
    
    # Ensure parent directory exists
    $parentDir = Split-Path -Path $Path -Parent
    if (!(Test-Path -Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    # Cross-platform symlink creation
    if ($script:IsWindows) {
        # Windows symlink creation using mklink
        $linkType = if ($Type -eq 'Directory') { 'D' } else { '' }
        $output = cmd /c "mklink /$linkType `"$Path`" `"$Target`"" 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create symbolic link: $output"
            return $false
        }
    }
    else {
        # Linux/macOS symlink creation using New-Item (PowerShell 6+)
        try {
            $itemType = if ($Type -eq 'Directory') { 'SymbolicLink' } else { 'SymbolicLink' }
            New-Item -ItemType $itemType -Path $Path -Target $Target -Force | Out-Null
        }
        catch {
            # Fallback to using ln -s
            $ln = if ($IsMacOS) { "/bin/ln" } else { "/usr/bin/ln" }
            $output = & $ln -s "$Target" "$Path" 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to create symbolic link: $output"
                return $false
            }
        }
    }
    
    return $true
}

function Update-BinarySymlinks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Software,
        
        [Parameter(Mandatory=$true)]
        [string]$InstallPath
    )
    
    # Create bin directory if it doesn't exist
    if (!(Test-Path $script:BuildBinPath)) {
        New-Item -ItemType Directory -Path $script:BuildBinPath -Force | Out-Null
    }

    # Get the template to determine executable patterns
    $template = Get-BuildTemplate -Software $Software
    if (!$template -or !$template.executablePatterns) {
        $executablePatterns = @('*.exe', '*.cmd', '*.bat')
        Write-Verbose "Using default executable patterns for $Software"
    } else {
        $executablePatterns = $template.executablePatterns
        Write-Verbose "Using template-defined executable patterns for $Software"
    }
    
    # Find all executable files in the installation directory
    $executableFiles = @()
    foreach ($pattern in $executablePatterns) {
        $executableFiles += Get-ChildItem -Path $InstallPath -Filter $pattern -Recurse -File
    }
    
    Write-Host "Found $($executableFiles.Count) executable files for $Software"
    
    # Create symlinks for each executable
    foreach ($file in $executableFiles) {
        $symlink = Join-Path -Path $script:BuildBinPath -ChildPath $file.Name
        
        # Skip if we already have a non-matching symlink for this software with the same name
        # This prevents overwriting symlinks from other versions of the same software
        if (Test-Path $symlink) {
            # PowerShell doesn't have built-in way to check if a file is a symlink and where it points
            # So we'll use alternative methods to avoid overwriting incorrect symlinks
            continue
        }
        
        New-SymbolicLink -Path $symlink -Target $file.FullName -Type File
        Write-Host "Created symlink: $symlink -> $($file.FullName)"
    }
}

function Get-BuildTemplate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Software
    )
    
    $templatePath = "$script:BuildTemplatesPath\$Software.json"
    
    if (!(Test-Path $templatePath)) {
        Write-Warning "Template for $Software not found at $templatePath"
        return $null
    }
    
    try {
        $template = Get-Content -Path $templatePath -Raw | ConvertFrom-Json
        return $template
    }
    catch {
        Write-Error "Failed to parse template for $($Software): $_"
        return $null
    }
}

function Register-BuildTemplate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Repository,
        
        [Parameter(Mandatory=$true)]
        [string]$BuildScript,
        
        [Parameter(Mandatory=$true)]
        [string]$BuildFunction,
        
        [Parameter()]
        [string]$Description = "",
        
        [Parameter()]
        [hashtable]$DefaultConfiguration = @{},
        
        [Parameter()]
        [hashtable]$ConfigurationSchema = @{},
        
        [Parameter()]
        [string[]]$ExecutablePatterns = @("*.exe", "*.cmd", "*.bat")
    )
    
    $template = @{
        name = $Name
        description = $Description
        repository = $Repository
        buildScript = $BuildScript
        buildFunction = $BuildFunction
        defaultConfiguration = $DefaultConfiguration
        configurationSchema = $ConfigurationSchema
        executablePatterns = $ExecutablePatterns
    }
    
    $templatePath = "$script:BuildTemplatesPath\$Name.json"
    ConvertTo-Json $template -Depth 10 | Set-Content $templatePath
    
    Write-Host "Registered build template for $Name at $templatePath"
}

function Get-BuildTemplates {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$IncludeBuildCommand
    )
    
    # Ensure templates directory exists
    if (!(Test-Path $script:BuildTemplatesPath)) {
        Write-Warning "Templates directory not found at $script:BuildTemplatesPath"
        return @()
    }
    
    # Get all template files
    $templateFiles = Get-ChildItem -Path $script:BuildTemplatesPath -Filter "*.json"
    $templates = @()
    
    foreach ($file in $templateFiles) {
        try {
            $template = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            
            # Create a custom object with template information
            $templateObj = [PSCustomObject]@{
                Name = $template.name
                Description = $template.description
                Repository = $template.repository
                BuildScript = $template.buildScript
                BuildFunction = $template.buildFunction
            }
            
            # Add build command if requested
            if ($IncludeBuildCommand) {
                $buildCommand = "Invoke-TemplateBuild -Software '$($template.name)'"
                
                # Add -UseDefaults flag if default configuration exists
                if ($template.defaultConfiguration -and $template.defaultConfiguration.PSObject.Properties.Count -gt 0) {
                    $buildCommand += " -UseDefaults"
                    
                    # Add custom configuration example
                    $configExample = "@{ "
                    $i = 0
                    foreach ($prop in $template.defaultConfiguration.PSObject.Properties) {
                        $configExample += if ($i -eq 0) { "" } else { "; " }
                        
                        # Format the value based on its type
                        $value = switch ($prop.Value) {
                            { $_ -is [bool] } { "`$$_" }
                            { $_ -is [int] } { "$_" }
                            default { "'$_'" }
                        }
                        
                        $configExample += "$($prop.Name) = $value"
                        $i++
                    }
                    $configExample += "}"
                    
                    $buildCommand += "`n# Or with custom configuration:`nInvoke-TemplateBuild -Software '$($template.name)' -Configuration $configExample"
                }
                
                $templateObj | Add-Member -MemberType NoteProperty -Name "BuildCommand" -Value $buildCommand
            }
            
            $templates += $templateObj
        }
        catch {
            Write-Warning "Failed to parse template $($file.Name): $_"
        }
    }
    
    return $templates
}

function Invoke-TemplateBuild {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Software,
        
        [Parameter()]
        [hashtable]$Configuration = @{},
        
        [Parameter()]
        [switch]$UseDefaults
    )
    
    # Get the template for the software
    $template = Get-BuildTemplate -Software $Software
    
    if (!$template) {
        Write-Error "No template found for $Software"
        return
    }
    
    # Merge configuration with defaults if UseDefaults is specified
    if ($UseDefaults -and $template.defaultConfiguration) {
        $defaultConfig = [hashtable]@{}
        foreach ($key in $template.defaultConfiguration.PSObject.Properties.Name) {
            $defaultConfig[$key] = $template.defaultConfiguration.$key
        }
        
        # Override defaults with provided configuration
        foreach ($key in $Configuration.Keys) {
            $defaultConfig[$key] = $Configuration[$key]
        }
        
        $Configuration = $defaultConfig
    }
    
    # Import the build script
    $scriptPath = Join-Path $PSScriptRoot $template.buildScript
    if (!(Test-Path $scriptPath)) {
        Write-Error "Build script not found at $scriptPath"
        return
    }
    
    . $scriptPath
    
    # Get repository path from template
    $repoUrl = $template.repository
    
    # Extract GitHash
    $repoName = Split-Path -Leaf $repoUrl -ErrorAction SilentlyContinue
    $repoName = $repoName -replace '\.git$', ''
    if (!$repoName) { $repoName = $Software }
    
    # Clone or update repository and get hash
    $gitHash = Get-RepositoryHash -RepoName $repoName -RepoUrl $repoUrl
    if (!$gitHash) {
        Write-Error "Failed to get git hash for $Software"
        return
    }
    
    # Set install directory based on hash
    $installDir = "$script:BuildSystemRoot\$Software\$gitHash"
    
    # Add install directory to configuration
    $Configuration["InstallDir"] = $installDir
    
    # Create parameter hashtable
    $params = @{}
    foreach ($key in $Configuration.Keys) {
        $params[$key] = $Configuration[$key]
    }
    
    # Invoke the build function
    $buildFunctionName = $template.buildFunction
    
    # Check if the function exists
    if (!(Get-Command $buildFunctionName -ErrorAction SilentlyContinue)) {
        Write-Error "Build function $buildFunctionName not found"
        return
    }
    
    # Build it
    & $buildFunctionName @params
    
    # Configuration summary for registration
    $configSummary = ($Configuration.Keys | ForEach-Object { "$_=$($Configuration[$_])" }) -join ';'
    
    # Register the build
    $buildId = Register-Build -Software $Software -GitHash $gitHash -Configuration $configSummary -InstallPath $installDir
    
    # Set as active
    Set-ActiveBuild -Software $Software -GitHash $gitHash
    
    Write-Host "$Software build completed. Installed to: $installDir"
    Write-Host "Symlinks created in: $script:BuildBinPath"
}

function Get-RepositoryHash {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$RepoName,
        
        [Parameter(Mandatory=$true)]
        [string]$RepoUrl
    )
    
    # Store current location
    $originalLocation = Get-Location
    
    try {
        # Check if repository exists
        if (Test-Path $RepoName) {
            Set-Location $RepoName
            
            # Get the current git commit hash before pull
            $oldHash = git rev-parse --short HEAD
            
            # Pull latest changes
            git pull
            git submodule update --init --recursive
            
            # Get the new git commit hash after pull
            $gitHash = git rev-parse --short HEAD
            
            Set-Location $originalLocation
            
            # Check if git hash has changed
            if ($oldHash -ne $gitHash) {
                Write-Host "Git hash changed from $oldHash to $gitHash."
            } else {
                Write-Host "Git hash unchanged ($gitHash)."
            }
        } else {
            Write-Host "Cloning repository $RepoUrl..."
            git clone $RepoUrl $RepoName
            
            Set-Location $RepoName
            git submodule update --init --recursive
            $gitHash = git rev-parse --short HEAD
            Set-Location $originalLocation
        }
        
        return $gitHash
    }
    catch {
        Write-Error "Failed to get repository hash: $_"
        Set-Location $originalLocation
        return $null
    }
}

function Update-BuildTemplateSchema {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    # Ensure templates directory exists
    if (!(Test-Path $script:BuildTemplatesPath)) {
        Write-Warning "Templates directory not found at $script:BuildTemplatesPath"
        return
    }
    
    # Get all template files
    $templateFiles = Get-ChildItem -Path $script:BuildTemplatesPath -Filter "*.json"
    
    foreach ($file in $templateFiles) {
        try {
            $template = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $modified = $false
            
            # Check if the build function follows the new naming schema
            if ($template.buildFunction -and -not $template.buildFunction.StartsWith("sTBuild-")) {
                $oldFunctionName = $template.buildFunction
                $newFunctionName = "sTBuild-" + $oldFunctionName.Replace("Build-", "")
                
                if ($PSCmdlet.ShouldProcess($file.Name, "Update build function from '$oldFunctionName' to '$newFunctionName'")) {
                    $template.buildFunction = $newFunctionName
                    $modified = $true
                    
                    Write-Host "Updated $($file.Name) - Function: $oldFunctionName -> $newFunctionName"
                }
            }
            
            # Save changes if modified
            if ($modified) {
                ConvertTo-Json $template -Depth 10 | Set-Content $file.FullName
            }
        }
        catch {
            Write-Warning "Failed to process template $($file.Name): $_"
        }
    }
}

# Initialize the build environment when the module is loaded
Initialize-BuildEnvironment

# Export public functions
Export-ModuleMember -Function @(
    'Register-Build',
    'Set-ActiveBuild', 
    'Get-ActiveBuild',
    'Get-BuildHistory',
    'Update-BinarySymlinks',
    'Register-BuildTemplate',
    'Get-BuildTemplate',
    'Get-BuildTemplates',
    'Invoke-TemplateBuild',
    'Update-BuildTemplateSchema'
)

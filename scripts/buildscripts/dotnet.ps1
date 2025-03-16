function _Get-DotNetBuildCommand {
    [CmdletBinding()]
    param(
        # Basic configuration
        [string]$BuildType,
        [string]$Architecture,
        [string]$Configuration,
        [string]$OS,
        
        # Component options
        [bool]$BuildRuntime,
        [bool]$BuildSdk,
        [bool]$BuildReferenceAssemblies,
        [bool]$BuildNETFxRuntime,
        [bool]$BuildNETCoreRuntime,
        [bool]$BuildMono,
        [bool]$BuildMSIPackages,
        [bool]$BuildNugetPackages,

        # Build options
        [int]$ParallelBuildJobs,
        [bool]$SkipTests,
        [bool]$SkipNonPortable,
        [bool]$DisableSourceLink,
        [bool]$UseSystemLibraries,
        [bool]$EnableSourceBuild,
        [string]$CmakeArgs,
        
        # Additional options
        [string]$BinlogPath,
        [bool]$UseNativeAOT,
        [bool]$StripSymbols,
        [bool]$EnableCodeSigning,
        [bool]$EnableCrossgen
    )

    $buildCommand = @()
    
    if ($BuildRuntime) {
        $buildCommand += "./build.cmd"
        $buildCommand += "-c $Configuration"
        $buildCommand += "-arch $Architecture"
        $buildCommand += "-os $OS"
        
        if ($ParallelBuildJobs -gt 0) {
            $buildCommand += "/p:MaxCpuCount=$ParallelBuildJobs"
        }
        
        if ($SkipTests) {
            $buildCommand += "/p:SkipTests=true"
        }
        
        if ($SkipNonPortable) {
            $buildCommand += "/p:PortableBuild=false"
        }
        
        if ($DisableSourceLink) {
            $buildCommand += "/p:EnableSourceLink=false"
        }
        
        if ($UseSystemLibraries) {
            $buildCommand += "/p:UseSystemLibraries=true"
        }
        
        if ($EnableCrossgen) {
            $buildCommand += "/p:CrossGen=true"
        }
        
        if ($StripSymbols) {
            $buildCommand += "/p:StripSymbols=true"
        }

        if ($UseNativeAOT) {
            $buildCommand += "/p:BuildNativeAOT=true"
        }
        
        if ($BinlogPath) {
            $buildCommand += "/bl:$BinlogPath"
        }
        
        if ($CmakeArgs) {
            $buildCommand += "/p:CMakeArgs=`"$CmakeArgs`""
        }

        if ($EnableCodeSigning) {
            $buildCommand += "/p:SignType=real"
        }
        else {
            $buildCommand += "/p:SignType=test"
        }
    }
    
    if ($BuildSdk) {
        $sdkBuildCommand = @()
        $sdkBuildCommand += "./build.cmd"
        $sdkBuildCommand += "-c $Configuration"
        $sdkBuildCommand += "-arch $Architecture"
        
        if ($ParallelBuildJobs -gt 0) {
            $sdkBuildCommand += "/p:MaxCpuCount=$ParallelBuildJobs"
        }
        
        if ($SkipTests) {
            $sdkBuildCommand += "/p:SkipTests=true"
        }
        
        if ($EnableSourceBuild) {
            $sdkBuildCommand += "/p:UseSourceBuild=true"
        }
        
        if ($EnableCodeSigning) {
            $sdkBuildCommand += "/p:SignType=real"
        }
        else {
            $sdkBuildCommand += "/p:SignType=test"
        }
        
        if ($BuildMSIPackages) {
            $sdkBuildCommand += "/p:BuildMsiInstallers=true"
        }
        
        if ($BuildNugetPackages) {
            $sdkBuildCommand += "/p:BuildNuGetPackages=true"
        }
        
        if ($BinlogPath) {
            $sdkCommand += "/bl:$BinlogPath.sdk"
        }
        
        $buildCommand += "`n" + ($sdkBuildCommand -join ' ')
    }

    return $buildCommand -join ' '
}

function Build-DotNet {
    [CmdletBinding()]
    param (
        # Basic configuration
        [Parameter(HelpMessage="Directory to install .NET")]
        [string]$InstallDir = "$env:USERPROFILE\sTBuild\dotnet\temp",
        
        [Parameter(HelpMessage="URL of the .NET runtime Git repository")]
        [string]$RuntimeRepoUrl = "https://github.com/dotnet/runtime.git",
        
        [Parameter(HelpMessage="URL of the .NET SDK Git repository")]
        [string]$SdkRepoUrl = "https://github.com/dotnet/sdk.git",
        
        [Parameter(HelpMessage="Build configuration (Debug, Release, RelWithDebInfo)")]
        [ValidateSet("Debug", "Release", "RelWithDebInfo")]
        [string]$Configuration = "Release",
        
        [Parameter(HelpMessage="Target architecture (x64, x86, arm, arm64)")]
        [ValidateSet("x64", "x86", "arm", "arm64")]
        [string]$Architecture = "x64",
        
        [Parameter(HelpMessage="Target operating system")]
        [ValidateSet("windows", "linux", "osx", "freeBSD", "android", "illumos", "solaris")]
        [string]$OS = "windows",

        # Component selection
        [Parameter(HelpMessage="Build .NET runtime")]
        [switch]$BuildRuntime = $true,
        
        [Parameter(HelpMessage="Build .NET SDK")]
        [switch]$BuildSdk = $false,
        
        [Parameter(HelpMessage="Build reference assemblies")]
        [switch]$BuildReferenceAssemblies = $false,
        
        [Parameter(HelpMessage="Build .NET Framework runtime")]
        [switch]$BuildNETFxRuntime = $false,
        
        [Parameter(HelpMessage="Build .NET Core runtime")]
        [switch]$BuildNETCoreRuntime = $true,
        
        [Parameter(HelpMessage="Build Mono runtime")]
        [switch]$BuildMono = $false,
        
        [Parameter(HelpMessage="Build MSI installers")]
        [switch]$BuildMSIPackages = $false,
        
        [Parameter(HelpMessage="Build NuGet packages")]
        [switch]$BuildNugetPackages = $true,
        
        # Build options
        [Parameter(HelpMessage="Number of parallel build jobs")]
        [int]$ParallelBuildJobs = $env:NUMBER_OF_PROCESSORS,
        
        [Parameter(HelpMessage="Skip running tests")]
        [switch]$SkipTests = $false,
        
        [Parameter(HelpMessage="Skip building portable binaries")]
        [switch]$SkipNonPortable = $false,
        
        [Parameter(HelpMessage="Disable SourceLink for debugging")]
        [switch]$DisableSourceLink = $false,
        
        [Parameter(HelpMessage="Use system libraries instead of bundled ones")]
        [switch]$UseSystemLibraries = $false,
        
        [Parameter(HelpMessage="Enable source build mode")]
        [switch]$EnableSourceBuild = $false,
        
        [Parameter(HelpMessage="Additional CMake arguments")]
        [string]$CmakeArgs = "",
        
        [Parameter(HelpMessage="Path to save build binary logs")]
        [string]$BinlogPath = "",
        
        # Advanced options
        [Parameter(HelpMessage="Enable Native AOT compilation")]
        [switch]$UseNativeAOT = $false,
        
        [Parameter(HelpMessage="Strip symbols from binaries to reduce size")]
        [switch]$StripSymbols = $false,
        
        [Parameter(HelpMessage="Enable code signing for official builds")]
        [switch]$EnableCodeSigning = $false,
        
        [Parameter(HelpMessage="Enable CrossGen for better startup performance")]
        [switch]$EnableCrossgen = $true
    )

    # Ensure script stops on any error
    $ErrorActionPreference = "Stop"

    # Get hash from installed version (if exists)
    if (Test-Path "$InstallDir\git-hash.txt") {
        $oldBuildHash = Get-Content "$InstallDir\git-hash.txt"
    } else {
        $oldBuildHash = ""
    }

    if (!(Test-Path "dotnet-hash.lock")) {
        $repoName = if ($BuildRuntime) { "runtime" } else { "sdk" }
        $repoUrl = if ($BuildRuntime) { $RuntimeRepoUrl } else { $SdkRepoUrl }

        # Check if repository directory exists
        if (Test-Path $repoName) {
            Write-Host -ForegroundColor Cyan "$repoName directory exists. Updating repository..."
            Set-Location $repoName
            
            # Get the current git commit hash before pull
            $oldHash = git rev-parse HEAD
            
            # Pull latest changes
            git pull
            git submodule update --init --recursive
            
            # Get the new git commit hash after pull
            $newHash = git rev-parse HEAD
            
            Set-Location ..
            
            # Check if git hash has changed
            $rebuildNeeded = $oldHash -ne $newHash
            
            if ($rebuildNeeded) {
                Write-Host -ForegroundColor Yellow "Git hash changed from $oldHash to $newHash. Rebuild required."
            } else {
                Write-Host -ForegroundColor Green "Git hash unchanged ($oldHash). No rebuild needed."
            }
        } else {
            Write-Host -ForegroundColor Cyan "Cloning $repoName repository..."
            git clone $repoUrl $repoName
            Set-Location $repoName
            git submodule update --init --recursive
            $newHash = git rev-parse HEAD
            Set-Location ..
            
            # New clone always needs a build
            $rebuildNeeded = $true
        }

        # Clean build if rebuild needed or old hash doesn't match
        if ($oldBuildHash -ne "" -and $oldBuildHash -ne $newHash) {
            Write-Host -ForegroundColor Cyan "Removing existing install directory from hash '$oldBuildHash' ..."
            Remove-Item -Recurse -Force $InstallDir -ErrorAction SilentlyContinue
        }

        Write-Host -ForegroundColor Cyan "Configuring the build..."
        
        # Create parameter hashtable for build command
        $buildParams = @{
            # Basic configuration
            BuildType = $BuildType
            Architecture = $Architecture
            Configuration = $Configuration
            OS = $OS
            
            # Component options
            BuildRuntime = $BuildRuntime
            BuildSdk = $BuildSdk
            BuildReferenceAssemblies = $BuildReferenceAssemblies
            BuildNETFxRuntime = $BuildNETFxRuntime
            BuildNETCoreRuntime = $BuildNETCoreRuntime
            BuildMono = $BuildMono
            BuildMSIPackages = $BuildMSIPackages
            BuildNugetPackages = $BuildNugetPackages

            # Build options
            ParallelBuildJobs = $ParallelBuildJobs
            SkipTests = $SkipTests
            SkipNonPortable = $SkipNonPortable
            DisableSourceLink = $DisableSourceLink
            UseSystemLibraries = $UseSystemLibraries
            EnableSourceBuild = $EnableSourceBuild
            CmakeArgs = $CmakeArgs
            
            # Additional options
            BinlogPath = $BinlogPath
            UseNativeAOT = $UseNativeAOT
            StripSymbols = $StripSymbols
            EnableCodeSigning = $EnableCodeSigning
            EnableCrossgen = $EnableCrossgen
        }
        
        # Generate build command
        $buildCommand = _Get-DotNetBuildCommand @buildParams

        if (Test-Path -Path "dotnet-build-command.txt") { Remove-Item -Path "dotnet-build-command.txt" -Force }
        Set-Content -Path "dotnet-build-command.txt" -Value $buildCommand
        
        Write-Host -ForegroundColor Cyan "Building .NET..."
        
        # Navigate to the appropriate repository directory
        Set-Location $repoName

        Write-Output "$newHash" > "..\dotnet-hash.lock"
        
        # Execute the build command
        Invoke-Expression $buildCommand
        
        Set-Location ..
        
        # Create install directory if it doesn't exist
        if (!(Test-Path $InstallDir)) {
            New-Item -ItemType Directory -Path $InstallDir -Force
        }
        
        # Copy build artifacts to install directory
        if ($BuildRuntime) {
            $artifactsDir = "runtime\artifacts\bin\coreclr\$OS.$Architecture.$Configuration"
            
            if (Test-Path $artifactsDir) {
                Write-Host -ForegroundColor Cyan "Copying build artifacts to install directory..."
                Copy-Item -Path "$artifactsDir\*" -Destination $InstallDir -Recurse -Force
            } else {
                Write-Host -ForegroundColor Yellow "Artifacts directory not found at: $artifactsDir"
            }
        }
        
        if ($BuildSdk) {
            $artifactsDir = "sdk\artifacts\bin\runtime\$OS-$Architecture\$Configuration"
            
            if (Test-Path $artifactsDir) {
                Write-Host -ForegroundColor Cyan "Copying SDK artifacts to install directory..."
                Copy-Item -Path "$artifactsDir\*" -Destination $InstallDir -Recurse -Force
            } else {
                Write-Host -ForegroundColor Yellow "SDK artifacts directory not found at: $artifactsDir"
            }
        }
        
        # Store the git hash for future reference
        Write-Output "$newHash" > "$InstallDir\git-hash.txt"
        
        Remove-Item -Force "dotnet-hash.lock" -ErrorAction SilentlyContinue
        
        Write-Host -ForegroundColor Green "Build completed successfully!"
    } else {
        Write-Host -ForegroundColor Yellow "Build already in progress (lock file exists). Skipping."
    }
}

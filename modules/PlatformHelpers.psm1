<#
.SYNOPSIS
    Cross-platform helper functions for sTBuild.
.DESCRIPTION
    Provides platform detection and utility functions to help sTBuild
    work consistently across Windows, Linux and macOS environments.
#>

# Platform detection
$script:IsWindows = $PSVersionTable.PSEdition -eq "Desktop" -or 
                   ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows)
$script:IsLinux = $PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux
$script:IsMacOS = $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS

# Path helpers
$script:HomeDir = if ($script:IsWindows) { $env:USERPROFILE } else { $env:HOME }
$script:PathSeparator = if ($script:IsWindows) { "\" } else { "/" }

# System information
$script:NumProcessors = if ($script:IsWindows) { 
    [int]$env:NUMBER_OF_PROCESSORS 
} elseif ($script:IsLinux -and (Get-Command nproc -ErrorAction SilentlyContinue)) {
    [int](nproc)
} elseif ($script:IsMacOS -and (Get-Command sysctl -ErrorAction SilentlyContinue)) {
    [int](sysctl -n hw.ncpu)
} else {
    4 # Default to 4 cores if we can't determine
}

function Get-PlatformInfo {
    <#
    .SYNOPSIS
        Returns platform information for the current system.
    .DESCRIPTION
        Provides detailed information about the current platform including
        OS type, version, paths, and system resources.
    #>
    [CmdletBinding()]
    param()

    $platformInfo = [PSCustomObject]@{
        IsWindows = $script:IsWindows
        IsLinux = $script:IsLinux
        IsMacOS = $script:IsMacOS
        HomeDirectory = $script:HomeDir
        PathSeparator = $script:PathSeparator
        NumberOfProcessors = $script:NumProcessors
        PowerShellVersion = $PSVersionTable.PSVersion.ToString()
        PowerShellEdition = $PSVersionTable.PSEdition
    }

    # Add OS-specific information
    if ($script:IsWindows) {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($osInfo) {
            $platformInfo | Add-Member -MemberType NoteProperty -Name "OSVersion" -Value $osInfo.Caption
            $platformInfo | Add-Member -MemberType NoteProperty -Name "OSArchitecture" -Value $osInfo.OSArchitecture
        }
    } 
    elseif ($script:IsLinux) {
        try {
            if (Test-Path "/etc/os-release") {
                $osRelease = Get-Content "/etc/os-release" | ConvertFrom-StringData
                $platformInfo | Add-Member -MemberType NoteProperty -Name "OSVersion" -Value $osRelease.PRETTY_NAME
            }
            
            if (Get-Command "uname" -ErrorAction SilentlyContinue) {
                $platformInfo | Add-Member -MemberType NoteProperty -Name "OSArchitecture" -Value (uname -m)
            }
        }
        catch {
            # Ignore errors in Linux detection
        }
    }
    elseif ($script:IsMacOS) {
        try {
            if (Get-Command "sw_vers" -ErrorAction SilentlyContinue) {
                $macOSVersion = sw_vers -productVersion
                $platformInfo | Add-Member -MemberType NoteProperty -Name "OSVersion" -Value "macOS $macOSVersion"
            }
            
            if (Get-Command "uname" -ErrorAction SilentlyContinue) {
                $platformInfo | Add-Member -MemberType NoteProperty -Name "OSArchitecture" -Value (uname -m)
            }
        }
        catch {
            # Ignore errors in macOS detection
        }
    }

    return $platformInfo
}

function Get-CrossPlatformPath {
    <#
    .SYNOPSIS
        Converts a path to the correct format for the current platform.
    .DESCRIPTION
        Ensures paths use the correct directory separator for the current OS.
    .PARAMETER Path
        The path to convert.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [string]$Path
    )
    
    process {
        if ($script:IsWindows) {
            return $Path.Replace('/', '\')
        } else {
            return $Path.Replace('\', '/')
        }
    }
}

function New-CrossPlatformSymlink {
    <#
    .SYNOPSIS
        Creates a symbolic link in a platform-independent way.
    .DESCRIPTION
        Creates symbolic links using the appropriate method for Windows, Linux or macOS.
    .PARAMETER Path
        The path where the symlink should be created.
    .PARAMETER Target
        The target that the symlink points to.
    .PARAMETER Type
        The type of symlink to create (File or Directory).
    #>
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
    elseif ($PSVersionTable.PSVersion.Major -ge 6) {
        # PowerShell 6+ has cross-platform New-Item -ItemType SymbolicLink
        try {
            New-Item -ItemType SymbolicLink -Path $Path -Target $Target -Force | Out-Null
        }
        catch {
            # Fallback to using ln -s
            $output = if ($script:IsLinux -or $script:IsMacOS) {
                & ln -s "$Target" "$Path" 2>&1
            }
            
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to create symbolic link: $output"
                return $false
            }
        }
    }
    else {
        # Old PowerShell on non-Windows, use ln directly
        $output = if ($script:IsLinux -or $script:IsMacOS) {
            & ln -s "$Target" "$Path" 2>&1
        }
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create symbolic link: $output"
            return $false
        }
    }
    
    return $true
}

# Export functions
Export-ModuleMember -Variable IsWindows, IsLinux, IsMacOS, HomeDir, PathSeparator, NumProcessors
Export-ModuleMember -Function Get-PlatformInfo, Get-CrossPlatformPath, New-CrossPlatformSymlink

<#
.SYNOPSIS
    Functions for working with GitVersion to generate semantic versioning.
.DESCRIPTION
    Provides functionality to integrate GitVersion with sTBuild, allowing
    automatic versioning based on Git history and tags.
#>

function Install-GitVersion {
    <#
    .SYNOPSIS
        Installs GitVersion if not already available.
    .DESCRIPTION
        Checks if GitVersion is installed and installs it if not found.
    .EXAMPLE
        Install-GitVersion
        Installs GitVersion if it's not already available.
    #>
    [CmdletBinding()]
    param()
    
    # Check if GitVersion is already installed
    $gitVersionInstalled = $null -ne (Get-Command "GitVersion.exe" -ErrorAction SilentlyContinue)
    
    if (-not $gitVersionInstalled) {
        Write-Verbose "GitVersion not found. Installing..."
        
        # Install GitVersion.Tool
        dotnet tool install --global GitVersion.Tool
        
        # Verify installation
        $gitVersionInstalled = $null -ne (Get-Command "dotnet-gitversion" -ErrorAction SilentlyContinue)
        
        if (-not $gitVersionInstalled) {
            throw "Failed to install GitVersion.Tool"
        }
        
        Write-Verbose "GitVersion installed successfully."
    }
    else {
        Write-Verbose "GitVersion is already installed."
    }
}

function Get-GitVersion {
    <#
    .SYNOPSIS
        Gets the current version using GitVersion.
    .DESCRIPTION
        Uses GitVersion to determine the current semantic version based on Git history and tags.
    .PARAMETER Path
        The path to the Git repository. Defaults to the current directory.
    .PARAMETER Format
        The format to return the version in. Valid values are Full, SemVer, and Simple.
    .EXAMPLE
        Get-GitVersion
        Returns the full GitVersion information as a PSObject.
    .EXAMPLE
        Get-GitVersion -Format SemVer
        Returns just the SemVer string.
    #>
    [CmdletBinding()]
    param (
        [string]$Path = $PWD,
        
        [ValidateSet('Full', 'SemVer', 'Simple')]
        [string]$Format = 'Full'
    )
    
    # Ensure GitVersion is installed
    Install-GitVersion
    
    # Store current location
    $originalLocation = Get-Location
    
    try {
        # Change to specified path
        Set-Location -Path $Path
        
        # Get GitVersion output
        $gitVersionCommand = Get-Command "dotnet-gitversion" -ErrorAction SilentlyContinue
        
        if ($null -ne $gitVersionCommand) {
            $gitVersionOutput = dotnet-gitversion /output json
        }
        else {
            $gitVersionOutput = GitVersion.exe /output json
        }
        
        # Parse JSON output
        $versionInfo = $gitVersionOutput | ConvertFrom-Json
        
        # Return version in requested format
        switch ($Format) {
            'SemVer' {
                return $versionInfo.SemVer
            }
            'Simple' {
                return $versionInfo.MajorMinorPatch
            }
            default {
                return $versionInfo
            }
        }
    }
    catch {
        Write-Error "Failed to get version using GitVersion: $_"
        return $null
    }
    finally {
        # Restore original location
        Set-Location -Path $originalLocation
    }
}

function Update-ModuleVersion {
    <#
    .SYNOPSIS
        Updates the module version in the module manifest using GitVersion.
    .DESCRIPTION
        Retrieves the version using GitVersion and updates the module manifest accordingly.
    .PARAMETER ManifestPath
        The path to the module manifest (.psd1) file.
    .EXAMPLE
        Update-ModuleVersion -ManifestPath .\sTBuild.psd1
        Updates the version in the specified module manifest.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$ManifestPath
    )
    
    # Ensure the manifest exists
    if (-not (Test-Path $ManifestPath)) {
        Write-Error "Module manifest not found at $ManifestPath"
        return $false
    }
    
    try {
        # Get current version from GitVersion
        $versionInfo = Get-GitVersion -Path (Split-Path -Parent $ManifestPath)
        $newVersion = $versionInfo.MajorMinorPatch
        
        # Read the module manifest
        $manifestContent = Get-Content -Path $ManifestPath -Raw
        
        # Update the ModuleVersion
        $updatedContent = $manifestContent -replace "ModuleVersion\s*=\s*['`"](\d+\.\d+\.\d+(\.\d+)?)['`"]", "ModuleVersion = '$newVersion'"
        
        # Add or update the PreRelease string if we're on a pre-release branch
        if ($versionInfo.PreReleaseTag) {
            if ($manifestContent -match "Prerelease\s*=\s*['`"]([^'`"]*)['`"]") {
                $updatedContent = $updatedContent -replace "Prerelease\s*=\s*['`"]([^'`"]*)['`"]", "Prerelease = '$($versionInfo.PreReleaseTag)'"
            }
            else {
                # Add PreRelease tag to PSData if it doesn't exist
                $updatedContent = $updatedContent -replace "(PSData\s*=\s*@\{)", "`$1`n        # Prerelease string of this module`n        Prerelease = '$($versionInfo.PreReleaseTag)'`n"
            }
        }
        
        # Write the updated content back to the manifest
        $updatedContent | Set-Content -Path $ManifestPath -NoNewline
        
        Write-Host "Updated module version to $newVersion$(if($versionInfo.PreReleaseTag){"-$($versionInfo.PreReleaseTag)"})"
        return $true
    }
    catch {
        Write-Error "Failed to update module version: $_"
        return $false
    }
}

# Export the public functions
Export-ModuleMember -Function Get-GitVersion, Update-ModuleVersion, Install-GitVersion

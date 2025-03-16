function Publish-STBuild {
    <#
    .SYNOPSIS
        Publishes the sTBuild module to the PowerShell Gallery.
    .DESCRIPTION
        Prepares and publishes the sTBuild module to the PowerShell Gallery,
        with automatic versioning using GitVersion or a manually specified version.
    .PARAMETER Path
        The path to the module directory. Defaults to the current directory.
    .PARAMETER Version
        Optional manual version override. If not specified, GitVersion will be used.
    .PARAMETER ApiKey
        The PowerShell Gallery API key. If not provided, the function will look for
        $PSGalleryApiKey in the environment.
    .PARAMETER WhatIf
        Shows what would happen without actually publishing the module.
    .EXAMPLE
        Publish-STBuild
        Publishes the module using GitVersion for versioning.
    .EXAMPLE
        Publish-STBuild -Version "1.2.3"
        Publishes the module with the specified version.
    .EXAMPLE
        Publish-STBuild -WhatIf
        Shows what would be published without actually publishing.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Path = ".",
        [string]$Version,
        [string]$ApiKey,
        [switch]$WhatIf
    )
    
    # Resolve the full path
    $modulePath = Resolve-Path $Path
    $manifestPath = Join-Path $modulePath "sTBuild.psd1"
    
    # Check if manifest exists
    if (-not (Test-Path $manifestPath)) {
        Write-Error "Module manifest not found at $manifestPath"
        return
    }
    
    try {
        # Check if we need to update the version
        if ([string]::IsNullOrEmpty($Version)) {
            # Use GitVersion
            Write-Verbose "Updating module version using GitVersion..."
            Update-ModuleVersion -ManifestPath $manifestPath
            
            # Read the updated version
            $moduleInfo = Import-PowerShellDataFile -Path $manifestPath
            $Version = $moduleInfo.ModuleVersion
            if ($moduleInfo.PrivateData.PSData.Prerelease) {
                $Version += "-" + $moduleInfo.PrivateData.PSData.Prerelease
            }
        }
        else {
            # Use manual version
            Write-Verbose "Setting manual version: $Version"
            $manifestContent = Get-Content -Path $manifestPath -Raw
            $updatedContent = $manifestContent -replace "ModuleVersion\s*=\s*['`"](\d+\.\d+\.\d+(\.\d+)?)['`"]", "ModuleVersion = '$Version'"
            $updatedContent | Set-Content -Path $manifestPath -NoNewline
        }
        
        # Find or prompt for API key
        if ([string]::IsNullOrEmpty($ApiKey)) {
            $ApiKey = $PSGalleryApiKey
            
            if ([string]::IsNullOrEmpty($ApiKey)) {
                $ApiKey = Read-Host "Enter PowerShell Gallery API Key" -AsSecureString | 
                          ConvertFrom-SecureString -AsPlainText
            }
        }
        
        if ([string]::IsNullOrEmpty($ApiKey)) {
            Write-Error "No API key provided. Use -ApiKey parameter or set `$PSGalleryApiKey variable."
            return
        }
        
        # Prepare for publishing
        if ($PSCmdlet.ShouldProcess("PowerShell Gallery", "Publish module sTBuild version $Version")) {
            Write-Host "Publishing module version $Version to PowerShell Gallery..." -ForegroundColor Cyan
            Publish-Module -Path $modulePath -NuGetApiKey $ApiKey -Verbose:($VerbosePreference -eq 'Continue')
            Write-Host "Module published successfully!" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to publish module: $_"
    }
}

# Export functions
Export-ModuleMember -Function Publish-STBuild

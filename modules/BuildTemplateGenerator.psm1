function New-BuildTemplate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$Repository,
        
        [Parameter()]
        [string]$Description,
        
        [Parameter()]
        [switch]$Interactive
    )
    
    if ($Interactive) {
        if (!$Description) {
            $Description = Read-Host "Enter description for $Name"
        }
        
        $buildScriptPath = Read-Host "Enter build script path (relative to scripts folder)"
        
        # For build function name, automatically format it according to the new schema
        $suggestedFunctionName = "sTBuild-$Name"
        $buildFunction = Read-Host "Enter build function name (suggested: $suggestedFunctionName)"
        if ([string]::IsNullOrWhiteSpace($buildFunction)) {
            $buildFunction = $suggestedFunctionName
        }
        
        $defaultConfig = @{}
        
        $addMore = $true
        while ($addMore) {
            $key = Read-Host "Enter configuration key (leave empty to finish)"
            if ([string]::IsNullOrWhiteSpace($key)) {
                $addMore = $false
                continue
            }
            
            $value = Read-Host "Enter value for $key"
            $defaultConfig[$key] = $value
            
            $addMore = (Read-Host "Add another configuration? (y/n)") -eq "y"
        }
        
        $schema = @{}
        Write-Host "Now define configuration schema (optional)"
        
        $addMore = (Read-Host "Add configuration schema? (y/n)") -eq "y"
        while ($addMore) {
            $key = Read-Host "Enter schema key (leave empty to finish)"
            if ([string]::IsNullOrWhiteSpace($key)) {
                $addMore = $false
                continue
            }
            
            $type = Read-Host "Enter type for $key (string, number, boolean)"
            
            $schemaEntry = @{
                type = $type
                description = Read-Host "Enter description for $key"
            }
            
            if ($type -eq "string") {
                $addEnum = (Read-Host "Add enum values? (y/n)") -eq "y"
                if ($addEnum) {
                    $enumValues = @()
                    $addMore2 = $true
                    while ($addMore2) {
                        $enumValue = Read-Host "Enter enum value (leave empty to finish)"
                        if ([string]::IsNullOrWhiteSpace($enumValue)) {
                            $addMore2 = $false
                            continue
                        }
                        $enumValues += $enumValue
                    }
                    $schemaEntry["enum"] = $enumValues
                }
            }
            
            $schema[$key] = $schemaEntry
            $addMore = (Read-Host "Add another schema entry? (y/n)") -eq "y"
        }
        
        $executablePatterns = @()
        Write-Host "Define executable patterns (e.g., *.exe, *.cmd)"
        $addMore = $true
        while ($addMore) {
            $pattern = Read-Host "Enter pattern (leave empty to finish)"
            if ([string]::IsNullOrWhiteSpace($pattern)) {
                $addMore = $false
                continue
            }
            $executablePatterns += $pattern
            
            $addMore = (Read-Host "Add another pattern? (y/n)") -eq "y"
        }
        
        if ($executablePatterns.Count -eq 0) {
            $executablePatterns = @("*.exe", "*.cmd", "*.bat")
        }
    }
    else {
        # Default values when not interactive
        $buildScriptPath = "buildscripts\$Name.ps1"
        $buildFunction = "sTBuild-$Name"
        $defaultConfig = @{}
        $schema = @{}
        $executablePatterns = @("*.exe", "*.cmd", "*.bat")
    }
    
    # Create the template
    $template = @{
        name = $Name
        description = $Description
        repository = $Repository
        buildScript = $buildScriptPath
        buildFunction = $buildFunction
        defaultConfiguration = $defaultConfig
        configurationSchema = $schema
        executablePatterns = $executablePatterns
    }
    
    # Write to file
    $templatePath = "$env:USERPROFILE\sTBuild\templates\$Name.json"
    
    # Create templates directory if it doesn't exist
    $templatesDir = Split-Path $templatePath -Parent
    if (!(Test-Path $templatesDir)) {
        New-Item -ItemType Directory -Path $templatesDir -Force | Out-Null
    }
    
    ConvertTo-Json $template -Depth 10 | Set-Content $templatePath
    
    Write-Host "Created build template for $Name at $templatePath"
}

Export-ModuleMember -Function 'New-BuildTemplate'

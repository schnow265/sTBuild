<#
.SYNOPSIS
    Functions for generating and accessing documentation for the sTBuild module.
.DESCRIPTION
    Provides functionality to extract help information from functions and create
    centralized documentation for the sTBuild module.
#>

function Get-STBuildHelp {
    <#
    .SYNOPSIS
        Displays help information for the sTBuild module.
    .DESCRIPTION
        Provides access to documentation for the sTBuild module, including
        general module information and help for specific functions.
    .PARAMETER Topic
        The specific topic or function name to get help for.
    .PARAMETER ListTopics
        Lists all available help topics.
    .EXAMPLE
        Get-STBuildHelp
        Shows general help for the sTBuild module.
    .EXAMPLE
        Get-STBuildHelp -Topic "Invoke-TemplateBuild"
        Shows help for the Invoke-TemplateBuild function.
    .EXAMPLE
        Get-STBuildHelp -ListTopics
        Lists all available help topics.
    #>
    [CmdletBinding(DefaultParameterSetName = "General")]
    param(
        [Parameter(ParameterSetName = "Specific", Position = 0)]
        [string]$Topic,
        
        [Parameter(ParameterSetName = "List")]
        [switch]$ListTopics
    )
    
    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $readmePath = Join-Path $moduleRoot "docs\README.md"
    
    if ($ListTopics) {
        # Get all exported functions
        $exportedFunctions = Get-Command -Module sTBuild
        $topics = @("General") + ($exportedFunctions | ForEach-Object { $_.Name })
        
        Write-Host "Available Help Topics:" -ForegroundColor Cyan
        foreach ($topic in $topics) {
            Write-Host " - $topic"
        }
        return
    }
    
    if ([string]::IsNullOrWhiteSpace($Topic)) {
        # Display general module help
        if (Test-Path $readmePath) {
            $readmeContent = Get-Content $readmePath -Raw
            Write-Host $readmeContent
        } else {
            Write-Host "sTBuild Module" -ForegroundColor Cyan
            Write-Host "A PowerShell module for building and managing software development tools."
            Write-Host "`nUse Get-STBuildHelp -ListTopics to see available topics."
        }
    } else {
        # Display help for specific function
        Get-Help $Topic -Detailed
    }
}

function Update-STBuildDocumentation {
    <#
    .SYNOPSIS
        Updates the documentation for the sTBuild module.
    .DESCRIPTION
        Generates updated documentation for all functions in the sTBuild module,
        including extracting help information and creating markdown files.
    .PARAMETER OutputPath
        Directory where documentation files will be created.
    .EXAMPLE
        Update-STBuildDocumentation
        Updates the documentation in the default location.
    .EXAMPLE
        Update-STBuildDocumentation -OutputPath "C:\temp\docs"
        Updates the documentation in the specified location.
    #>
    [CmdletBinding()]
    param(
        [string]$OutputPath = "$PSScriptRoot\..\docs"
    )
    
    # Ensure output directory exists
    if (!(Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    # Get all exported functions
    $exportedFunctions = Get-Command -Module sTBuild
    
    # Create index file
    $indexPath = Join-Path $OutputPath "function-index.md"
    "# sTBuild Function Reference`n" | Set-Content $indexPath
    "| Function | Synopsis |" | Add-Content $indexPath
    "|----------|----------|" | Add-Content $indexPath
    
    foreach ($function in $exportedFunctions) {
        $help = Get-Help $function.Name
        $synopsis = $help.Synopsis.Trim()
        
        # Add to index
        "| [$($function.Name)]($($function.Name).md) | $synopsis |" | Add-Content $indexPath
        
        # Create individual function doc
        $functionPath = Join-Path $OutputPath "$($function.Name).md"
        "# $($function.Name)`n" | Set-Content $functionPath
        
        if ($help.Synopsis) {
            "## Synopsis`n" | Add-Content $functionPath
            $help.Synopsis | Add-Content $functionPath
            "`n" | Add-Content $functionPath
        }
        
        if ($help.Description) {
            "## Description`n" | Add-Content $functionPath
            $help.Description.Text | Add-Content $functionPath
            "`n" | Add-Content $functionPath
        }
        
        if ($help.Parameters.Parameter) {
            "## Parameters`n" | Add-Content $functionPath
            foreach ($param in $help.Parameters.Parameter) {
                "### -$($param.Name)`n" | Add-Content $functionPath
                $param.Description.Text | Add-Content $functionPath
                
                if ($param.ParameterValue) {
                    "`nType: $($param.ParameterValue)`n" | Add-Content $functionPath
                }
                
                if ($param.Required -eq $true) {
                    "Required: Yes`n" | Add-Content $functionPath
                } else {
                    "Required: No`n" | Add-Content $functionPath
                }
                
                if ($param.DefaultValue) {
                    "Default value: $($param.DefaultValue)`n" | Add-Content $functionPath
                }
                
                "`n" | Add-Content $functionPath
            }
        }
        
        if ($help.Examples.Example) {
            "## Examples" | Add-Content $functionPath
            "" | Add-Content $functionPath
            
            foreach ($example in $help.Examples.Example) {
                "### $($example.Title -replace '^EXAMPLE', 'Example')" | Add-Content $functionPath
                "" | Add-Content $functionPath
                "```powershell" | Add-Content $functionPath
                $example.Code | Add-Content $functionPath
                "```\" | Add-Content $functionPath
                
                if ($example.Remarks) {
                    $example.Remarks.Text | Add-Content $functionPath
                }
                
                "" | Add-Content $functionPath
            }
        }
    }
    
    Write-Host "Documentation updated in $OutputPath" -ForegroundColor Green
}

Export-ModuleMember -Function Get-STBuildHelp, Update-STBuildDocumentation

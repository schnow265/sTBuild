# Platform detection
$script:IsWindows = $PSVersionTable.PSEdition -eq "Desktop" -or 
                   ($PSVersionTable.PSVersion.Major -ge 6 -and $IsWindows)
$script:IsLinux = $PSVersionTable.PSVersion.Major -ge 6 -and $IsLinux
$script:IsMacOS = $PSVersionTable.PSVersion.Major -ge 6 -and $IsMacOS

# Create an empty array to collect function names
$functionsToExport = @()

# First, import any supporting modules
$moduleFiles = Get-ChildItem -Path (Join-Path $PSScriptRoot "modules") -Filter "*.psm1" -ErrorAction SilentlyContinue
foreach ($module in $moduleFiles) {
    Write-Verbose "Importing module from $($module.FullName)"
    Import-Module $module.FullName -Force
    
    # Get public functions from the module to export
    $moduleFunctions = Get-Command -Module ($module.BaseName) | 
                       Where-Object { -not $_.Name.StartsWith('_') } | 
                       Select-Object -ExpandProperty Name
    $functionsToExport += $moduleFunctions
}

# Get all PS1 files in the Scripts folder
$scriptFiles = Get-ChildItem -Path (Join-Path $PSScriptRoot "scripts") -Filter "*.ps1" -Recurse

# Source each PS1 file and track functions
foreach ($script in $scriptFiles) {
    Write-Verbose "Importing functions from $($script.FullName)"
    
    # Get functions before dot-sourcing
    $existingFunctions = Get-ChildItem Function:\ | Select-Object -ExpandProperty Name
    
    # Dot-source the script
    . $script.FullName
    
    # Get functions after dot-sourcing, exclude private functions (starting with underscore)
    $newFunctions = Get-ChildItem Function:\ | 
                   Where-Object { 
                       $_.Name -notin $existingFunctions -and 
                       -not $_.Name.StartsWith('_')  # Exclude private functions
                   } | 
                   Select-Object -ExpandProperty Name
    
    # Add to export list
    $functionsToExport += $newFunctions
}

# Ensure we have unique function names
$functionsToExport = $functionsToExport | Select-Object -Unique

# Log the functions being exported
Write-Verbose "Exporting functions: $($functionsToExport -join ', ')"

# Export all collected functions (excluding private ones)
Export-ModuleMember -Function $functionsToExport

# Initialize module on load
if (-not $env:sTBuild_NO_INIT) {
    # Check if Initialize-BuildEnvironment exists and call it
    if (Get-Command Initialize-BuildEnvironment -ErrorAction SilentlyContinue) {
        Initialize-BuildEnvironment
    }
}
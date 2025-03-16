# Import the module
Import-Module "$PSScriptRoot\..\scripts\manager.ps1"

# 1. Create a custom build template
Register-BuildTemplate -Name "cmake-project" `
    -Repository "https://github.com/example/cmake-project.git" `
    -Description "Example CMake Project" `
    -BuildScript "buildscripts\cmake-generic.ps1" `
    -BuildFunction "Build-CMakeProject" `
    -DefaultConfiguration @{
    BuildType    = "Release"
    EnableTests  = $false
    ParallelJobs = 8
}

# 2. Build using a template with default configuration
Invoke-TemplateBuild -Software "llvm" -UseDefaults

# 3. Build using a template with custom configuration
Invoke-TemplateBuild -Software "dotnet" -Configuration @{
    Configuration = "Debug"
    Architecture  = "x64"
    SkipTests     = $true
}

# 4. List build history
Get-BuildHistory -Software "llvm"

# 5. Get active builds
Get-ActiveBuild -Software "dotnet"

# 6. Switch active build to a specific hash
Set-ActiveBuild -Software "llvm" -GitHash "abc123"

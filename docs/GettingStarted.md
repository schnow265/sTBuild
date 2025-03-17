# Getting Started with sTBuild

This guide will help you get started with the sTBuild PowerShell module, which automates building and managing development tools.

## Installation

1. Clone the repository or download the module files
2. Ensure the module is in your PowerShell module path
3. Import the module:

```powershell
Import-Module sTBuild
```

## Basic Usage

### Building Software with Templates

sTBuild uses templates to define how different software packages are built. To build software:

```powershell
# Build LLVM using the default configuration
Invoke-TemplateBuild -Software "llvm" -UseDefaults

# Build with custom configuration
Invoke-TemplateBuild -Software "llvm" -Configuration @{
    BuildType = "Debug"
    LLvmProjects = "clang;lld;compiler-rt"
    EnableAssertions = $true
}
```

### Managing Multiple Builds

You can build and maintain multiple versions of the same software:

```powershell
# View build history
Get-BuildHistory -Software "llvm"

# Switch to a specific build by its Git hash
Set-ActiveBuild -Software "llvm" -GitHash "abc123"
```

### Creating New Build Templates

You can create custom build templates for other software:

```powershell
New-BuildTemplate -Name "MyProject" -Repository "https://github.com/user/myproject.git" -Interactive
```

## Directory Structure

sTBuild creates and uses the following directory structure:

```
$env:USERPROFILE\sTBuild\
  ├── bin\            # Symlinks to built executables
  ├── llvm\           # LLVM builds
  │    ├── current\   # Symlink to active LLVM build
  │    └── abc123\    # Specific build by Git hash
  ├── dotnet\         # .NET builds
  └── templates\      # Build templates
```

## Next Steps

- Review the [Function Reference](./commands/index.md) for detailed command information
- Check out the [Example Scripts](../examples) for more usage patterns

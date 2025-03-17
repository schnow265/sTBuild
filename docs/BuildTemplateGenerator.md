# Build Template Generator

The BuildTemplateGenerator module provides functionality for creating new build templates to use with sTBuild.

## Overview

Build templates define how sTBuild builds and manages different software packages. The `New-BuildTemplate` function provides an easy way to create these templates, either interactively or programmatically.

## Functions

### New-BuildTemplate

Creates a new build template for use with sTBuild.

#### Syntax

```powershell
New-BuildTemplate 
    -Name <String> 
    -Repository <String> 
    [-Description <String>] 
    [-Interactive]
```

#### Parameters

- **Name** (Required): The name of the software package. This will be used as the template name.
- **Repository** (Required): The Git repository URL for the software.
- **Description** (Optional): A brief description of the software.
- **Interactive** (Switch): When specified, prompts for additional configuration interactively.

#### Examples

**Example 1: Create a simple template non-interactively**

```powershell
New-BuildTemplate -Name "MyProject" -Repository "https://github.com/user/myproject.git" -Description "My custom project"
```

**Example 2: Create a template interactively**

```powershell
New-BuildTemplate -Name "CustomCompiler" -Repository "https://github.com/user/compiler.git" -Interactive
```

## Template Structure

Templates are stored as JSON files in `$env:USERPROFILE\sTBuild\templates\` with the following structure:

```json
{
  "name": "example",
  "description": "Example Project",
  "repository": "https://github.com/example/repo.git",
  "buildScript": "buildscripts\\example.ps1",
  "buildFunction": "sTBuild-example",
  "defaultConfiguration": {
    "BuildType": "Release",
    "EnableTests": false
  },
  "configurationSchema": {
    "BuildType": {
      "type": "string",
      "enum": ["Debug", "Release", "RelWithDebInfo"],
      "description": "Build type"
    },
    "EnableTests": {
      "type": "boolean",
      "description": "Whether to build tests"
    }
  },
  "executablePatterns": ["*.exe", "*.cmd", "*.bat"]
}
```

## Interactive Template Creation

When using the `-Interactive` switch, you'll be prompted for:

1. **Description** (if not provided)
2. **Build script path** (relative to scripts folder)
3. **Build function name** (defaults to "sTBuild-[Name]")
4. **Default configuration** (key-value pairs)
5. **Configuration schema** (property definitions)
6. **Executable patterns** (for symlinking)

## Best Practices

- Use standardized function names (sTBuild-[Name]) for consistency
- Include detailed schema information to help users understand configuration options
- Keep repository URLs updated
- Document any special build requirements in the description
- Use interactive mode when first creating templates to ensure all fields are properly populated

## See Also

- [Get-BuildTemplate](./commands/Get-BuildTemplate.md) - View existing build templates
- [Invoke-TemplateBuild](./commands/Invoke-TemplateBuild.md) - Build software using templates
- [Example Build Templates](../examples/template-usage.ps1)

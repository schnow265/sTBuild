# sTBuild PowerShell Module

A comprehensive PowerShell module for building and managing software development tools and environments.

## Overview

sTBuild automates the process of building, managing, and switching between different versions of development tools such as LLVM, .NET, and more. It provides a template-based system for defining build configurations and a unified interface for managing multiple builds.

## Key Features

- Template-based build system
- Version management of built software
- Automatic symlinking of executables
- Build history tracking
- Cross-platform support

## Getting Started

```powershell
# Import the module
Import-Module sTBuild

# List available build templates
Get-BuildTemplate

# Build LLVM with default configuration
Invoke-TemplateBuild -Software "llvm" -UseDefaults

# View documentation
Get-STBuildHelp
```

## Available Commands

Run `Get-Command -Module sTBuild` to see all available commands, or `Get-STBuildHelp` for detailed documentation.

## Directory Structure

- `/scripts` - Core scripts and build functions
- `/scripts/buildscripts` - Individual build scripts for different software
- `/modules` - Supporting PowerShell modules
- `/templates` - Build templates (JSON format)
- `/docs` - Documentation
- `/examples` - Example usage scripts

BeforeAll {
    $modulePath = Split-Path -Parent $PSScriptRoot
    Import-Module -Name $modulePath -Force
}

Describe "sTBuild Module Tests" {
    Context "Module Loading" {
        It "Imports the module without errors" {
            { Get-Module sTBuild } | Should -Not -Throw
            Get-Module sTBuild | Should -Not -BeNullOrEmpty
        }

        It "Exports expected functions" {
            $expectedFunctions = @(
                "Register-Build",
                "Set-ActiveBuild",
                "Get-ActiveBuild",
                "Get-BuildHistory",
                "Update-BinarySymlinks",
                "Register-BuildTemplate",
                "Get-BuildTemplate",
                "Invoke-TemplateBuild"
            )

            foreach ($function in $expectedFunctions) {
                Get-Command -Module sTBuild -Name $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "function $function should be exported"
            }
        }
    }

    Context "Documentation Functions" {
        It "Exports documentation functions" {
            $docFunctions = @(
                "Get-STBuildHelp",
                "Update-STBuildDocumentation"
            )

            foreach ($function in $docFunctions) {
                Get-Command -Module sTBuild -Name $function -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty -Because "function $function should be exported"
            }
        }

        It "Documentation files exist" {
            Test-Path -Path "$modulePath\docs\README.md" | Should -BeTrue
            Test-Path -Path "$modulePath\docs\GettingStarted.md" | Should -BeTrue
        }
    }
}

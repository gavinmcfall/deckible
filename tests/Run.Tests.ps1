#Requires -Modules Pester

<#
.SYNOPSIS
    Pester tests for Bootible PowerShell modules

.DESCRIPTION
    Tests core functions without requiring actual installation operations.
    Run with: Invoke-Pester -Path ./tests/
#>

BeforeAll {
    # Import the shared helper functions from the lib directory
    # This ensures tests use the same code as production
    $helpersPath = Join-Path $PSScriptRoot "../config/rog-ally/lib/helpers.ps1"
    . $helpersPath
}

Describe "Merge-Configs" {
    It "Merges simple values" {
        $base = @{ a = 1; b = 2 }
        $override = @{ b = 3; c = 4 }
        $result = Merge-Configs $base $override

        $result.a | Should -Be 1
        $result.b | Should -Be 3
        $result.c | Should -Be 4
    }

    It "Recursively merges nested hashtables" {
        $base = @{
            outer = @{
                a = 1
                b = 2
            }
        }
        $override = @{
            outer = @{
                b = 3
                c = 4
            }
        }
        $result = Merge-Configs $base $override

        $result.outer.a | Should -Be 1
        $result.outer.b | Should -Be 3
        $result.outer.c | Should -Be 4
    }

    It "Overwrites non-hashtable values completely" {
        $base = @{ list = @(1, 2, 3) }
        $override = @{ list = @(4, 5) }
        $result = Merge-Configs $base $override

        $result.list | Should -Be @(4, 5)
    }

    It "Handles empty override" {
        $base = @{ a = 1 }
        $override = @{}
        $result = Merge-Configs $base $override

        $result.a | Should -Be 1
    }
}

Describe "Get-ConfigValue" {
    BeforeAll {
        $script:TestConfig = @{
            simple = "value"
            nested = @{
                level1 = @{
                    level2 = "deep"
                }
                other = 42
            }
            boolean = $true
        }
    }

    It "Gets simple values" {
        Get-ConfigValue -Config $script:TestConfig -Key "simple" | Should -Be "value"
    }

    It "Gets nested values with dot notation" {
        Get-ConfigValue -Config $script:TestConfig -Key "nested.level1.level2" | Should -Be "deep"
    }

    It "Returns default for missing keys" {
        Get-ConfigValue -Config $script:TestConfig -Key "missing" -Default "fallback" | Should -Be "fallback"
    }

    It "Returns default for missing nested keys" {
        Get-ConfigValue -Config $script:TestConfig -Key "nested.missing.deep" -Default 0 | Should -Be 0
    }

    It "Gets boolean values correctly" {
        Get-ConfigValue -Config $script:TestConfig -Key "boolean" | Should -Be $true
    }
}

Describe "Convert-OrderedDictToHashtable" {
    It "Converts simple OrderedDictionary" {
        $ordered = [ordered]@{ a = 1; b = 2 }
        $result = Convert-OrderedDictToHashtable $ordered

        $result | Should -BeOfType [hashtable]
        $result.a | Should -Be 1
        $result.b | Should -Be 2
    }

    It "Recursively converts nested OrderedDictionary" {
        $ordered = [ordered]@{
            outer = [ordered]@{
                inner = "value"
            }
        }
        $result = Convert-OrderedDictToHashtable $ordered

        $result.outer | Should -BeOfType [hashtable]
        $result.outer.inner | Should -Be "value"
    }

    It "Handles arrays with OrderedDictionary elements" {
        $ordered = [ordered]@{
            list = @(
                [ordered]@{ name = "first" },
                [ordered]@{ name = "second" }
            )
        }
        $result = Convert-OrderedDictToHashtable $ordered

        $result.list[0] | Should -BeOfType [hashtable]
        $result.list[0].name | Should -Be "first"
        $result.list[1].name | Should -Be "second"
    }
}

Describe "PowerShell Script Syntax" {
    It "Run.ps1 has valid syntax" {
        $script = "$PSScriptRoot/../config/rog-ally/Run.ps1"
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It "All module files have valid syntax" {
        $modules = Get-ChildItem -Path "$PSScriptRoot/../config/rog-ally/modules/*.ps1"
        foreach ($module in $modules) {
            $errors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseFile($module.FullName, [ref]$null, [ref]$errors)
            if ($errors.Count -gt 0) {
                $errorMsg = $errors | ForEach-Object { "Line $($_.Extent.StartLineNumber): $($_.Message)" }
                $errors.Count | Should -Be 0 -Because "Module $($module.Name) has syntax errors: $($errorMsg -join '; ')"
            }
        }
    }

    It "ally.ps1 has valid syntax" {
        $script = "$PSScriptRoot/../targets/ally.ps1"
        $errors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }
}

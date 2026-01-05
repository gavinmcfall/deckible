#Requires -Modules Pester

BeforeAll {
    # Import the main script containing Install-WingetPackage
    $runScriptPath = Join-Path $PSScriptRoot "../config/rog-ally/Run.ps1"
    . $runScriptPath

    # Ensure helper functions are available
    $helpersPath = Join-Path $PSScriptRoot "../config/rog-ally/lib/helpers.ps1"
    . $helpersPath
}

Describe "Install-WingetPackage" {
    BeforeEach {
        # Reset script-scoped variables before each test
        $Script:DryRun = $false
        $Script:HasWingetSource = $true
        $Script:HasMsStoreSource = $true

        # Clear any previous mocks to ensure isolation
        Mock | Remove-Mock

        # Mock JSON logging functions for all tests
        Mock -CommandName Add-JsonLogEntry -MockWith { }
        Mock -CommandName Get-CurrentModuleName -MockWith { "apps" }
    }

    It "Installs a package successfully from winget source" {
        Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith {
            "" # Not installed
        }
        Mock -CommandName Start-Job -MockWith { [PSCustomObject]@{ Id = 1; State = 'Running' } }
        Mock -CommandName Wait-Job -MockWith { $true }
        Mock -CommandName Receive-Job -MockWith { @{ ExitCode = 0; Output = "Success" } }
        Mock -CommandName Remove-Job

        $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"
        $result | Should -Be $true
        Assert-MockCalled winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -Times 1
        Assert-MockCalled Start-Job -Times 1
        Assert-MockCalled Add-JsonLogEntry -ParameterFilter { $Result -eq "success" } -Times 1
    }

    It "Skips installation if package is already installed" {
        Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith {
            "Test.Package" # Installed
        }
        $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"
        $result | Should -Be $true
        Assert-MockCalled winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -Times 1
        Assert-MockCalled Start-Job -Times 0 # Should not attempt install
        Assert-MockCalled Add-JsonLogEntry -ParameterFilter { $Result -eq "skipped" } -Times 1
    }

    It "Fails installation if winget source fails and no msstore fallback" {
        $Script:HasMsStoreSource = $false # Disable msstore fallback
        Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith { "" }
        Mock -CommandName Start-Job -MockWith { [PSCustomObject]@{ Id = 1; State = 'Running' } }
        Mock -CommandName Wait-Job -MockWith { $true }
        Mock -CommandName Receive-Job -MockWith { @{ ExitCode = 1; Output = "Failure" } }
        Mock -CommandName Remove-Job

        $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"
        $result | Should -Be $false
        Assert-MockCalled Start-Job -Times 1
        Assert-MockCalled Add-JsonLogEntry -ParameterFilter { $Result -eq "failed" } -Times 1
    }

    It "Installs a package successfully from msstore fallback if winget source fails" {
        Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith { "" }
        Mock -CommandName Start-Job -MockWith {
            param($ScriptBlock, $ArgumentList)
            if ($ArgumentList[1] -eq "winget") {
                return [PSCustomObject]@{ Id = 1; State = 'Running' }
            } else { # msstore
                return [PSCustomObject]@{ Id = 2; State = 'Running' }
            }
        }
        Mock -CommandName Wait-Job -MockWith { $true }
        Mock -CommandName Receive-Job -MockWith {
            param($Job)
            if ($Job.Id -eq 1) {
                return @{ ExitCode = 1; Output = "Winget failed" }
            } else {
                return @{ ExitCode = 0; Output = "MsStore success" }
            }
        }
        Mock -CommandName Remove-Job

        $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"
        $result | Should -Be $true
        Assert-MockCalled Start-Job -Times 2 # Once for winget, once for msstore
        Assert-MockCalled Add-JsonLogEntry -ParameterFilter { $Result -eq "success" } -Times 1
    }

    It "Fails installation if both winget and msstore sources fail" {
        Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith { "" }
        Mock -CommandName Start-Job -MockWith { [PSCustomObject]@{ Id = 1; State = 'Running' } }
        Mock -CommandName Wait-Job -MockWith { $true }
        Mock -CommandName Receive-Job -MockWith { @{ ExitCode = 1; Output = "Failure" } }
        Mock -CommandName Remove-Job

        $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"
        $result | Should -Be $false
        Assert-MockCalled Start-Job -Times 2
        Assert-MockCalled Add-JsonLogEntry -ParameterFilter { $Result -eq "failed" } -Times 1
    }

    Context "Dry Run Scenarios" {
        BeforeEach {
            $Script:DryRun = $true
        }

        It "Reports package found in winget source during dry run" {
            Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith { "" }
            Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "show --id Test.Package --source winget --accept-source-agreements" } -MockWith {
                $script:LASTEXITCODE = 0
                "Found Test.Package"
            }
            Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "show --id Test.Package --source msstore --accept-source-agreements" } -Times 0

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"
            $result | Should -Be $true
            Assert-MockCalled winget -ParameterFilter { $_.Arguments -eq "show --id Test.Package --source winget --accept-source-agreements" } -Times 1
            Assert-MockCalled Start-Job -Times 0 # No install in dry run
            Assert-MockCalled Add-JsonLogEntry -ParameterFilter { $Result -eq "dry_run" } -Times 1
        }

        It "Reports package found in msstore fallback during dry run" {
            Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith { "" }
            Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "show --id Test.Package --source winget --accept-source-agreements" } -MockWith {
                $script:LASTEXITCODE = 1
                "Not Found"
            }
            Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "show --id Test.Package --source msstore --accept-source-agreements" } -MockWith {
                $script:LASTEXITCODE = 0
                "Found Test.Package"
            }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"
            $result | Should -Be $true
            Assert-MockCalled winget -ParameterFilter { $_.Arguments -eq "show --id Test.Package --source winget --accept-source-agreements" } -Times 1
            Assert-MockCalled winget -ParameterFilter { $_.Arguments -eq "show --id Test.Package --source msstore --accept-source-agreements" } -Times 1
            Assert-MockCalled Add-JsonLogEntry -ParameterFilter { $Result -eq "dry_run" } -Times 1
        }

        It "Reports package not found during dry run" {
            Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith { "" }
            Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "show --id Test.Package --source winget --accept-source-agreements" } -MockWith {
                $script:LASTEXITCODE = 1
                "Not Found"
            }
            Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "show --id Test.Package --source msstore --accept-source-agreements" } -MockWith {
                $script:LASTEXITCODE = 1
                "Not Found"
            }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"
            $result | Should -Be $false
            Assert-MockCalled winget -ParameterFilter { $_.Arguments -eq "show --id Test.Package --source winget --accept-source-agreements" } -Times 1
            Assert-MockCalled winget -ParameterFilter { $_.Arguments -eq "show --id Test.Package --source msstore --accept-source-agreements" } -Times 1
            Assert-MockCalled Add-JsonLogEntry -ParameterFilter { $Result -eq "not_found" } -Times 1
        }
    }

    It "Installs successfully even if initial winget list check fails" {
        Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith {
            $script:LASTEXITCODE = 1
            "Error: winget list failed"
        }
        Mock -CommandName Start-Job -MockWith { [PSCustomObject]@{ Id = 1; State = 'Running' } }
        Mock -CommandName Wait-Job -MockWith { $true }
        Mock -CommandName Receive-Job -MockWith { @{ ExitCode = 0; Output = "Success" } }
        Mock -CommandName Remove-Job

        $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"
        $result | Should -Be $true
        Assert-MockCalled Start-Job -Times 1
    }

    It "Returns false on timeout during installation from winget source" {
        Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith { "" }
        Mock -CommandName Start-Job -MockWith { [PSCustomObject]@{ Id = 1; State = 'Running' } }
        Mock -CommandName Wait-Job -ParameterFilter { $Timeout -eq 5 } -MockWith { $null }
        Mock -CommandName Stop-Job
        Mock -CommandName Remove-Job
        Mock -CommandName Get-Process

        $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package" -TimeoutSeconds 5
        $result | Should -Be $false
        Assert-MockCalled Start-Job -Times 1
        Assert-MockCalled Wait-Job -Times 1
        Assert-MockCalled Stop-Job -Times 1
        Assert-MockCalled Remove-Job -Times 1
        # It should try msstore after timeout
        Assert-MockCalled Start-Job -Times 2
    }

    It "Returns false on timeout during msstore fallback" {
        Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith { "" }
        Mock -CommandName Start-Job -MockWith {
            param($ScriptBlock, $ArgumentList)
            if ($ArgumentList[1] -eq "winget") { return [PSCustomObject]@{ Id = 1; State = 'Running' } }
            if ($ArgumentList[1] -eq "msstore") { return [PSCustomObject]@{ Id = 2; State = 'Running' } }
        }
        Mock -CommandName Wait-Job -MockWith {
            param($Job, $Timeout)
            if ($Job.Id -eq 1) { return $true } # Winget succeeds, but job fails
            if ($Job.Id -eq 2) { return $null } # msstore times out
        }
        Mock -CommandName Receive-Job -MockWith {
             param($Job)
            if ($Job.Id -eq 1) { return @{ ExitCode = 1; Output = "Winget failed" } }
        }
        Mock -CommandName Stop-Job
        Mock -CommandName Remove-Job
        Mock -CommandName Get-Process

        $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package" -TimeoutSeconds 5
        $result | Should -Be $false
        Assert-MockCalled Start-Job -Times 2
        Assert-MockCalled Wait-Job -Times 2
        Assert-MockCalled Stop-Job -Times 1
        Assert-MockCalled Add-JsonLogEntry -ParameterFilter { $Result -eq "failed" } -Times 1
    }

    It "Succeeds with msstore when winget list fails and winget install fails" {
        Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith {
            $script:LASTEXITCODE = 1
        }
        Mock -CommandName Start-Job -MockWith {
            param($ScriptBlock, $ArgumentList)
            if ($ArgumentList[1] -eq "winget") { return [PSCustomObject]@{ Id = 1; State = 'Running' } }
            else { return [PSCustomObject]@{ Id = 2; State = 'Running' } }
        }
        Mock -CommandName Wait-Job -MockWith { $true }
        Mock -CommandName Receive-Job -MockWith {
            param($Job)
            if ($Job.Id -eq 1) { return @{ ExitCode = 1; Output = "Winget failed" } }
            else { return @{ ExitCode = 0; Output = "MsStore success" } }
        }
        Mock -CommandName Remove-Job

        $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"
        $result | Should -Be $true
        Assert-MockCalled Start-Job -Times 2
        Assert-MockCalled Add-JsonLogEntry -ParameterFilter { $Result -eq "success" } -Times 1
    }

    It "Installs from msstore if winget source is unavailable" {
        $Script:HasWingetSource = $false
        Mock -CommandName winget -ParameterFilter { $_.Arguments -eq "list --id Test.Package --accept-source-agreements" } -MockWith { "" }
        Mock -CommandName Start-Job -MockWith { [PSCustomObject]@{ Id = 1; State = 'Running' } }
        Mock -CommandName Wait-Job -MockWith { $true }
        Mock -CommandName Receive-Job -MockWith { @{ ExitCode = 0; Output = "Success" } }
        Mock -CommandName Remove-Job

        $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"
        $result | Should -Be $true
        Assert-MockCalled Start-Job -Times 1
        Assert-MockCalled Add-JsonLogEntry -ParameterFilter { $Result -eq "success" } -Times 1
    }
}

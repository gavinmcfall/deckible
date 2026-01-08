#Requires -Modules Pester

BeforeAll {
    # Import the extracted helper containing Install-WingetPackage
    # This avoids executing the full Run.ps1 setup script
    $helpersPath = Join-Path $PSScriptRoot "../config/rog-ally/lib/winget-helpers.ps1"
    . $helpersPath
}

Describe "Install-WingetPackage" {
    BeforeEach {
        # Reset script-scoped variables before each test
        $Script:DryRun = $false
        $Script:HasWingetSource = $true
        $Script:HasMsStoreSource = $true
        $Script:JsonLogEnabled = $true
        $Script:JsonLogEntries = @()
    }

    Context "Package Already Installed" {
        It "Skips installation if package is already installed" {
            Mock winget {
                return "Test.Package  1.0.0  winget"
            } -ParameterFilter { ($args -join ' ') -match 'list --id Test\.Package' }
            Mock Start-Job { [PSCustomObject]@{ Id = 1; State = 'Running' } }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"

            $result | Should -Be $true
            Should -Invoke winget -Times 1 -ParameterFilter { ($args -join ' ') -match 'list --id Test\.Package' }
            Should -Invoke Start-Job -Times 0
        }
    }

    Context "Successful Installation" {
        BeforeEach {
            Mock winget { return "" } -ParameterFilter { ($args -join ' ') -match 'list --id' }
        }

        It "Installs a package successfully from winget source" {
            Mock Start-Job { [PSCustomObject]@{ Id = 1; State = 'Running' } }
            Mock Wait-Job { $true }
            Mock Receive-Job { @{ ExitCode = 0; Output = "Successfully installed" } }
            Mock Remove-Job { }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"

            $result | Should -Be $true
            Should -Invoke Start-Job -Times 1
        }

        It "Falls back to msstore when winget source fails" {
            $script:jobCounter = 0
            Mock Start-Job {
                $script:jobCounter++
                [PSCustomObject]@{ Id = $script:jobCounter; State = 'Running' }
            }
            Mock Wait-Job { $true }
            Mock Receive-Job { @{ ExitCode = 1; Output = "Winget source failed" } } -ParameterFilter { $Id -eq 1 }
            Mock Receive-Job { @{ ExitCode = 0; Output = "msstore success" } } -ParameterFilter { $Id -eq 2 }
            Mock Remove-Job { }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"

            $result | Should -Be $true
            Should -Invoke Start-Job -Times 2
        }
    }

    Context "Failed Installation" {
        BeforeEach {
            Mock winget { return "" } -ParameterFilter { ($args -join ' ') -match 'list --id' }
        }

        It "Returns false when both sources fail" {
            Mock Start-Job { [PSCustomObject]@{ Id = 1; State = 'Running' } }
            Mock Wait-Job { $true }
            Mock Receive-Job { @{ ExitCode = 1; Output = "Installation failed" } }
            Mock Remove-Job { }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"

            $result | Should -Be $false
            Should -Invoke Start-Job -Times 2
        }

        It "Returns false when msstore is disabled and winget fails" {
            $Script:HasMsStoreSource = $false

            Mock Start-Job { [PSCustomObject]@{ Id = 1; State = 'Running' } }
            Mock Wait-Job { $true }
            Mock Receive-Job { @{ ExitCode = 1; Output = "Winget failed" } }
            Mock Remove-Job { }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"

            $result | Should -Be $false
            Should -Invoke Start-Job -Times 1
        }
    }

    Context "Timeout Handling" {
        BeforeEach {
            Mock winget { return "" } -ParameterFilter { ($args -join ' ') -match 'list --id' }
        }

        It "Returns false on timeout during winget installation" {
            Mock Start-Job { [PSCustomObject]@{ Id = 1; State = 'Running' } }
            Mock Wait-Job { $null }  # null indicates timeout
            Mock Stop-Job { }
            Mock Remove-Job { }
            Mock Get-Process { }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package" -TimeoutSeconds 5

            $result | Should -Be $false
            Should -Invoke Stop-Job -Times 2  # Once per source
        }
    }

    Context "Dry Run Mode" {
        BeforeEach {
            $Script:DryRun = $true
            Mock winget { return "" } -ParameterFilter { ($args -join ' ') -match 'list --id' }
        }

        It "Reports package found in winget source during dry run" {
            Mock winget {
                $global:LASTEXITCODE = 0
                return "Found Test.Package"
            } -ParameterFilter { ($args -join ' ') -match 'show --id.*--source winget' }
            Mock Start-Job { [PSCustomObject]@{ Id = 1; State = 'Running' } }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"

            $result | Should -Be $true
            Should -Invoke winget -Times 1 -ParameterFilter { ($args -join ' ') -match 'show --id.*--source winget' }
            Should -Invoke Start-Job -Times 0
        }

        It "Reports package found in msstore during dry run when winget fails" {
            Mock winget {
                $global:LASTEXITCODE = 1
                return "No package found"
            } -ParameterFilter { ($args -join ' ') -match 'show --id.*--source winget' }

            Mock winget {
                $global:LASTEXITCODE = 0
                return "Found Test.Package"
            } -ParameterFilter { ($args -join ' ') -match 'show --id.*--source msstore' }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"

            $result | Should -Be $true
            Should -Invoke winget -Times 1 -ParameterFilter { ($args -join ' ') -match 'show --id.*--source msstore' }
        }

        It "Reports package not found during dry run" {
            Mock winget {
                $global:LASTEXITCODE = 1
                return "No package found"
            } -ParameterFilter { ($args -join ' ') -match 'show --id' }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"

            $result | Should -Be $false
        }
    }

    Context "Source Availability" {
        BeforeEach {
            Mock winget { return "" } -ParameterFilter { ($args -join ' ') -match 'list --id' }
        }

        It "Uses msstore directly when winget source is unavailable" {
            $Script:HasWingetSource = $false

            Mock Start-Job { [PSCustomObject]@{ Id = 1; State = 'Running' } }
            Mock Wait-Job { $true }
            Mock Receive-Job { @{ ExitCode = 0; Output = "Success" } }
            Mock Remove-Job { }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"

            $result | Should -Be $true
            Should -Invoke Start-Job -Times 1
        }
    }

    Context "Error Handling" {
        It "Continues installation even if winget list check fails" {
            Mock winget {
                throw "winget list error"
            } -ParameterFilter { ($args -join ' ') -match 'list --id' }

            Mock Start-Job { [PSCustomObject]@{ Id = 1; State = 'Running' } }
            Mock Wait-Job { $true }
            Mock Receive-Job { @{ ExitCode = 0; Output = "Success" } }
            Mock Remove-Job { }

            $result = Install-WingetPackage -PackageId "Test.Package" -Name "Test Package"

            $result | Should -Be $true
            Should -Invoke Start-Job -Times 1
        }
    }
}

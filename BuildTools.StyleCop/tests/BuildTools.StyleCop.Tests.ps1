TestScope "BuildTools.StyleCop" {

    Enable-Mock | iex
    Import-Module $testscriptpath\..\tools\StyleCop.psm1 -Force
    Import-Module $testscriptpath\..\..\BuildTools.MsBuild\BuildTools.MsBuild.psm1 -Force

    $projectFile = "$testscriptpath\Scratch.csproj"

    function New-TestProject {
        # create a temporary project
        $tempFile = New-TestFile
        Copy-Item $projectFile -Destination $tempFile

        return Get-MsBuildProject $tempFile
    }

    function Get-TestProjectContent {
        param (
            $testProject
        )

        $testProject.Save()
        return [xml](Get-Content $tempProject.FullPath)
    }

    Describing "Install-StyleCop" {
        Given "a project" {
            $tempProject = New-TestProject

            It "adds the build import and target" {
                Install-StyleCop $tempProject -Quiet

                $xml = Get-TestProjectContent $tempProject
                $xml.Project.Import |? Project -match 'StyleCop' | Should Count 1
                $targets = $xml.Project.Target |? Name -match 'StyleCop'
                $targets | Should Count 1
                $targets.BeforeTargets | Should Be 'BeforeBuild'
                $targets.Error | Should Count 1
                $targets.Error.Text | Should Match 'BuildTools.StyleCop' And | Should Match 'restorepackages'
            }

            It "enables StyleCop for Release only" {
                Install-StyleCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopEnabled -Configuration Release |% Value | Should Count 1 And | Should Be 'True'
                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopEnabled -Configuration Debug |% Value | Should Count 1 And | Should Be 'False'
            }

            It "sets Errors as Errors" {
                Install-StyleCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopTreatErrorsAsWarnings -Configuration Release |% Value | Should Count 1 And | Should Be 'False'
                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopTreatErrorsAsWarnings -Configuration Debug |% Value | Should Count 0
            }

            It "enables code analysis" {
                Install-StyleCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name DefineConstants -Configuration Release |% Value | Should Count 1 And | Should Match 'CODE_ANALYSIS'
                Get-MsBuildConfigurationProperty $tempProject -Name DefineConstants -Configuration Debug |% Value | Should Count 1 And | Should Not Match 'CODE_ANALYSIS'
            }
        }

        Given "a project with stylecop installed" {
            $tempProject = New-TestProject
            Install-StyleCop $tempProject -Quiet

            It "does not overwrite configuration values" {
                Enable-StyleCop $tempProject -Quiet
                Set-StyleCopErrorsAs Warnings $tempProject -Quiet
                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopEnabled | Should Count 2

                Install-StyleCop $tempProject -Quiet
                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopEnabled | Should Count 2
                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopTreatErrorsAsWarnings |? Value -eq True | Should Count 2
            }
        }
    }

    Describing "Uninstall-StyleCop" {
        Given "a project with StyleCop installed" {
            $tempProject = New-TestProject
            Install-StyleCop $tempProject -Quiet

            It "removes the build import and target" {
                UnInstall-StyleCop $tempProject -Quiet

                $xml = Get-TestProjectContent $tempProject
                $xml.Project.Import |? Project -match 'StyleCop' | Should Count 0
                $targets = $xml.Project.Target |? Name -match 'StyleCop'
                $targets | Should Count 0
            }

            It "does not remove the StyleCopEnabled property" {
                UnInstall-StyleCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopEnabled | Should Count 2
            }

            It "does not remove the StyleCopTreatErrorsAsWarnings property" {
                UnInstall-StyleCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopTreatErrorsAsWarnings | Should Count 1
            }

            It "does not remove the code analysis constant" {
                UnInstall-StyleCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name DefineConstants |% Value | Should Be 'DEBUG;TRACE','TRACE;CODE_ANALYSIS'
            }
        }
    }

    Describing "Enable-StyleCop" {
        Given "a project with StyleCop installed but disabled" {
            $tempProject = New-TestProject
            Install-StyleCop $tempProject -Quiet
            Disable-StyleCop $tempProject -Quiet
            Get-MsBuildConfigurationProperty $tempProject -Name StyleCopEnabled |? Value -eq True | Should Count 0

            It "enables StyleCop globally" {
                Enable-StyleCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopEnabled |? Value -eq True | Should Count 2
                Get-MsBuildConfigurationProperty $tempProject -Name DefineConstants |% Value | Should Count 2 And | Should Match 'CODE_ANALYSIS'
            }

            It "enables StyleCop individually" {
                Enable-StyleCop $tempProject -Configuration Release -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopEnabled |? Value -eq True | Should Count 1
                Get-MsBuildConfigurationProperty $tempProject -Name DefineConstants -Configuration Release |% Value | Should Count 1 And | Should Match 'CODE_ANALYSIS'
            }

            It "does not change error setting without parameter" {
                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopTreatErrorsAsWarnings |? Value -eq True | Should Count 0
                Enable-StyleCop $tempProject -Quiet
                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopTreatErrorsAsWarnings |? Value -eq True | Should Count 0
            }

            It "does change error setting with parameter" {
                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopTreatErrorsAsWarnings |? Value -eq True | Should Count 0
                Enable-StyleCop $tempProject -TreatErrorsAs warnings -Quiet
                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopTreatErrorsAsWarnings |? Value -eq True | Should Count 2
            }
        }
    }

    Describing "Disable-StyleCop" {
        Given "a project with StyleCop installed" {
            $tempProject = New-TestProject
            Install-StyleCop $tempProject -Quiet

            It "does not remove the build import and target" {
                Disable-StyleCop $tempProject -Quiet

                $xml = Get-TestProjectContent $tempProject
                $xml.Project.Import |? Project -match 'StyleCop' | Should Count 1
                $targets = $xml.Project.Target |? Name -match 'StyleCop'
                $targets | Should Count 1
            }

            It "sets the StyleCopEnabled property to false" {
                Disable-StyleCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopEnabled |% Value | Should Count 2 And | Should Be 'False','False'
            }

            It "removes the code analysis constant" {
                Disable-StyleCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name DefineConstants |% Value | Should Be 'DEBUG;TRACE','TRACE'
            }
        }
    }

    Describing "Set-StyleCopErrorsAs" {
        Given "a project with StyleCop installed" {
            $tempProject = New-TestProject
            Install-StyleCop $tempProject -Quiet
            Set-StyleCopErrorsAs Errors $tempProject -Quiet
            Get-MsBuildConfigurationProperty $tempProject -Name StyleCopTreatErrorsAsWarnings |? Value -eq False | Should Count 2

            It "changes the value globally" {
                Set-StyleCopErrorsAs Warnings $tempProject -Quiet
                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopTreatErrorsAsWarnings |? Value -eq True | Should Count 2
            }

            It "changes the value individually" {
                Set-StyleCopErrorsAs Warnings $tempProject -Configuration Release -Quiet
                Get-MsBuildConfigurationProperty $tempProject -Name StyleCopTreatErrorsAsWarnings |% Value | Should Count 2 And | Should Be 'False','True'
            }
        }
    }
}
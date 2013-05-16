TestScope "BuildTools.FxCop" {

    Enable-Mock | iex
    Import-Module $testscriptpath\..\tools\FxCop.psm1 -Force
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

    Describing "Install-FxCop" {
        Given "a project" {
            $tempProject = New-TestProject
            Install-FxCop $tempProject -Quiet

            It "installs global properties" {
  
                Get-MsBuildProperty $tempProject -Name BuildToolsFxCopVersion |% Value | Should Count 1 And | Should Not Be Empty
                Get-MsBuildConfigurationProperty $tempProject -Name CodeAnalysisRuleSet |% Value | Should Count 2 And | Should Be 'CodeAnalysisRules.ruleset','CodeAnalysisRules.ruleset'
            }

            It "enables for release only" {
                Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis -Configuration Release |% Value | Should Count 1 And | Should Be 'True'
                Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis -Configuration Debug |% Value | Should Count 1 And | Should Be 'False'

                Get-MsBuildConfigurationProperty $tempProject -Name CodeAnalysisTreatWarningsAsErrors -Configuration Release |% Value | Should Count 1 And | Should Be 'true'
            }

            It "enables code analysis" {
                Get-MsBuildConfigurationProperty $tempProject -Name DefineConstants -Configuration Release |% Value | Should Count 1 And | Should Match 'CODE_ANALYSIS'
                Get-MsBuildConfigurationProperty $tempProject -Name DefineConstants -Configuration Debug |% Value | Should Count 1 And | Should Not Match 'CODE_ANALYSIS'
            }                      
        }

        Given "a project with stylecop installed" {
            $tempProject = New-TestProject
            Install-FxCop $tempProject -Quiet

            It "does not overwrite configuration values" {
                Enable-FxCop $tempProject -Quiet
                Set-FxCopWarningsAs Warnings $tempProject -Quiet
                Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis | Should Count 2

                Install-FxCop $tempProject -Quiet
                Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis | Should Count 2
                Get-MsBuildConfigurationProperty $tempProject -Name CodeAnalysisTreatWarningsAsErrors |? Value -eq False | Should Count 2
            }
        }
    }

    Describing "Uninstall-FxCop" {
        Given "a project with FxCop installed" {
            $tempProject = New-TestProject
            Install-FxCop $tempProject -Quiet

            It "sets the RunCodeAnalysis property to false" {
                Uninstall-FxCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis |% Value | Should Count 2 And | Should Be 'false','false'
            }

            It "does not remove the CodeAnalysisTreatWarningsAsErrors property" {
                Uninstall-FxCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name CodeAnalysisTreatWarningsAsErrors | Should Count 2
            }

            It "does not remove the code analysis constant" {
                Uninstall-FxCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name DefineConstants |% Value | Should Be 'DEBUG;TRACE','TRACE'
            }

            It "saves the enabled state for restore" {
                Uninstall-FxCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysisRestore |% Value | Should Count 2 And | Should Be 'false','true'
            }
        }

        Given "a project with FxCop installed then uninstalled" {
            $tempProject = New-TestProject
            Install-FxCop $tempProject -Quiet
            Enable-FxCop $tempProject -Quiet
            Uninstall-FxCop $tempProject -Quiet
            Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis |% Value | Should Count 2 And | Should Be 'false','false'
            Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysisRestore |% Value | Should Count 2 And | Should Be 'true','true'

            It "restores the previous state" {
                Install-FxCop $tempProject -Quiet

                Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis |% Value | Should Count 2 And | Should Be 'true','true'
            }
       }
    }

    Describing "Enable-FxCop" {
        Given "a project with FxCop installed but disabled" {
            $tempProject = New-TestProject
            Install-FxCop $tempProject -Quiet
            Disable-FxCop $tempProject -Quiet
            Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis |% Value | Should Count 2 And | Should Be 'false','false'

            It "can enable FxCop globally" {
                Enable-FxCop $tempProject -Quiet
                Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis |% Value | Should Count 2 And | Should Be 'true','true'
            }

            It "can enable FxCop singly" {
                Enable-FxCop $tempProject -Quiet -Configuration Debug
                Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis |% Value | Should Count 2 And | Should Be 'true','false'
            }

            It "can set warnings as errors" {
                Enable-FxCop $tempProject -Quiet -TreatWarningsAs Errors
                Get-MsBuildConfigurationProperty $tempProject -Name CodeAnalysisTreatWarningsAsErrors |% Value | Should Count 2 And | Should Be 'true','true'
            }
        }
    }

    Describing "Disable-FxCop" {
         Given "a project with FxCop installed and enabled" {
            $tempProject = New-TestProject
            Install-FxCop $tempProject -Quiet
            Enable-FxCop $tempProject -Quiet
            Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis |% Value | Should Count 2 And | Should Be 'true','true'

            It "can disable FxCop globally" {
                Disable-FxCop $tempProject -Quiet
                Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis |% Value | Should Count 2 And | Should Be 'false','false'
            }

            It "can disable FxCop singly" {
                Disable-FxCop $tempProject -Quiet -Configuration Debug
                Get-MsBuildConfigurationProperty $tempProject -Name RunCodeAnalysis |% Value | Should Count 2 And | Should Be 'false','true'
            }
        }
    }

    Describing "Set-FxCopWarningsAs" {
        Given "a project with StyleCop installed" {
            $tempProject = New-TestProject
            Install-StyleCop $tempProject -Quiet
            Set-FxCopWarningsAs Errors $tempProject -Quiet
            Get-MsBuildConfigurationProperty $tempProject -Name CodeAnalysisTreatWarningsAsErrors |? Value -eq True | Should Count 2

            It "changes the value globally" {
                Set-FxCopWarningsAs Warnings $tempProject -Quiet
                Get-MsBuildConfigurationProperty $tempProject -Name CodeAnalysisTreatWarningsAsErrors |? Value -eq False | Should Count 2
            }

            It "changes the value individually" {
                Set-FxCopWarningsAs Warnings $tempProject -Configuration Release -Quiet
                Get-MsBuildConfigurationProperty $tempProject -Name CodeAnalysisTreatWarningsAsErrors |% Value | Should Count 2 And | Should Be 'True','False'
            }
        }
    }
}
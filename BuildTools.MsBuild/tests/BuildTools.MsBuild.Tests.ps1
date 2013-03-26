TestScope "BuildTools.MsBuild" {

    Enable-Mock | iex
    Import-Module $testscriptpath\..\BuildTools.MsBuild.psm1 -Force

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

    Describing "Get-MsBuildProject" {
        Given "a project file" {
            It "returns a build file" {
                $project = Get-MsBuildProject $projectFile
                $project | Should Not Be Null
                $project.GetType().Name | Should Be 'Project'
            }

            It "returns the same object twice" {
                $project = Get-MsBuildProject $projectFile
                Get-MsBuildProject $project | Should Be $project
            }
        }

        Given "a build file" {
            $project = Get-MsBuildProject $projectFile
            $project.GetType().Name | Should Be 'Project'

            It "returns the same file" {
                Get-MsBuildProject $project | Should Be $project
            }
        }

        Given "null" {

            # our mock will return the project file
            Mock Get-Project { $projectFile }

            It "calls Get-Project" {
                $project = Get-MsBuildProject $null
                $project | Should Not Be Null
                $project.GetType().Name | Should Be 'Project'
                (Get-Mock Get-Project).Calls.Count | Should Count 1
            }
        }
    }

    Describing "Add-MsBuildImport" {
        Given "a project" {
            $tempProject = New-TestProject

            It "adds an import and target" {
                Add-MsBuildImport -Project $tempProject -ImportFile "$(Split-Path $tempProject.FullPath -Parent)\foo.targets" -PackageID 'Test.Package' -TestProperty 'TestProperty'

                $xml = Get-TestProjectContent $tempProject
                $xml.Project.Import |? Project -eq foo.targets | Should Count 1
            }

            It "creates a beforebuild target to check package restore" {
                Add-MsBuildImport -Project $tempProject -ImportFile "$(Split-Path $tempProject.FullPath -Parent)\foo.targets" -PackageID 'Test.Package' -TestProperty 'TestProperty'

                $xml = Get-TestProjectContent $tempProject
                $targets = $xml.Project.Target |? Name -eq 'foo_targets'
                $targets | Should Count 1
                $targets.BeforeTargets | Should Be 'BeforeBuild'
                $targets.Error | Should Count 1
                $targets.Error.Text | Should Match 'Test.Package' And | Should Match 'restorepackages'
            }

            It "does not create a beforebuild target when PackageID is not specified" {
                Add-MsBuildImport -Project $tempProject -ImportFile "$(Split-Path $tempProject.FullPath -Parent)\foo.targets"

                $xml = Get-TestProjectContent $tempProject
                $xml.Project.Target |? Name -eq 'foo_targets' | Should Count 0
            }

            It "requires both PackageID and TestProperty" {
                { Add-MsBuildImport -Project $tempProject -ImportFile "$(Split-Path $tempProject.FullPath -Parent)\foo.targets" -PackageID 'Test.Package' } | Should Throw
                { Add-MsBuildImport -Project $tempProject -ImportFile "$(Split-Path $tempProject.FullPath -Parent)\foo.targets" -TestProperty 'TestProperty' } | Should Throw
            }
        }

        Given "a project with an import" {
            $tempProject = New-TestProject

            Add-MsBuildImport -Project $tempProject -ImportFile "$(Split-Path $tempProject.FullPath -Parent)\foo.targets" -PackageID 'Test.Package' -TestProperty 'TestProperty'

            It "does not add it again" {
                Add-MsBuildImport -Project $tempProject -ImportFile "$(Split-Path $tempProject.FullPath -Parent)\foo.targets" -PackageID 'Test.Package' -TestProperty 'TestProperty'

                $xml = Get-TestProjectContent $tempProject
                $xml.Project.Import |? Project -eq foo.targets | Should Count 1
                $xml.Project.Target |? Name -eq 'foo_targets' | Should Count 1
            }
        }
    }

    Describing "Remove-MsBuildImport" {
        Given "a project with an import" {
            $tempProject = New-TestProject

            Add-MsBuildImport -Project $tempProject -ImportFile "$(Split-Path $tempProject.FullPath -Parent)\foo.targets" -PackageID 'Test.Package' -TestProperty 'TestProperty'

            It "removes the import and target" {
                Remove-MsBuildImport -Project $tempProject -ImportFile "$(Split-Path $tempProject.FullPath -Parent)\foo.targets" -PackageID 'Test.Package' -TestProperty 'TestProperty'

                $xml = Get-TestProjectContent $tempProject
                $xml.Project.Import |? Project -eq foo.targets | Should Count 0
                $xml.Project.Target |? Name -eq 'foo_targets' | Should Count 0
            }
        }

        Given "a project with no import" {
            $tempProject = New-TestProject

            It "does not fail" {
                Remove-MsBuildImport -Project $tempProject -ImportFile "$(Split-Path $tempProject.FullPath -Parent)\foo.targets" -PackageID 'Test.Package' -TestProperty 'TestProperty'

                $xml = Get-TestProjectContent $tempProject
                $xml.Project.Import |? Project -eq foo.targets | Should Count 0
                $xml.Project.Target |? Name -eq 'foo_targets' | Should Count 0
            }
        }
    }

    Describing "Get-MsBuildProperty" {
        Given "a standard project" {
            $tempProject = New-TestProject

            It "gets a property" {
                $prop = Get-MsBuildProperty -Project $tempProject -Name TargetFrameworkVersion
                $prop | Should Count 1
                $prop.Value | Should Be 'v4.5'
            }
        }
    }

    Describing "Set-MsBuildProperty" {
        Given "a standard project" {
            $tempProject = New-TestProject

            It "gets a global property" {
                Set-MsBuildProperty -Project $tempProject -Name Foo -Value Bar
                $prop = Get-MsBuildProperty -Project $tempProject -Name Foo
                $prop | Should Count 1
                $prop.Value | Should Be 'Bar'
            }
        }
    }

    Describing "Get-MsBuildConfiguration" {
        Given "a standard project" {
            $tempProject = New-TestProject

            It "finds both configurations" {
                $configs = Get-MsBuildConfiguration -Project $tempProject

                $configs | Should Count 2
                $configs.Condition | Should Contain ' ''$(Configuration)|$(Platform)'' == ''Debug|AnyCPU'' ' And |
                    Should Contain ' ''$(Configuration)|$(Platform)'' == ''Release|AnyCPU'' '
            }

            It "can select a configuration" {
                $configs = Get-MsBuildConfiguration -Project $tempProject -Configuration Release

                $configs | Should Count 1
                $configs.Condition | Should Not Contain ' ''$(Configuration)|$(Platform)'' == ''Debug|AnyCPU'' ' And |
                    Should Contain ' ''$(Configuration)|$(Platform)'' == ''Release|AnyCPU'' '
            }
        }
    }

    Describing "Get-MsBuildConfigurationProperty" {
        $tempProject = New-TestProject

        Given "a standard project" {
            It "finds matching properties" {
                $props = Get-MsBuildConfigurationProperty -Project $tempProject -Name 'DebugType'

                $props | Should Count 2
                $props.Value | Should Equal 'full','pdbonly'
            }

            It "selects a configuration" {
                $props = Get-MsBuildConfigurationProperty -Project $tempProject -Name 'DebugType' -Configuration Release

                $props | Should Count 1
                $props.Value | Should Equal 'pdbonly'
            }
        }
    }

    Describing "Set-MsBuildConfigurationProperty" {
        Given "a standard project" {
            $tempProject = New-TestProject

            It "sets a property across all configurations" {
                Set-MsBuildConfigurationProperty -Project $tempProject -Name 'DebugType' -Value 'nobugs'

                $props = Get-MsBuildConfigurationProperty -Project $tempProject -Name 'DebugType'
                $props | Should Count 2
                $props.Value | Should Equal 'nobugs','nobugs'
            }

            It "selects a configuration" {
                Set-MsBuildConfigurationProperty -Project $tempProject -Name 'DebugType' -Value 'nobugs' -Configuration Release

                $props = Get-MsBuildConfigurationProperty -Project $tempProject -Name 'DebugType' -Configuration Release
                $props | Should Count 1
                $props.Value | Should Contain 'nobugs'

                $props = Get-MsBuildConfigurationProperty -Project $tempProject -Name 'DebugType' -Configuration Debug
                $props | Should Count 1
                $props.Value | Should Contain 'full'
            }

            It "can add a new property globally" {
                Set-MsBuildConfigurationProperty -Project $tempProject -Name 'Foo' -Value 'Bar'

                $props = Get-MsBuildConfigurationProperty -Project $tempProject -Name 'Foo'
                $props | Should Count 2
                $props.Value | Should Equal 'Bar','Bar'
            }

            It "can add a new property individually" {
                Set-MsBuildConfigurationProperty -Project $tempProject -Name 'Foo' -Value 'Bar' -Configuration Release

                $props = Get-MsBuildConfigurationProperty -Project $tempProject -Name 'Foo' -Configuration Release
                $props | Should Count 1
                $props.Value | Should Equal 'Bar'

                $props = Get-MsBuildConfigurationProperty -Project $tempProject -Name 'Foo' -Configuration Debug
                $props | Should Count 0
            }
        }
    }

    Describing "Enable-CodeAnalysisConstant" {
        Given "a project with nothing" {
            $tempProject = New-TestProject

            It "adds code analysis" {
                Enable-CodeAnalysisConstant -Project $tempProject

                $props = Get-MsBuildConfigurationProperty -Project $tempProject -Name DefineConstants
                $props.Value | Should Match 'CODE_ANALYSIS'
            }

            It "doesn't re-add code analysis" {
                Enable-CodeAnalysisConstant -Project $tempProject
                Enable-CodeAnalysisConstant -Project $tempProject

                $props = Get-MsBuildConfigurationProperty -Project $tempProject -Name DefineConstants -Configuration Release
                $props | Should Count 1
                $props.Value | Should Match 'CODE_ANALYSIS'
                $props.Value |% { $_ -split ';' } |? { $_ -eq 'CODE_ANALYSIS' } | Should Count 1
            }
        }
    }

    Describing "Disable-CodeAnalysisContent" {
        Given "a project with code analysis" {
            $tempProject = New-TestProject
            Enable-CodeAnalysisConstant -Project $tempProject

            It "removes code analysis" {
                Disable-CodeAnalysisConstant -Project $tempProject

                Get-MsBuildConfigurationProperty -Project $tempProject -Name DefineConstants |? Value -match CODE_ANALYSIS | Should Count 0
            }
        }

        Given "a project with code analysis and FxCop" {
            $tempProject = New-TestProject
            Enable-CodeAnalysisConstant -Project $tempProject
            Set-MsBuildConfigurationProperty -Project $tempProject -Name RunCodeAnalysis -Value true

            It "does not remove code analysis" {
                Disable-CodeAnalysisConstant -Project $tempProject

                $props = Get-MsBuildConfigurationProperty -Project $tempProject -Name DefineConstants |? Value -match CODE_ANALYSIS
                $props.Name | Should Count 2
            }
        }
    }
}
$psake.use_exit_on_error = $true

#########################################
# to build a new version
# 1. git tag 1.0.x
# 2. build package
#########################################

properties {
    $baseDir = $psake.build_script_dir
    $changeset = (git log -1 --pretty=format:%H)
}

Task default -depends Test
Task Package -depends Test, Version-Modules, Package-Nuget, Unversion-Modules { }

function Version-Module {
    param (
        [string] $Path,
        [string] $Version
    )

    (Get-Content $Path) |
      % {$_ -replace '\$version\$', "$Version" } |
      % {$_ -replace '\$changeset\$', "$changeset" } |
      Set-Content $Path
}

function Unversion-Module {
    param (
        [string] $Path
    )

    git checkout $Path
}

# run tests
Task Test {
    Invoke-Tests $basedir\BuildTools.MsBuild\tests
    Invoke-Tests $basedir\BuildTools.StyleCop\tests
    Invoke-Tests $basedir\BuildTools.FxCop\tests
}

# package the nuget file
Task Package-Nuget {

    # make sure there is a build directory
    if (Test-Path "$baseDir\build") {
        Remove-Item "$baseDir\build" -Recurse -Force
    }
    mkdir "$baseDir\build"

    # pack it up
    nuget pack "$baseDir\BuildTools.MsBuild\BuildTools.MsBuild.nuspec" -OutputDirectory "$baseDir\build" -NoPackageAnalysis -version (Get-Content BuildTools.MsBuild\version.txt)
    nuget pack "$baseDir\BuildTools.StyleCop\BuildTools.StyleCop.nuspec" -OutputDirectory "$baseDir\build" -NoPackageAnalysis -version (Get-Content BuildTools.StyleCop\version.txt)
    nuget pack "$baseDir\BuildTools.FxCop\BuildTools.FxCop.nuspec" -OutputDirectory "$baseDir\build" -NoPackageAnalysis -version (Get-Content BuildTools.FxCop\version.txt)
}

# update the version number in the file
Task Version-Modules {
    Version-Module "$baseDir\BuildTools.MsBuild\BuildTools.MsBuild.psm1" (Get-Content BuildTools.MsBuild\version.txt)

    # stylecop needs the script updated, and also remove the full path from the targets file
    # the targets file is a regex so hopefully we don't have to fix future versions
    Version-Module "$baseDir\BuildTools.StyleCop\tools\StyleCop.psm1" (Get-Content BuildTools.StyleCop\version.txt)
    (Get-Content "$baseDir\BuildTools.StyleCop\tools\StyleCop.targets") |
        Foreach-Object { $_ -replace '\$\(MSBuildExtensionsPath\)\\\.\.\\StyleCop \d+\.\d+\\','' } |
        Set-Content "$baseDir\BuildTools.StyleCop\tools\StyleCop.targets"

    Version-Module "$baseDir\BuildTools.FxCop\tools\FxCop.psm1" (Get-Content BuildTools.FxCop\version.txt)
}

# clear out the version information in the file
Task Unversion-Modules {
    Unversion-Module "$baseDir\BuildTools.MsBuild\BuildTools.MsBuild.psm1"

    Unversion-Module "$baseDir\BuildTools.StyleCop\tools\StyleCop.psm1"
    Unversion-Module "$baseDir\BuildTools.StyleCop\tools\StyleCop.targets"

    Unversion-Module "$baseDir\BuildTools.FxCop\tools\FxCop.psm1"
}
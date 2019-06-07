<#
.SYNOPSIS
Requirement bootstrapper

.DESCRIPTION
Bootstraps the environment importing requirements
#>
Function BootstrapBuilder {
  [CmdletBinding(SupportsShouldProcess)]
  Param()
  Process {
    If ($PSCmdlet.ShouldProcess( "NuGet", "Get-PackageProvider")) {
      Get-PackageProvider -Name NuGet -ForceBootstrap | Out-Null
    }

    @(
      @{ Name = "PSScriptAnalyzer" ; MinimumVersion = "1.17" }, # For validating code quality
      @{ Name = "Pester" ; MinimumVersion = "4.4" }             # For executing unit tests
    ) | ForEach-Object {
      $module = $_
      $moduleName = $module.Name

      If ($PSCmdlet.ShouldProcess($moduleName, "Load Module")) {
        $existingModule = Get-InstalledModule @module -ErrorAction "Ignore"
        If ($null -eq $existingModule) {
          Install-Module @module -SkipPublisherCheck -Force
        }
        Import-Module @module
      }
    }
  }
}

<#
.SYNOPSIS
Cleans previous build output

.DESCRIPTION
Remove the previous build output establishing up a clean environment

.PARAMETER OutputPath
Path to the build output
#>
Function CleanModuleBuild {
  [CmdletBinding(SupportsShouldProcess)]
  Param(
    [Parameter(Position = 0)]
    [ValidateScript({ Test-Path $_ -IsValid })]
    [string]$OutputPath = ".\dist"
  )
  Process {
    If ($PSCmdlet.ShouldProcess($OutputPath, "Clean" )) {
      If (Test-Path $OutputPath) {
        Remove-Item $OutputPath -Recurse -Force
      }
    }
  }
}

<#
.SYNOPSIS
Build the module

.DESCRIPTION
Builds the module and updates the manifest file to reflect new additions.

.PARAMETER Source
Path to the module source

.PARAMETER OutputPath
Path to the build output
#>
Function BuildModule {
  [CmdletBinding(SupportsShouldProcess)]
  Param(
    [Parameter(Position = 0)]
    [ValidateScript({ Test-Path $_ -PathType "Container" })]
    [string]$Source = ".\src"
    ,
    [Parameter(Position = 1)]
    [ValidateScript({ Test-Path $_ -IsValid })]
    [string]$OutputPath = ".\dist"
  )
  Process {
    BootstrapBuilder
    CleanModuleBuild -OutputPath $OutputPath

    If ($PSCmdlet.ShouldProcess($OutputPath, "Create")) {
      If (!(Test-Path $OutputPath)) {
        New-Item $OutputPath -ItemType "Container" | Out-Null
      }
    }

    If ($PSCmdlet.ShouldProcess($OutputPath, "Copy Source")) {
      Copy-Item "${Source}\*" -Destination $OutputPath -Container -Recurse
    }

    $manifestPath = Resolve-Path (Join-Path $OutputPath -ChildPath "*.psd1") -ErrorAction Ignore
    If ($null -ne $manifestPath -and $PSCmdlet.ShouldProcess($moduleManifest, "Update Manifest")) {
      $currentManifest = Import-PowerShellDataFile $manifestPath
      $libPath = Join-Path $OutputPath -ChildPath "lib"
      $publicPath = Join-Path $OutputPath -ChildPath "Public"

      $scriptsToProcess = Get-ChildItem $libPath -Include "*.ps1" -Recurse -ErrorAction "SilentlyContinue" | ForEach-Object { ".\lib\$($_.Name)" }
      $functionsToExport = (Get-ChildItem $publicPath -Include "*.ps1" -Recurse -ErrorAction "SilentlyContinue").BaseName
      
      $version = [version]$currentManifest.ModuleVersion
      $revision = Get-Date -UFormat "%Y%m%d"

      $updateParams = @{
        Path = $manifestPath
        ModuleVersion = [version]($version.Major, $version.Minor, $version.Build, $revision -join ".")
      }
      If ($scriptsToProcess.Length -gt 0) {
        $updateParams.Add("ScriptsToProcess", $scriptsToProcess)
      }
      If ($functionsToExport.Length -gt 0) {
        $updateParams.Add("FunctionsToExport", $functionsToExport)
      }

      Update-ModuleManifest @updateParams
    }

    If ($null -ne $moduleManifest -and $PSCmdlet.ShouldProcess($moduleManifest, "Validate")) {
      If (!(Test-ModuleManifest $moduleManifest)) {
        Throw "Module manifest malformed."
      }
    }
  }
}

<#
.SYNOPSIS
Loads the module

.DESCRIPTION
Loads the module locally for testing without formalities

.PARAMETER Source
Path to module source

.PARAMETER ModuleName
Name to assign to module

.EXAMPLE
LoadModule -Source ".\module\root" -ModuleName "MyModule"

.NOTES
Loads the module almost as if to be dot-sourced allowing access to methods without
cluttering environment with the formalities of bundling/importing.
#>
Function LoadModule {
  [CmdletBinding(SupportsShouldProcess)]
  Param(
    [Parameter(Position = 0)]
    [ValidateScript({ Test-Path $_ -PathType "Container" })]
    [string]$Source = ".\src"
    ,
    [Parameter(Position = 1)]
    [ValidateNotNullOrEmpty()]
    [Alias("As")]
    [string]$ModuleName = "PowershellModuleStarter"
  )
  Process {
    If ($PSCmdlet.ShouldProcess($Source, "Assemble module")) {
      $ModuleSource = "Set-StrictMode -Version Latest`n"
      $ModuleSource += Get-ChildItem $ModuleSourcePath -File -Include "*.ps1" -Recurse | Get-Content -Delimiter ([System.Environment]::NewLine)
      $ModuleSource += "Export-ModuleMember -Function *"
    }
    If ($PSCmdlet.ShouldProcess($ModuleName, "Load module")) {
      New-Module $ModuleName -ScriptBlock ([scriptblock]::Create($ModuleSource)) | Import-Module -DisableNameChecking -Verbose:$false
    }
  }
}

<#
.SYNOPSIS
Run module tests

.DESCRIPTION
Run module tests using pseudo-import (making private members accessible during
test context)

.PARAMETER Source
Path to the module source

.PARAMETER TestsSource
Path to the tests being ran

.PARAMETER Detailed
Include detailed output, including skips and failures.

.EXAMPLE
TestModule -Source ".\module\root" -TestsSource ".\test"

TestModule -Source ".\module\root" -TestsSource ".\test" -Detailed

.NOTES
The module is not formally loaded (and subsequently unloaded after tests have run), making
the environment more capabile of being tested against during incremental changes.
#>
Function TestModule {
  [CmdletBinding(SupportsShouldProcess)]
  Param(
    [Parameter(Position = 0)]
    [ValidateScript({ Test-Path $_ -PathType "Container" })]
    [string]$Source = ".\src"
    ,
    [Parameter(Position = 1)]
    [ValidateScript({ Test-Path $_ -PathType "Container" })]
    [string]$TestsSource = ".\test"
    ,
    [Parameter()]
    [switch]$Detailed
  )
  Process {
    BootstrapBuilder

    $moduleName = (New-Guid).ToString("d")

    If ($PSCmdlet.ShouldProcess($TestsSource, "Run tests")) {
      Try {
        LoadModule -Source $Source -As $moduleName

        If ($Detailed) {
          Invoke-Pester -Path $TestsSource
        } Else {
          Invoke-Pester -Path $TestsSource -Show "Summary", "Failed"
        }
      } Finally {
        UnloadModule -ModuleName $moduleName
      }
    }
  }
}

<#
.SYNOPSIS
Unloads a module

.DESCRIPTION
Unloads a module from the current environment

.PARAMETER ModuleName
Name of the module

.EXAMPLE
UnloadModule -ModuleName "MyModule"

.NOTES
Unloads the module freeing resources
#>
Function UnloadModule {
  [CmdletBinding(SupportsShouldProcess)]
  Param(
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string]$ModuleName
  )
  Process {
    If ($PSCmdlet.ShouldProcess($ModuleName, "Unload module")) {
      Get-Module $ModuleName -ErrorAction SilentlyContinue | Remove-Module -ErrorAction Ignore
    }
  }
}
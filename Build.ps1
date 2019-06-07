[CmdletBinding(DefaultParameterSetName = "__Build")]
Param(
  [Parameter(ParameterSetName = "__Bootstrap")]
  [switch]$Bootstrap
  ,
  [Parameter(ParameterSetName = "__Build")]
  [switch]$Build
  ,
  [Parameter(ParameterSetName = "__Build")]
  [switch]$WithDocker
  ,
  [Parameter(ParameterSetName = "__Clean")]
  [switch]$Clean
  ,
  [Parameter(ParameterSetName = "__Test")]
  [switch]$Test
  ,
  [Parameter(ParameterSetName = "__Test")]
  [switch]$ShowDetails
)
Begin {
  # Save existing preferences
  $eap = $ErrorActionPreference
  $pp = $ProgressPreference

  # Configure preferences for this script
  $ErrorActionPreference = "Stop"
  $ProgressPreference = "Continue"
  
  # Store some common paths
  $ModuleName = "PowershellModuleStarter"
  $ModuleDestinationPath = Join-Path $PSScriptRoot -ChildPath "dist"
  $ModuleSourcePath = Join-Path $PSScriptRoot -ChildPath "src"
  $ModuleTestsPath = Join-Path $PSScriptRoot -ChildPath "test"
}
Process {
  . (Join-Path $PSScriptRoot -ChildPath "Build.Util.ps1")

  # Invoke the desired action
  $paramSetname = $PSCmdlet.ParameterSetName
  Switch ($paramSetName) {
    "__Bootstrap" {
      Write-Host "Bootstrapping..."
      BootstrapBuilder
      Write-Host "Bootstrap complete"
      Break
    }
    "__Build" {
      If ($WithDocker) {
        Write-Host "Building (in docker)..."

        $tag = "{0}_build" -f $ModuleName.ToLower()
        @(
          '# escape=`'
          'FROM mcr.microsoft.com/windows/servercore:ltsc2016'
          'SHELL ["powershell.exe", "-Command", "$ErrorActionPreference=''{0}'';$ProgressPreference=''{1}'';"]' -f $ErrorActionPreference, $ProgressPreference
          'WORKDIR /build'
          'COPY ./Build.ps1 ./Build.Util.ps1 ./'
          'RUN .\Build.ps1 -Bootstrap'
          'COPY . .'
          'RUN .\Build.ps1 -Build'
        ) | Out-String | & docker build --tag $tag -f - $PSScriptRoot
        If ($LASTEXITCODE -ne 0) {
          Write-Error "Build failed"
        } Else {
          Write-Host "Build complete"
        }
      } Else {
        Write-Host "Cleaning..."
        CleanModuleBuild -OutputPath $ModuleDestinationPath
        Write-Host "Clean complete"

        Write-Host "Testing..."
        TestModule -Source $ModuleSourcePath -TestsSource $ModuleTestsPath
        Write-Host "Tests complete"

        Write-Host "Building..."
        BuildModule -Source $ModuleSourcePath -OutputPath $ModuleDestinationPath
        Write-Host "Build complete"
      }
      Break
    }
    "__Clean" {
      Write-Host "Cleaning..."
      CleanModuleBuild -OutputPath $ModuleDestinationPath
      Write-Host "Clean complete"

      Break
    }
    "__Test" {
      Write-Host "Testing..."
      TestModule -Source $ModuleSourcePath -TestsSource $ModuleTestsPath -Detailed:$ShowDetails
      Write-Host "Tests complete"

      Break
    }
    Default {
      Write-Error "Unexpected parameter set name: ${paramSetName}"
    }
  }
}
End {
  # Restore preferences
  $ErrorActionPreference = $eap
  $ProgressPreference = $pp
}
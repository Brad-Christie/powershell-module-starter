Set-StrictMode -Version $PSVersionTable.PSVersion

$Public  = @(Get-ChildItem -Path "${PSScriptRoot}\Public\" -Include "*.ps1" -Recurse -ErrorAction SilentlyContinue)
$Private = @(Get-ChildItem -Path "${PSScriptRoot}\Private\" -Include "*.ps1" -Recurse -ErrorAction SilentlyContinue)

@($Public + $Private) | ForEach-Object {
  $fullname = $_.FullName
  Try {
    . $fullname
  } Catch {
    Write-Error "Unable to import ${fullName}"
  }
}

Export-ModuleMember -Function $Public.BaseName

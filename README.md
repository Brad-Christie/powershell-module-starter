# powershell-module-starter
Starter template for creating a PowerShell module

## Getting Started
While this module will work as-is, you should perform the following simple
modifications before diving in too deep:

1. Rename both the .psd1 & .psm1 files in the `.\src` directory to match your
   desired module name.
2. Update the `$ModuleName` variable within `Build.ps1` to match this new name.

## Convention
This template leverages convention over configuration. This means the module's
final manifest is driven off file location and not parameters passed at build
time.

The folder structure is broken down as follows:

* `.\src`  
  Path to all the module's source files
  * `lib`  
    Intended to provide a location to include dlls as well as a location
    to create PowerShell classes that may be used throughout the module.
  * `Private`  
    This should consist only of functions intended to be used by the module
    itself. Feel free to add subfolders to provide meaningful organization
    of these functions.
  * `Public`  
    This should consist of functions intended to be included in the manifest's
    `FunctionsToExport` list. This list is automatically generated, and, again,
    subfolders may be used to organize this directory.
* `.\test`  
  Path to store tests written against various functions/classes included in
  your module. These tests will be ran against a temporarily-imported module,
  therefore you may write tests against public and private functions alike.
  **Suggestion** Apply the `lib`/`Public`/`Private` (and custom hierarchy)
  structure to this folder to maintain consistency and organization between
  this and the `.\src` directory.

## Building

The `Build.ps1` file (and referenced `Build.Util.ps1`) are included to do a
lot of the heavy lifting. This file includes four basic tasks to help with
building and testing the module.

### Build.ps1 -Bootstrap

Use this to import the basic requirements necessary to build and test your
module. As a baseline, this includes `PSScriptAnalyzer` and `Pester`, but
can be modified to suite your own needs via `TestModule` found in the
`Build.util.ps1` file.

### Build.ps1 -Clean

Cleans the environment from previous build artifacts.

### Build.ps1 -Test [-ShowDetails]

Run all tests found in the `.\test` directory against your current module's
source files. by default, the test summary will only show a successful summary
(or discovered failures). To display a full summary, use the `-ShowDetails`
switch.

### Build.ps1 -Build

Performs an implicit `-Clean` and `-Test`. Upon successful completion, the
module is then built assigning the version found in the module's .psd1 file
(but appending a release timestamp of 'YYMMDD')). To modify the major, minor
and build version numbers, directly modify the .psd1 file _before_ invoking
a build.
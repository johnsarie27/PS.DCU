# ==============================================================================
# Filename: build.ps1
# Version:  0.1.0 | Updated: 2026-05-20
# Author:   johnsarie27
# ==============================================================================

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet(
        'Default',
        'Init',
        'Setup',
        'CombineFunctionsAndStage',
        'ImportStagingModule',
        'Analyze',
        'Test',
        'CreateBuildArtifact',
        'Cleanup'
    )]
    [System.String[]] $TaskList = 'Default',

    [Parameter()]
    [System.Collections.Hashtable] $Parameters,

    [Parameter()]
    [System.Collections.Hashtable] $Properties,

    [Parameter()]
    [System.Management.Automation.SwitchParameter] $ResolveDependency
)

Set-StrictMode -Version Latest

$nl = [System.Environment]::NewLine

Write-Output -InputObject ('{0}STARTED TASKS: {1}{0}' -f $nl, ($TaskList -join ','))

Write-Output -InputObject ('{0}PowerShell Version Information:' -f $nl)
$PSVersionTable

# RESOLVE DEPENDENCIES VIA PSDEPEND
if ($PSBoundParameters.Keys -contains 'ResolveDependency') {
    Get-PackageProvider -Name 'NuGet' -ForceBootstrap | Out-Null

    if (-not (Get-Module -Name 'PSDepend' -ListAvailable)) {
        Write-Output -InputObject ('{0}PSDepend is not yet installed...installing PSDepend now...' -f $nl)
        Install-Module -Name 'PSDepend' -Scope 'CurrentUser' -Force
    }
    else {
        Write-Output -InputObject ('{0}PSDepend already installed...skipping.' -f $nl)
    }

    $psdependencyConfigPath = Join-Path -Path $PSScriptRoot -ChildPath 'depend.psd1'
    Write-Output -InputObject ('Checking / resolving module dependencies from [{0}]...' -f $psdependencyConfigPath)

    Import-Module -Name 'PSDepend'

    $invokePSDependParams = @{
        Path    = $psdependencyConfigPath
        Import  = $true
        Confirm = $false
        Install = $true
        Force   = $true
    }
    Invoke-PSDepend @invokePSDependParams

    $PSBoundParameters.Remove('ResolveDependency') | Out-Null
}
else {
    Write-Output -InputObject ('{0}Skipping dependency check...{0}' -f $nl)
}

# BUILD ENVIRONMENT VARIABLES
$env:BHProjectPath = $PSScriptRoot | Split-Path -Parent
$manifestFile = Get-ChildItem -Path $env:BHProjectPath -Filter '*.psd1' | Select-Object -First 1
$env:BHProjectName = $manifestFile.BaseName
$env:BHPSModuleManifest = $manifestFile.FullName

# INVOKE PSAKE
$invokePsakeParams = @{
    buildFile = Join-Path -Path $env:BHProjectPath -ChildPath 'Build\build.psake.ps1'
    nologo    = $true
}
Invoke-psake @invokePsakeParams @PSBoundParameters

Write-Output -InputObject ('{0}FINISHED TASKS: {1}' -f $nl, ($TaskList -join ','))
exit ( [System.Int32](-not $psake.build_success) )

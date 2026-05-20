# ==============================================================================
# Filename: PS.DCU.psm1
# Version:  0.1.0 | Updated: 2026-05-20
# Author:   johnsarie27
# ==============================================================================

Set-StrictMode -Version Latest

# IMPORT ALL FUNCTIONS
foreach ( $directory in @('Private', 'Public') ) {
    foreach ( $fn in (Get-ChildItem -Path "$PSScriptRoot\$directory\*.ps1" -ErrorAction Ignore) ) {
        . $fn.FullName
    }
}

# MODULE CONSTANTS
New-Variable -Name 'dcu_default_install_paths' -Option Constant -Value @(
    'C:\Program Files\Dell\CommandUpdate\dcu-cli.exe'
    'C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe'
)

New-Variable -Name 'dcu_report_path' -Option Constant -Value (
    Join-Path -Path ([System.Environment]::GetFolderPath('CommonApplicationData')) -ChildPath 'Dell\CommandUpdate\Reports'
)

New-Variable -Name 'dcu_exit_codes' -Option Constant -Value @{
    0    = 'Success'
    1    = 'RebootRequired'
    2    = 'Fatal'
    3    = 'UnknownError'
    4    = 'InvalidUsage'
    5    = 'RebootAndScanPending'
    6    = 'RebootAndApplyPending'
    7    = 'ScanInProgress'
    8    = 'ApplyInProgress'
    100  = 'NoUpdatesAvailable'
    101  = 'NoUpdatesApplicable'
    500  = 'NoApplicableUpdates'
    501  = 'NoUpdatesForCriteria'
    1000 = 'UnableToConnectToWebService'
    1001 = 'WebServiceErrorResponse'
    1002 = 'ProxyAuthenticationRequired'
    1505 = 'AdminRightsRequired'
    1506 = 'AdminRightsRequiredFailedElevation'
}

# CACHE FOR DCU EXECUTABLE LOOKUP
New-Variable -Name 'dcu_cached_executable' -Value $null -Scope 'Script'

# EXPORT MEMBERS
Export-ModuleMember -Function @(
    'Get-DCUConfiguration'
    'Get-DCUDriverHistory'
    'Get-DCUReport'
    'Get-DCUUpdate'
    'Get-DCUVersion'
    'Install-DCUUpdate'
    'Invoke-DCUScan'
    'Set-DCUConfiguration'
) -Variable * -Alias *

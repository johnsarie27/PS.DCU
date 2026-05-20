function Test-DCUElevation {
    <#
    .SYNOPSIS
        Test whether the current PowerShell session is running elevated.
    .DESCRIPTION
        Returns $true when the current Windows identity is a member of the local
        Administrators group. Used by mutating cmdlets to validate elevation before
        invoking dcu-cli.exe.
    .INPUTS
        None.
    .OUTPUTS
        System.Boolean.
    .EXAMPLE
        PS C:\> Test-DCUElevation
        Returns True if running as administrator.
    .NOTES
        Name:     Test-DCUElevation
        Author:   johnsarie27
        Version:  0.1.0 | Last Edit: 2026-05-20
        - Module-private helper. Not exported.
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    Param()

    Begin {
        Set-StrictMode -Version Latest
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [System.Security.Principal.WindowsPrincipal]::new($identity)
        $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
    }
}

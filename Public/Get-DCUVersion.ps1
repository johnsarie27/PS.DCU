function Get-DCUVersion {
    <#
    .SYNOPSIS
        Return the installed Dell Command Update version and executable path.
    .DESCRIPTION
        Locates dcu-cli.exe and returns a PSCustomObject describing the product
        version, file version, and full executable path. Useful for confirming Dell
        Command Update is installed and at the expected version before invoking
        other PS.DCU cmdlets.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Get-DCUVersion
        Returns the installed Dell Command Update version information.
    .NOTES
        Name:     Get-DCUVersion
        Author:   johnsarie27
        Version:  0.1.0 | Last Edit: 2026-05-20
        - https://www.dell.com/support/kbdoc/en-us/000177325/
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param()

    Begin {
        Set-StrictMode -Version Latest
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        $executable = Get-DCUExecutable
        $info = $executable.VersionInfo

        [PSCustomObject] @{
            ProductVersion = $info.ProductVersion
            FileVersion    = $info.FileVersion
            ExecutablePath = $executable.FullName
        }
    }
}

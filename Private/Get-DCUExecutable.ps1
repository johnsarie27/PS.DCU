function Get-DCUExecutable {
    <#
    .SYNOPSIS
        Locate the Dell Command Update CLI executable.
    .DESCRIPTION
        Searches the standard Dell Command Update install paths for dcu-cli.exe and
        returns a FileInfo object pointing to the first match. Caches the resolved
        path for the lifetime of the module session.
    .INPUTS
        None.
    .OUTPUTS
        System.IO.FileInfo.
    .EXAMPLE
        PS C:\> Get-DCUExecutable
        Returns the FileInfo object for the installed dcu-cli.exe.
    .NOTES
        Name:     Get-DCUExecutable
        Author:   johnsarie27
        Version:  0.1.0 | Last Edit: 2026-05-20
        - Module-private helper. Not exported.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    Param()

    Begin {
        Set-StrictMode -Version Latest
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        if ($script:dcu_cached_executable -and (Test-Path -Path $script:dcu_cached_executable.FullName)) {
            Write-Verbose -Message ('Returning cached executable: [{0}]' -f $script:dcu_cached_executable.FullName)
            $script:dcu_cached_executable
            return
        }

        foreach ($candidate in $dcu_default_install_paths) {
            if (Test-Path -Path $candidate -PathType 'Leaf') {
                Write-Verbose -Message ('Found dcu-cli.exe at [{0}]' -f $candidate)
                $script:dcu_cached_executable = Get-Item -Path $candidate
                $script:dcu_cached_executable
                return
            }
        }

        Write-Error -Message 'dcu-cli.exe was not found. Install Dell Command Update from https://www.dell.com/support/kbdoc/en-us/000177325/' -ErrorAction Stop
    }
}

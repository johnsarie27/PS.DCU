function Get-DCUDriverHistory {
    <#
    .SYNOPSIS
        Return previously installed driver and firmware updates from Dell Command Update.
    .DESCRIPTION
        Invokes dcu-cli.exe /driverInstall -report=<tempDir> to capture the install
        history and parses the resulting XML report into PSCustomObject records.
        Equivalent inventory data is also available by parsing existing reports under
        %ProgramData%\Dell\CommandUpdate\Reports via Get-DCUReport.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Get-DCUDriverHistory
        Returns the driver and firmware update install history.
    .NOTES
        Name:     Get-DCUDriverHistory
        Author:   johnsarie27
        Version:  0.1.0 | Last Edit: 2026-05-20
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param()

    Begin {
        Set-StrictMode -Version Latest
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        $reportDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('DCU_History_{0}' -f ([System.Guid]::NewGuid().Guid))
        New-Item -Path $reportDir -ItemType 'Directory' -Force | Out-Null

        try {
            $arguments = @('/driverInstall', ('-report={0}' -f $reportDir))
            $result = Invoke-DCU -Arguments $arguments

            Write-Verbose -Message ('dcu-cli exit code [{0}] status [{1}]' -f $result.ExitCode, $result.Status)

            Get-ChildItem -Path $reportDir -Filter '*.xml' -File -ErrorAction 'Ignore' | ForEach-Object -Process {
                ConvertFrom-DCUReport -Path $_.FullName
            }
        }
        finally {
            Remove-Item -Path $reportDir -Recurse -Force -ErrorAction 'Ignore'
        }
    }
}

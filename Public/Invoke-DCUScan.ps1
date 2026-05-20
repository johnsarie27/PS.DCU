function Invoke-DCUScan {
    <#
    .SYNOPSIS
        Run a Dell Command Update scan and return the report path with exit metadata.
    .DESCRIPTION
        Invokes dcu-cli.exe /scan, writing the XML report to the supplied -OutputPath
        (or to a fresh temp directory when not specified). Returns a PSCustomObject
        with the resolved report path, exit code, friendly status, duration, and the
        arguments used. Use Get-DCUReport or ConvertFrom-DCUReport to parse the
        resulting XML.
    .PARAMETER OutputPath
        File or directory path for the report. When a directory is supplied, DCU
        writes its default-named XML inside it. When omitted, a fresh subdirectory
        under the user temp folder is created.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Invoke-DCUScan
        Runs a scan, writes the report to a temp folder, and returns the report path.
    .EXAMPLE
        PS C:\> Invoke-DCUScan -OutputPath 'C:\Reports\dcu'
        Runs a scan and writes the XML report under C:\Reports\dcu.
    .NOTES
        Name:     Invoke-DCUScan
        Author:   johnsarie27
        Version:  0.1.0 | Last Edit: 2026-05-20
        - dcu-cli.exe /scan reference: https://www.dell.com/support/manuals/en-us/command-update/
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(HelpMessage = 'Path to write the XML scan report (file or directory)')]
        [ValidateNotNullOrEmpty()]
        [System.String] $OutputPath
    )
    Begin {
        Set-StrictMode -Version Latest
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        if (-not $PSBoundParameters.ContainsKey('OutputPath')) {
            $OutputPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('DCU_Scan_{0}' -f ([System.Guid]::NewGuid().Guid))
        }

        # ENSURE TARGET DIRECTORY EXISTS WHEN OUTPUTPATH IS A DIRECTORY OR HAS NO EXTENSION
        $targetDirectory = if ([System.IO.Path]::GetExtension($OutputPath)) {
            [System.IO.Path]::GetDirectoryName($OutputPath)
        }
        else {
            $OutputPath
        }
        if ($targetDirectory -and -not (Test-Path -Path $targetDirectory)) {
            New-Item -Path $targetDirectory -ItemType 'Directory' -Force | Out-Null
        }

        $arguments = @('/scan', ('-report={0}' -f $OutputPath))
        $result = Invoke-DCU -Arguments $arguments

        [PSCustomObject] @{
            ExitCode   = $result.ExitCode
            Status     = $result.Status
            ReportPath = $OutputPath
            Duration   = $result.Duration
            Arguments  = $result.Arguments
            StdOut     = $result.StdOut
            StdErr     = $result.StdErr
        }
    }
}

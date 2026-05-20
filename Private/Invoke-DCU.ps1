function Invoke-DCU {
    <#
    .SYNOPSIS
        Internal launcher for dcu-cli.exe.
    .DESCRIPTION
        Locates the Dell Command Update CLI executable, launches it with the supplied
        arguments, captures stdout and stderr to temp files, and returns a structured
        result object including the exit code and a friendly status string mapped from
        the module-level exit code table.
    .PARAMETER Arguments
        Array of arguments to pass to dcu-cli.exe.
    .PARAMETER RequireElevation
        When set, validates the session is elevated before invoking the CLI; throws a
        terminating error if not.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Invoke-DCU -Arguments @('/scan', '-report=C:\Temp')
        Runs dcu-cli.exe /scan -report=C:\Temp and returns the result object.
    .NOTES
        Name:     Invoke-DCU
        Author:   johnsarie27
        Version:  0.1.0 | Last Edit: 2026-05-20
        - Module-private helper. Not exported.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Arguments to pass to dcu-cli.exe')]
        [ValidateNotNullOrEmpty()]
        [System.String[]] $Arguments,

        [Parameter(HelpMessage = 'Require an elevated session before invoking the CLI')]
        [System.Management.Automation.SwitchParameter] $RequireElevation
    )
    Begin {
        Set-StrictMode -Version Latest
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        if ($RequireElevation.IsPresent -and -not (Test-DCUElevation)) {
            Write-Error -Message 'This operation requires an elevated PowerShell session (Run as Administrator).' -ErrorAction Stop
        }

        $executable = Get-DCUExecutable
    }
    Process {
        $stdoutFile = [System.IO.Path]::GetTempFileName()
        $stderrFile = [System.IO.Path]::GetTempFileName()
        $startTime = Get-Date

        Write-Verbose -Message ('Invoking [{0}] with arguments [{1}]' -f $executable.FullName, ($Arguments -join ' '))

        $startParams = @{
            FilePath               = $executable.FullName
            ArgumentList           = $Arguments
            Wait                   = $true
            PassThru               = $true
            NoNewWindow            = $true
            RedirectStandardOutput = $stdoutFile
            RedirectStandardError  = $stderrFile
            ErrorAction            = 'Stop'
        }

        try {
            $process = Start-Process @startParams
            $stdout = Get-Content -Path $stdoutFile -Raw -ErrorAction 'Ignore'
            $stderr = Get-Content -Path $stderrFile -Raw -ErrorAction 'Ignore'

            $exitCode = $process.ExitCode
            $status = if ($dcu_exit_codes.ContainsKey($exitCode)) {
                $dcu_exit_codes[$exitCode]
            }
            else {
                'Unknown'
            }

            [PSCustomObject] @{
                ExitCode  = $exitCode
                Status    = $status
                StdOut    = $stdout
                StdErr    = $stderr
                Arguments = $Arguments
                Duration  = (Get-Date) - $startTime
            }
        }
        catch {
            Write-Error -Message ('Failed to invoke dcu-cli.exe: {0}' -f $PSItem.Exception.Message) -ErrorAction Stop
        }
        finally {
            Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction 'Ignore'
        }
    }
}

function Get-DCUUpdate {
    <#
    .SYNOPSIS
        Scan for applicable Dell Command Update updates and return them as objects.
    .DESCRIPTION
        Runs dcu-cli.exe /scan against a fresh temporary report directory, applying
        any supplied UpdateType, Severity, or DeviceCategory filters as CLI flags,
        and returns one PSCustomObject per applicable update. When -Name is supplied,
        results are filtered client-side to entries whose Name matches the wildcard.
    .PARAMETER Name
        Optional wildcard filter applied to the Name property of each returned update.
    .PARAMETER UpdateType
        One or more update types to include. Maps to dcu-cli /scan -updateType=.
    .PARAMETER Severity
        One or more severities to include. Maps to dcu-cli /scan -updateSeverity=.
    .PARAMETER DeviceCategory
        One or more device categories to include. Maps to dcu-cli /scan -updateDeviceCategory=.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Get-DCUUpdate
        Returns every applicable update detected by Dell Command Update.
    .EXAMPLE
        PS C:\> Get-DCUUpdate -Severity 'security', 'critical'
        Returns only security and critical updates.
    .EXAMPLE
        PS C:\> Get-DCUUpdate -Name '*BIOS*'
        Returns only updates whose Name contains "BIOS".
    .NOTES
        Name:     Get-DCUUpdate
        Author:   johnsarie27
        Version:  0.1.0 | Last Edit: 2026-05-20
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(HelpMessage = 'Wildcard filter applied to the update Name')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Name,

        [Parameter(HelpMessage = 'Filter by update type')]
        [ValidateSet('bios', 'firmware', 'driver', 'application', 'utility', 'others')]
        [System.String[]] $UpdateType,

        [Parameter(HelpMessage = 'Filter by update severity')]
        [ValidateSet('security', 'critical', 'recommended', 'optional')]
        [System.String[]] $Severity,

        [Parameter(HelpMessage = 'Filter by device category')]
        [ValidateSet('audio', 'video', 'network', 'storage', 'input', 'chipset', 'others')]
        [System.String[]] $DeviceCategory
    )
    Begin {
        Set-StrictMode -Version Latest
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)
    }
    Process {
        $reportDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('DCU_Scan_{0}' -f ([System.Guid]::NewGuid().Guid))
        New-Item -Path $reportDir -ItemType 'Directory' -Force | Out-Null

        try {
            $scanParams = @{ OutputPath = $reportDir }

            $extraArgs = [System.Collections.Generic.List[System.String]]::new()
            if ($PSBoundParameters.ContainsKey('UpdateType')) {
                $extraArgs.Add(('-updateType={0}' -f ($UpdateType -join ','))) | Out-Null
            }
            if ($PSBoundParameters.ContainsKey('Severity')) {
                $extraArgs.Add(('-updateSeverity={0}' -f ($Severity -join ','))) | Out-Null
            }
            if ($PSBoundParameters.ContainsKey('DeviceCategory')) {
                $extraArgs.Add(('-updateDeviceCategory={0}' -f ($DeviceCategory -join ','))) | Out-Null
            }

            if ($extraArgs.Count -gt 0) {
                # COMPOSE ARGUMENTS DIRECTLY VIA INVOKE-DCU SO FILTERS PASS THROUGH
                $arguments = @('/scan', ('-report={0}' -f $reportDir)) + $extraArgs.ToArray()
                $result = Invoke-DCU -Arguments $arguments
            }
            else {
                $result = Invoke-DCUScan @scanParams
            }

            Write-Verbose -Message ('dcu-cli exit code [{0}] status [{1}]' -f $result.ExitCode, $result.Status)

            $updates = Get-ChildItem -Path $reportDir -Filter '*.xml' -File -ErrorAction 'Ignore' | ForEach-Object -Process {
                ConvertFrom-DCUReport -Path $_.FullName
            }

            if ($PSBoundParameters.ContainsKey('Name')) {
                $updates = $updates | Where-Object -FilterScript { $_.Name -like $Name }
            }

            $updates
        }
        finally {
            Remove-Item -Path $reportDir -Recurse -Force -ErrorAction 'Ignore'
        }
    }
}

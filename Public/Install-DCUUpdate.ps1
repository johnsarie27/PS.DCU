function Install-DCUUpdate {
    <#
    .SYNOPSIS
        Apply Dell Command Update updates.
    .DESCRIPTION
        Invokes dcu-cli.exe /applyUpdates with the supplied filters. Names supplied
        via the -Name parameter (or piped in from Get-DCUUpdate) are accumulated and
        passed in a single CLI invocation. Requires an elevated session. Supports
        ShouldProcess so -WhatIf and -Confirm work as expected.
    .PARAMETER Name
        One or more update names to apply. Accepts pipeline input from Get-DCUUpdate.
    .PARAMETER UpdateType
        Restrict the apply operation to one or more update types.
    .PARAMETER Severity
        Restrict the apply operation to one or more severities.
    .PARAMETER DeviceCategory
        Restrict the apply operation to one or more device categories.
    .PARAMETER Reboot
        Allow Dell Command Update to reboot the system automatically when required.
    .PARAMETER AutoSuspendBitLocker
        Auto-suspend BitLocker when needed to apply BIOS or firmware updates.
    .PARAMETER ForceUpdate
        Enable or disable forcing the apply operation through pending reboots.
    .INPUTS
        System.String. Update names from Get-DCUUpdate.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Install-DCUUpdate -Severity 'security' -Reboot
        Applies all security updates and allows a reboot.
    .EXAMPLE
        PS C:\> Get-DCUUpdate -Severity 'critical' | Install-DCUUpdate -AutoSuspendBitLocker -Confirm:$false
        Applies all critical updates returned by Get-DCUUpdate without prompting.
    .NOTES
        Name:     Install-DCUUpdate
        Author:   johnsarie27
        Version:  0.1.0 | Last Edit: 2026-05-20
        - Requires an elevated PowerShell session.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Update name(s) to apply')]
        [ValidateNotNullOrEmpty()]
        [System.String[]] $Name,

        [Parameter(HelpMessage = 'Filter by update type')]
        [ValidateSet('bios', 'firmware', 'driver', 'application', 'utility', 'others')]
        [System.String[]] $UpdateType,

        [Parameter(HelpMessage = 'Filter by update severity')]
        [ValidateSet('security', 'critical', 'recommended', 'optional')]
        [System.String[]] $Severity,

        [Parameter(HelpMessage = 'Filter by device category')]
        [ValidateSet('audio', 'video', 'network', 'storage', 'input', 'chipset', 'others')]
        [System.String[]] $DeviceCategory,

        [Parameter(HelpMessage = 'Allow automatic reboot when required')]
        [System.Management.Automation.SwitchParameter] $Reboot,

        [Parameter(HelpMessage = 'Auto-suspend BitLocker for BIOS or firmware updates')]
        [System.Management.Automation.SwitchParameter] $AutoSuspendBitLocker,

        [Parameter(HelpMessage = 'Enable or disable forcing the apply operation')]
        [ValidateSet('Enable', 'Disable')]
        [System.String] $ForceUpdate
    )
    Begin {
        Set-StrictMode -Version Latest
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        if (-not (Test-DCUElevation)) {
            Write-Error -Message 'Install-DCUUpdate requires an elevated PowerShell session (Run as Administrator).' -ErrorAction Stop
        }

        $collectedNames = [System.Collections.Generic.List[System.String]]::new()
    }
    Process {
        if ($PSBoundParameters.ContainsKey('Name')) {
            foreach ($n in $Name) {
                $collectedNames.Add($n) | Out-Null
            }
        }
    }
    End {
        $arguments = [System.Collections.Generic.List[System.String]]::new()
        $arguments.Add('/applyUpdates') | Out-Null

        if ($collectedNames.Count -gt 0) {
            $arguments.Add(('-updateName={0}' -f ($collectedNames -join ','))) | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('UpdateType')) {
            $arguments.Add(('-updateType={0}' -f ($UpdateType -join ','))) | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('Severity')) {
            $arguments.Add(('-updateSeverity={0}' -f ($Severity -join ','))) | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('DeviceCategory')) {
            $arguments.Add(('-updateDeviceCategory={0}' -f ($DeviceCategory -join ','))) | Out-Null
        }
        if ($Reboot.IsPresent) {
            $arguments.Add('-reboot=enable') | Out-Null
        }
        if ($AutoSuspendBitLocker.IsPresent) {
            $arguments.Add('-autoSuspendBitLocker=enable') | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('ForceUpdate')) {
            $arguments.Add(('-forceupdate={0}' -f $ForceUpdate.ToLower())) | Out-Null
        }

        $target = if ($collectedNames.Count -gt 0) { ($collectedNames -join ', ') } else { 'all applicable updates' }
        $action = 'Apply Dell Command Update updates'

        if ($PSCmdlet.ShouldProcess($target, $action)) {
            $result = Invoke-DCU -Arguments $arguments.ToArray() -RequireElevation
            $result
        }
    }
}

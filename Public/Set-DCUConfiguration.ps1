function Set-DCUConfiguration {
    <#
    .SYNOPSIS
        Configure Dell Command Update policy settings.
    .DESCRIPTION
        Invokes dcu-cli.exe /configure with the supplied options to set schedule,
        notification, deferral, advanced driver restore, lock, or import/export
        behavior. Requires an elevated session. Supports ShouldProcess so -WhatIf
        and -Confirm work as expected.
    .PARAMETER ScheduleWeekly
        Day of the week to run the weekly update schedule.
    .PARAMETER ScheduleMonthly
        Day of the month (1-28) to run the monthly update schedule.
    .PARAMETER ScheduleManual
        When set, switches the schedule mode to manual.
    .PARAMETER ScheduleTime
        Time of day (HH:mm, 24-hour) for the schedule.
    .PARAMETER UpdatesNotification
        Controls how updates notifications appear.
    .PARAMETER ImportSettings
        Path to an XML settings file to import.
    .PARAMETER ExportSettings
        Path to write the current settings XML.
    .PARAMETER AdvancedDriverRestore
        Enable or disable advanced driver restore.
    .PARAMETER SystemRestartDeferral
        Enable or disable restart deferral.
    .PARAMETER DeferralRestartInterval
        Restart deferral interval in days.
    .PARAMETER DeferralInstallInterval
        Install deferral interval in days.
    .PARAMETER LockSettings
        Lock or unlock the DCU settings to prevent end-user changes.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Set-DCUConfiguration -ScheduleWeekly 'Sunday' -ScheduleTime '03:00'
        Sets the update schedule to weekly Sunday at 03:00.
    .EXAMPLE
        PS C:\> Set-DCUConfiguration -LockSettings 'Enable' -Confirm:$false
        Locks the DCU settings without prompting.
    .NOTES
        Name:     Set-DCUConfiguration
        Author:   johnsarie27
        Version:  0.1.0 | Last Edit: 2026-05-20
        - Requires an elevated PowerShell session.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(HelpMessage = 'Day of week for weekly schedule')]
        [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
        [System.String] $ScheduleWeekly,

        [Parameter(HelpMessage = 'Day of month (1-28) for monthly schedule')]
        [ValidateRange(1, 28)]
        [System.Int32] $ScheduleMonthly,

        [Parameter(HelpMessage = 'Switch to manual scheduling mode')]
        [System.Management.Automation.SwitchParameter] $ScheduleManual,

        [Parameter(HelpMessage = 'Time of day (HH:mm) for the schedule')]
        [ValidatePattern('^([01]\d|2[0-3]):[0-5]\d$')]
        [System.String] $ScheduleTime,

        [Parameter(HelpMessage = 'Updates notification mode')]
        [ValidateSet('Enable', 'Disable', 'NotifyAvailable', 'NotifyDownloaded')]
        [System.String] $UpdatesNotification,

        [Parameter(HelpMessage = 'Path to an XML settings file to import')]
        [ValidateScript({ Test-Path -Path $_ -PathType 'Leaf' })]
        [System.String] $ImportSettings,

        [Parameter(HelpMessage = 'Path to export the current settings XML')]
        [ValidateNotNullOrEmpty()]
        [System.String] $ExportSettings,

        [Parameter(HelpMessage = 'Enable or disable advanced driver restore')]
        [ValidateSet('Enable', 'Disable')]
        [System.String] $AdvancedDriverRestore,

        [Parameter(HelpMessage = 'Enable or disable system restart deferral')]
        [ValidateSet('Enable', 'Disable')]
        [System.String] $SystemRestartDeferral,

        [Parameter(HelpMessage = 'Restart deferral interval in days')]
        [ValidateRange(1, 99)]
        [System.Int32] $DeferralRestartInterval,

        [Parameter(HelpMessage = 'Install deferral interval in days')]
        [ValidateRange(1, 99)]
        [System.Int32] $DeferralInstallInterval,

        [Parameter(HelpMessage = 'Lock or unlock the DCU settings')]
        [ValidateSet('Enable', 'Disable')]
        [System.String] $LockSettings
    )
    Begin {
        Set-StrictMode -Version Latest
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        if (-not (Test-DCUElevation)) {
            Write-Error -Message 'Set-DCUConfiguration requires an elevated PowerShell session (Run as Administrator).' -ErrorAction Stop
        }
    }
    Process {
        $arguments = [System.Collections.Generic.List[System.String]]::new()
        $arguments.Add('/configure') | Out-Null

        if ($PSBoundParameters.ContainsKey('ScheduleWeekly')) {
            $arguments.Add(('-scheduleWeekly={0}' -f $ScheduleWeekly)) | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('ScheduleMonthly')) {
            $arguments.Add(('-scheduleMonthly={0}' -f $ScheduleMonthly)) | Out-Null
        }
        if ($ScheduleManual.IsPresent) {
            $arguments.Add('-scheduleManual') | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('ScheduleTime')) {
            $arguments.Add(('-scheduleAction={0}' -f $ScheduleTime)) | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('UpdatesNotification')) {
            $arguments.Add(('-updatesNotification={0}' -f $UpdatesNotification.ToLower())) | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('ImportSettings')) {
            $arguments.Add(('-importSettings={0}' -f $ImportSettings)) | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('ExportSettings')) {
            $arguments.Add(('-exportSettings={0}' -f $ExportSettings)) | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('AdvancedDriverRestore')) {
            $arguments.Add(('-advancedDriverRestore={0}' -f $AdvancedDriverRestore.ToLower())) | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('SystemRestartDeferral')) {
            $arguments.Add(('-systemRestartDeferral={0}' -f $SystemRestartDeferral.ToLower())) | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('DeferralRestartInterval')) {
            $arguments.Add(('-deferralRestartInterval={0}' -f $DeferralRestartInterval)) | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('DeferralInstallInterval')) {
            $arguments.Add(('-deferralInstallInterval={0}' -f $DeferralInstallInterval)) | Out-Null
        }
        if ($PSBoundParameters.ContainsKey('LockSettings')) {
            $arguments.Add(('-lockSettings={0}' -f $LockSettings.ToLower())) | Out-Null
        }

        if ($arguments.Count -le 1) {
            Write-Error -Message 'At least one configuration parameter must be specified.' -ErrorAction Stop
        }

        $action = 'Set Dell Command Update configuration'
        $target = ($arguments | Select-Object -Skip 1) -join ' '

        if ($PSCmdlet.ShouldProcess($target, $action)) {
            $result = Invoke-DCU -Arguments $arguments.ToArray() -RequireElevation
            $result
        }
    }
}

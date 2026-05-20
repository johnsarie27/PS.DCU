function ConvertFrom-DCUReport {
    <#
    .SYNOPSIS
        Parse a Dell Command Update XML report into PSCustomObject records.
    .DESCRIPTION
        Reads a Dell Command Update XML report file and emits one PSCustomObject per
        update entry. Reports are normally written to %ProgramData%\Dell\CommandUpdate\Reports
        or to the directory supplied via the -report= argument of dcu-cli.exe.
    .PARAMETER Path
        Path to the XML report file or to a directory containing one or more reports.
        When a directory is supplied, every *.xml file found is parsed.
    .INPUTS
        System.String. Accepts a file or directory path from the pipeline.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> ConvertFrom-DCUReport -Path 'C:\ProgramData\Dell\CommandUpdate\Reports\DCUApplicableUpdates.xml'
        Parses the supplied report and emits one object per update entry.
    .NOTES
        Name:     ConvertFrom-DCUReport
        Author:   johnsarie27
        Version:  0.1.0 | Last Edit: 2026-05-20
        - Module-private helper. Not exported.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, HelpMessage = 'Path to the XML report file or directory')]
        [ValidateNotNullOrEmpty()]
        [System.String] $Path
    )
    Begin {
        Set-StrictMode -Version Latest
        Write-Verbose -Message ('Starting {0}' -f $MyInvocation.MyCommand)

        # SAFE XML ATTRIBUTE ACCESSOR
        function Get-XmlAttr {
            param([System.Xml.XmlNode] $Node, [System.String] $AttributeName)
            if ($null -eq $Node -or $null -eq $Node.Attributes) { return $null }
            $attr = $Node.Attributes[$AttributeName]
            if ($null -eq $attr) { return $null }
            $attr.Value
        }
    }
    Process {
        if (-not (Test-Path -Path $Path)) {
            Write-Error -Message ('Path not found: [{0}]' -f $Path) -ErrorAction Stop
        }

        $item = Get-Item -Path $Path
        $reportFiles = if ($item.PSIsContainer) {
            Get-ChildItem -Path $item.FullName -Filter '*.xml' -File -ErrorAction 'Ignore'
        }
        else {
            @($item)
        }

        foreach ($reportFile in $reportFiles) {
            Write-Verbose -Message ('Parsing report file [{0}]' -f $reportFile.FullName)

            try {
                $xml = New-Object -TypeName 'System.Xml.XmlDocument'
                $xml.Load($reportFile.FullName)
            }
            catch {
                Write-Error -Message ('Failed to load XML from [{0}]: {1}' -f $reportFile.FullName, $PSItem.Exception.Message) -ErrorAction Stop
            }

            # DCU REPORTS USE NODE NAMES UPDATE / SUPPORTED-UPDATE BENEATH THE ROOT
            $updateNodes = [System.Collections.Generic.List[System.Xml.XmlNode]]::new()
            foreach ($xpath in @('//Update', '//SupportedUpdate')) {
                foreach ($n in $xml.SelectNodes($xpath)) {
                    if ($null -ne $n) { $updateNodes.Add($n) | Out-Null }
                }
            }

            foreach ($node in $updateNodes) {
                [PSCustomObject] @{
                    Name              = Get-XmlAttr -Node $node -AttributeName 'name'
                    Release           = Get-XmlAttr -Node $node -AttributeName 'release'
                    Category          = Get-XmlAttr -Node $node -AttributeName 'category'
                    Severity          = Get-XmlAttr -Node $node -AttributeName 'urgency'
                    Type              = Get-XmlAttr -Node $node -AttributeName 'type'
                    Reboot            = Get-XmlAttr -Node $node -AttributeName 'rebootRequired'
                    InstalledDateTime = Get-XmlAttr -Node $node -AttributeName 'installationDateTime'
                    ReleaseDate       = Get-XmlAttr -Node $node -AttributeName 'releaseDate'
                    Size              = Get-XmlAttr -Node $node -AttributeName 'size'
                    Version           = Get-XmlAttr -Node $node -AttributeName 'version'
                    SourcePath        = $reportFile.FullName
                }
            }
        }
    }
}

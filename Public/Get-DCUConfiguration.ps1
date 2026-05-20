function Get-DCUConfiguration {
    <#
    .SYNOPSIS
        Export the current Dell Command Update configuration as a structured object.
    .DESCRIPTION
        Invokes dcu-cli.exe /configure -exportSettings against a fresh temp file and
        parses the resulting XML into a PSCustomObject describing the current DCU
        policy: schedule, notification, deferral, advanced driver restore, and lock
        settings.
    .INPUTS
        None.
    .OUTPUTS
        System.Management.Automation.PSCustomObject.
    .EXAMPLE
        PS C:\> Get-DCUConfiguration
        Returns the current Dell Command Update configuration.
    .NOTES
        Name:     Get-DCUConfiguration
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
        $exportFile = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('DCU_Settings_{0}.xml' -f ([System.Guid]::NewGuid().Guid))

        try {
            $arguments = @('/configure', ('-exportSettings={0}' -f $exportFile))
            $result = Invoke-DCU -Arguments $arguments

            if ($result.ExitCode -ne 0) {
                Write-Error -Message ('dcu-cli /configure -exportSettings failed: exit code [{0}] status [{1}]' -f $result.ExitCode, $result.Status) -ErrorAction Stop
            }

            if (-not (Test-Path -Path $exportFile)) {
                Write-Error -Message ('Expected settings export not found at [{0}]' -f $exportFile) -ErrorAction Stop
            }

            $xml = New-Object -TypeName 'System.Xml.XmlDocument'
            $xml.Load($exportFile)

            $output = [Ordered] @{
                ExportPath = $exportFile
                ExitCode   = $result.ExitCode
                Status     = $result.Status
            }

            # FLATTEN TOP-LEVEL SETTINGS NODES INTO PROPERTIES
            if ($xml.DocumentElement) {
                foreach ($childNode in $xml.DocumentElement.ChildNodes) {
                    if ($childNode.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }

                    $value = if ($childNode.HasChildNodes -and $childNode.ChildNodes.Count -eq 1 -and $childNode.FirstChild.NodeType -eq [System.Xml.XmlNodeType]::Text) {
                        $childNode.InnerText
                    }
                    else {
                        $childNode.OuterXml
                    }

                    $output[$childNode.Name] = $value
                }
            }

            [PSCustomObject] $output
        }
        finally {
            # KEEP THE EXPORT FILE FOR INSPECTION; CONSUMER MAY DELETE IT
        }
    }
}

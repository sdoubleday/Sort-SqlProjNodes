<#
.SUMMARY
Sort xml, possibly specific to the .sqlproj Visual Studio project type.
Based on the link, below.

.DESCRIPTION
Git merges on .sqlproj files are annoying. Sort and deduplicate the .sqlproj files on both branches first for easier merges.

.LINK
https://stackoverflow.com/questions/21104514/powershell-xml-sort-nodes-and-replacechild#21112613
#>

[CmdletBinding()]
PARAM(
    [ValidateNotNullorEmpty()][ValidateScript({
                IF (Test-Path -PathType leaf -Path $_ ) 
                    {$True}
                ELSE {
                    Throw "$_ is not a file."
                } 
            })][Alias("SqlProjFileName")][String]$FilePath
)
BEGIN{
CLASS SqlProjItemGroup {
    [System.Xml.XmlNode]$XmlNode;
    [String[]]$Properties;

    [void]AssignProperties()
    {
        $this.Properties = Get-Member -MemberType Property -InputObject $this.XmlNode | Select-Object -ExpandProperty Name;
    }

    SqlProjItemGroup ([System.Xml.XmlNode]$XmlNode)
    {
        $this.XmlNode = $XmlNode;
        $this.AssignProperties();
    }

} <# END CLASS SqlProjItemGroup #>

CLASS SqlProjXml {
    [Xml]$Xml;

    SqlProjXml([Xml]$Xml)
    {
        $this.Xml = $Xml;
    }

    [void] Save([String]$FullName)
    {
        $this.Xml.Save($FullName);
    }

    ProcessItemGroups()
    {
        foreach ($ig in $this.Xml.Project.ItemGroup)
        {
            [SqlProjItemGroup]$SqlProjItemGroup = [SqlProjItemGroup]::New($ig);
            foreach ($property in $SqlProjItemGroup.Properties)
            {
                $SqlProjItemGroup.XmlNode.$($property) | Sort-Object Include -Descending | ForEach-Object {
                    [void]$SqlProjItemGroup.XmlNode.PrependChild($_) };
                $previous = $null;
                $SqlProjItemGroup.XmlNode.$($property) | ForEach-Object {
                    IF ($_.Include -like $previous)
                    {
                        Write-Verbose "Removing duplicate: $($_.Include)" -Verbose;
                        [void]$SqlProjItemGroup.XmlNode.RemoveChild($_);
                    } <# END IF ($_.Include -like $previous) #>
                    $previous = $_.Include;
                } <# END $SqlProjItemGroup.XmlNode.$($property) | ForEach-Object #>
            } <# END foreach ($property in $SqlProjItemGroup.Properties) #>
        } <# END foreach ($ig in $this.Xml.Project.ItemGroup) #>
    } <# END ProcessItemGroups() #>
} <# END CLASS SqlProjXml #>

} <# END BEGIN #>
PROCESS{
    $contents = Get-Content $FilePath;
    [SqlProjXml]$SqlProjXml = [SqlProjXml]::NEW($contents);
    $SqlProjXml.ProcessItemGroups();
    $SqlProjXml.Save($FilePath);
} <# END PROCESS #>
END {} <# END END #>

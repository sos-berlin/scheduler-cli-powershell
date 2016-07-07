function Get-JobSchedulerInventory
{
<#
.SYNOPSIS
Returns the JobScheduler Master inventory

.DESCRIPTION
The cmdlet returns the inventory of JobScheduler Master instances
including information about related Agent instances.

.PARAMETER Url
Specifies the URL for which a Master is available. Any Agents configured for this Master
are added to the inventory output.

Both parameters -Url and -InputFile cannot be used at the same time.
.PARAMETER InputFile
Specifies the location of a simple text file that includes the URLs
of JobScheduler Master instances.

Each Master URL is expected in a separate line, e.g.

http://host1:4444
http://host2:4444

Both parameters -Url and -InputFile cannot be used at the same time.
.PARAMETER OutputFile
Specifies the location of an output file in XML format.

The output file includes the inventory for any Master instance specified.
.EXAMPLE
$inventory = Get-Inventory http://localhost:4444

Returns the inventory for the specified JobScheduler Master instance.

.EXAMPLE
$inventory = Get-Inventory http://localhost:4444 -OutputFile /tmp/inventory.xml

Returns the inventory for the specified JobScheduler Master instance and
creates an XML output file that includes the inventory.

.EXAMPLE
$inventory = Get-Inventory -InputFile /tmp/inventory.csv -OutputFile /tmp/inventory.xml

Reads the input file "/tmp/inventory.csv" that includes a number of Master URLs.

The cmdlets checks the inventory for each Master specified and
creates an XML output file that includes the inventory.

.EXAMPLE
$instances = @( 'http://localhost:4444', 'http://localhost:4454' )
$inventory = $instances | Get-Inventory -OutputFile /tmp/inventory.xml
.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $Url,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $InputFile,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OutputFile
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        [xml] $xmlDoc  = "<?xml version='1.0' encoding='ISO-8859-1'?><Inventory/>"
        $inventoryNode = $xmlDoc.CreateElement( 'Inventory' )
        $mastersNode = $xmlDoc.CreateElement( 'Masters' )
        
        $instances = @()
        $masterCount = 0
        $agentCount = 0
        $jobCount = 0
        $jobChainCount = 0
        $orderCount = 0
    }
    
    Process
    {
        if ( ( !$Url -and !$InputFile) -or ( $Url -and $InputFile ) )
        {
            throw "$MyInvocation.MyCommand.Name: one of the parameters -Url or -InputFile have to be specified"
        }

        if ( $InputFile )
        {
            $masterInstances = Import-CSV $InputFile -Header Url
        } else {
            $masterInstance = New-Object PSObject
            $masterInstance | Add-Member -Membertype NoteProperty -Name Url -Value $Url
            $masterInstances = @( $masterInstance )
        }
        
        foreach( $masterInstance in $masterInstances )
        {
            Use-Master -Url $masterInstance.Url | Out-Null
            $masterStatus = Get-Status
            $agentStatus = Get-AgentCluster | Get-AgentStatus
            
            $masterNode = $xmlDoc.CreateElement( 'Master' )
            $masterStatus.PSObject.Properties | Foreach { $masterNode.SetAttribute( $_.Name, $_.Value ) }
            
            $agentsNode = $xmlDoc.CreateElement( 'Agents' )
            for( $i=0; $i -lt $agentStatus.length; $i++ )
            {
                $agentNode = $xmlDoc.CreateElement( 'Agent' )
                $agentStatus[$i].PSObject.Properties | Foreach {
                    if ( !$_.Value.GetType().ToString().startsWith( 'System.Collections.' ) )
                    {
                        if ( $_.Value.GetType().fullname -eq 'System.Management.Automation.PSCustomObject' )
                        {
                            $_.Value.PSObject.Properties | Foreach {
                                $agentNode.SetAttribute( $_.Name, $_.Value )
                            }
                        } else {
                            $agentNode.SetAttribute( $_.Name, $_.Value )
                        }
                    }
                }
                $agentsNode.AppendChild( $agentNode ) | Out-Null
            }
            
            $masterNode.AppendChild( $agentsNode ) | Out-Null
            $mastersNode.AppendChild( $masterNode ) | Out-Null
    
            $masterCount++
            $agentCount += $agentStatus.count
            $jobCount += $masterStatus.JobsExist
            $jobChainCount += $masterStatus.JobChainsExist
            $orderCount += $masterStatus.OrdersExist
        }
    }

    End
    {
        if ( $OutputFile )
        {
            $xmlDoc.RemoveAll()
            $xmlDecl = $xmlDoc.CreateXmlDeclaration( '1.0', 'ISO-8859-1', $null )
            $xmlDoc.InsertBefore( $xmlDecl, $xmlDoc.DocumentElement ) | Out-Null
            $inventoryNode.AppendChild( $mastersNode ) | Out-Null
            $xmlDoc.AppendChild( $inventoryNode ) | Out-Null
    
            [System.XML.XmlWriterSettings] $xmlSettings = New-Object System.XML.XmlWriterSettings
            $xmlSettings.Encoding = [System.Text.Encoding]::GetEncoding("ISO-8859-1")
            $xmlSettings.Indent = $true
            $xmlSettings.NewLineChars = "`n"
            $xmlWriter = [Xml.XmlWriter]::Create( $OutputFile, $xmlSettings )
            $xmlDoc.Save( $xmlWriter )
            $xmlWriter.Close()
        }

        Write-Verbose ".. $MyInvocation.MyCommand.Name: inventory includes Master=$masterCount, Agent=$agentCount, Job=$jobCount, JobChain=$jobChainCount, Order=$orderCount"
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
        
        $xmlDoc
    }    
}

Set-Alias -Name Get-Inventory -Value Get-JobSchedulerInventory

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

.PARAMETER Append
Specifies that contents from an existing output file is preserved
and that the inventory information is added.

.EXAMPLE
$inventory = Get-JobSchedulerInventory http://localhost:4444

Returns the inventory for the specified JobScheduler Master instance.

.EXAMPLE
$inventory = Get-JobSchedulerInventory http://localhost:4444 -OutputFile /tmp/inventory.xml

Returns the inventory for the specified JobScheduler Master instance and
creates an XML output file that includes the inventory.

.EXAMPLE
$inventory = Get-JobSchedulerInventory -InputFile /tmp/inventory.csv -OutputFile /tmp/inventory.xml

Reads the input file "/tmp/inventory.csv" that includes a number of Master URLs.

The cmdlets checks the inventory for each Master specified and
creates an XML output file that includes the inventory.

.EXAMPLE
$instances = @( 'http://localhost:4444', 'http://localhost:4454' )
$inventory = $instances | Get-JobSchedulerInventory -OutputFile /tmp/inventory.xml
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
    [string] $OutputFile,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Append
)
    Begin
    {
        $stopWatch = Start-StopWatch

        if ( $Append -and ( Test-Path $OutputFile -PathType Leaf ) )
        {
            [xml] $xmlDoc = Get-Content $OutputFile
            $inventoryNode = $xmlDoc.Inventory
            $mastersNode = $xmlDoc.Inventory.Masters
            $masterCount = $mastersNode.SelectNodes( 'Master' ).count
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): found $($masterCount) Master instances from existing output file: $($OutputFile)"
        } else {
            [xml] $xmlDoc  = "<?xml version='1.0' encoding='ISO-8859-1'?><Inventory/>"
            $inventoryNode = $xmlDoc.CreateElement( 'Inventory' )
            $mastersNode = $xmlDoc.CreateElement( 'Masters' )
            $masterCount = 0
        }

        $agentCount = 0
        $jobCount = 0
        $jobChainCount = 0
        $orderCount = 0
        
        $agentClustersChecked = @()
        $agentInstancesChecked = @()
        $jobs = @()
        $jobResults = @()

        $jobScript = {
            Param ( [Uri] $masterUrl, [Uri] $agentUrl )
            Import-Module JobScheduler
            $state = Get-JobSchedulerAgentStatus -Url $agentUrl
            $state | Add-Member -Membertype NoteProperty -Name MasterUrl -Value $masterUrl
            $state
        }        
    }
    
    Process
    {
        if ( ( !$Url -and !$InputFile) -or ( $Url -and $InputFile ) )
        {
            throw "$($MyInvocation.MyCommand.Name): one of the parameters -Url or -InputFile has to be specified"
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
		    # enforce Uri datatype when reading master URLs from input file
            [Uri] $masterInstance.Url = $masterInstance.Url
			
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): checking Master: $($masterInstance.Url)"
            Use-Master -Url $masterInstance.Url | Out-Null
            $masterStatus = Get-Status
            $agentCluster = Get-AgentCluster 

            foreach( $agentClusterInstance in $AgentCluster ) 
            {
                if ( $agentClustersChecked -contains $agentClusterInstance.Path )
                {
                    continue
                } else {
                    $agentClustersChecked += $agentClusterInstance.Path
                }
                
                foreach( $agentInstance in $agentClusterInstance.Agents ) 
                {
                    if ( $agentInstancesChecked -contains $agentInstance.OriginalString )
                    {
                        continue
                    } else {
                        $agentInstancesChecked += $agentInstance.OriginalString
                    }
            
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): checking Master $($masterInstance.Url.OriginalString) for Agent: $($agentInstance.OriginalString)"
                    $jobs += Start-Job -Name $masterInstance.Url.OriginalString -ScriptBlock $jobScript -ArgumentList $masterInstance.Url.OriginalString, $agentInstance.OriginalString
                }
            }
        }                
    }

    End
    {
        Wait-Job -Job $jobs | Out-Null

        foreach ($job in $jobs) 
        {
            if ($job.State -eq 'Failed') {
                Write-Warning "$($MyInvocation.MyCommand.Name): $($job.ChildJobs[0].JobStateInfo.Reason.Message)"
            } else {
                $jobResults += Receive-Job -Job $job
            }
            
            Remove-Job -Job $job
        }

        foreach( $masterInstance in $masterInstances )
        {        
            $masterNode = $xmlDoc.CreateElement( 'Master' )
            $masterStatus.PSObject.Properties | Foreach { $masterNode.SetAttribute( $_.Name, $_.Value ) }
            
            $agentsNode = $xmlDoc.CreateElement( 'Agents' )
            for( $i=0; $i -lt $jobResults.length; $i++ )
            {
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): Receiving job result for Master $($masterInstance.Url)"
                if ( $jobResults[$i].MasterUrl -ne $masterInstance.Url )
                {
                    continue
                }
                
                $agentNode = $xmlDoc.CreateElement( 'Agent' )
                $jobResults[$i].PSObject.Properties | Foreach {
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

                $agentNode.SetAttribute( 'surveyCreated', ( Get-Date -Format u ).Replace(' ', 'T') )
                $agentsNode.AppendChild( $agentNode ) | Out-Null
                $agentCount++
            }
            
            $masterNode.SetAttribute( 'surveyCreated', ( Get-Date -Format u ).Replace(' ', 'T') )
            $masterNode.AppendChild( $agentsNode ) | Out-Null
            $mastersNode.AppendChild( $masterNode ) | Out-Null
    
            $masterCount++
            $jobCount += $masterStatus.JobsExist
            $jobChainCount += $masterStatus.JobChainsExist
            $orderCount += $masterStatus.OrdersExist
        }
    
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

        Write-Verbose ".. $($MyInvocation.MyCommand.Name): inventory includes Master=$masterCount, Agent=$agentCount, Job=$jobCount, JobChain=$jobChainCount, Order=$orderCount"
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
        
        $xmlDoc
    }    
}

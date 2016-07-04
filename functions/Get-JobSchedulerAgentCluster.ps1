function Get-JobSchedulerAgentCluster
{
<#
.SYNOPSIS
Returns a number of Agent clusters from the JobScheduler Master. Agent clusters correspond to process class 
objects in JobScheduler Master.

.DESCRIPTION
Agent clusters are retrieved from a JobScheduler Master, they correspond to process classes that specify 
a remote JobScheduler instance.

Agent clusters can be selected either by the folder of the Agent cluster location including subfolders 
or by an individual Agent cluster.

Resulting Agent clusters can be forwarded to cmdlets, such as Get-AgentStatus, for pipelined bulk operations.

.PARAMETER Directory
Optionally specifies the folder for which Agent clusters should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

One of the parameters -Directory and -AgentCluster has to be specified.

.PARAMETER AgentCluster
Optionally specifies the path and name of an Agent cluster that should be returned.
If the name of an Agent cluster is specified then the -Directory parameter is used to determine the folder.
Otherwise the -AgentCluster parameter is assumed to include the full path and name of the Agent cluster.

One of the parameters -Directory or -AgentCluster has to be specified.

.PARAMETER NoSubfolders
Specifies that no subfolders should be looked up. By default any subfolders will be searched for Agent clusters.

.PARAMETER NoCache
Specifies that the cache for JobScheduler Agent objects is ignored.
This results in the fact that for each Get-Agent* cmdlet execution the response is 
retrieved directly from the JobScheduler Master and is not resolved from the cache.

.OUTPUTS
This cmdlet returns an array of Agent cluster objects.

.EXAMPLE
$agentClusters = Get-AgentCluster

Returns all Agent clusters.

.EXAMPLE
$agentClusters = Get-AgentCluster -Directory / -NoSubfolders

Returns all Agent clusters that are configured with the root folder ("live" directory)
without consideration of subfolders.

.EXAMPLE
$agentClusters = Get-AgentCluster -AgentCluster /test/globals/Agent_01

Returns the Agent cluster "Agent_01" from the folder "/test/globals".

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $AgentCluster,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoSubfolders,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoCache
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch
        $agentClusterCount = 0
    }
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, AgentCluster=$AgentCluster"

        if ( !$Directory -and !$AgentCluster )
        {
            throw "$($MyInvocation.MyCommand.Name): no directory and no Agent cluster specified, use -Directory or -AgentCluster"
        }

        if ( $Directory -and $Directory -ne '/' )
        { 
            if ( $Directory.Substring( 0, 1) -ne '/' ) {
                $Directory = '/' + $Directory
            }
        
            if ( $Directory.Length -gt 1 -and $Directory.LastIndexOf( '/' )+1 -eq $Directory.Length )
            {
                $Directory = $Directory.Substring( 0, $Directory.Length-1 )
            }
        }

        if ( $AgentCluster ) 
        {
            if ( (Get-JobSchedulerObject-Basename $AgentCluster) -ne $AgentCluster ) # Agent cluster name includes a path
            {
                $Directory = Get-JobSchedulerObject-Parent $AgentCluster
            } else { # Agent cluster name includes no directory
                if ( $Directory -eq '/' )
                {
                    $AgentCluster = $Directory + $AgentCluster
                } else {
                    $AgentCluster = $Directory + '/' + $AgentCluster
                }
            }
        }

        $xPath = '//folder'

        if ( $Directory )
        {
            if ( $NoSubfolders )
            {
                $xPath += "[@path='$($Directory)']"
            } else {
                $xPath += "[starts-with(@path, '$($Directory)')]"
            }
        }

        if ( $AgentCluster )
        {
            $xPath += "/process_classes/process_class[@path = '$($AgentCluster)' and "
        } else {
            $xPath += '/process_classes/process_class['
        }
        
        $xPath += 'source/process_class[@remote_scheduler] or source/process_class/remote_schedulers/remote_scheduler[@remote_scheduler]]'
        
        if ( $NoCache -or !$SCRIPT:jsHasAgentCache )
        {
            $whatNoSubfolders = if ( $NoSubfolders ) { ' no_subfolders' } else { '' }
            $command = "<show_state subsystems='folder process_class' what='source folders$($whatNoSubfolders)' path='$($Directory)'/>"
    
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending request: $command"
        
            $SCRIPT:jsAgentCache = Send-JobSchedulerXMLCommand $js.Url $command

            if ( !$NoCache -and !$SCRIPT:jsNoAgentCache)
            {
                $SCRIPT:jsHasAgentCache = $true
            }
            
        }

        Write-Debug ".. $($MyInvocation.MyCommand.Name): using cache: $xPath"
        $agentClusterNodes = Select-XML -XML $SCRIPT:jsAgentCache -Xpath $xPath
        
        if ( $agentClusterNodes )
        {
            foreach( $agentClusterNode in $agentClusterNodes )
            {
                if ( !$agentClusterNode.Node.name )
                {
                    continue
                }
        
                $ac = Create-AgentClusterObject
                $ac.AgentCluster = $agentClusterNode.Node.name
                $ac.Path = $agentClusterNode.Node.path
                $ac.Directory = Get-JobSchedulerObject-Parent $agentClusterNode.Node.path
                $ac.MaxProcesses = $agentClusterNode.Node.max_processes
                
                if ( $agentClusterNode.Node.remote_scheduler )
                {
                    $ac.ClusterType = 'none'
                    $ac.Agents += [URI] $agentClusterNode.Node.remote_scheduler
                } else {
                    $ac.ClusterType = if ( $agentClusterNode.Node.remote_schedulers.select -eq 'next' ) { 'active' } else { 'passive' }
                    foreach( $agentNode in $agentClusterNode.Node.SelectNodes( 'source/process_class/remote_schedulers/remote_scheduler' ) ) {
                        $ac.Agents += [URI] $agentNode.GetAttribute( 'remote_scheduler' )
                    }
                }
                
                $ac
                $agentClusterCount++
            }            
        }
    }
    
    End
    {
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): $agentClusterCount Agent clusters found"
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

Set-Alias -Name Get-AgentCluster -Value Get-JobSchedulerAgentCluster

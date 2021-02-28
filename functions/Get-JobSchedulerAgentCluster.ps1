function Get-JobSchedulerAgentCluster
{
<#
.SYNOPSIS
Returns Agent Clusters from the JobScheduler Master.

.DESCRIPTION
Agent Clusters are retrieved from a JobScheduler Master.

Agent Clusters can be selected either by the folder of the Agent Cluster location including sub-folders
or by an individual Agent Cluster.

Resulting Agent Clusters can be forwarded to cmdlets, such as Get-JobSchedulerAgentStatus, for pipelined bulk operations.

.PARAMETER Directory
Optionally specifies the folder for which Agent Clusters should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

One of the parameters -Directory and -AgentCluster has to be specified.

.PARAMETER AgentCluster
Optionally specifies the path and name of an Agent Cluster that should be returned.
If the name of an Agent Cluster is specified then the -Directory parameter is used to determine the folder.
Otherwise the -AgentCluster parameter is assumed to include the full path and name of the Agent Cluster.

One of the parameters -Directory or -AgentCluster has to be specified.

.PARAMETER Recursive
Specifies that any sub-folders should be looked up. By default no sub-folders will be searched for Agent Clusters.

.OUTPUTS
This cmdlet returns an array of Agent Cluster objects.

.EXAMPLE
$agentClusters = Get-JobSchedulerAgentCluster

Returns all Agent Clusters.

.EXAMPLE
$agentClusters = Get-JobSchedulerAgentCluster -Directory /some_folder -Recursive

Returns all Agent Clusters that are configured with the folder "some_folder" (starting from the "live" directory)
and any sub-folders.

.EXAMPLE
$agentClusters = Get-JobSchedulerAgentCluster -AgentCluster /test/globals/Agent_01

Returns the Agent Cluster "Agent_01" from the folder "/test/globals".

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $AgentCluster,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Compact,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateSet(0,1,2)] [int] $State = 0
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        $objAgentClusters = @()
        $objFolders = @()
    }

    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, AgentCluster=$AgentCluster"

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

        if ( $Directory -eq '/' -and !$Recursive )
        {
            $Recursive = $true
        }

        if ( $AgentCluster )
        {
            if ( (Get-JobSchedulerObject-Basename $AgentCluster) -ne $AgentCluster ) # Agent Cluster name includes a path
            {
                $Directory = Get-JobSchedulerObject-Parent $AgentCluster
            } else { # Agent Cluster name includes no directory
                if ( $Directory -eq '/' )
                {
                    $AgentCluster = $Directory + $AgentCluster
                } else {
                    $AgentCluster = $Directory + '/' + $AgentCluster
                }
            }
        }

        if ( $AgentCluster )
        {
            $objAgentCluster = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'agentCluster' -value $AgentCluster -InputObject $objAgentCluster
            $objAgentClusters += $objAgentCluster
        } elseif ( $Directory ) {
            $objFolder = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'folder' -value $Directory -InputObject $objFolder
            Add-Member -Membertype NoteProperty -Name 'recursive' -value ( $Recursive -eq $true ) -InputObject $objFolder
            $objFolders += $objFolder
        }
    }

    End
    {
        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

        if ( $Compact )
        {
            Add-Member -Membertype NoteProperty -Name 'compact' -value ( $Compact -eq $true ) -InputObject $body
        }

        if ( $objAgentClusters )
        {
            Add-Member -Membertype NoteProperty -Name 'agentClusters' -value $objAgentClusters -InputObject $body
        }

        if ( $State )
        {
            Add-Member -Membertype NoteProperty -Name 'state' -value $State -InputObject $body
        }

        if ( $objFolders )
        {
            Add-Member -Membertype NoteProperty -Name 'folders' -value $objFolders -InputObject $body
        }

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest -Path '/jobscheduler/agent_clusters' -Body $requestBody

        if ( $response.StatusCode -eq 200 )
        {
            $volatileAgentClusters = ( $response.Content | ConvertFrom-JSON ).agentClusters
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }

        $returnAgentClusters = @()

        foreach( $volatileAgentCluster in $volatileAgentClusters )
        {
            $returnAgentCluster = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'AgentCluster' -value $volatileAgentCluster.path -InputObject $returnAgentCluster
            Add-Member -Membertype NoteProperty -Name 'Directory' -value $volatileAgentCluster.path -InputObject $returnAgentCluster
            $agents = @()

            foreach( $agent in $volatileAgentCluster.Agents )
            {
                $agents += $agent.url
            }

            Add-Member -Membertype NoteProperty -Name 'Agents' -value $agents -InputObject $returnAgentCluster
            Add-Member -Membertype NoteProperty -Name 'Volatile' -value $volatileAgentCluster -InputObject $returnAgentCluster

            $returnAgentClusters += $returnAgentCluster
        }

        $returnAgentClusters | Select-Object -Property `
                                            agentCluster, `
                                            @{name='path'; expression={ $_.agentCluster }}, `
                                            agents, `
                                            volatile

        if ( $returnAgentClusters.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($returnAgentClusters.count) Agent Clusters found"
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no Agent Clusters found"
        }

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

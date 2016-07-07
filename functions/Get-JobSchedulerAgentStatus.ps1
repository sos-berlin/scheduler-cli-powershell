function Get-JobSchedulerAgentStatus
{
<#
.SYNOPSIS
Return summary information and statistics information from a JobScheduler Agent.

.DESCRIPTION
Summary information and statistics information are returned from a JobScheduler Agent.

* Summary information includes e.g. the start date and JobScheduler Agent release.
* Statistics information includes e.g. the number of running tasks.

This cmdlet can be used to check if an Agent is available.

.PARAMETER Url
Specifies the URL to access the Agent.

This parameter cannot be specified if the -Agents parameter is used.

.PARAMETER Agents
Specifies an array of URLs that point to Agents. This is useful if a number of Agents
should be checked at the same time, e.g. should the Agents from the result of the
Get-AgentCluster cmdlet be checked.

This parameter cannot be specified if the -Url parameter is used.

.PARAMETER Path
Specifies the URL path that is used to retrieve the Agent status.

Default: /jobscheduler/agent/api/overview

.PARAMETER Timeout
Specifies the number of milliseconds for establishing a connection to the JobScheduler Agent.
With the timeout being exceeded the Agent is considered being unavailable.

Default: 1000 ms

.PARAMETER Display
Optionally specifies formatted output to be displayed.

.PARAMETER NoOutputs
Optionally specifies that no output is returned by this cmdlet.

.EXAMPLE
Get-AgentStatus http://localhost:4455

Returns summary information about the JobScheduler Agent.

.EXAMPLE
Get-AgentStatus -Url http://localhost:4455 -Display

Returns summary information about the Agent. Formatted output is displayed.

.EXAMPLE
$status = Get-AgentStatus http://localhost:4455

Returns a status information object.

.EXAMPLE
$status = Get-AgentCluster /agent/fixed_priority_scheduling_agent | Get-AgentStatus

Returns an array of status information objects each representing the state of an Agent in the cluster.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $Url,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [Uri[]] $Agents,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $Path = '/jobscheduler/agent/api/overview',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [int] $Timeout = 1000,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Display,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoOutputs
)
    Begin
    {
        $stopWatch = Start-StopWatch

        $agentsChecked = @()
    }

    Process
    {
        if ( !$Url -and !$Agents )
        {
            if ( $SCRIPT:jsAgent.Url )
            {
                [Uri] $Url = $SCRIPT:jsAgent.Url
            } else {
                throw "$($MyInvocation.MyCommand.Name): one of the parameters -Url or -Agents has to be specified"
            }
        } elseif ( $Url -and $Agents )
        {
            throw "$($MyInvocation.MyCommand.Name): one of the parameters -Url or -Agents has to be specified"
        }

        if ( !$Agents )
        {
            [Uri[]] $Agents = @( [Uri]$Url )
        }
        
        if ( $Timeout )
        {
            $SCRIPT:jsAgentOptionWebRequestTimeout = $Timeout
        }

        foreach( $agentUrl in $Agents )
        {
            # cast is required as for some weird reasons foreach forgets about the object type
            [Uri] $agentUrl = $agentUrl

            if ( $agentUrl )
            {
                # is protocol provided? e.g. http://localhost:4444
                if ( !$agentUrl.OriginalString.startsWith('http://') -and !$agentUrl.OriginalString.startsWith('https://') )
                {
                    $agentUrl = 'http://' + $agentUrl.OriginalString
                }
    
                # is valid hostname specified?
                if ( [System.Uri]::CheckHostName( $agentUrl.DnsSafeHost ).equals( [System.UriHostNameType]::Unknown ) )
                {
                    throw "$($MyInvocation.MyCommand.Name): no valid hostname specified, check use of -Url parameter, e.g. -Url http://localhost:4445: $($agentUrl.OriginalString)"
                }
                
                if ( $agentUrl.LocalPath -eq '/' -and $Path )
                {
                    $agentUrl = $agentUrl.OriginalString + $Path
                }
            }

            if ( $agentsChecked -contains $agentUrl.OriginalString )
            {
                continue
            } else {
                $agentsChecked += $agentUrl.OriginalString
            }
            
            try
            {
                Write-Debug ".. $($MyInvocation.MyCommand.Name): sending request to JobScheduler Agent $($agentUrl)"
                $state = Send-JobSchedulerAgentRequest $agentUrl 'GET'
                $state | Add-Member -Membertype NoteProperty -Name Url -Value "$($agentUrl.Scheme)://$($agentUrl.Authority)"
            } catch {
                Write-Warning ".. $($MyInvocation.MyCommand.Name): JobScheduler Agent not available at $($agentUrl)"
                $state = Create-AgentStateObject
                $state | Add-Member -Membertype NoteProperty -Name Url -Value "$($agentUrl.Scheme)://$($agentUrl.Authority)"
            }
    
            if ( $state )
            {
                if ( $Display )
                {
                    $output = "
________________________________________________________________________
Job Scheduler Agent URL: $($state.Url)
............... version: $($state.version)
.......... operated for: $($state.system.hostname)
......... running since: $($state.startedAt)
........ is terminating: $($state.isTerminating)
-..... total task count: $($state.totalTaskCount)
.... current task count: $($state.currentTaskCount)
________________________________________________________________________
                    "
                    Write-Output $output
                }
        
                if ( !$NoOutputs )
                {
                    $state
                }
            }
        }
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

Set-Alias -Name Get-AgentStatus -Value Get-JobSchedulerAgentStatus

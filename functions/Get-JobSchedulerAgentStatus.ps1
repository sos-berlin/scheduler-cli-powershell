function Get-JobSchedulerAgentStatus
{
<#
.SYNOPSIS
Return summary information and statistics information from a JobScheduler Agent.

.DESCRIPTION
Summary information and statistics information are returned from a JobScheduler Agent.

* Summary information includes e.g. the start date and JobScheduler Agent release.
* Statistics information includes e.g. the number of running tasks.

.PARAMETER Url
Specifies the URL to access the Agent.

This parameter cannot be specified if the -Agents parameter is used.

.PARAMETER Timeout
Specifies the number of milliseconds for establishing a connection to the JobScheduler Agent.
With the timeout being exceeded the Agent is considered being unavailable.

Default: 3000 ms

.PARAMETER Path
Specifies the URL path that is used to retrieve the Agent status.

Default: /jobscheduler/agent/api/overview

.PARAMETER Agents
Specifies an array of URLs that point to Agents. This is useful if a number of Agents
should be checked at the same time, e.g. should the Agents from the result of the
Get-AgentCluster cmdlet be checked.

This parameter cannot be specified if the -Url parameter is used.

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

Returns an array of status information objects each representing the state of one of Agents in the cluster.

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
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $Timeout = 5000,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Display,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoOutputs
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch
        $agentsChecked = @()
    }

    Process
    {
        if ( !$Url -and !$Agents )
        {
            if ( $SCRIPT:jsAgent.Url )
            {
                $Url = $SCRIPT:jsAgent.Url
            } else {
                throw "$($MyInvocation.MyCommand.Name): one of the parameters -Url or -Agents has to be specified"
            }
        } elseif ( $Url -and $Agents )
        {
            throw "$($MyInvocation.MyCommand.Name): one of the parameters -Url or -Agents has to be specified"
        }

        if ( !$Agents )
        {
            $Agents = @( $Url )
        }
        
        if ( $Timeout )
        {
            $SCRIPT:jsAgentOptionWebRequestTimeout = $Timeout
        }
        
        foreach( $Url in $Agents )
        {
            if ( $agentsChecked -contains $Url )
            {
                continue
            } else {
                $agentsChecked += $Url
            }
            
            if ( $Url )
            {
                # is protocol provided? e.g. http://localhost:4444
                if ( !$Url.OriginalString.startsWith('http://') -and !$Url.OriginalString.startsWith('https://') )
                {
                    $Url = 'http://' + $Url.OriginalString
                }
    
                # is valid hostname specified?
                if ( [System.Uri]::CheckHostName( $Url.DnsSafeHost ).equals( [System.UriHostNameType]::Unknown ) )
                {
                    throw "$($MyInvocation.MyCommand.Name): no valid hostname specified, check use of -Url parameter, e.g. -Url http://localhost:4445: $($Url.OriginalString)"
                }
                
                if ( $Url.LocalPath -eq '/' -and $Path )
                {
                    $Url = $Url.OriginalString + $Path
                }
            }

            try
            {
                Write-Debug ".. $($MyInvocation.MyCommand.Name): sending request to JobScheduler Agent $($Url)"
                $state = Send-JobSchedulerAgentRequest $Url 'GET'
                $state | Add-Member -Membertype NoteProperty -Name Url -Value $Url
            } catch {
                Write-Warning ".. $($MyInvocation.MyCommand.Name): JobScheduler Agent not available at $($Url)"
                $state = Create-AgentStateObject
                $state | Add-Member -Membertype NoteProperty -Name Url -Value $Url
            }
    
            if ( $state )
            {
                if ( $Display )
                {
                    $output = "
________________________________________________________________________
Job Scheduler Agent URL: $($Url)
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

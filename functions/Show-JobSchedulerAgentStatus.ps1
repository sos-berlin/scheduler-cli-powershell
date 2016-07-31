function Show-JobSchedulerAgentStatus
{
<#
.SYNOPSIS
Show summary information and statistics information for a JobScheduler Agent.

.DESCRIPTION
This cmdlet is an alias for Get-JobSchedulerAgentStatus -Display -NoOutputs

.PARAMETER Url
Specifies the URL to access the Agent.

This parameter cannot be specified if the -Agents parameter is used.

.PARAMETER Agents
Specifies an array of URLs that point to Agents. This is useful if a number of Agents
should be checked at the same time, e.g. should the Agents from the result of the
Get-JobSchedulerAgentCluster cmdlet be checked.

This parameter cannot be specified if the -Url parameter is used.

.PARAMETER Path
Specifies the URL path that is used to retrieve the Agent status.

Default: /jobscheduler/agent/api/overview

.PARAMETER Timeout
Specifies the number of milliseconds for establishing a connection to the JobScheduler Agent.
With the timeout being exceeded the Agent is considered being unavailable.

Default: 3000 ms

.EXAMPLE
Show-JobSchedulerAgentStatus http://localhost:4445

Returns the summary information of the JobScheduler Agent for the specified host and port.

.EXAMPLE
Get-JobSchedulerAgentCluster | Show-JobSchedulerAgentStatus

Returns the summary information and statistics information about all JobScheduler Agents
that are configured with the JobScheduler Master that is currently in use.

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
    [int] $Timeout = 3000
)
    Begin
    {
		$clusters = @()
    }

    Process
    {
        $parameters = @{ 'Url'=$Url; 'Agents'=$Agents; 'Path'=$Path; 'Timeout'=$Timeout }
        $arguments = New-Object System.Management.Automation.PSObject -Property $parameters
        $clusters += $arguments
    }

	End
	{
        $clusters | Get-JobSchedulerAgentStatus -Display -NoOutputs        
	}
}

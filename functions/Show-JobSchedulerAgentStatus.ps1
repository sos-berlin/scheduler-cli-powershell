function Show-JobSchedulerAgentStatus
{
<#
.SYNOPSIS
Show summary information and statistics information of a JobScheduler Agent.

.DESCRIPTION
This cmdlet is an alias for Get-JobSchedulerAgentStatus -Display -NoOutputs

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
    [string] $Path = '/jobscheduler/agent/api/overview'
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
		$clusters = @()
    }

    Process
    {
        $parameters = @{ 'Url'=$Url; 'Agents'=$Agents; 'Path'=$Path }
        $arguments = New-Object System.Management.Automation.PSObject -Property $parameters
        $clusters += $arguments
    }

	End
	{
        $clusters | Get-JobSchedulerAgentStatus -Display -NoOutputs        
	}
}

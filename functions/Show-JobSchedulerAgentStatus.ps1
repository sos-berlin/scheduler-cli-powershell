function Show-JobSchedulerAgentStatus
{
<#
.SYNOPSIS
Show summary information and statistics information of a JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Get-Status -Display -NoOutputs

.EXAMPLE
Show-Status

Returns the summary information of JobScheduler Master.

.EXAMPLE
Show-Status -Statistics

Returns the summary information and statistics information about jobs and ordes.

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
    }

    Process
    {
        $parameters = @{ 'Url'=$Url; 'Agents'=$Agents; 'Path'=$Path }
        $arguments = New-Object System.Management.Automation.PSObject -Property $parameters
        $arguments | Get-JobSchedulerAgentStatus -Display -NoOutputs        
    }
}

Set-Alias -Name Show-AgentStatus -Value Show-JobSchedulerAgentStatus

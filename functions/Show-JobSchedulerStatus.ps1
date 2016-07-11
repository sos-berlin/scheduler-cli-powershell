function Show-JobSchedulerStatus
{
<#
.SYNOPSIS
Show summary information and statistics information of a JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Get-JobSchedulerStatus -Display -NoOutputs

.EXAMPLE
Show-JobSchedulerStatus

Returns the summary information of a JobScheduler Master.

.EXAMPLE
Show-JobSchedulerStatus -Statistics

Returns the summary information and statistics information about jobs and orders.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipelinebyPropertyName=$True)]
	[switch] $Statistics
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand
	}

    Process
    {
		$parameters = @{ "Statistics"=$Statistics }
		$arguments = New-Object System.Management.Automation.PSObject -Property $parameters
		$arguments | Get-JobSchedulerStatus -Display -NoOutputs		
    }
}

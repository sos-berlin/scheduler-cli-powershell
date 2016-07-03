function Show-JobSchedulerStatus
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

Set-Alias -Name Show-Status -Value Show-JobSchedulerStatus

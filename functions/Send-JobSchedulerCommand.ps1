function Send-JobSchedulerCommand
{
<#
.SYNOPSIS
Sends an XMl command to the JobScheduler Master.

.DESCRIPTION
JobScheduler Master supports a number of XML commands.
This cmdlet accepts XML commands and forward them to the JobScheduler Master.

.PARAMETER Command
Specifies the XML command to be executed, e.g. <show_state/>

.OUTPUTS
This cmdlet returns the XML object of the JobScheduler response.

.EXAMPLE
$stateXml = Send-Command '<show_state/>'

Returns summary information and inventory of jobs and job chains.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Command
)

	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand
	}

    Process
    {
        if ( !$Command )
        {
            throw "$($MyInvocation.MyCommand.Name): no XML command specified, use -Command"
        }
        
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command: $Command"
        
        Send-JobSchedulerXMLCommand $js.Url $Command
    }
}

Set-Alias -Name Send-Command -Value Send-JobSchedulerCommand

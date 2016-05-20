function Suspend-JobSchedulerMaster
{
<#
.SYNOPSIS
Pause JobScheduler Master, i.e. prevent any tasks from starting.
Respectively the Resume-JobSchedulerInstance cmdlet will resume operations.

.DESCRIPTION
When JobScheduler Master is paused then

* no new tasks are started
* running tasks are continued to complete:
** shell jobs will continue until their normal termination.
** API jobs complete a current spooler_process() call.
* any task starts that would normally occur during the pause period are postponed until JobScheduler Master is continued.

.EXAMPLE
Suspend-Master

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand
	}

    Process
    {
        $command = "<modify_spooler cmd='pause'/>"

        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command: $command"
        
        $result = Send-JobSchedulerXMLCommand $js.Url $command
    }
}

Set-Alias -Name Suspend-Master -Value Suspend-JobSchedulerMaster

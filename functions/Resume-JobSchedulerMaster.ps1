function Resume-JobSchedulerMaster
{
<#
.SYNOPSIS
Continue JobScheduler Master that has previously been paused.
This command is typically executed after a Suspend-JobSchedulerMaster command.

.DESCRIPTION
When JobScheduler Master is continued then

* any task starts that would normally have occurred during the pause period are immediately executed.

.EXAMPLE
Resume-Master

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
)
    Process
    {
        $command = "<modify_spooler cmd='continue'/>"

        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command: $command"
        
        $result = Send-JobSchedulerXMLCommand $js.Url $command
    }
}

Set-Alias -Name Resume-Master -Value Resume-JobSchedulerMaster

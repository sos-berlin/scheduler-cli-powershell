function Get-JobSchedulerVersion
{
<#
.SYNOPSIS
Returns the JobScheduler Master version

.DESCRIPTION
The cmdlet returns the version of the JobScheduler Master.

.EXAMPLE
Get-Version

Returns the JobScheduler version.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
)
    Begin
    {
        # Approve-JobSchedulerCommand $MyInvocation.MyCommand
    }
    
    Process
    {
        # $arguments = "-ini=$(($js.Config.FactoryIni).Replace( '/', '\' )) -config=$($js.Config.SchedulerXml) -V"                        
        # Write-Host ".. $($MyInvocation.MyCommand.Name): executing version command: $($js.Install.ExecutableFile) $($arguments)"

        # $process = Start-Process -FilePath """$($js.Install.ExecutableFile)""" "$($arguments)" -PassThru 

        $command = "<show_state what='job_chain_orders' max_task_history='0'/>"
        Write-Debug ". $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
        Write-Debug ". $($MyInvocation.MyCommand.Name): sending command: $command"
            
        $stateXml = Send-JobSchedulerXMLCommand $js.Url $command    
        if ( $stateXml )
        {
          $stateXml.spooler.answer.state.version
        }
    }
}

Set-Alias -Name Get-Version -Value Get-JobSchedulerVersion

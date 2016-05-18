function Start-JobSchedulerMaster
{
<#
.SYNOPSIS
Starts the JobScheduler Master

.DESCRIPTION
JobScheduler can be started in service mode and in dialog mode:

* Service Mode: the Windows service of the JobScheduler Master is started.
* Dialog Mode: the JobScheduler Master is started in the context of the current user account.

.PARAMETER Service
Starts the JobScheduler Windows service.

Without this parameter being specified JobScheduler will be started in dialog mode.

.PARAMETER Pause
Specifies that the JobScheduler is paused after start-up.

When used with -Service then the pause is applied to the initial start-up only, it is not applied
to further starts, e.g. carried out by the Windows service panel.

.PARAMETER PauseAfterFailure
Specifies that the JobScheduler Master will pause on start-up if it has previously been terminated with an error.

When used with -Service then this behavior will apply to each start of the Windows service, 
e.g. by use of the Windows service panel.

.EXAMPLE
Start-Master

Starts the JobScheduler Master in dialog mode.

.EXAMPLE
Start-Master -Service

Starts the JobScheduler Master Windows service.

.LINK
about_jobscheduler

#>
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
	[switch] $Service,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
	[switch] $Cluster,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
	[switch] $Pause,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
	[switch] $PauseAfterFailure
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand
	}

	Process
	{
		if ( $Service )
		{
			if ( $PauseAfterFailure )
			{
				throw ".. $($MyInvocation.MyCommand.Name): parameters -Service and -PauseAfterFailure not compatible, use Install-JobSchedulerService cmdlet to run the service with -PauseAfterFailure"
			}
			
			Write-Verbose ".. $($MyInvocation.MyCommand.Name): starting JobScheduler service with ID '$($js.Id)' at '$($js.Hostname):$($js.Port)'"
            $serviceInstance = Start-Service -Name $js.Service.serviceName -PassThru

			if ( $Pause )
			{
				Start-Sleep -Seconds 3
				$result = $serviceInstance.Pause()
			}
		} else {
			if ( $PauseAfterFailure )
			{
				$startOptions = ' -pause-after-failure'
			} else {
				$startOptions = ''
			}

			$command = """$($js.Install.ExecutableFile)"" $($js.Install.StartParams)$($startOptions)"
			Write-Debug ".. $($MyInvocation.MyCommand.Name): start by command: $command"
			Write-Verbose ".. $($MyInvocation.MyCommand.Name): starting JobScheduler instance with ID '$($js.Id)' at '$($js.Hostname):$($js.Port)'"
			$process = Start-Process -FilePath "$($js.Install.ExecutableFile)" "$($js.Install.StartParams)" -PassThru
			
			if ( $Pause )
			{
				Start-Sleep -Seconds 3
				$command = "<modify_spooler cmd='pause'/>"

				Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Hostname):$($js.Port)"
				Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command: $command"
        
				$result = Send-JobSchedulerXMLCommand $js.Hostname $js.Port $command
			}
		}
	}
}

Set-Alias -Name Start-Master -Value Start-JobSchedulerMaster

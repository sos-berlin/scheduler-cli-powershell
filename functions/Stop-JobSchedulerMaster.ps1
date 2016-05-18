function Stop-JobSchedulerMaster
{ 
<#
.SYNOPSIS
Stops a JobScheduler Master

.DESCRIPTION
The stopping of a Master can be performed in a graceful manner leaving some time to 
running tasks for completion. In addition more immediate operations for aborting
or killing a Master are available and Master instances can be restarted.

.PARAMETER Action
Stopping includes the following actions:

* Action "terminate" (Default)
** no new tasks are started.
** running tasks are continued to complete:
*** shell jobs will continue until their normal termination.
*** API jobs complete a current spooler_process() call.
** JobScheduler Master terminates normally.

* Action "terminate-fail-safe"
** terminates an instance in the same way as -Action "terminate".
** in addition in a Passive Cluster the backup instance will be activated after termination of the primary instance.

* Action "abort"
** no new tasks are started.
** any running tasks are killed.
** JobScheduler Master terminates normally.

* Action "kill"
** the process of the JobScheduler Master is killed including any tasks running.
** no cleanup is performed, e.g. database connections are not closed.
** this action might require elevated privileges of an administrator.

.PARAMETER Restart
When used with the operations -Action "terminate" and "abort" then the
JobScheduler instance will shut down and restart.

This switch can be used with the -Cluster swith to restart a JobScheduler Cluster.

.PARAMETER Cluster
Carries out the operation -Action "terminate" for a JobScheduler Cluster:

* All instances are terminated and optionally restarted.
* Optional -Timeout settings apply to this operation.

.PARAMETER Timeout
A timeout is applied for the operation -Action "terminate" that affects running tasks:

* For shell jobs
** in a Unix environment the task is sent a SIGTERM signal and - in case of the timeout parameter being used - 
after expiration of the timeout a SIGKILL signal is sent.
** in a Windows environment the task is killed immediately.
* For API jobs
** the method spooler_process() of the respective job will not be called by JobScheduler any more. 
** the task is expected to terminate normally after completion of its spooler_process() method.

The timeout is applied when shutting down or restarting (-Restart switch) invidual instances or clustered instances (-Cluster switch).

.PARAMETER Pid
When carrying out the operation -Action "kill" then

* with the PID being specified the given process will be killed
* with no PID being specified the PID is used from the PID file that is created on JobScheduler start.

.PARAMETER Service
Stops the JobScheduler Windows Service

Use of this parameter ignores any other parameters.
The Windows service is stopped as specified with -Action "terminate".
No timeout and no cluster operations are applied.

.EXAMPLE
Stop-Master

Stops the JobScheduler instance with normal termination.
This is the same as the operation: Stop-Instance -Action "terminate"

.EXAMPLE
Stop-Master -Service

Stops the JobScheduler Windows service with normal termination,
i.e. with -Action "terminate" without any timeouts and cluster options being applied.

.EXAMPLE
Stop-Master -Action abort -Restart

Stops the JobScheduler instance by immediately killing any tasks and aborting the JobScheduler Master.
After shutdown the JobScheduler instance is restarted.

.EXAMPLE
Stop-Master -Action kill

Kills the JobScheduler process and any tasks without proper cleanup.

.EXAMPLE
Stop-Master -Cluster -Timeout 30

Carries out the -Action "terminate" operation for all members of a JobScheduler Cluster.
All running tasks are sent a SIGTERM signal and after expiration of the timeout
any running tasks will be sent a SIGKILL signal.

.EXAMPLE
Stop-Master -Restart -Cluster -Timeout 30

Carries out the -Action "terminate" operation for all members of a JobScheduler Cluster.
All running tasks are sent a SIGTERM signal and after expiration of the timeout
any running tasks will be sent a SIGKILL signal.

After termination all cluster members willl be restarted.

.LINK
about_jobscheduler

#>
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateSet('terminate','terminate-fail-safe','abort','kill')] [string] $Action = "terminate",
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Restart,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Cluster,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $Timeout,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [int] $Pid,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Service
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
    }

    Process
    {
        if ( $Service )
        {
            $serviceInstance = $null
            $serviceName = $js.Service.ServiceName

            # Check an existing service
            try 
            {
                $serviceInstance = Get-Service $serviceName -ErrorAction SilentlyContinue
            } catch {
                throw "$($MyInvocation.MyCommand.Name): could not find service: $($_.Exception.Message)"
            }
        
            # stop an existing service
            try
            {
                if ( $serviceInstance -and $serviceInstance.Status -eq "running" )
                {
                    Write-Verbose ".. $($MyInvocation.MyCommand.Name): stop JobScheduler service: $($serviceName)"       
                    $result = Stop-Service -Name $serviceName
                    Start-Sleep -s 3
                }
            } catch {
                throw "$($MyInvocation.MyCommand.Name): could not stop service: $($_.Exception.Message)"
            }
                
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): JobScheduler service stopped: $($serviceName)"
        } else {
            switch ( $Action )
            {
                'terminate' 
                {
                    if ( $Timeout )
                    {
                        $attributeTimeout = " timeout='$($Timeout)'"
                        $messageTimeout = " with timeout $($Tiemout)s"
                    } else {
                        $attributeTimeout = ""
                        $messageTimeout = ""
                    }
    
                    if ( $Cluster )
                    {                            
                        if ( $Restart )
                        {
                            Write-Verbose ".. $($MyInvocation.MyCommand.Name): restarting JobScheduler cluster$($messageTimeout)"
                            $command = "<terminate all_schedulers='yes' restart='yes'$($attributeTimeout)/>"
                        } else {
                            Write-Verbose ".. $($MyInvocation.MyCommand.Name): shutting down JobScheduler cluster$($messageTimeout)"
                            $command = "<terminate all_schedulers='yes'$($attributeTimeout)/>"
                        }
                    } else {
                        if ( $Restart )
                        {
                            Write-Verbose ".. $($MyInvocation.MyCommand.Name): restarting JobScheduler gracefully$($messageTimeout)"
                            $command = "<modify_spooler cmd='terminate_and_restart'$($attributeTimeout)/>"
                        } else {
                            Write-Verbose ".. $($MyInvocation.MyCommand.Name): shutting down JobScheduler gracefully$($messageTimeout)"
                            $command = "<modify_spooler cmd='terminate'$($attributeTimeout)/>"
                        }
                    }
    
                    Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Hostname):$($js.Port)"
                    Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command: $command"

                    $result = Send-JobSchedulerXMLCommand $js.Hostname $js.Port $command
                }
                'terminate-fail-safe' 
                {
                    if ( $Timeout )
                    {
                        Write-Verbose ".. $($MyInvocation.MyCommand.Name): shutting down JobScheduler fail-safe with timeout $($Timeout)s"
                        $terminateTimeout = " timeout='$($Timeout)'"
                    } else {
                        Write-Verbose ".. $($MyInvocation.MyCommand.Name): shutting down JobScheduler fail-safe"
                        $terminateTimeout
                    }
                    $command = "<terminate continue_exclusive_operation='yes'$($terminateTimeout)/>"
    
                    Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Hostname):$($js.Port)"
                    Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command: $command"
            
                    $result = Send-JobSchedulerXMLCommand $js.Hostname $js.Port $command
                }
                'abort' 
                {
                    if ( $Restart ) {
                        Write-Verbose ".. $($MyInvocation.MyCommand.Name): shutting down JobScheduler immediately and restarting"
                        $command = "<modify_spooler cmd='abort_immediately_and_restart'/>"
                    } else {
                        Write-Verbose ".. $($MyInvocation.MyCommand.Name): shutting down JobScheduler immediately"
                        $command = "<modify_spooler cmd='abort_immediately'/>"
                    }
    
                    Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Hostname):$($js.Port)"
                    Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command: $command"
            
                    $result = Send-JobSchedulerXMLCommand $js.Hostname $js.Port $command
                }
                'kill' 
                {
                    if ( $Pid )
                    {
                        Write-Verbose ".. $($MyInvocation.MyCommand.Name): killing JobScheduler from process list with PID $Pid"
                        $arguments = "-kill=$($Pid)"
                    } else {
                        Write-Verbose ".. $($MyInvocation.MyCommand.Name): killing JobScheduler from process list with PID file"
                        $arguments = "-kill -pid-file=$($js.Install.PidFile)"
                    }
                    
                    Write-Debug ".. $($MyInvocation.MyCommand.Name): kill by command: $($arguments)"
                    $process = Start-Process -FilePath "$($js.Install.ExecutableFile)" "$($arguments)" -PassThru
                }
            }
        }
    }
}

Set-Alias -Name Stop-Master -Value Stop-JobSchedulerMaster

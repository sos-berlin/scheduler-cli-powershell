function Start-JobSchedulerAgent
{
<#
.SYNOPSIS
Starts the JobScheduler Agent

.DESCRIPTION
JobScheduler can be started in service mode and in dialog mode:

* Service Mode: the Windows service of the JobScheduler Master is started.
* Dialog Mode: the JobScheduler Master is started in the context of the current user account.

.PARAMETER Service
Starts the JobScheduler Windows service.

Without this parameter being specified JobScheduler will be started in dialog mode.

.PARAMETER Cluster
Specifies that the JobScheduler instance is a cluster member.

* An active cluster operates a number of instances for shared job execution
* A passive cluster operates a single instance as a primary JobScheduler and any number of additional instances as backup JobSchedulers.

When using -Cluster "passive" then the -Backup parameter can be used to specify that the instance to be installed is a backup JobScheduler.

.PARAMETER Backup
Specifies that the JobScheduler instance is a backup instance in a passive cluster.

Backup instances use the same JobScheduler ID and database connection as the primary instance.

This parameter can only be used with -Cluster "passive".

.PARAMETER Pause
Specifies that the JobScheduler is paused after start-up.

When used with -Service then the pause is applied to the initial start-up only, it is not applied
to further starts, e.g. carried out by the Windows service panel.

.PARAMETER PauseAfterFailure
Specifies that the JobScheduler Master will pause on start-up if it has previously been terminated with an error.

When used with -Service then this behavior will apply to each start of the Windows service, 
e.g. by use of the Windows service panel.

.EXAMPLE
Start-JobSchedulerAgent

Starts the JobScheduler Agent in dialog mode.

.EXAMPLE
Start-JobSchedulerAgent -Service

Starts the JobScheduler Agent Windows service.

.LINK
about_jobscheduler

#>
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Service,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $HttpPort = '127.0.0.1:4445',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $HttpsPort,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $ConfigDirectory,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $LogDirectory,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $PidFileDirectory,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $WorkingDirectory,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $KillScript,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $InstanceScript = 'jobscheduler_agent_[port].cmd',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $JavaHome,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [string] $JavaOptions = '-Xms100m'
)
    Begin
    {
        Approve-JobSchedulerAgentCommand $MyInvocation.MyCommand
    }

    Process
    {
        if ( $Service )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): starting JobScheduler Agent service with Url '$($jsAgent.Url)'"
            $serviceInstance = Start-Service -Name $jsAgent.Service.serviceName -PassThru
        } else {
			$httpPortNumber = $HttpPort.Substring( $HttpPort.IndexOf( ':' )+1 )
		
			$SCRIPT:jsAgent.Config.Directory = $ConfigDirectory
			
			$SCRIPT:jsAgent.Install.HttpPort = $HttpPort
			$SCRIPT:jsAgent.Install.HttpsPort = $HttpsPort
			$SCRIPT:jsAgent.Install.LogDirectory = $LogDirectory
			$SCRIPT:jsAgent.Install.PidFileDirectory = $PidFileDirectory
			$SCRIPT:jsAgent.Install.WorkingDirectory = $WorkingDirectory
			$SCRIPT:jsAgent.Install.KillScript = $KillScript
			$SCRIPT:jsAgent.Install.InstanceScript = $SCRIPT:jsAgent.Install.Directory + '\bin\' + ( $InstanceScript -replace '\[port\]', $httpPortNumber )
			
			$parameters = @{}
			
			if ( $SCRIPT:jsAgent.Install.Directory )
			{
				$parameters.Add( 'SchedulerHome', $SCRIPT:jsAgent.Install.Directory )
			}
			
			if ( $SCRIPT:jsAgent.Config.Directory )
			{
				$parameters.Add( 'SchedulerData', $SCRIPT:jsAgent.Config.Directory )
			}
			
			if ( $HttpPort )
			{
				$parameters.Add( 'HttpPort', $HttpPort )
			}
			
			if ( $HttpsPort )
			{
				$parameters.Add( 'HttpsPort', $HttpsPort )
			}

			if ( $LogDirectory )
			{
				$parameters.Add( 'LogDirectory', $LogDirectory )
			}
			
			if ( $PidFileDirectory )
			{
				$parameters.Add( 'PidFileDirectory', $PidFileDirectory )
			}

			if ( $WorkingDirectory )
			{
				$parameters.Add( 'WorkingDirectory', $WorkingDirectory )
			}
			
			if ( $KillScript )
			{
				$parameters.Add( 'KillScript', $KillScript )
			}
			
			if ( $JavaHome )
			{
				$parameters.Add( 'JavaHome', $JavaHome )
			}
			
			if ( $JavaOptions )
			{
				$parameters.Add( 'JavaOptions', $JavaOptions )
			}
			
			$javaLocations = Get-Command javaw.exe
			if ( !$javaLocations )
			{
				throw "could not find location for javaw.exe"
			}

			$schedulerLogFile = "$($LogDirectory)\jobscheduler_agent_$($httpPortNumber)"
			
#   		$parameters = @{ 'SchedulerHome'=$SCRIPT:jsAgent.Install.Directory; 'SchedulerData'=$SCRIPT:jsAgent.Config.Directory; 'HttpPort'=$HttpPort; 'HttpsPort'=$HttpsPort; 'LogDirectory'=$LogDirectory; 'PidFileDirectory'=$PidFileDirectory; 'WorkingDirectory'=$WorkingDirectory; 'KillScript'=$KillScript; 'JavaHome'=$JavaHome; 'JavaOptions'=$JavaOptions }
#			$parameters | Create-AgentInstanceScript | Out-File $SCRIPT:jsAgent.Install.InstanceScript -Encoding ASCII	
			
#            $command = """$($SCRIPT:jsAgent.Install.InstanceScript)"" $($SCRIPT:jsAgent.Install.StartParams)$($startOptions)"
#            Write-Debug ".. $($MyInvocation.MyCommand.Name): start by command: $command"
#            Write-Verbose ".. $($MyInvocation.MyCommand.Name): starting JobScheduler Agent instance with URL '$($jsAgent.Url)'"
#           $process = Start-Process -FilePath "$($SCRIPT:jsAgent.Install.InstanceScript)" "$($jsAgent.Install.StartParams)$($startOptions)" -PassThru            
#           $process = Start-Process -FilePath "$($SCRIPT:jsAgent.Install.InstanceScript)" -PassThru
#           $process = Start-Process -FilePath 'cmd.exe' "/c ""`"$($SCRIPT:jsAgent.Install.InstanceScript)`" $($SCRIPT:jsAgent.Install.StartParams)$($startOptions)"" " -NoNewWindow -PassThru

#           start "JobSchedulerAgent" /D "%SCHEDULER_WORK_DIR%" /B /WAIT "%JAVAWBIN%" -DLOGFILE="%SCHEDULER_LOGFILE%" %JAVA_OPTIONS% -classpath "%SCHEDULER_CLASSPATH%" com.sos.scheduler.engine.agent.main.AgentMain -http-port=%SCHEDULER_HTTP_PORT% %HTTPS_PORT_OPTION% -data-directory="%SCHEDULER_DATA%" -log-directory="%SCHEDULER_LOG_DIR%" %KILL_SCRIPT_OPTION% -job-java-options="-DLOGFILE=%SCHEDULER_LOGFILE%"
            $process = Start-Process -FilePath 'cmd.exe' "/c ""start /D `"$($WorkingDirectory)`" /B /WAIT `"$($javaLocations[0].Definition)`" -DLOGFILE=`"$($schedulerLogFile)`" $($JavaOptions) -classpath `"$($SchedulerClasspath)`" com.sos.scheduler.engine.agent.main.AgentMain -http-port=$($HttpPort) -data-directory=`"$($ConfigDirectory)`" -log-directory=`"$($LogDirectory)`" $($KillScript) -job-java-options=`"-DLOGFILE=$($SchedulerLogFile)`""" " -NoNewWindow -PassThru

			$process
        }
    }
}

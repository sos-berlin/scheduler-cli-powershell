function Use-JobSchedulerMaster
{
<#
.SYNOPSIS
This cmdlet is required to be used as the first operation with JobScheduler cmdlets.

Applies settings from a JobScheduler Master location. A Master is identified
by its JobScheduler ID and Url for which it is operated.

For a local Master settings are imported from its installation directory.
For a remote Master settings are specified by parameters.

.DESCRIPTION
During installation of a JobScheduler Master a number of settings are specified. 
Such settings are imported for use with subsequent cmdlets.

* For a local Master that is installed on the local computer the cmdlet reads
settings from the installation path.
* For a remote Master the parameter -Remote has to be used with the -Id and -Url
parameters to specify the instance.

.PARAMETER Id
Specifies the ID of a JobScheduler Master.
The installation path is determined from the -BasePath parameter and the JobScheduler ID,
therefore no -InstallPath parameter has to be specified.

.PARAMETER Url
Specifies the Url for which a JobScheduler Master is available.

The Url includes one of the protocols http or https and optionally the port that JobScheduler listens to, e.g. http://gollum.sos:4110

.PARAMETER Remote
Specifies if the JobScheduler Master to be used is a remote instance. 
By default a local instance is assumed with the Master being installed on the local computer.

Use this switch in addition to the parameters -Id and -Url to use a remote Master.

.PARAMETER InstallPath
Specifies the installation path of a JobScheduler Master.
The installation path is expected to be accessible from the host on which the JobScheduler cmdlets are executed.

.PARAMETER BasePath
Specifies the base path of a JobScheduler Master installation. This parameter is used in
combination with the -Id parameter to determine the installation path.

Default Value: C:\Program Files\sos-berlin.com\jobscheduler

.PARAMETER EnvironmentVariablesScript
Specifies the name of the script that includes environment variables of a JobScheduler Master installation.
Typically the script name is "jobscheduler_environment_variables.cmd" and the script is available
from the "bin" directory and optionally "user_bin" directory of a JobScheduler installation directory.

Default Value: jobscheduler_environment_variables.cmd

.EXAMPLE
Use-Master scheduler110

Imports settings from the the JobScheduler Master with ID "scheduler110".
The installation path is determined from the default value of the -BasePath parameter.

.EXAMPLE
Use-Master -InstallPath "C:\Program Files\sos-berlin.com\jobscheduler\scheduler110"

Imports settings from the specified installation path.

.EXAMPLE
Use-Master -InstallPath $env:SCHEDULER_HOME

Imports settings from the installation path that is specified from the SCHEDULER_HOME environment variable.

.EXAMPLE
Use-Master -Remote -Id scheduler110 -Url http://gollum.sos:4454

Uses the specified JobScheduler Master as the base for cmdlets of this module.
Cmdlets that require a local Master cannot be used, e.g. Install-Service, Remove-Service, Start-Master.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
	[string] $Id,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
	[string] $Url,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Remote,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $InstallPath,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $BasePath                       = 'C:\Program Files\sos-berlin.com\jobscheduler',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EnvironmentVariablesScript     = 'jobscheduler_environment_variables.cmd'
)
	Process
	{
		if ( !$InstallPath -and !$Id )
		{
			throw "one of the parameters -Id or -InstallPath has to be specified"
		}

		if ( $SCRIPT:jsWriter )
		{
			$SCRIPT:jsWriter.Close()
			$SCRIPT:jsWriter = $null
		}
		
		if ( $SCRIPT:jsStream )
		{
			$SCRIPT:jsStream.Close()
			$SCRIPT:jsStream = $null
		}
		
		if ( $SCRIPT:jsSocket )
		{
			$SCRIPT:jsSocket = $null
		}

		$SCRIPT:js = Create-JSObject

		if ( $Id )
		{
			$SCRIPT:js.Id = $Id
		}
	
		if ( $Url )
		{
			$SCRIPT:js.Url = $Url
		}
	
		# Subsequent settings are used for local instances only
		if ( $Remote )
		{
			$SCRIPT:js.Local = $false
		} else {
			if ( !$InstallPath )
			{
				$InstallPath = "$($BasePath)\$($Id)"
			}
			
			if ( $InstallPath.Substring( $InstallPath.Length-1 ) -eq '/' -or $InstallPath.Substring( $InstallPath.Length-1 ) -eq '\' )
			{
				$InstallPath = $InstallPath.Substring( 0, $InstallPath.Length-1 )
			}
		
			if ( !( Test-Path $InstallPath -PathType Container) )
			{
				throw "JobScheduler installation path not found: $($InstallPath)"
			}
			
			$environmentVariablesScriptPath = $InstallPath + '/bin/' + $EnvironmentVariablesScript
			if ( Test-Path $environmentVariablesScriptPath -PathType Leaf )
			{
				Write-Debug ".. importing settings from $environmentVariablesScriptPath"
				Invoke-CommandScript $environmentVariablesScriptPath
			} else {
				throw "JobScheduler installation path not found: $($InstallPath)"
			}
			
			$environmentVariablesScriptPath = $InstallPath + '/user_bin/' + $EnvironmentVariablesScript
			if ( Test-Path $environmentVariablesScriptPath -PathType Leaf )
			{
				Write-Debug ".. importing settings from $environmentVariablesScriptPath"
				Invoke-CommandScript $environmentVariablesScriptPath
			}    
		
			$SCRIPT:InstallPath = $InstallPath
			
			if ( $env:SCHEDULER_ID )
			{
				$SCRIPT:js.ID = $env:SCHEDULER_ID
			}
		
			if ( $env:SCHEDULER_HOME )
			{
				$SCRIPT:js.Install.Directory = $env:SCHEDULER_HOME
			}
		
			if ( $env:SCHEDULER_DATA )
			{
				$SCRIPT:js.Config.Directory = $env:SCHEDULER_DATA
			}
		
			if ( $env:SOS_INI )
			{
				$SCRIPT:js.Config.SosIni = $env:SOS_INI
			}
		
			if ( $env:SCHEDULER_INI )
			{
				$SCRIPT:js.Config.FactoryIni = $env:SCHEDULER_INI
			}
		
			if ( $env:SCHEDULER_PID )
			{
				$SCRIPT:js.Install.PidFile = $env:SCHEDULER_PID
			}
		
			if ( $env:SCHEDULER_CLUSTER_OPTIONS )
			{
				$SCRIPT:js.Install.ClusterOptions = $env:SCHEDULER_CLUSTER_OPTIONS
			}
		
			if ( $env:SCHEDULER_PARAMS )
			{
				$SCRIPT:js.Install.Params = $env:SCHEDULER_PARAMS
			}
		
			if ( $env:SCHEDULER_START_PARAMS )
			{
				$SCRIPT:js.Install.StartParams = $env:SCHEDULER_START_PARAMS
			}
		
			if ( $env:SCHEDULER_BIN )
			{
				$SCRIPT:js.Install.ExecutableFile = $env:SCHEDULER_BIN
			}
		
			$schedulerXmlPath = $env:SCHEDULER_DATA + '/config/scheduler.xml'
			if ( Test-Path $schedulerXmlPath -PathType Leaf )
			{
				$configResponse = (Select-XML -Path $schedulerXmlPath -xPath '/spooler/config' ).Node
		
				$SCRIPT:js.Config.SchedulerXml = $schedulerXmlPath
				$SCRIPT:js.Url = "http://localhost:$($configResponse.port)"
			} else {
				throw "JobScheduler configuration file not found: $($schedulerXmlPath)"
			}
			
			$SCRIPT:js.Service.ServiceName = "sos_scheduler_$($SCRIPT:js.ID)"
			$SCRIPT:js.Service.ServiceDisplayName = "SOS JobScheduler -id=$($SCRIPT:js.ID)"
			$SCRIPT:js.Service.ServiceDescription = "JobScheduler"
			
			$SCRIPT:js.Local = $true
		}
		
		$SCRIPT:js
	}
}

Set-Alias -Name Use-Master -Value Use-JobSchedulerMaster

function Start-JobSchedulerDashboard
{
<#
.SYNOPSIS
Starts the JobScheduler Dashboard (JID)

.DESCRIPTION
JobScheduler Dashboard can be started from a JobScheduler Master location or from a JobScheduler Dashboard location:

* The JobScheduler Master Installation includes the JobScheduler Dashboard
* The JobScheduler Dashboard is available from a separate installer

.PARAMETER Id
Specifies the ID of a JobScheduler Master.

The installation path is assumed from the -InstallBasePath parameter and the JobScheduler ID,
therefore no -InstallPath parameter has to be specified.

.PARAMETER InstallPath
Specifies the installation path of a JobScheduler Master or JobScheduler Dashboard.

The installation path is expected to be accessible from the host on which the JobScheduler cmdlets are executed.

.PARAMETER InstallBasePath
Specifies the base path of a JobScheduler Master or JobScheduler Dashboard installation. This parameter is used in
combination with the -Id parameter to determine the installation path.

Default Value: C:\Program Files\sos-berlin.com\jobscheduler

.PARAMETER ConfigPath
Specifies the configuration path of a JobScheduler Maser or JobScheduler Dashboard.

The configuration path is expected to be accessible from the host on which the JobScheduler cmdlets are executed.

.PARAMETER ConfigBasePath
Specifies the base path of a JobScheduler Master or JobScheduler Dashboard configuration. This parameter is used in
combination with the -Id parameter to determine the configuration path.

Default Value: C:\ProgramData\sos-berlin.com\jobscheduler

.PARAMETER EnvironmentVariablesScript
Specifies the name of the script that includes environment variables of a JobScheduler Dashboard installation.
Typically the script name is "dashboard_environment_variables.cmd" and the script is available
from the "bin" directory and optionally "user_bin" directory of a JobScheduler Dashboard installation directory.

Default Value: dashboard_environment_variables.cmd

.EXAMPLE
Start-JID -Id scheduler110

Starts the JobScheduler Dashboard from a local JobScheduler Master installation with the specified id.

.LINK
about_jobscheduler

#>
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Id,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $InstallPath,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $InstallBasePath = 'C:\Program Files\sos-berlin.com\jobscheduler',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ConfigPath,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ConfigBasePath = 'C:\ProgramData\sos-berlin.com\jobscheduler',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EnvironmentVariablesScript = 'dashboard_environment_variables.cmd'
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        
        $isLocal = $false
    }

    Process
    {
        if ( $InstallPath )
        {
            if ( $InstallPath.Substring( $InstallPath.Length-1 ) -eq '/' -or $InstallPath.Substring( $InstallPath.Length-1 ) -eq '\' )
            {
                $InstallPath = $InstallPath.Substring( 0, $InstallPath.Length-1 )
            }

            if ( !(Test-Path $InstallPath -PathType Container) )
            {
                throw "$($MyInvocation.MyCommand.Name): JobScheduler Dashboard (JID) installation path not found: $($InstallPath)"
            }
            
            if ( !$Id )
            {
                $Id = Get-DirectoryName $InstallPath
            }
        
            $isLocal = $true
        } elseif ( $Id ) {
            try 
            {
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): checking implicit installation path: $($InstallBasePath)\$($Id)"
                $isLocal = Test-Path "$($InstallBasePath)\$($Id)" -PathType Container
            } catch {
                throw "$($MyInvocation.MyCommand.Name): error occurred checking installation path '$($InstallBasePath)\$($Id)' from JobScheduler ID. Maybe parameter -Id '$($Id)' was mismatched: $($_.Exception.Message)"
            }

            if ( $isLocal )
            {
                $InstallPath = "$($InstallBasePath)\$($Id)"
            }
        }

        if ( $InstallPath )
        {
            $dashboardInstallPath = $InstallPath
        } elseif ( $SCRIPT:js.Local ) {
            $dashboardInstallPath = $SCRIPT:js.Install.Directory
        } elseif ( $InstallBasePath ) {
            $dashboiardInstallPath = $InstallBasePath + '/dashboard'
        }
        
        if ( !$dashboardInstallPath )
        {
            throw "$($MyInvocation.MyCommand.Name): no installation path specified, use -Id or -InstallPath parameter or Use-Master -InstallPath cmdlet"
        }
        
        if ( !(Test-Path $dashboardInstallPath -PathType Container) )
        {
            throw "$($MyInvocation.MyCommand.Name): JobScheduler Dashboard (JID) installation path not found: $($dashboardInstallPath)"
        }

        if ( $ConfigPath )
        {
            $dashboardConfigPath = $ConfigPath
        } elseif ( $SCRIPT:js.Local ) {
            $dashboardConfigPath = $SCRIPT:js.Config.Directory
        } elseif ( $ConfigBasePath -and $Id ) {
            $dashboardConfigPath = $ConfigBasePath + '/' + $Id
        } elseif ( $ConfigBasePath ) {
            $dashboardConfigPath = $ConfigBasePath + '/JOE'
        }

        if ( !$dashboardConfigPath )
        {
            throw "$($MyInvocation.MyCommand.Name): no configuration path specified, use -ConfigPath parameter or Use-Master cmdlet"
        }
        
        if ( !(Test-Path $dashboardConfigPath -PathType Container) )
        {
            throw "$($MyInvocation.MyCommand.Name): JobScheduler Dashboard (JID) configuration path not found: $($dashboardConfigPath)"
        }

        $environmentVariablesScriptPath = $dashboardInstallPath + '/bin/' + $EnvironmentVariablesScript
        if ( Test-Path $environmentVariablesScriptPath -PathType Leaf )
        {
            Write-Debug ".. $($MyInvocation.MyCommand.Name): importing settings from $($environmentVariablesScriptPath)"
            Invoke-CommandScript $environmentVariablesScriptPath
        }
        
        $environmentVariablesScriptPath = $dashboardInstallPath + '/user_bin/' + $EnvironmentVariablesScript
        if ( Test-Path $environmentVariablesScriptPath -PathType Leaf )
        {
            Write-Debug ".. $($MyInvocation.MyCommand.Name): importing settings from $($environmentVariablesScriptPath)"
            Invoke-CommandScript $environmentVariablesScriptPath
        }
        
        if ( !$env:SCHEDULER_HOME )
        {
            $env:SCHEDULER_HOME = $dashboardInstallPath
        }

        if ( !$env:SCHEDULER_DATA )
        {
            $env:SCHEDULER_DATA = $dashboardConfigPath
        }

        if ( !$env:SCHEDULER_HOT_FOLDER )
        {
            $env:SCHEDULER_HOT_FOLDER = "$($env:SCHEDULER_DATA)/config/live"
        }

        if ( !$env:JAVA_HOME )
        {
            $env:JAVA_HOME = 'C:\Program Files\Java\jre8'
        }
        
        if ( !$env:JAVA_OPTIONS )
        {
            $env:JAVA_OPTIONS = '-Xms128m -Xmx256m'
        }

        if ( !$env:LOG_BRIDGE )
        {
            $env:LOG_BRIDGE = 'log4j'
        }

        if ( !$env:LOG4JPROP )
        {
            if ( Test-Path -Path "$($dashboardInstallPath)\lib\JOE-log4j.properties" -PathType Leaf )
            {
                $env:LOG4JPROP = "-Dlog4j.configuration=`"file:///$($dashboardInstallPath)/lib/JID-log4j.properties`""
            }
        }

        if ( !$env:HIBERNATE_CONFIGURATION_FILE )
        {
            $env:HIBERNATE_CONFIGURATION_FILE = "$($env:SCHEDULER_DATA)/config/hibernate.cfg.xml"
        }
        
        if ( !$env:ENABLE_JOE )
        {
            $env:ENABLE_JOE = 'false'
        }
        
        if ( !$env:ENABLE_JOC )
        {
            $env:ENABLE_JOC = 'true'
        }
        
        if ( !$env:ENABLE_EVENTS )
        {
            $env:ENABLE_EVENTS = 'false'
        }
        
        if ( !$env:ENABLE_JOB_START )
        {
            $env:ENABLE_JOB_START = 'true'
        }
        
        if ( $DebugPreferences -eq "Continue" )
        {
            $javaExecutableFile = "$env:JAVA_HOME/bin/java.exe"
        } else {
            $javaExecutableFile = "$env:JAVA_HOME/bin/javaw.exe"
        }
        
        $javaClassPath = "patches/*;user_lib/*;log/%LOG_BRIDGE%/*;jdbc/*;3rd-party/*;sos/*"
        $javaArguments = "-classpath `"$($javaClassPath)`" $($env:LOG4JPROP) $($env:JAVA_OPTIONS) -DSCHEDULER_HOME=`"$($dashboardInstallPath)`" -DSCHEDULER_DATA=`"$($dashboardConfigPath)`" -DSCHEDULER_HOT_FOLDER=`"$env:SCHEDULER_HOT_FOLDER`" com.sos.dailyschedule.SosSchedulerDashboardMain -enable_joe=$($env:ENABLE_JOE) -enable_joc=$($env:ENABLE_JOC) -enable_events=$($env:ENABLE_EVENTS) -enable_job_start=$($env:ENABLE_JOB_START) -Hibernate_Configuration_File=`"$($env:HIBERNATE_CONFIGURATION_FILE)`""

        $currentLocation = Set-Location -Path "$($dashboardInstallPath)/lib" -PassThru

        $command = """$($javaExecutableFile)"" $($javaArguments)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): start by command: $command"
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): starting JobScheduler Dashboard: $($command)"
        $process = Start-Process -FilePath "$($javaExecutableFile)" "$($javaArguments)" -PassThru

        Set-Location -Path $currentLocation
    }
}

Set-Alias -Name Start-Dashboard -Value Start-JobSchedulerDashboard
Set-Alias -Name Start-JID -Value Start-JobSchedulerDashboard

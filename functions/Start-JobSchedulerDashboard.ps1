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

Default Value: %ProgramFiles%\sos-berlin.com\jobscheduler

.PARAMETER ConfigPath
Specifies the configuration path of a JobScheduler Maser or JobScheduler Dashboard.

The configuration path is expected to be accessible from the host on which the JobScheduler cmdlets are executed.

.PARAMETER ConfigBasePath
Specifies the base path of a JobScheduler Master or JobScheduler Dashboard configuration. This parameter is used in
combination with the -Id parameter to determine the configuration path.

Default Value: %ProgramData%\sos-berlin.com\jobscheduler

.PARAMETER EnvironmentVariablesScript
Specifies the name of the script that includes environment variables of a JobScheduler Master installation.
Typically the script is available from the "bin" directory of a JobScheduler Master installation directory.

Default Value: jobscheduler_environment_variables.cmd

.PARAMETER DashboardEnvironmentVariablesScript
Specifies the name of the script that includes environment variables of a JobScheduler Dashboard installation.
Typically the script is available
from the "user_bin" directory of a JobScheduler Dashboard installation directory.

Default Value: dashboard_environment_variables.cmd

.EXAMPLE
Start-JID -Id scheduler110

Starts the JobScheduler Dashboard from a local JobScheduler Master installation with the specified id.

.EXAMPLE
Start-JOD -InstallPath c:\Program Files\JID

Starts JID from the specified installation directory. This is a suitable option if
JID has been installed independently from a JobScheduler Master installation.

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
    [string] $InstallBasePath = "$($env:ProgramFiles)\sos-berlin.com\jobscheduler",
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ConfigPath,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ConfigBasePath = "$($env:ProgramData)\sos-berlin.com\jobscheduler",
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EnvironmentVariablesScript = 'jobscheduler_environment_variables.cmd',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $DashboardEnvironmentVariablesScript = 'dashboard_environment_variables.cmd'
)
    Begin
    {
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
            # standalone instance or included with Master
            $dashboardInstallPath = $InstallPath
        } elseif ( $SCRIPT:js.Local ) {
            # instance included with Master
            $dashboardInstallPath = $SCRIPT:js.Install.Directory
        } elseif ( $InstallBasePath ) {
            # standalone instance without Master
            $dashboardInstallPath = (Split-Path -Path $InstallBasePath -Parent) + '/dashboard'
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
            # standalone instance or included with Master
            $dashboardConfigPath = $ConfigPath
        } elseif ( $SCRIPT:js.Local ) {
            # instance included with Master
            $dashboardConfigPath = $SCRIPT:js.Config.Directory
        } elseif ( $ConfigBasePath -and $Id ) {
            # instance included with Master
            $dashboardConfigPath = $ConfigBasePath + '/' + $Id
        } elseif ( $ConfigBasePath ) {
            # standalone instance without Master
            $dashboardConfigPath = (Split-Path -Path $ConfigBasePath -Parent) + '/dashboard'
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
        
        $environmentVariablesScriptPath = $dashboardInstallPath + '/user_bin/' + $DashboardEnvironmentVariablesScript
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
            $env:JAVA_HOME = "$($env:ProgramFiles)\Java\jre8"
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
                $env:LOG4JPROP = "-Dlog4j.configuration=`"file:///$($dashboardInstallPath -replace "\\","/")/lib/JID-log4j.properties`""
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
            $javaExecutableFile = "$($env:JAVA_HOME)\bin\java.exe"
        } else {
            $javaExecutableFile = "$($env:JAVA_HOME)\bin\javaw.exe"
        }
        
        if ( -Not (Test-Path -Path "$($javaExecutableFile)" -PathType Leaf) )
        {
            $javaExecutableFile = Split-Path -Path "$($javaExecutableFile)" -Leaf
        }
        
        $javaClassPath = "patches/*;user_lib/*;log/$($env:LOG_BRIDGE)/*;jdbc/*;3rd-party/*;sos/*"
        
        $dbmsDialect = Select-XML -Path "$($env:HIBERNATE_CONFIGURATION_FILE)" -Xpath "//property[@name='hibernate.dialect']"
        $dbms = $($dbmsDialect.Node.'#text' -replace 'org\.hibernate\.dialect\.(.*?)(?:InnoDB|\d+g)?Dialect','$1')
        Write-Debug ".. $($MyInvocation.MyCommand.Name): DBMS: $($dbms)"
        if ( $dbms -eq 'PostgreSQL' )
        {
            $javaClassPath = "pgsql/com.sos.hibernate_pgsql.jar;$($javaClassPath)"
        }
        
        $javaArguments = "-classpath `"$($javaClassPath)`" $($env:LOG4JPROP) $($env:JAVA_OPTIONS) -DSCHEDULER_HOME=`"$($dashboardInstallPath)`" -DSCHEDULER_DATA=`"$($dashboardConfigPath)`" -DSCHEDULER_HOT_FOLDER=`"$env:SCHEDULER_HOT_FOLDER`" com.sos.dailyschedule.SosSchedulerDashboardMain -enable_joe=$($env:ENABLE_JOE) -enable_joc=$($env:ENABLE_JOC) -enable_events=$($env:ENABLE_EVENTS) -enable_job_start=$($env:ENABLE_JOB_START) -Hibernate_Configuration_File=`"$($env:HIBERNATE_CONFIGURATION_FILE)`""

        $currentLocation = $pwd
        Set-Location -Path "$($dashboardInstallPath)/lib"

        $command = """$($javaExecutableFile)"" $($javaArguments)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): start by command: $command"
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): starting JobScheduler Dashboard: $($command)"
        Start-Process -FilePath "$($javaExecutableFile)" "$($javaArguments)"

        Set-Location -Path $currentLocation
    }
}

Set-Alias -Name Start-Dashboard -Value Start-JobSchedulerDashboard
Set-Alias -Name Start-JID -Value Start-JobSchedulerDashboard

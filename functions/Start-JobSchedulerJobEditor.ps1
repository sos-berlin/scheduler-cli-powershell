function Start-JobSchedulerJobEditor
{
<#
.SYNOPSIS
Starts the JobScheduler Editor (JOE)

.DESCRIPTION
JobScheduler Editor can be started from a JobScheduler Master location or from a JobScheduler Editor location:

* The JobScheduler Master Installation includes the JobScheduler Editor
* The JobScheduler Editor is available from a separate installer

.PARAMETER Id
Specifies the ID of a JobScheduler Master.

The installation path is assumed from the -InstallBasePath parameter and the JobScheduler ID,
therefore no -InstallPath parameter has to be specified.

.PARAMETER InstallPath
Specifies the installation path of a JobScheduler Master or JobScheduler Editor.

The installation path is expected to be accessible from the host on which the JobScheduler cmdlets are executed.

.PARAMETER InstallBasePath
Specifies the base path of a JobScheduler Master or JobScheduler Editor installation. This parameter is used in
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

.PARAMETER EditorEnvironmentVariablesScript
Specifies the name of the script that includes environment variables of a JobScheduler Editor installation.
Typically the script is available
from the "user_bin" directory of a JobScheduler Dashboard installation directory.

Default Value: jobeditor_environment_variables.cmd

.EXAMPLE
Start-JobSchedulerJobEditor -Id scheduler110

Starts the JobScheduler Editor from a local JobScheduler Master installation with the specified id.

.EXAMPLE
Start-JobSchedulerJobEditor -InstallPath c:\Program Files\JOE

Starts JOE from the specified installation directory. This is a suitable option if
JOE has been installed independently from a JobScheduler Master installation.
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
    [string] $EditorEnvironmentVariablesScript = 'jobeditor_environment_variables.cmd'
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
                throw "$($MyInvocation.MyCommand.Name): JobScheduler Editor (JOE) installation path not found: $($InstallPath)"
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
            $editorInstallPath = $InstallPath
        } elseif ( $SCRIPT:js.Local ) {
            # instance included with Master
            $editorInstallPath = $SCRIPT:js.Install.Directory
        } elseif ( $InstallBasePath ) {
            # standalone instance without Master
            $editorInstallPath = (Split-Path -Path $InstallBasePath -Parent) + '/JOE'
        }
        
        if ( !$editorInstallPath )
        {
            throw "$($MyInvocation.MyCommand.Name): no installation path specified, use -Id or -InstallPath parameter or Use-Master -InstallPath cmdlet"
        }
        
        if ( !(Test-Path $editorInstallPath -PathType Container) )
        {
            throw "$($MyInvocation.MyCommand.Name): JobScheduler Editor (JOE) installation path not found: $($editorInstallPath)"
        }

        if ( $ConfigPath )
        {
            # standalone instance or included with Master
            $editorConfigPath = $ConfigPath
        } elseif ( $SCRIPT:js.Local ) {
            # instance included with Master
            $editorConfigPath = $SCRIPT:js.Config.Directory
        } elseif ( $ConfigBasePath -and $Id ) {
            # instance included with Master
            $editorConfigPath = $ConfigBasePath + '/' + $Id
        } elseif ( $ConfigBasePath ) {
            # standalone instance without Master
            $editorConfigPath = (Split-Path -Path $ConfigBasePath -Parent) + '/JOE'
        }

        if ( !$editorConfigPath )
        {
            throw "$($MyInvocation.MyCommand.Name): no configuration path specified, use -ConfigPath parameter or Use-Master cmdlet"
        }
        
        if ( !(Test-Path $editorConfigPath -PathType Container) )
        {
            throw "$($MyInvocation.MyCommand.Name): JobScheduler Editor (JOE) configuration path not found: $($editorConfigPath)"
        }

        $environmentVariablesScriptPath = $editorInstallPath + '/bin/' + $EnvironmentVariablesScript
        if ( Test-Path $environmentVariablesScriptPath -PathType Leaf )
        {
            Write-Debug ".. $($MyInvocation.MyCommand.Name): importing settings from $($environmentVariablesScriptPath)"
            Invoke-CommandScript $environmentVariablesScriptPath
        }
        
        $environmentVariablesScriptPath = $editorInstallPath + '/user_bin/' + $EditorEnvironmentVariablesScript
        if ( Test-Path $environmentVariablesScriptPath -PathType Leaf )
        {
            Write-Debug ".. $($MyInvocation.MyCommand.Name): importing settings from $($environmentVariablesScriptPath)"
            Invoke-CommandScript $environmentVariablesScriptPath
        }
        
        $envSchedulerHome = if ( $env:SCHEDULER_HOME ) { $env:SCHEDULER_HOME } else { $editorInstallPath }

        $envSchedulerData = if ( $env:SCHEDULER_DATA ) { $env:SCHEDULER_DATA } else { $editorConfigPath }

        $envSchedulerHotFolder = if ( $env:SCHEDULER_HOT_FOLDER ) { $env:SCHEDULER_HOT_FOLDER } else { "$($envSchedulerData)/config/live" }

        $envSosJoeHome = if ( $env:SOS_JOE_HOME ) { $env:SOS_JOE_HOME } else { $editorConfigPath }

        $envJavaHome = if ( $env:JAVA_HOME ) { $env:JAVA_HOME } else { "$($env:ProgramFiles)\Java\jre8" }

        $envJavaOptions = if ( $env:JAVA_OPTIONS ) { $env:JAVA_OPTIONS }

        $envLogBridge = if ( $env:LOG_BRIDGE ) { $env:LOG_BRIDGE }

        if ( !$env:LOG4JPROP -and ( Test-Path -Path "$($editorInstallPath)\lib\JOE-log4j.properties" -PathType Leaf ) )
        {
            $envLog4JProp = "-Dlog4j.configuration=`"file:///$($editorInstallPath -replace "\\","/")/lib/JOE-log4j.properties`""
        } else {
            $envLog4JProp = $env:LOG4JPROP
        }

        $envJavaHome = if ( $env:CAIRO_JAVA_OPTION ) { $env:CAIRO_JAVA_OPTION } else { '-Dorg.eclipse.swt.internal.gtk.cairoGraphics=false' }
        
        if ( $DebugPreferences -eq "Continue" )
        {
            $javaExecutableFile = "$($envJavaHome)\bin\java.exe"
        } else {
            $javaExecutableFile = "$($envJavaHome)\bin\javaw.exe"
        }
        
        if ( -Not (Test-Path -Path "$($javaExecutableFile)" -PathType Leaf) )
        {
            $javaExecutableFile = Split-Path -Path "$($javaExecutableFile)" -Leaf
        }
        
        $javaClassPath = "patches/*;user_lib/*;log/$($envLogBridge)/*;3rd-party/*;sos/*"
        $javaArguments = "-classpath `"$($javaClassPath)`" $($envLog4JProp) $($envJavaOptions) -DSCHEDULER_HOME=`"$($envSchedulerHome)`" -DSCHEDULER_DATA=`"$($envSchedulerData)`" -DSCHEDULER_HOT_FOLDER=`"$envSchedulerHotFolder`" sos.scheduler.editor.app.Editor"

        $currentLocation = $pwd
        Set-Location -Path "$($editorInstallPath)/lib"

        $command = """$($javaExecutableFile)"" $($javaArguments)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): start by command: $command"
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): starting JobScheduler Editor: $($command)"
        Start-Process -FilePath "$($javaExecutableFile)" "$($javaArguments)"

        Set-Location -Path $currentLocation
    }
}

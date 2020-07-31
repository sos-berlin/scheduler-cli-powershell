function Use-JobSchedulerMaster
{
<#
.SYNOPSIS
This cmdlet can be used to import settings from a local JobScheduler Master installation for Windows.
The cmdlet is not related to the JobScheduler REST Web Service.

Optionally applies settings from a JobScheduler Master location. A Master is identified
by its JobScheduler ID and URL for which it is operated.

.DESCRIPTION
During installation of a JobScheduler Master a number of settings are specified. 
Such settings are imported for use with subsequent cmdlets.

* For a Master that is installed on the local Windows computer the cmdlet reads
settings from the installation path.
* For a remote Master operations for management of the
Windows service are not available.

.PARAMETER Url
Specifies the URL for which a JobScheduler Master is available.

The URL includes one of the protocols HTTP or HTTPS, the hostname and the port that JobScheduler Master listens to, e.g. http://localhost:4444

If JobScheduler Master is operated for the Jetty web server then the URLs for the JOC GUI and the command interface differ:

* JOC GUI: https://localhost:40444/jobscheduler/operations_gui/
* XML Command Interface: http://localhost:40444/jobscheduler/engine/command/

For use with Jetty specify the URL for the XML Command Interface. 
The cmdlet will convert the above JOC GUI path automatically to the XML Command Interface path.

.PARAMETER Id
Specifies the ID of a JobScheduler Master.

The installation path is assumed from the -BasePath parameter and the JobScheduler ID,
therefore no -InstallPath parameter has to be specified.

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
from the "bin" subdirectory and optionally "user_bin" subdirectory of a JobScheduler installation directory.

Default Value: jobscheduler_environment_variables.cmd

.PARAMETER Credentials
Specifies a credentials object that is used for authentication with JobScheduler.

A credentials object can be created e.g. with:

    $account = 'John'
    $password = ( 'Doe' | ConvertTo-SecureString -AsPlainText -Force)
    $credentials = New-Object -typename System.Management.Automation.PSCredential -Argumentlist $account, $password

An existing credentials object can be retrieved from the Windows Credential Manager e.g. with:

    $systemCredentials = Get-JobSchedulerSystemCredentials -TargetName 'localhost'
    $credentials = ( New-Object -typename System.Management.Automation.PSCredential -Argumentlist $systemCredentials.UserName, $systemCredentials.Password )

.PARAMETER ProxyUrl
Specifies the URL of a proxy that is used to access a JobScheduler Master.

The URL includes one of the protocols HTTP or HTTPS and optionally the port that proxy listens to, e.g. http://localhost:3128

.PARAMETER ProxyCredentials
Specifies a credentials object that is used for authentication with a proxy. See parameter -Credentials how to create a credentials object.

.EXAMPLE
Use-JobSchedulerMaster -Url http://localhost:40444 -Id scheduler

Specifies the URL for a local Master and imports settings from the the JobScheduler Master with ID *scheduler*.
The installation path is determined from the default value of the -BasePath parameter.

Cmdlets that require a local Master can be used, e.g. Install-JobSchedulerService, Remove-JobSchedulerService, Start-JobSchedulerMaster.

.EXAMPLE
Use-JobSchedulerMaster -InstallPath "C:\Program Files\sos-berlin.com\jobscheduler\scheduler110"

Imports settings from the specified installation path.

.EXAMPLE
Use-JobSchedulerMaster -InstallPath $env:SCHEDULER_HOME

Imports settings from the installation path that is specified from the SCHEDULER_HOME environment variable.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $Url,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Id,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $InstallPath,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $BasePath = "$($env:ProgramFiles)\sos-berlin.com\jobscheduler",
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EnvironmentVariablesScript = 'jobscheduler_environment_variables.cmd',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $Credentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [Uri] $ProxyUrl,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $ProxyCredentials
)
    Begin
    {
        $stopWatch = Start-StopWatch
        
        if ( !$isWindows )
        {
            throw "$($MyInvocation.MyCommand.Name): cmdlet can be used with Windows OS only"
        }
    }
        
    Process
    {
        if ( !$InstallPath -and !$Id -and !$Url )
        {
            throw "$($MyInvocation.MyCommand.Name): one of the parameters -Url, -Id or -InstallPath has to be specified"
        }

        if ( $Url )
        {
            # is protocol provided? e.g. http://localhost:4444
            if ( !$Url.OriginalString.startsWith('http://') -and !$Url.OriginalString.startsWith('https://') )
            {
                $Url = 'http://' + $Url.OriginalString
            }

            # is valid hostname specified?
            if ( [System.Uri]::CheckHostName( $Url.DnsSafeHost ).equals( [System.UriHostNameType]::Unknown ) )
            {
                throw "$($MyInvocation.MyCommand.Name): no valid hostname specified, check use of -Url parameter, e.g. -Url http://localhost:4444: $($Url.OriginalString)"
            }
            
            # replace GUI Url with Command URl for operations with Jetty
            if ( $Url.AbsolutePath -eq '/jobscheduler/operations_gui/' )
            {
                $Url = "$($Url.scheme)://$($Url.Authority)/jobscheduler/engine/command/"
            }
        }

        if ( $ProxUrl )
        {
            # is protocol provided? e.g. http://localhost:3128
            if ( !$ProxyUrl.OriginalString.startsWith('http://') -and !$ProxyUrl.OriginalString.startsWith('https://') )
            {
                $ProxyUrl = 'http://' + $ProxyUrl.OriginalString
            }

            # is valid hostname specified?
            if ( [System.Uri]::CheckHostName( $ProxyUrl.DnsSafeHost ).equals( [System.UriHostNameType]::Unknown ) )
            {
                throw "$($MyInvocation.MyCommand.Name): no valid hostname specified, check use of -ProxyUrl parameter, e.g. -ProxyUrl http://localhost:3128: $($Url.OriginalString)"
            }            
        }

        if ( $Credentials )
        {
            $script:jsOptionWebRequestUseDefaultCredentials = $false
            $script:jsCredentials = $Credentials
        }
        
        if ( $ProxyCredentials )
        {
            $script:jsOptionWebRequestProxyUseDefaultCredentials = $false
            $script:jsProxyCredentials = $ProxyCredentials
        }
        
        $script:jsEnv = @{}
        
        $script:js = Create-JSObject
        $script:js.Url = $Url
        $script:js.Id = $Id
        $script:js.Local = $false

		$script:jsWebService = $null
		
        if ( $ProxyUrl )
        {
            $script:js.ProxyUrl = $ProxyUrl
        }        
        
        if ( $InstallPath )
        {
            if ( $InstallPath.Substring( $InstallPath.Length-1 ) -eq '/' -or $InstallPath.Substring( $InstallPath.Length-1 ) -eq '\' )
            {
                $InstallPath = $InstallPath.Substring( 0, $InstallPath.Length-1 )
            }

            if ( !(Test-Path $InstallPath -PathType Container) )
            {
                throw "$($MyInvocation.MyCommand.Name): JobScheduler Master installation path not found: $($InstallPath)"
            }
            
            if ( !$Id )
            {
                $script:js.Id = Get-DirectoryName $InstallPath
            }
        
            $script:js.Local = $true
        } elseif ( $Id ) {
            try 
            {
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): checking implicit installation path: $($BasePath)\$($Id)"
                $script:js.Local = Test-Path "$($BasePath)\$($Id)" -PathType Container
            } catch {
                throw "$($MyInvocation.MyCommand.Name): error occurred checking installation path '$($BasePath)\$($Id)' from JobScheduler ID. Maybe parameter -Id '$($Id)' was mismatched: $($_.Exception.Message)"
            }

            if ( $script:js.Local )
            {
                $InstallPath = "$($BasePath)\$($Id)"
            }
        }
            
        if ( $script:js.Local )
        {            
            $environmentVariablesScriptPath = $InstallPath + '/bin/' + $EnvironmentVariablesScript
            if ( Test-Path $environmentVariablesScriptPath -PathType Leaf )
            {
                Write-Debug ".. $($MyInvocation.MyCommand.Name): importing settings from $($environmentVariablesScriptPath)"
                Invoke-CommandScript $environmentVariablesScriptPath
            } else {
                throw "$($MyInvocation.MyCommand.Name): JobScheduler installation path not found: $($InstallPath)"
            }
            
            $environmentVariablesScriptPath = $InstallPath + '/user_bin/' + $EnvironmentVariablesScript
            if ( Test-Path $environmentVariablesScriptPath -PathType Leaf )
            {
                Write-Debug ".. $($MyInvocation.MyCommand.Name): importing settings from $($environmentVariablesScriptPath)"
                Invoke-CommandScript $environmentVariablesScriptPath
            }    
        
            $script:js.Install.Directory = $InstallPath
            
            if ( $script:jsEnv['SCHEDULER_ID'] )
            {            
                $script:js.Id = $script:jsEnv['SCHEDULER_ID']
            }
        
            if ( $script:jsEnv['SCHEDULER_HOME'] )
            {
                $script:js.Install.Directory = $script:jsEnv['SCHEDULER_HOME']
            }
        
            if ( $script:jsEnv['SCHEDULER_DATA'] )
            {
                $script:js.Config.Directory = $script:jsEnv['SCHEDULER_DATA']
            }
        
            if ( $script:jsEnv['SOS_INI'] )
            {
                $script:js.Config.SosIni = $script:jsEnv['SOS_INI']
            }
        
            if ( $script:jsEnv['SCHEDULER_INI'] )
            {
                $script:js.Config.FactoryIni = $script:jsEnv['SCHEDULER_INI']
            }
        
            if ( $script:jsEnv['SCHEDULER_PID'] )
            {
                $script:js.Install.PidFile = $script:jsEnv['SCHEDULER_PID']
            }
        
            if ( $script:jsEnv['SCHEDULER_CLUSTER_OPTIONS'] )
            {
                $script:js.Install.ClusterOptions = $script:jsEnv['SCHEDULER_CLUSTER_OPTIONS']
            }
        
            if ( $script:jsEnv['SCHEDULER_PARAMS'] )
            {
                $script:js.Install.Params = $script:jsEnv['SCHEDULER_PARAMS']
            }
        
            if ( $script:jsEnv['SCHEDULER_START_PARAMS'] )
            {
                $script:js.Install.StartParams = $script:jsEnv['SCHEDULER_START_PARAMS']
            }
        
            if ( $script:jsEnv['SCHEDULER_BIN'] )
            {
                $script:js.Install.ExecutableFile = $script:jsEnv['SCHEDULER_BIN']
            }

            $schedulerXmlPath = $script:jsEnv['SCHEDULER_DATA'] + '/config/scheduler.xml'
            if ( Test-Path $schedulerXmlPath -PathType Leaf )
            {
                $configResponse = ( Select-XML -Path $schedulerXmlPath -Xpath '/spooler/config' ).Node
        
                $script:js.Config.SchedulerXml = $schedulerXmlPath
                if ( !$script:js.Url )
                {
                    $script:js.Url = "http://localhost:$($configResponse.port)"
                }
            } else {
                throw "$($MyInvocation.MyCommand.Name): JobScheduler configuration file not found: $($schedulerXmlPath)"
            }
            
            $script:js.Service.ServiceName = "sos_scheduler_$($script:js.Id)"
            $script:js.Service.ServiceDisplayName = "SOS JobScheduler -id=$($script:js.Id)"
            $script:js.Service.ServiceDescription = 'JobScheduler'
        }
        
        $script:js
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

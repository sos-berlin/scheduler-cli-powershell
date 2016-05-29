function Use-JobSchedulerMaster
{
<#
.SYNOPSIS
This cmdlet has to be used as the first operation with JobScheduler cmdlets
and identifies the JobScheduler Master that should be used.

Optionally applies settings from a JobScheduler Master location. A Master is identified
by its JobScheduler ID and URL for which it is operated.

.DESCRIPTION
During installation of a JobScheduler Master a number of settings are specified. 
Such settings are imported for use with subsequent cmdlets.

* For a local Master that is installed on the local computer the cmdlet reads
settings from the installation path.
* For a remote Master operations for management of the
Windows serivce are not available.

.PARAMETER Url
Specifies the URL for which a JobScheduler Master is available.

The URL includes one of the protocols HTTP or HTTPS and optionally the port that JobScheduler listens to, e.g. http://localhost:4444

If JobScheduler is operated for the Jetty web server then the URLs for the JOC GUI and the command interface differ:

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
from the "bin" directory and optionally "user_bin" directory of a JobScheduler installation directory.

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

.PARAMETER NoCache
Specifies that the cache for JobScheduler objects is ignored.
This results in the fact that for each Get-JobScheduler* cmdlet execution the response is 
retrieved directly from the JobScheduler Master and is not resolved from the cache.

.EXAMPLE
Use-Master http://somehost:4444

Allows to manage a JobScheduler Master that is operated on the same or on a remote host. 
This includes to manage Master instances that are running e.g. in a Linux box.

.EXAMPLE
Use-Master http://localhost:4444 scheduler110
Use-Master -Url http://localhost:4444 -Id scheduler110

Specifies the URL for a local master and imports settings from the the JobScheduler Master with ID *scheduler110*.
The installation path is determined from the default value of the -BasePath parameter.

Cmdlets that require a local Master can be used, e.g. Install-Service, Remove-Service, Start-Master.

.EXAMPLE
Use-Master -InstallPath "C:\Program Files\sos-berlin.com\jobscheduler\scheduler110"

Imports settings from the specified installation path.

.EXAMPLE
Use-Master -InstallPath $env:SCHEDULER_HOME

Imports settings from the installation path that is specified from the SCHEDULER_HOME environment variable.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $Url,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Id,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $InstallPath,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $BasePath = 'C:\Program Files\sos-berlin.com\jobscheduler',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EnvironmentVariablesScript = 'jobscheduler_environment_variables.cmd',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $Credentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [Uri] $ProxyUrl,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $ProxyCredentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoCache
)
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
            $SCRIPT:jsOptionWebRequestUseDefaultCredentials = $false
            $SCRIPT:jsCredentials = $Credentials
        }
        
        if ( $ProxyCredentials )
        {
            $SCRIPT:jsOptionWebRequestProxyUseDefaultCredentials = $false
            $SCRIPT:jsProxyCredentials = $ProxyCredentials
        }
        
        $SCRIPT:jsNoCache = $NoCache
        $SCRIPT:jsHasCache = $false
        
        $SCRIPT:js = Create-JSObject
        $SCRIPT:js.Url = $Url
        $SCRIPT:js.Id = $Id
        $SCRIPT:js.Local = $false

        if ( $ProxyUrl )
        {
            $SCRIPT:js.ProxyUrl = $ProxyUrl
        }        
        
        if ( $InstallPath )
        {
            if ( $InstallPath.Substring( $InstallPath.Length-1 ) -eq '/' -or $InstallPath.Substring( $InstallPath.Length-1 ) -eq '\' )
            {
                $InstallPath = $InstallPath.Substring( 0, $InstallPath.Length-1 )
            }

            if ( !(Test-Path $InstallPath -PathType Container) )
            {
                throw "$($MyInvocation.MyCommand.Name): JobScheduler installation path not found: $($InstallPath)"
            }
            
            if ( !$Id )
            {
                $SCRIPT:js.Id = Get-DirectoryName $InstallPath
            }
        
            $SCRIPT:js.Local = $true
        } elseif ( $Id ) {
            try 
            {
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): checking implicit installation path: $($BasePath)\$($Id)"
                $SCRIPT:js.Local = Test-Path "$($BasePath)\$($Id)" -PathType Container
            } catch {
                throw "$($MyInvocation.MyCommand.Name): error occurred checking installation path '$($BasePath)\$($Id)' from JobScheduler ID. Maybe parameter -Id '$($Id)' was mismatched: $($_.Exception.Message)"
            }

            if ( $SCRIPT:js.Local )
            {
                $InstallPath = "$($BasePath)\$($Id)"
            }
        }
            
        if ( $SCRIPT:js.Local )
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
        
            $SCRIPT:InstallPath = $InstallPath
            
            if ( $env:SCHEDULER_ID )
            {            
                $SCRIPT:js.Id = $env:SCHEDULER_ID
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
                $configResponse = ( Select-XML -Path $schedulerXmlPath -Xpath '/spooler/config' ).Node
        
                $SCRIPT:js.Config.SchedulerXml = $schedulerXmlPath
                if ( !$SCRIPT:js.Url )
                {
                    $SCRIPT:js.Url = "http://localhost:$($configResponse.port)"
                }
            } else {
                throw "$($MyInvocation.MyCommand.Name): JobScheduler configuration file not found: $($schedulerXmlPath)"
            }
            
            $SCRIPT:js.Service.ServiceName = "sos_scheduler_$($SCRIPT:js.Id)"
            $SCRIPT:js.Service.ServiceDisplayName = "SOS JobScheduler -id=$($SCRIPT:js.Id)"
            $SCRIPT:js.Service.ServiceDescription = 'JobScheduler'
        }
        
        $SCRIPT:js
    }
}

Set-Alias -Name Use-Master -Value Use-JobSchedulerMaster

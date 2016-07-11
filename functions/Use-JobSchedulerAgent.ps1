function Use-JobSchedulerAgent
{
<#
.SYNOPSIS
This cmdlet has to be used as the first operation with JobScheduler Agent cmdlets
and identifies the JobScheduler Agent that should be used.

Optionally applies settings from a JobScheduler Agent location. An Agent is identified
by the URL for which it is operated.

.DESCRIPTION
During installation of a JobScheduler Agent a number of settings are specified. 
Such settings are imported for use with subsequent cmdlets.

* For a local Agent that is installed on the local computer the cmdlet reads
settings from the installation path.
* For a remote Agent operations for management of the
Windows service are not available.

.PARAMETER Url
Specifies the URL for which a JobScheduler Agent is available.

The URL includes one of the protocols HTTP or HTTPS, the hostname and the port that JobScheduler listens to, e.g. http://localhost:4444

.PARAMETER InstallPath
Specifies the installation path of a JobScheduler Agent.

The installation path is expected to be accessible from the host on which the JobScheduler cmdlets are executed.

.PARAMETER BasePath
Specifies the base path of a JobScheduler Agent installation. This parameter is used in
combination with the -Id parameter to determine the installation path.

Default Value: C:\Program Files\sos-berlin.com\agent

.PARAMETER InstanceScript
Specifies the name of the script that includes environment variables of a JobScheduler Agent installation.
Typically the script name is "jobscheduler_agent_[port].cmd" where "[port]" is a placeholder for the Agent port number.

The script is looked up from the "bin" subdirectory of a JobScheduler Agent installation directory.

Default Value: jobscheduler_agent_[port].cmd

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
Specifies the URL of a proxy that is used to access a JobScheduler Agent.

The URL includes one of the protocols HTTP or HTTPS, the hostname and optionally the port that proxy listens to, e.g. http://localhost:3128

.PARAMETER ProxyCredentials
Specifies a credentials object that is used for authentication with a proxy. See parameter -Credentials how to create a credentials object.

.EXAMPLE
Use-JobSchedulerAgent http://somehost:4444

Allows to manage a JobScheduler Agent that is operated on the same or on a remote host. 
This includes to manage Agent instances that are running e.g. in a Linux box.

.EXAMPLE
Use-JobSchedulerAgent -InstallPath "C:\Program Files\sos-berlin.com\agent\scheduler110"

Imports settings from the specified installation path.

.EXAMPLE
Use-JobSchedulerAgent -InstallPath $env:SCHEDULER_HOME

Imports settings from the installation path that is specified from the SCHEDULER_HOME environment variable.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $Url,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $InstallPath,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $BasePath = "$($env:ProgramFiles)\sos-berlin.com\jobscheduler\agent",
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $InstanceScript = 'jobscheduler_agent_[port].cmd',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $Credentials,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [Uri] $ProxyUrl,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [System.Management.Automation.PSCredential] $ProxyCredentials
)
    Process
    {
        if ( !$InstallPath -and !$Url )
        {
            throw "$($MyInvocation.MyCommand.Name): one of the parameters -Url or -InstallPath has to be specified"
        }

        if ( $Url )
        {
            # is protocol provided? e.g. http://localhost:4445
            if ( !$Url.OriginalString.startsWith('http://') -and !$Url.OriginalString.startsWith('https://') )
            {
                $Url = 'http://' + $Url.OriginalString
            }

            # is valid hostname specified?
            if ( [System.Uri]::CheckHostName( $Url.DnsSafeHost ).equals( [System.UriHostNameType]::Unknown ) )
            {
                throw "$($MyInvocation.MyCommand.Name): no valid hostname specified, check use of -Url parameter, e.g. -Url http://localhost:4444: $($Url.OriginalString)"
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
            $SCRIPT:jsAgentOptionWebRequestUseDefaultCredentials = $false
            $SCRIPT:jsAgentCredentials = $Credentials
        }
        
        if ( $ProxyCredentials )
        {
            $SCRIPT:jsAgentOptionWebRequestProxyUseDefaultCredentials = $false
            $SCRIPT:jsAgentProxyCredentials = $ProxyCredentials
        }
        
        $SCRIPT:jsAgentHasCache = $false
        
        $SCRIPT:jsAgent = Create-JSAgentObject
        [Uri] $SCRIPT:jsAgent.Url = $Url
        [bool] $SCRIPT:jsAgent.Local = $false

        if ( $ProxyUrl )
        {
            $SCRIPT:jsAgent.ProxyUrl = $ProxyUrl
        }        
        
        if ( $InstallPath )
        {
            if ( $InstallPath.Substring( $InstallPath.Length-1 ) -eq '/' -or $InstallPath.Substring( $InstallPath.Length-1 ) -eq '\' )
            {
                $InstallPath = $InstallPath.Substring( 0, $InstallPath.Length-1 )
            }

            if ( !(Test-Path $InstallPath -PathType Container) )
            {
                throw "$($MyInvocation.MyCommand.Name): JobScheduler Agent installation path not found: $($InstallPath)"
            }
            
            $SCRIPT:jsAgent.Local = $true
        } elseif ( $BasePath ) {
            try 
            {
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): checking implicit installation path: $($BasePath)"
                $SCRIPT:jsAgent.Local = Test-Path "$($BasePath)" -PathType Container
            } catch {
                throw "$($MyInvocation.MyCommand.Name): error occurred checking installation path '$($BasePath)': $($_.Exception.Message)"
            }

            if ( $SCRIPT:jsAgent.Local )
            {
                $InstallPath = "$($BasePath)"
            }
        }
            
        if ( $SCRIPT:jsAgent.Local )
        {
			$InstanceScript = $InstanceScript -replace '\[port\]', $Url.port
            $instanceScriptPath = $InstallPath + '/bin/' + $InstanceScript
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): checking instance script path: $($instanceScriptPath)"
            if ( Test-Path $instanceScriptPath -PathType Leaf )
            {
                Write-Debug ".. $($MyInvocation.MyCommand.Name): importing settings from $($instanceScriptPath)"
				$tempFile = [IO.Path]::GetTempFileName() + '.cmd'
				( ( ( ( Get-Content $instanceScriptPath ) -replace '"\%SCHEDULER_HOME\%\\bin\\jobscheduler_agent.cmd"', '@REM' ) -replace 'SETLOCAL', '@REM' ) -replace 'ENDLOCAL', '@REM' ) | Out-File $tempFile -Encoding ASCII
                Invoke-CommandScript $tempFile
            } else {
                throw "$($MyInvocation.MyCommand.Name): JobScheduler Agent instance script not found: $($instanceScriptPath)"
            }
            
            $SCRIPT:jsAgent.Install.Directory = $InstallPath
            
            if ( $env:SCHEDULER_HOME )
            {
                $SCRIPT:jsAgent.Install.Directory = $env:SCHEDULER_HOME
            }
        
            if ( $env:SCHEDULER_DATA )
            {
                $SCRIPT:jsAgent.Config.Directory = $env:SCHEDULER_DATA
            } else {
                $SCRIPT:jsAgent.Config.Directory = $SCRIPT:jsAgent.Install.Directory + '/var_' + $SCRIPT:jsAgent.Url.port
			}
                            
            $SCRIPT:jsAgent.Service.ServiceName = "sos_jobscheduler_agent_$($SCRIPT:jsAgent.Url.port)"
            $SCRIPT:jsAgent.Service.ServiceDisplayName = "SOS JobScheduler Agent -port=$($SCRIPT:jsAgent.Url.port)"
            $SCRIPT:jsAgent.Service.ServiceDescription = 'JobScheduler Universal Agent'
        }
        
        $SCRIPT:jsAgent
    }
}

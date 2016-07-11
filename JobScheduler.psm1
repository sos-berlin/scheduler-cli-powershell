<#
.SYNOPSIS
JobScheduler command line interface

For further information see

    PS C:\> about_JobScheduler

If the documentation is not available for your language then consider to use

    PS C:\> [System.Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
    
TODOs

    * Add proxy support: implemented, feedback require
    * Add Agent availability checks via process classes: implemented, possible improvement: use PowerShell jobs for parallelization
#>

# --------------------------------
# Globals with JobScheduler Master
# --------------------------------

# JobScheduler Master Object
[PSObject] $js = $null

# CLI operated for a JobScheduler job or monitor
[bool] $jsOperations = ( $spooler -and $spooler.id() )

# JobScheduler Master State Cache
#    State
[xml] $jsStateCache = $null
#    Has Cache
[bool] $jsHasCache = $false
#    Use Cache
[bool] $jsNoCache = $false

# JobScheduler Master environment
[hashtable] $jsEnv = @{}

# JobScheduler Master Web Request 
#     Credentials
[System.Management.Automation.PSCredential] $jsCredentials = $null
#    Use default credentials of the current user?
[bool] $jsOptionWebRequestUseDefaultCredentials = $true
#     Proxy Credentials
[System.Management.Automation.PSCredential] $jsProxyCredentials = $null
#    Use default credentials of the current user?
[bool] $jsOptionWebRequestProxyUseDefaultCredentials = $true

# Commands that require a local Master instance (Management of Windows Service)
[string[]] $jsLocalCommands = @( 'Install-JobSchedulerService', 'Remove-JobSchedulerService', 'Start-JobSchedulerMaster' )

# -------------------------------
# Globals with JobScheduler Agent
# -------------------------------

# JobScheduler Agent Object
[PSObject] $jsAgent = $null

# JobScheduler Agent Cluster Cache
#    State
[xml] $jsAgentCache = $null
#    Has Cache
[bool] $jsHasAgentCache = $false
#    Use Cache
[bool] $jsNoAgentCache = $false

# JobScheduler Agent Web Request 
#     Credentials
[System.Management.Automation.PSCredential] $jsAgentCredentials = $null
#    Use default credentials of the current user?
[bool] $jsAgentOptionWebRequestUseDefaultCredentials = $true
#     Proxy Credentials
[System.Management.Automation.PSCredential] $jsAgentProxyCredentials = $null
#    Use default credentials of the current user?
[bool] $jsAgentOptionWebRequestProxyUseDefaultCredentials = $true

# Commands that require a local Agent instance (Management of Windows Service)
[string[]] $jsAgentLocalCommands = @( 'Install-JobSchedulerAgentService', 'Remove-JobSchedulerAgentService', 'Start-JobSchedulerAgent' )

# -------------------------------------
# Globals with JobScheduler Web Service
# -------------------------------------

# JobScheduler Web Service Object
[PSObject] $jsWebService = $null

# JobScheduler Web Service Request 
#     Credentials
[System.Management.Automation.PSCredential] $jsWebServiceCredentials = $null
#    Use default credentials of the current user?
[bool] $jsWebServiceOptionWebRequestUseDefaultCredentials = $true
#     Proxy Credentials
[System.Management.Automation.PSCredential] $jsWebServiceProxyCredentials = $null
#    Use default credentials of the current user?
[bool] $jsWebServiceOptionWebRequestProxyUseDefaultCredentials = $true


# --------------------
# Globals with Options
# --------------------

# Options
#     Debug Message: responses exceeding the max. output size are stored in temporary files
[int] $jsOptionDebugMaxOutputSize = 1000
#    Master Web Request: timeout for establishing the connection in ms
[int] $jsOptionWebRequestTimeout = 15000
#    Agent Web Request: timeout for establishing the connection in ms
[int] $jsAgentOptionWebRequestTimeout = 5000

# ----------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------

$moduleRoot = Split-Path -Path $MyInvocation.MyCommand.Path
"$moduleRoot\functions\*.ps1" | Resolve-Path | ForEach-Object { . $_.ProviderPath }
Export-ModuleMember -Function "*"

. Use-JobSchedulerAlias -Prefix JS
. Use-JobSchedulerAlias -NoDuplicates -ExcludesPrefix JS

# ----------------------------------------------------------------------
# Private Functions
# ----------------------------------------------------------------------

function Approve-JobSchedulerCommand( [System.Management.Automation.CommandInfo] $command )
{
    if ( !$SCRIPT:js.Local )
    {
        if ( $SCRIPT:jsLocalCommands -contains $command.Name )
        {
            throw "$($command.Name): cmdlet is available exclusively for local JobScheduler Master. Switch instance with the Use-JobSchedulerMaster cmdlet and specify the -Id or -InstallPath parameter for a local JobScheduler Master"
        }
    }

    if ( !$SCRIPT:js.Url -and !$SCRIPT:jsOperations )
    {
        if ( $SCRIPT:jsLocalCommands -notcontains $command.Name )
        {
            throw "$($command.Name): cmdlet requires a JobScheduler URL. Switch instance with the Use-JobSchedulerMaster cmdlet and specify the -Url parameter"
        }
    }
}

function Start-StopWatch()
{
    [System.Diagnostics.Stopwatch]::StartNew()
}

function Log-StopWatch( [string] $commandName, [System.Diagnostics.Stopwatch] $stopWatch )
{
    if ( $stopWatch )
    {
        Write-Verbose ".. $($commandName): time elapsed: $($stopWatch.Elapsed.TotalMilliseconds) ms"
    }
}

function Create-JSObject()
{
    $js = New-Object PSObject
    $jsInstall = New-Object PSObject
    $jsConfig = New-Object PSObject
    $jsService = New-Object PSObject
    
    $js | Add-Member -Membertype NoteProperty -Name Id -Value ''
    $js | Add-Member -Membertype NoteProperty -Name Url -Value ''
    $js | Add-Member -Membertype NoteProperty -Name ProxyUrl -Value ''
    $js | Add-Member -Membertype NoteProperty -Name Local -Value $false

    $jsInstall | Add-Member -Membertype NoteProperty -Name Directory -Value ''
    $jsInstall | Add-Member -Membertype NoteProperty -Name ExecutableFile -Value ''
    $jsInstall | Add-Member -Membertype NoteProperty -Name Params -Value ''
    $jsInstall | Add-Member -Membertype NoteProperty -Name StartParams -Value ''
    $jsInstall | Add-Member -Membertype NoteProperty -Name ClusterOptions -Value ''
    $jsInstall | Add-Member -Membertype NoteProperty -Name PidFile -Value ''

    $jsConfig | Add-Member -Membertype NoteProperty -Name Directory -Value ''
    $jsConfig | Add-Member -Membertype NoteProperty -Name FactoryIni -Value ''
    $jsConfig | Add-Member -Membertype NoteProperty -Name SosIni -Value ''
    $jsConfig | Add-Member -Membertype NoteProperty -Name SchedulerXml -Value ''

    $jsService | Add-Member -Membertype NoteProperty -Name ServiceName -Value ''
    $jsService | Add-Member -Membertype NoteProperty -Name ServiceDisplayName -Value ''
    $jsService | Add-Member -Membertype NoteProperty -Name ServiceDescription -Value ''

    $js | Add-Member -Membertype NoteProperty -Name Install -Value $jsInstall
    $js | Add-Member -Membertype NoteProperty -Name Config -Value $jsConfig
    $js | Add-Member -Membertype NoteProperty -Name Service -Value $jsService

    $js
}

function Create-StatusObject()
{
    $state = New-Object PSObject

    $state | Add-Member -Membertype NoteProperty -Name Id -Value ''
    $state | Add-Member -Membertype NoteProperty -Name Url -Value ''
    $state | Add-Member -Membertype NoteProperty -Name ProxyUrl -Value ''

    $state | Add-Member -Membertype NoteProperty -Name Version -Value ''
    $state | Add-Member -Membertype NoteProperty -Name State -Value ''
    $state | Add-Member -Membertype NoteProperty -Name Pid -Value 0
    $state | Add-Member -Membertype NoteProperty -Name RunningSince -Value ''

    $state | Add-Member -Membertype NoteProperty -Name JobChainsExist -Value 0
    $state | Add-Member -Membertype NoteProperty -Name OrdersExist -Value 0
    $state | Add-Member -Membertype NoteProperty -Name JobsExist -Value 0
    $state | Add-Member -Membertype NoteProperty -Name TasksExist -Value 0
    $state | Add-Member -Membertype NoteProperty -Name TasksEnqueued -Value 0

    $state
}

function Create-StatisticsObject()
{
    $stat = New-Object PSObject

    $stat | Add-Member -Membertype NoteProperty -Name JobsExist -Value 0
    $stat | Add-Member -Membertype NoteProperty -Name JobsPending -Value 0
    $stat | Add-Member -Membertype NoteProperty -Name JobsRunning -Value 0
    $stat | Add-Member -Membertype NoteProperty -Name JobsStopped -Value 0
    $stat | Add-Member -Membertype NoteProperty -Name JobsNeedProcess -Value 0

    $stat | Add-Member -Membertype NoteProperty -Name TasksExist -Value 0
    $stat | Add-Member -Membertype NoteProperty -Name TasksRunning -Value 0
    $stat | Add-Member -Membertype NoteProperty -Name TasksStarting -Value 0
    
    $stat | Add-Member -Membertype NoteProperty -Name OrdersExist -Value 0
    $stat | Add-Member -Membertype NoteProperty -Name OrdersClustered -Value 0
    $stat | Add-Member -Membertype NoteProperty -Name OrdersStanding -Value 0

    $stat | Add-Member -Membertype NoteProperty -Name SchedulesExist -Value 0
    $stat | Add-Member -Membertype NoteProperty -Name ProcessClassesExist -Value 0
    $stat | Add-Member -Membertype NoteProperty -Name FoldersExist -Value 0
    $stat | Add-Member -Membertype NoteProperty -Name LocksExist -Value 0
    $stat | Add-Member -Membertype NoteProperty -Name MonitorsExist -Value 0
    
    $stat
}

function Create-CalendarObject()
{
    $cal = New-Object PSObject

    $cal | Add-Member -Membertype NoteProperty -Name AtOrder -Value @()
    $cal | Add-Member -Membertype NoteProperty -Name PeriodOrder -Value @()
    $cal | Add-Member -Membertype NoteProperty -Name PeriodJob -Value @()
    
    $cal
}

function Create-CalendarAtOrderObject()
{
    $calAtOrder = New-Object PSObject

    $calAtOrder | Add-Member -Membertype NoteProperty -Name JobChain -Value ''
    $calAtOrder | Add-Member -Membertype NoteProperty -Name OrderId -Value ''
    $calAtOrder | Add-Member -Membertype NoteProperty -Name StartAt -Value ''
    
    $calAtOrder
}

function Create-CalendarPeriodOrderObject()
{
    $calPeriodOrder = New-Object PSObject

    $calPeriodOrder | Add-Member -Membertype NoteProperty -Name JobChain -Value ''
    $calPeriodOrder | Add-Member -Membertype NoteProperty -Name OrderId -Value ''
    $calPeriodOrder | Add-Member -Membertype NoteProperty -Name BeginAt -Value ''
    $calPeriodOrder | Add-Member -Membertype NoteProperty -Name EndAt -Value ''
    $calPeriodOrder | Add-Member -Membertype NoteProperty -Name Repeat -Value ''
    $calPeriodOrder | Add-Member -Membertype NoteProperty -Name AbsoluteRepeat -Value ''
    
    $calPeriodOrder
}

function Create-CalendarPeriodJobObject()
{
    $calPeriodJob = New-Object PSObject

    $calPeriodJob | Add-Member -Membertype NoteProperty -Name Job -Value ''
    $calPeriodJob | Add-Member -Membertype NoteProperty -Name BeginAt -Value ''
    $calPeriodJob | Add-Member -Membertype NoteProperty -Name EndAt -Value ''
    $calPeriodJob | Add-Member -Membertype NoteProperty -Name Repeat -Value ''
    $calPeriodJob | Add-Member -Membertype NoteProperty -Name AbsoluteRepeat -Value ''
    
    $calPeriodJob
}

function Create-JobChainObject()
{
    $jobChain = New-Object PSObject

    $jobChain | Add-Member -Membertype NoteProperty -Name JobChain -Value ''
    $jobChain | Add-Member -Membertype NoteProperty -Name Path -Value ''
    $jobChain | Add-Member -Membertype NoteProperty -Name Directory -Value ''
    $jobChain | Add-Member -Membertype NoteProperty -Name State -Value ''
    $jobChain | Add-Member -Membertype NoteProperty -Name Title -Value ''
    $jobChain | Add-Member -Membertype NoteProperty -Name Orders -Value 0
    $jobChain | Add-Member -Membertype NoteProperty -Name RunningOrders -Value 0

    $jobChain
}

function Create-OrderObject()
{
    $order = New-Object PSObject

    $order | Add-Member -Membertype NoteProperty -Name Order -Value ''
    $order | Add-Member -Membertype NoteProperty -Name Name -Value ''
    $order | Add-Member -Membertype NoteProperty -Name Path -Value ''
    $order | Add-Member -Membertype NoteProperty -Name Directory -Value ''
    $order | Add-Member -Membertype NoteProperty -Name JobChain -Value ''
    $order | Add-Member -Membertype NoteProperty -Name State -Value ''
    $order | Add-Member -Membertype NoteProperty -Name EndState -Value ''
    $order | Add-Member -Membertype NoteProperty -Name Title -Value ''
    $order | Add-Member -Membertype NoteProperty -Name LogFile -Value ''
    $order | Add-Member -Membertype NoteProperty -Name Job -Value ''
    $order | Add-Member -Membertype NoteProperty -Name At -Value ''
    $order | Add-Member -Membertype NoteProperty -Name NextStartTime -Value ''
    $order | Add-Member -Membertype NoteProperty -Name StateText -Value ''
    $order | Add-Member -Membertype NoteProperty -Name Parameters -Value @{}
    $order | Add-Member -Membertype NoteProperty -Name Log -Value ''

    $order
}

function Create-JobObject()
{
    $job = New-Object PSObject

    $job | Add-Member -Membertype NoteProperty -Name Job -Value ''
    $job | Add-Member -Membertype NoteProperty -Name Path -Value ''
    $job | Add-Member -Membertype NoteProperty -Name Directory -Value ''
    $job | Add-Member -Membertype NoteProperty -Name State -Value ''
    $job | Add-Member -Membertype NoteProperty -Name Title -Value ''
    $job | Add-Member -Membertype NoteProperty -Name LogFile -Value ''
    $job | Add-Member -Membertype NoteProperty -Name Tasks -Value ''
    $job | Add-Member -Membertype NoteProperty -Name IsOrder -Value ''
    $job | Add-Member -Membertype NoteProperty -Name ProcessClass -Value ''
    $job | Add-Member -Membertype NoteProperty -Name At -Value ''
    $job | Add-Member -Membertype NoteProperty -Name NextStartTime -Value ''
    $job | Add-Member -Membertype NoteProperty -Name StateText -Value ''
    $job | Add-Member -Membertype NoteProperty -Name Parameters -Value @{}

    $job
}

function Create-TaskObject()
{
    $task = New-Object PSObject

    $task | Add-Member -Membertype NoteProperty -Name Task -Value 0
    $task | Add-Member -Membertype NoteProperty -Name Job -Value ''
    $task | Add-Member -Membertype NoteProperty -Name State -Value ''
    $task | Add-Member -Membertype NoteProperty -Name LogFile -Value ''
    $task | Add-Member -Membertype NoteProperty -Name Steps -Value ''
    $task | Add-Member -Membertype NoteProperty -Name EnqueuedAt -Value ''
    $task | Add-Member -Membertype NoteProperty -Name StartAt -Value ''
    $task | Add-Member -Membertype NoteProperty -Name RunningSince -Value ''
    $task | Add-Member -Membertype NoteProperty -Name Cause -Value ''

    # $taskDefaultProperties = @("Task", "Job")
    # $taskDefaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet( "DefaultDisplayPropertySet", [string[]] $taskDefaultProperties )
    # $taskPSStandardMembers = [System.Management.Automation.PSMemberInfo[]] @( $taskDefaultDisplayPropertySet )
    # $task | Add-Member MemberSet PSStandardMembers $taskPSStandardMembers
    
    $task
}

function Create-EventObject()
{
    $event = New-Object PSObject

    $event | Add-Member -Membertype NoteProperty -Name EventClass -Value ''
    $event | Add-Member -Membertype NoteProperty -Name EventId -Value ''
    $event | Add-Member -Membertype NoteProperty -Name ExitCode -Value 0
    $event | Add-Member -Membertype NoteProperty -Name Job -Value ''
    $event | Add-Member -Membertype NoteProperty -Name JobChain -Value ''
    $event | Add-Member -Membertype NoteProperty -Name Order -Value ''
    $event | Add-Member -Membertype NoteProperty -Name MasterUrl -Value ''
    $event | Add-Member -Membertype NoteProperty -Name ExpirationDate -Value ''
    $event | Add-Member -Membertype NoteProperty -Name ExpirationCycle -Value ''
    $event | Add-Member -Membertype NoteProperty -Name ExpirationPeriod -Value ''
    $event | Add-Member -Membertype NoteProperty -Name Created -Value ''

    $event
}

function Create-JSAgentObject()
{
    $jsAgent = New-Object PSObject
    $jsAgentInstall = New-Object PSObject
    $jsAgentConfig = New-Object PSObject
    $jsAgentService = New-Object PSObject
    
    $jsAgent | Add-Member -Membertype NoteProperty -Name Url -Value ''
    $jsAgent | Add-Member -Membertype NoteProperty -Name ProxyUrl -Value ''
    $jsAgent | Add-Member -Membertype NoteProperty -Name Local -Value $false

    $jsAgentInstall | Add-Member -Membertype NoteProperty -Name Directory -Value ''
    $jsAgentInstall | Add-Member -Membertype NoteProperty -Name ExecutableFile -Value ''
    $jsAgentInstall | Add-Member -Membertype NoteProperty -Name Params -Value ''
    $jsAgentInstall | Add-Member -Membertype NoteProperty -Name StartParams -Value ''
    $jsAgentInstall | Add-Member -Membertype NoteProperty -Name PidFile -Value ''

    $jsAgentConfig | Add-Member -Membertype NoteProperty -Name Directory -Value ''

    $jsAgentService | Add-Member -Membertype NoteProperty -Name ServiceName -Value ''
    $jsAgentService | Add-Member -Membertype NoteProperty -Name ServiceDisplayName -Value ''
    $jsAgentService | Add-Member -Membertype NoteProperty -Name ServiceDescription -Value ''

    $jsAgent | Add-Member -Membertype NoteProperty -Name Install -Value $jsAgentInstall
    $jsAgent | Add-Member -Membertype NoteProperty -Name Config -Value $jsAgentConfig
    $jsAgent | Add-Member -Membertype NoteProperty -Name Service -Value $jsAgentService

    $jsAgent
}

function Create-AgentClusterObject()
{
    $jsAgentCluster = New-Object PSObject

    $jsAgentCluster | Add-Member -Membertype NoteProperty -Name AgentCluster -Value ''
    $jsAgentCluster | Add-Member -Membertype NoteProperty -Name Path -Value ''
    $jsAgentCluster | Add-Member -Membertype NoteProperty -Name Directory -Value ''
    $jsAgentCluster | Add-Member -Membertype NoteProperty -Name MaxProcesses -Value 0
    $jsAgentCluster | Add-Member -Membertype NoteProperty -Name ClusterType -Value ''
    $jsAgentCluster | Add-Member -Membertype NoteProperty -Name Agents -Value @()

    $jsAgentCluster
}

function Create-AgentStateObject()
{
    $jsAgentState = New-Object PSObject

    $jsAgentstate | Add-Member -Membertype NoteProperty -Name isTerminating -Value ''

    $jsAgentStateSystem = New-Object PSObject
    $jsAgentStateSystem | Add-Member -Membertype NoteProperty -Name hostname -Value ''
    $jsAgentState | Add-Member -Membertype NoteProperty -Name system -Value $jsAgentStateSystem
    
    $jsAgentState | Add-Member -Membertype NoteProperty -Name currentTaskCount -Value ''
    $jsAgentState | Add-Member -Membertype NoteProperty -Name startedAt -Value ''
    $jsAgentState | Add-Member -Membertype NoteProperty -Name version -Value ''
    $jsAgentState | Add-Member -Membertype NoteProperty -Name totalTaskCount -Value ''
    
    $jsAgentState
}

function Create-WebServiceObject()
{
    $jsWebService = New-Object PSObject

    $jsWebService | Add-Member -Membertype NoteProperty -Name Url -Value ''
    $jsWebService | Add-Member -Membertype NoteProperty -Name ProxyUrl -Value ''
    $jsWebService | Add-Member -Membertype NoteProperty -Name AccessToken -Value ''

    $jsWebService
}

# send XML encoded command to JobScheduler Master
function Send-JobSchedulerXMLCommand( [Uri] $jobSchedulerURL, [string] $command, [bool] $checkResponse=$true ) 
{
    $output = $null

    $request = $null
    $requestStream = $null

    $response = $null
    $responseStream = $null
    $streamReader = $null

    try
    {
        if ( $SCRIPT:jsOperations -and $jobSchedulerURL -eq $SCRIPT:js.Url )
        {
            $output = $spooler.execute_xml( $command )
        } else {
            $request = [System.Net.WebRequest]::Create( $jobSchedulerURL )
    
            $request.Method = 'POST'
            $request.ContentType = 'text/xml'
            $request.Timeout = $SCRIPT:jsOptionWebRequestTimeout
            
            if ( $SCRIPT:jsOptionWebRequestUseDefaultCredentials )
            {
                Write-Debug ".... $($MyInvocation.MyCommand.Name): using default credentials"
                $request.UseDefaultCredentials = $true
            } elseif ( $SCRIPT:jsCredentials ) {
                Write-Debug ".... $($MyInvocation.MyCommand.Name): using explicit credentials"
                $request.Credentials = $SCRIPT:jsCredentials
            }
    
            if ( $SCRIPT:js.ProxyUrl )
            {
                $proxy = new-object System.Net.WebProxy $SCRIPT:js.ProxyUrl
    
                if ( $SCRIPT:jsOptionWebRequestProxyUseDefaultCredentials )
                {
                    $proxy.UseDefaultCredentials = $true
                    Write-Debug ".... $($MyInvocation.MyCommand.Name): using default proxy credentials"
                } elseif ( $SCRIPT:jsProxyCredentials ) {
                    Write-Debug ".... $($MyInvocation.MyCommand.Name): using explicit proxy credentials"
                    $proxy.Credentials = $SCRIPT:jsProxyCredentials
                }
    
                $request.Proxy = $proxy
            }
    
            $bytes = [System.Text.Encoding]::ASCII.GetBytes( $command )
            $request.ContentLength = $bytes.Length
            $requestStream = $request.GetRequestStream()
            $requestStream.Write( $bytes, 0, $bytes.Length )
    
            $requestStream.Close()
            
            if ( $checkResponse )
            {
                try
                {
                    $response = $request.GetResponse()
                } catch {
                    # reset credentials in case of response errors, eg. HTTP 401 not authenticated
                    $SCRIPT:jsCredentials = $null
                    throw "$($MyInvocation.MyCommand.Name): JobScheduler returns error, if credentials are missing consider to use the Set-Credentials cmdlet: " + $_.Exception                
                }
    
                if ( $response.StatusCode -ne 'OK' )
                {
                    throw "JobScheduler returns status code: $($response.StatusCode)"
                }
    
                $responseStream = $response.getResponseStream() 
                
                # $streamReader = new-object System.IO.StreamReader $responseStream
                # $output = $streamReader.ReadToEnd()
                
                $encoding = [Text.Encoding]::GetEncoding(28591)
                $streamReader = new-object System.IO.StreamReader -Argumentlist $responseStream, $encoding
                $output = $streamReader.ReadToEnd()
            }
        }

        if ( $checkResponse -and $output )
        {
            if ( $DebugPreference -eq 'Continue' )
            {
                if ( $output.Length -gt $SCRIPT:jsOptionDebugMaxOutputSize )
                {
                    $tempFile = [IO.Path]::GetTempFileName()
                    $output | Out-File $tempFile -encoding utf8
                    Write-Debug ".... $($MyInvocation.MyCommand.Name): XML response available with temporary file: $($tempFile)"
                } else {
                    Write-Debug ".... $($MyInvocation.MyCommand.Name): response: $($output)"
                }
            }

            try
            {
                $answer = Select-XML -Content $output -Xpath '/spooler/answer'
                if ( !$answer ) 
                {
                    throw 'missing answer element /spooler/answer in response'
                }
            } catch {
                throw 'not a valid JobScheduler XML response: ' + $_.Exception.Message
            }
            
            $errorText = Select-XML -Content $output -Xpath '/spooler/answer/ERROR/@text'
            if ( $errorText.Node."#text" )
            {
                throw $errorText.Node."#text"
            }

            try
            {
                [xml] $output
            } catch {
                throw 'not a valid JobScheduler XML response: ' + $_.Exception.Message
            }
        }
    } catch {
        throw "$($MyInvocation.MyCommand.Name): " + $_.Exception.Message
    } finally {
        if ( $streamReader )
        {
            $streamReader.Close()
            $streamReader = $null
        }
        
        if ( $responseStream )
        {
            $responseStream.Close()
            $responseStream = $null
        }
        
        if ( $response )
        {
            $response.Close()
            $response = $null
        }
    }
}

# send JSON encoded request to JobScheduler Agent
function Send-JobSchedulerAgentRequest( [Uri] $url, [string] $method='GET', [string] $command, [bool] $checkResponse=$true )
{
    $output = $null

    $request = $null
    $requestStream = $null

    $response = $null
    $responseStream = $null
    $streamReader = $null

    try
    {
        $request = [System.Net.WebRequest]::Create( $url )
        $request.Method = $method
        $request.ContentType = 'application/json'
        $request.Accept = 'application/json'
        $request.Timeout = $SCRIPT:jsAgentOptionWebRequestTimeout
        
        if ( $SCRIPT:jsAgentOptionWebRequestUseDefaultCredentials )
        {
            Write-Debug ".... $($MyInvocation.MyCommand.Name): using default credentials"
            $request.UseDefaultCredentials = $true
        } elseif ( $SCRIPT:jsAgentCredentials ) {
            Write-Debug ".... $($MyInvocation.MyCommand.Name): using explicit credentials"
            $request.Credentials = $SCRIPT:jsAgentCredentials
        }
    
        if ( $SCRIPT:jsAgent.ProxyUrl )
        {
            $proxy = New-Object System.Net.WebProxy $SCRIPT:jsAgent.ProxyUrl
    
            if ( $SCRIPT:jsAgentOptionWebRequestProxyUseDefaultCredentials )
            {
                $proxy.UseDefaultCredentials = $true
                Write-Debug ".... $($MyInvocation.MyCommand.Name): using default proxy credentials"
            } elseif ( $SCRIPT:jsAgentProxyCredentials ) {
                Write-Debug ".... $($MyInvocation.MyCommand.Name): using explicit proxy credentials"
                $proxy.Credentials = $SCRIPT:jsAgentProxyCredentials
            }
    
            $request.Proxy = $proxy
        }

        if ( $method -eq 'POST' )
        {
            $bytes = [System.Text.Encoding]::ASCII.GetBytes( $command )
            $request.ContentLength = $bytes.Length
            $requestStream = $request.GetRequestStream()
            $requestStream.Write( $bytes, 0, $bytes.Length )
            $requestStream.Close()
        }

        if ( $checkResponse )
        {
            try
            {
                $response = $request.GetResponse()
            } catch {
                # reset credentials in case of response errors, eg. HTTP 401 not authenticated
                $SCRIPT:jsAgentCredentials = $null
                throw "$($MyInvocation.MyCommand.Name): JobScheduler Agent returns error, if credentials are missing consider to use the Set-AgentCredentials cmdlet: " + $_.Exception                
            }
    
            if ( $response.StatusCode -ne 'OK' )
            {
                throw "JobScheduler Agent returns status code: $($response.StatusCode)"
            }
    
            $responseStream = $response.getResponseStream()             
            $streamReader = New-Object System.IO.StreamReader $responseStream            
            $output = $streamReader.ReadToEnd()
        }

        if ( $checkResponse -and $output )
        {
            if ( $DebugPreference -eq 'Continue' )
            {
                if ( $output.Length -gt $SCRIPT:jsOptionDebugMaxOutputSize )
                {
                    $tempFile = [IO.Path]::GetTempFileName()
                    $output | Out-File $tempFile -encoding utf8
                    Write-Debug ".... $($MyInvocation.MyCommand.Name): JobScheduler Agent response available with temporary file: $($tempFile)"
                } else {
                    Write-Debug ".... $($MyInvocation.MyCommand.Name): response: $($output)"
                }
            }

            try
            {
                Add-Type -AssemblyName System.Web.Extensions
                $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
                $answer = New-Object PSObject -Property $serializer.DeserializeObject( $output )

               if ( !$answer ) 
                {
                    throw 'missing JSON content in response'
                }
            } catch {
                throw 'not a valid JobScheduler Agent JSON response: ' + $_.Exception.Message
            }
            
            try
            {
                $answer
            } catch {
                throw 'not a valid JobScheduler Agent JSON response: ' + $_.Exception.Message
            }
        }
    } catch {
        throw "$($MyInvocation.MyCommand.Name): " + $_.Exception.Message
    } finally {
        if ( $streamReader )
        {
            $streamReader.Close()
            $streamReader = $null
        }
        
        if ( $responseStream )
        {
            $responseStream.Close()
            $responseStream = $null
        }
        
        if ( $response )
        {
            $response.Close()
            $response = $null
        }
    }
}

# send JSON encoded request to JobScheduler Web Service
function Send-JobSchedulerWebServiceRequest( [Uri] $url, [string] $method='GET', [string] $body, [bool] $checkResponse=$true, [hashtable] $headers )
{
    $output = $null

    $request = $null
    $requestStream = $null

    $response = $null
    $responseStream = $null
    $streamReader = $null

    try
    {
        $request = [System.Net.WebRequest]::Create( $url )
        $request.Method = $method
        $request.ContentType = 'application/json'
        $request.Accept = 'application/json'
        $request.Timeout = $SCRIPT:jsOptionWebRequestTimeout
        
        $headers.Keys | % { 
            $request.Headers.add( $_, $headers.Item($_) )
            Write-Debug ".... $($MyInvocation.MyCommand.Name): using header $($_): $($headers.Item($_))"
        }
        
        if ( $SCRIPT:jsWebService -and $SCRIPT:jsWebService.AccessToken )
        {
            $request.Headers.add( 'access_token', $SCRIPT:jsWebService.AccessToken )
        }
        
        if ( $SCRIPT:jsWebServiceOptionWebRequestUseDefaultCredentials )
        {
            Write-Debug ".... $($MyInvocation.MyCommand.Name): using default credentials"
            $request.UseDefaultCredentials = $true
        } elseif ( $SCRIPT:jsWebServiceCredentials ) {
            # Write-Debug ".... $($MyInvocation.MyCommand.Name): using explicit credentials"
            # $request.Credentials = $SCRIPT:jsWebServiceCredentials
        }
    
        if ( $SCRIPT:jsWebService -and $SCRIPT:jsWebService.ProxyUrl )
        {
            $proxy = New-Object System.Net.WebProxy $SCRIPT:jsWebService.ProxyUrl
    
            if ( $SCRIPT:jsWebServiceOptionWebRequestProxyUseDefaultCredentials )
            {
                $proxy.UseDefaultCredentials = $true
                Write-Debug ".... $($MyInvocation.MyCommand.Name): using default proxy credentials"
            } elseif ( $SCRIPT:jsWebServiceProxyCredentials ) {
                Write-Debug ".... $($MyInvocation.MyCommand.Name): using explicit proxy credentials"
                $proxy.Credentials = $SCRIPT:jsWebServiceProxyCredentials
            }
    
            $request.Proxy = $proxy
        }

        if ( $method -eq 'POST' )
        {
            $bytes = [System.Text.Encoding]::ASCII.GetBytes( $body )
            $request.ContentLength = $bytes.Length
            $requestStream = $request.GetRequestStream()
            $requestStream.Write( $bytes, 0, $bytes.Length )
            $requestStream.Close()
        }

        if ( $checkResponse )
        {
            try
            {
                $response = $request.GetResponse()                
            } catch {
                # reset credentials in case of response errors, eg. HTTP 401 not authenticated
                $SCRIPT:jsWebServiceCredentials = $null
                throw "$($MyInvocation.MyCommand.Name): Web Service returns error, if credentials are missing consider to use the Set-WebServiceCredentials cmdlet: " + $_.Exception                
            } finally {
            
                if ( $response -and $response.Headers['access_token'] )
                {
                    if ( !$SCRIPT:jsWebService )
                    {
                        $SCRIPT:jsWebService = Create-WebServiceObject
                        $SCRIPT:jsWebService.Url = $url.scheme + '://' + $url.Authority
                    }
                    $SCRIPT:jsWebService.AccessToken = $response.Headers['access_token']
                }
                
                foreach( $headerKey in $response.Headers ) {                
                    $headerStr = $response.Headers[$headerKey];
                    if ( $headerStr )
                    {
                        Write-Debug ".... $($MyInvocation.MyCommand.Name): response header: $($headerKey): $($headerStr)"
                    }
                }
                
            }
    
            if ( $response.StatusCode -ne 'OK' )
            {
                throw "Web Service returns status code: $($response.StatusCode)"
            }
    
            $responseStream = $response.getResponseStream() 
            $streamReader = New-Object System.IO.StreamReader $responseStream            
            $output = $streamReader.ReadToEnd()
        }

        if ( $checkResponse -and $output )
        {
            if ( $DebugPreference -eq 'Continue' )
            {
                if ( $output.Length -gt $SCRIPT:jsOptionDebugMaxOutputSize )
                {
                    $tempFile = [IO.Path]::GetTempFileName()
                    $output | Out-File $tempFile -encoding utf8
                    Write-Debug ".... $($MyInvocation.MyCommand.Name): Web Service response available with temporary file: $($tempFile)"
                } else {
                    Write-Debug ".... $($MyInvocation.MyCommand.Name): response: $($output)"
                }
            }

            try
            {
                Add-Type -AssemblyName System.Web.Extensions
                $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
                $answer = New-Object PSObject -Property $serializer.DeserializeObject( $output )

               if ( !$answer ) 
                {
                    throw 'missing JSON content in Web Service response'
                }
            } catch {
                throw 'not a valid Web Service JSON response: ' + $_.Exception.Message
            }
            
            try
            {
                $answer
            } catch {
                throw 'not a valid Web Service JSON response: ' + $_.Exception.Message
            }
        }
    } catch {
        throw "$($MyInvocation.MyCommand.Name): " + $_.Exception.Message
    } finally {
        if ( $streamReader )
        {
            $streamReader.Close()
            $streamReader = $null
        }
        
        if ( $responseStream )
        {
            $responseStream.Close()
            $responseStream = $null
        }
        
        if ( $response )
        {
            $response.Close()
            $response = $null
        }
    }
}

# return the directory name of a path
function Get-DirectoryName( [string] $path )
{
    if ( $path.LastIndexOf('\') -ge 0 )
    {
        $path = $path.Substring( $path.LastIndexOf('\')+1 )
    } elseif ( $path.LastIndexOf('/') -ge 0 ) {
        $path = $path.Substring( $path.LastIndexOf('/')+1 )
    }
    
    $path
}

# return the basename of an object
function Get-JobSchedulerObject-Basename( [string] $objectPath )
{
    if ( $objectPath.LastIndexOf('/') -ge 0 )
    {
        $objectPath = $objectPath.Substring( $objectPath.LastIndexOf('/')+1 )
    }

    $objectPath
}

# return the parent folder of an object
function Get-JobSchedulerObject-Parent( [string] $objectPath )
{
    if ( $objectPath.LastIndexOf('/') -ge 0 )
    {
        $objectPath.Substring( 0, $objectPath.LastIndexOf('/') )
    }
}

# return the canonical path of an object, i.e. the full path
function Get-JobSchedulerObject-CanonicalPath( [string] $objectPath )
{
    if ( $objectPath.LastIndexOf('/') -ge 0 )
    {
        $objectPath = $objectPath.Substring( 0, $objectPath.LastIndexOf('/') )
    }
    
    $objectPath = ([string] $spooler.configuration_directory()) + $objectPath

    $objectPath
}

# execute Windows command script and return environment variables
function Invoke-CommandScript
{
<#
.SYNOPSIS

Invoke the specified batch file (and parameters), but also propagate any
environment variable changes back to the PowerShell environment that
called it.

#>
param
(
    [Parameter(Mandatory = $true)]
    [string] $Path,
    [string] $ArgumentList
)

    #Set-StrictMode -Version 3

    $tempFile = [IO.Path]::GetTempFileName()

    ## Store the output of cmd.exe.  We also ask cmd.exe to output
    ## the environment table after the batch file completes
    ## cmd /c " `"$Path`" $ArgumentList && set > `"$tempFile`" "

    $process = Start-Process -FilePath "cmd.exe" "/c ""`"$Path`" $ArgumentList && set > `"$tempFile`""" " -WindowStyle Hidden -PassThru -Wait
    if ( !$process.ExitCode -eq 0 )
    {
        throw "$($MyInvocation.MyCommand.Name): command script execution failed with exit code: $($process.ExitCode)"
    }

    ## Go through the environment variables in the temp file.
    ## For each of them, set the variable in our local environment.
    Get-Content $tempFile | Foreach-Object {
        if($_ -match "^(.*?)=(.*)$")
        {
#           Set-Content "env:\$($matches[1])" $matches[2]
            $SCRIPT:jsEnv["$($matches[1])"] = $matches[2]
        }
    }

    Remove-Item $tempFile
}

function Create-ParamNode( [xml] $xmlDoc, [string] $name, [string] $value )
{
    $paramNode = $xmlDoc.CreateElement( 'param' )
    $paramNode.SetAttribute( 'name', $name )
    $paramNode.SetAttribute( 'value', $value )
        
    $paramNode
}

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------

$js = Create-JSObject

if ( $jsOperations )
{
    # no addtional connection to Master required
    $js.Url = "http://$($spooler.hostname()):$($spooler.tcp_port())"
    $js.Id = $spooler.id()
    $js.Local = $false
} elseif ( $env:SCHEDULER_URL ) {
    Use-JobSchedulerMaster -Url $env:SCHEDULER_URL -Id $env:SCHEDULER_ID
} elseif ( $env:SCHEDULER_ID ) {
    Use-JobSchedulerMaster -Id $env:SCHEDULER_ID
}

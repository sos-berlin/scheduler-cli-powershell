<#
.SYNOPSIS
JobScheduler command line interface

For further information see

    PS C:\> about_JobScheduler

If the documentation is not available for your language then consider to use

    PS C:\> [System.Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
    
#>

#Requires -Version 5.0

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
[System.Management.Automation.PSCredential] $jsCredential = $null
#    Use default credentials of the current user?
[bool] $jsOptionWebRequestUseDefaultCredentials = $true
#     Proxy Credentials
[System.Management.Automation.PSCredential] $jsProxyCredential = $null
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
[System.Management.Automation.PSCredential] $jsAgentCredential = $null
#    Use default credentials of the current user?
[bool] $jsAgentOptionWebRequestUseDefaultCredentials = $true
#     Proxy Credentials
[System.Management.Automation.PSCredential] $jsAgentProxyCredential = $null
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
[System.Management.Automation.PSCredential] $jsWebServiceCredential = $null
#    Use default credentials of the current user?
[bool] $jsWebServiceOptionWebRequestUseDefaultCredentials = $false
#     Proxy Credentials
[System.Management.Automation.PSCredential] $jsWebServiceProxyCredential = $null
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

    if ( !$SCRIPT:js.Url -and !$SCRIPT:jsOperations -and !$SCRIPT:jsWebService.JobSchedulerId )
    {
        if ( $SCRIPT:jsLocalCommands -notcontains $command.Name )
        {
            throw "$($command.Name): cmdlet requires a JobScheduler URL. Switch instance with the Use-JobSchedulerWebService cmdlet and specify the -Url parameter"
        }
    }
}

function Approve-JobSchedulerAgentCommand( [System.Management.Automation.CommandInfo] $command )
{
    if ( !$SCRIPT:jsAgent.Local )
    {
        if ( $SCRIPT:jsAgentLocalCommands -contains $command.Name )
        {
            throw "$($command.Name): cmdlet is available exclusively for local JobScheduler Agent. Switch instance with the Use-JobSchedulerAgent cmdlet and specify the -InstallPath parameter for a local JobScheduler Agent"
        }
    }

    if ( !$SCRIPT:jsAgent.Url -and !$SCRIPT:jsOperations )
    {
        if ( $SCRIPT:jsAgentLocalCommands -notcontains $command.Name )
        {
            throw "$($command.Name): cmdlet requires a JobScheduler Agent URL. Switch instance with the Use-JobSchedulerAgent cmdlet and specify the -Url parameter"
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
    $jobChain | Add-Member -Membertype NoteProperty -Name Volatile -Value ''
    $jobChain | Add-Member -Membertype NoteProperty -Name Permanent -Value ''

    $jobChain
}

function Create-OrderObject()
{
    $order = New-Object PSObject

    $order | Add-Member -Membertype NoteProperty -Name OrderId -Value ''
    $order | Add-Member -Membertype NoteProperty -Name JobChain -Value ''
    $order | Add-Member -Membertype NoteProperty -Name Path -Value ''
    $order | Add-Member -Membertype NoteProperty -Name Directory -Value ''
    $order | Add-Member -Membertype NoteProperty -Name Volatile -Value ''
    $order | Add-Member -Membertype NoteProperty -Name Permanent -Value ''
    $order | Add-Member -Membertype NoteProperty -Name OrderHistory -Value @()

    $order
}

function Create-OrderHistoryObject()
{
    $orderHistory = Create-OrderObject
    $orderHistory | Add-Member -Membertype NoteProperty -Name HistoryId -Value ''

    $orderHistory
}

function Create-JobObject()
{
    $job = New-Object PSObject

    $job | Add-Member -Membertype NoteProperty -Name Job -Value ''
    $job | Add-Member -Membertype NoteProperty -Name Path -Value ''
    $job | Add-Member -Membertype NoteProperty -Name Directory -Value ''
    $job | Add-Member -Membertype NoteProperty -Name Volatile -Value ''
    $job | Add-Member -Membertype NoteProperty -Name Permanent -Value ''
    $job | Add-Member -Membertype NoteProperty -Name Tasks -Value @()
    $job | Add-Member -Membertype NoteProperty -Name TaskHistory -Value @()

    $job
}

function Create-JobHistoryObject()
{
    $jobHistory = Create-JobObject

    $jobHistory | Add-Member -Membertype NoteProperty -Name HistoryId -Value ''
    $jobHistory | Add-Member -Membertype NoteProperty -Name AgentUrl -Value ''
    $jobHistory | Add-Member -Membertype NoteProperty -Name Cause -Value ''
    $jobHistory | Add-Member -Membertype NoteProperty -Name StartTime -Value ''
    $jobHistory | Add-Member -Membertype NoteProperty -Name EndTime -Value ''
    $jobHistory | Add-Member -Membertype NoteProperty -Name ExitCode -Value ''
    $jobHistory | Add-Member -Membertype NoteProperty -Name Task -Value ''
    $jobHistory | Add-Member -Membertype NoteProperty -Name Steps -Value ''

    $jobHistory
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
   #$event | Add-Member -Membertype NoteProperty -Name MasterUrl -Value ''
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
    $jsAgentInstall | Add-Member -Membertype NoteProperty -Name HttpPort -Value ''
    $jsAgentInstall | Add-Member -Membertype NoteProperty -Name HttpsPort -Value ''
    $jsAgentInstall | Add-Member -Membertype NoteProperty -Name LogDirectory -Value ''
    $jsAgentInstall | Add-Member -Membertype NoteProperty -Name PidFileDirectory -Value ''
    $jsAgentInstall | Add-Member -Membertype NoteProperty -Name WorkingDirectory -Value ''
    $jsAgentInstall | Add-Member -Membertype NoteProperty -Name KillScript -Value ''
    $jsAgentInstall | Add-Member -Membertype NoteProperty -Name InstanceScript -Value ''

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
    $jsWebService | Add-Member -Membertype NoteProperty -Name Base -Value ''
    $jsWebService | Add-Member -Membertype NoteProperty -Name Timeout -Value 0
    $jsWebService | Add-Member -Membertype NoteProperty -Name SkipCertificateCheck -Value $false
    $jsWebService | Add-Member -Membertype NoteProperty -Name SSLProtocol -Value ''
    $jsWebService | Add-Member -Membertype NoteProperty -Name Certificate -Value ''
    $jsWebService | Add-Member -Membertype NoteProperty -Name JobSchedulerId -Value ''
    $jsWebService | Add-Member -Membertype NoteProperty -Name AccessToken -Value ''

    $jsWebService
}

function isPowerShellVersion( [int] $Major=-1, [int] $Minor=-1, [int] $Patch=-1 )
{
    $rc = $false
    
    if ( $Major -gt -1 )
    {
        if ( $PSVersionTable.PSVersion.Major -eq $Major )
        {
            if ( $Minor -gt -1 )
            {
                if ( $PSVersionTable.PSVersion.Minor -eq $Minor )
                {
                    if ( $Patch -gt - 1 )
                    {
                        if ( $PSVersionTable.PSVersion.Patch -ge $Patch )
                        {
                            $rc = $true
                        }
                    } else {
                        $rc = $true
                    }
                } elseif ( $PSVersionTable.PSVersion.Minor -gt $Minor ) {
                    $rc = $true
                } else {
                    $rc = $true
                }
            } else {
                $rc = $true
            }
        } elseif ( $PSVersionTable.PSVersion.Major -gt $Major ) {
            $rc = $true
        }
    }

    $rc
}

function Invoke-JobSchedulerWebRequest( [string] $Path, [string] $Body, [string] $ContentType='application/json', [hashtable] $Headers=@{'Accept' = 'application/json'} )
{
    if ( $script:jsWebService.Url.UserInfo )
    {
        $requestUrl = $script:jsWebService.Url.scheme + '://' + $script:jsWebService.Url.UserInfo + '@' + $script:jsWebService.Url.Authority + $script:jsWebService.Base + $Path
    } else {
        $requestUrl = $script:jsWebService.Url.scheme + '://' + $script:jsWebService.Url.Authority + $script:jsWebService.Base + $Path
    }

    $requestParams = @{}
    $requestParams.Add( 'Verbose', $false )
    $requestParams.Add( 'Uri', $requestUrl )
    $requestParams.Add( 'Method', 'POST' )
    $requestParams.Add( 'ContentType', $ContentType )

    $Headers.Add( 'Content-Type', $ContentType )
    $Headers.Add( 'X-Access-Token', $script:jsWebService.AccessToken )
    $requestParams.Add( 'Headers', $Headers )
    
    if ( isPowerShellVersion 6 )
    {
        $requestParams.Add( 'AllowUnencryptedAuthentication', $true )
        $requestParams.Add( 'SkipHttpErrorCheck', $true )
    }
        
    if ( $script:jsWebServiceTimeout )
    {
        $requestParams.Add( 'TimeoutSec', $script:jsWebService.Timeout )
    }
    
    if ( $script:jsWebService.SkipCertificateCheck )
    {
        $requestParams.Add( 'SkipCertificateCheck', $true )
    }
    
    if ( $script:jsWebService.SSLProtocol )
    {
        $requestParams.Add( 'SSLProtocol', $script:jsWebService.SSLProtocol  )
    }

    if ( $script:jsWebService.Certificate )
    {
        $requestParams.Add( 'Certificate', $script:jsWebService.Certificate  )
    }

    if ( $Body )
    {
        $requestParams.Add( 'Body', $Body )
    }

    try 
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending request to JobScheduler Web Service $($requestUrl)"
        Write-Debug ".... Invoke-WebRequest:"
        
        $requestParams.Keys | % {
            if ( $_ -eq 'Headers' )
            {
                $item = $_
                $requestParams.Item($_).Keys | % {
                    Write-Debug "...... Header: $_ : $($requestParams.Item($item).Item($_))"
                }
            } else {
                Write-Debug "...... Argument: $_  $($requestParams.Item($_))"
            }
        }
        
        $response = Invoke-WebRequest @requestParams

        if ( $response -and $response.StatusCode -and $response.Content )
        {
            if ( $response.StatusCode -eq 200 -and $response.Content )
            {
                $response
            } else {
                $response
            }
        } else {
            $message = $response | Format-List -Force | Out-String
            throw $message
        }
    } catch {
        $message = $_.Exception | Format-List -Force | Out-String
        throw $message
    }
}

function Invoke-JobSchedulerWebRequestXmlCommand( [string] $Command, [switch] $CheckResponse, [string] $Path='/jobscheduler/commands', [Uri] $Uri, $Method='POST', $ContentType='application/xml', [hashtable] $Headers=@{'Accept' = 'application/xml'} ) 
{
    $xmlDoc = [xml] $command
    if ($xmlDoc.commands)
    {
        $command = $xmlDoc.commands.innerXml
    }

    # handle XML and JSON requests
    if ( $Command.startsWith( '<' ) )
    {
        if ( $Command -notcontains '<jobscheduler_commands' )
        {
            $Command = "<jobscheduler_commands jobschedulerId='$($script:jsWebService.JobSchedulerId)'>$($Command)</jobscheduler_commands>"
        }

        $ContentType = 'application/xml'
    }

    if ( $Uri )
    {
        $response = Invoke-JobSchedulerWebRequest -Uri $Uri -Method $Methhod -Body $Command -ContentType $ContentType -Headers $Headers
    } else {
        $response = Invoke-JobSchedulerWebRequest -Path $Path -Method $Methhod -Body $Command -ContentType $ContentType -Headers $Headers
    }

    if ( $response.StatusCode -ne 200 )
    {
        throw ( $response | Format-List -Force | Out-String )
    }    

    if ( $CheckResponse -and $response.Headers.'Content-Type' -eq 'application/xml' )
    {
        try
        {
            $answer = Select-XML -Content $response.Content -Xpath '/spooler/answer'
            if ( !$answer ) 
            {
                throw 'missing answer element /spooler/answer in response'
            }
        } catch {
            throw 'not a valid JobScheduler XML response: ' + $_.Exception.Message
        }
    
        $errorText = Select-XML -Content $response.Content -Xpath '/spooler/answer/ERROR/@text'
        if ( $errorText.Node."#text" )
        {
            throw $errorText.Node."#text"
        }

        try
        {
            [xml] $response.Content
        } catch {
            throw ( $_.Exception | Format-List -Force | Out-String )
        }
    } else {
        throw "Web Service response received with unsupported content type: $($response.Headers.'Content-Type')"
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

function Create-AgentInstanceScript( $SchedulerHome, $SchedulerData, $HttpPort='127.0.0.1:4445', $HttpsPort, $LogDirectory, $PidFileDirectory, $WorkingDirectory, $KillScript, $JavaHome, $JavaOptions )
{
    $script = "
@echo off

rem #  -----------------------------------------------------------------------
rem #  Company: Software- und Organisations-Service GmbH
rem #  Purpose: Instance (service) startscript for JobScheduler Agent
rem #  -----------------------------------------------------------------------

SETLOCAL

rem ### USAGE OF THIS FILE ####################################
rem #
rem # This is a template for the JobScheduler Agent Instance 
rem # script. 
rem # It can be used as service startscript.
rem #
rem # Each instance of the JobScheduler Agent must have a
rem # different HTTP port. For example if the port 4445 
rem # is used for the instance then copy this file
rem # 
rem # '.\bin\jobscheduler_agent_instance.cmd-example' 
rem # -> '.\bin\jobscheduler_agent_4445.cmd'
rem #
rem # and set the SCHEDULER_HTTP_PORT variable below.
rem #
rem # See also the other environment variables below.
rem #
rem ###########################################################

rem ### SETTINGS ##############################################

rem # This variable has to point to the installation path of 
rem # the JobScheduler Agent.
rem # If this variable not defined then the parent directory 
rem # of this startscript is used.

"
    if ( $SchedulerHome )
    {
        $script += "
set SCHEDULER_HOME=$($SchedulerHome)
"
    } else {
        $script += "
rem set SCHEDULER_HOME=
"
    }

    $script += "

rem # The http port of the JobScheduler Agent can be set here,
rem # as command line option -http-port (see usage) or as
rem # environment variable. Otherwise the above default port 
rem # is used.
rem # If only a port is specified then the JobScheduler Agent 
rem # listens to all available network interfaces.
rem # It is the same like 0.0.0.0:port.
rem # Use the form <ip address or hostname>:port for indicating 
rem # which network interfaces the JobScheduler Agent should 
rem # listen to.
rem # The command line option -http-port beats the environment 
rem # variable SCHEDULER_HTTP_PORT and the environment variable 
rem # SCHEDULER_HTTP_PORT beats the default port from 
rem # SCHEDULER_AGENT_DEFAULT_HTTP_PORT(=4445).
rem ### NOTE:
rem # If you start the JobScheduler Agent with the command line 
rem # option -http-port then you must enter -http-port for 
rem # stop, status, restart too (see usage). It's recommended 
rem # to set this environment variable instead.

"

    if ( $HttpPort )
    {
        $script += "
set SCHEDULER_HTTP_PORT=$($HttpPort)
"
    } else {
        $script += "
rem set SCHEDULER_HTTP_PORT=
"        
    }

    $script += "

rem # In addition to the http port a https port of the 
rem # JobScheduler Agent can be set here, as command line option 
rem # -https-port (see usage) or as environment variable.
rem # If only a port is specified then the JobScheduler Agent 
rem # listens to all available network interfaces.
rem # It is the same like 0.0.0.0:port.
rem # Use the form <ip address or hostname>:port for indicating 
rem # which network interfaces the JobScheduler Agent should 
rem # listen to.
rem # The command line option -https-port beats the environment 
rem # variable SCHEDULER_HTTPS_PORT.

"

    if ( $HttpsPort )
    {
        $script += "
set SCHEDULER_HTTPS_PORT=$($HttpsPort)
"
    } else {
        $script += "
rem set SCHEDULER_HTTPS_PORT=
"        
    }

    $script += "

rem # Set the directory where the JobScheduler Agent has the
rem # configuration, logs, etc. 
rem # This directory must be unique for each instance of the 
rem # JobScheduler Agent. The default is
rem # SCHEDULER_HOME\var_SCHEDULER_HTTP_PORT
rem # Make sure that the JobScheduler Agent user has read/write 
rem # permissions

"

    if ( $SchedulerData )
    {
        $script += "
set SCHEDULER_DATA=$($SchedulerData)
"
    } else {
        $script += "
rem set SCHEDULER_DATA=
"
    }

    $script += "
 
rem # Set the directory where the JobScheduler Agent log file 
rem # is created. The default is SCHEDULER_DATA\logs
rem ### NOTE:
rem # Make sure that the JobScheduler Agent user has write 
rem # permissions

"

    if ( $LogDirectory )
    {
        $script += "
set SCHEDULER_LOG_DIR=$($LogDirectory)
"
    } else {
        $script += "
rem set SCHEDULER_LOG_DIR=
"
    }

    $script += "

rem # Set the directory where the JobScheduler Agent pid file 
rem # is created. The default is SCHEDULER_LOG_DIR
rem ### NOTE:
rem # Make sure that the JobScheduler Agent user has write 
rem # permissions

"

    if ( $PidFileDirectory )
    {
        $script += "
set SCHEDULER_PID_FILE_DIR=$($PidFileDirectory)
"
    } else {
        $script += "
rem set SCHEDULER_PID_FILE_DIR=
"
    }

    $script += "

rem # The working directory of the JobScheduler Agent is  
rem # SCHEDULER_HOME. Here you can set a different working 
rem # directory (e.g. %USERPROFILE%).

"

    if ( $WorkingDirectory )
    {
        $script += "
set SCHEDULER_WORK_DIR=$($WorkingDirectory)
"
    } else {
        $script += "
rem set SCHEDULER_WORK_DIR=
"
    }

    $script += "

rem # Set the location of a script which is called by the 
rem # JobScheduler Agent to kill a process and it's children.

"

    if ( $KillScript )
    {
        $script += "
set SCHEDULER_KILL_SCRIPT=$($KillScript)
"
    } else {
        $script += "
rem set SCHEDULER_KILL_SCRIPT=
"
    }

    $script += "

rem # Actually JAVA_HOME is already set. If you want to use 
rem # another Java environment then you can set it here. If  
rem # no JAVA_HOME is set then the Java from the path is used.

"

    if ( $JavaHome )
    {
        $script += "
set JAVA_HOME=$($JavaHome)
"
    } else {
        $script += "
rem set JAVA_HOME=
"
    }

    $script += "

rem # With Java 1.8 the initial memory allocation has changed, 
rem # for details see https://kb.sos-berlin.com/x/aIC9
rem # As a result on start-up of the JobScheduler Agent an 
rem # excessive amount of virtual memory is assigned by Java.  
rem # The environment variable JAVA_OPTIONS can use to apply 
rem # memory settings such as '-Xms100m' (default).

"

    if ( $JavaOptions )
    {
        $script += "
set JAVA_OPTIONS=$($JavaOptions)
"
    } else {
        $script += "
rem set JAVA_OPTIONS=
"
    }

    $script += '

rem ###########################################################

if not defined SCHEDULER_HOME set SCHEDULER_HOME=%~dp0..

"%SCHEDULER_HOME%\bin\jobscheduler_agent.cmd" %*

ENDLOCAL
'
    $script
}

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------

$js = Create-JSObject
$jsWebService = Create-WebServiceObject

if ( $jsOperations )
{
    # no addtional connection to Master required
#    $js.Url = "http://$($spooler.hostname()):$($spooler.tcp_port())"
#    $js.Id = $spooler.id()
#    $js.Local = $false
#    $jsWebService.Id = $js.Id
}

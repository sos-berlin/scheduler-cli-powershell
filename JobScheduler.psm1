<#
.SYNOPSIS
JobScheduler command line interface

For further information see

    PS > about_JobScheduler

If the documentation is not available for your language then consider to use

    PS > [System.Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'

#>

# --------------------------------
# Globals with JobScheduler Master
# --------------------------------

# JobScheduler Master Object
[PSObject] $script:js = $null

# CLI operated for a JobScheduler job or monitor
[bool] $script:jsOperations = ( $spooler -and $spooler.id() )

# JobScheduler Master environment
[hashtable] $script:jsEnv = @{}

# Commands that require a local Master instance (Management of Windows Service)
[string[]] $script:jsLocalCommands = @( 'Install-JobSchedulerService', 'Remove-JobSchedulerService', 'Start-JobSchedulerMaster' )

# -------------------------------
# Globals with JobScheduler Agent
# -------------------------------

# JobScheduler Agent Object
[PSObject] $script:jsAgent = $null

# Commands that require a local Agent instance (Management of Windows Service)
[string[]] $script:jsAgentLocalCommands = @( 'Install-JobSchedulerAgentService', 'Remove-JobSchedulerAgentService', 'Start-JobSchedulerAgent' )

# -------------------------------------
# Globals with JobScheduler Web Service
# -------------------------------------

# JobScheduler Web Service Object
[PSObject] $script:jsWebService = $null

# JobScheduler Web Service Request
#     Credentials
[System.Management.Automation.PSCredential] $script:jsWebServiceCredential = $null
#    Use default credentials of the current user?
[bool] $script:jsWebServiceOptionWebRequestUseDefaultCredentials = $false
#     Proxy Credentials
[System.Management.Automation.PSCredential] $script:jsWebServiceProxyCredential = $null
#    Use default credentials of the current user?
[bool] $script:jsWebServiceOptionWebRequestProxyUseDefaultCredentials = $true

# --------------------
# Globals with Options
# --------------------

# Options
#     Debug Message: responses exceeding the max. output size are stored in temporary files
[int] $script:jsOptionDebugMaxOutputSize = 1000
#    Master Web Request: timeout for establishing the connection in ms
[int] $script:jsOptionWebRequestTimeout = 30

# ----------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------

$moduleRoot = Split-Path -Path $MyInvocation.MyCommand.Path
"$moduleRoot\functions\*.ps1" | Resolve-Path | ForEach-Object { . $_.ProviderPath }
Export-ModuleMember -Function "*"

# ----------------------------------------------------------------------
# Public Function Alias Management
# ----------------------------------------------------------------------

function Use-JobSchedulerAlias
{
<#
.SYNOPSIS
This cmdlet creates alias names for JobScheduler cmdlets.

.DESCRIPTION
To create alias names this cmdlet has to be dot sourced, i.e. use

* . Use-JobSchedulerAlias -Prefix JS: works as expected
* Use-JobSchedulerAlias-Prefix JS: has no effect

When using a number of modules from different vendors then naming conflicts might occur
for cmdlets with the same name from different modules.

The JobScheduler CLI makes use of the following policy:

* All cmdlets use a unique qualifier for the module as e.g. Use-JobSchedulerMaster, Get-JobSchedulerInventory etc.
* Users can use this cmdlet to create a shorthand notation for cmdlet alias names. Two flavors are offered:
** use a shorthand notation as e.g. Use-JSMaster instead of Use-JobSchedulerMaster. This notation is recommended as is suggests fairly unique names.
** use a shorthand notation as e.g. Use-Master instead of Use-JobSchedulerMaster. This notation can conflict with cmdlets of the PowerShell Core, e.g. for Start-Job, Stop-Job
* Users can exclude shorthand notation for specific cmdlets by use of an exclusion list.

You can find the resulting aliases by use of the command Get-Command -Module JobScheduler.

.PARAMETER Prefix
Specifies the prefix that is used for a shorthand notation, e.g.

* with the parameter -Prefix "JS" used this cmdlet creates an alias Use-JSMaster for Use-JobSchedulerMaster
* with the parameter -Prefix being omitted this cmdlet creates an alias Use-Master for Use-JobSchedulerMaster

By default aliases are created for both the prefix "JS" and with an empty prefix being assigned which results in the following possible notation:

* Use-JobSchedulerMaster
* Use-JSMaster
* Use-Master

Default: . UseJobSchedulerAlias -Prefix JS
Default: . UseJobSchedulerAlias -NoDuplicates -ExcludesPrefix JS

.PARAMETER Excludes
Specifies a list of resulting alias names that are excluded from alias creation.

When omitting the -Prefix parameter then
- at the time of writing - the following alias names would conflict with cmdlet names from the PowerShell Core:

* Get-Event
* Get-Job
* Start-Job
* Stop-Job

.PARAMETER ExcludesPrefix
Specifies a prefix that is used should a resulting alias be a member of the list of
excluded aliases that is specified with the -Excludes parameter.

When used with the -NoDuplicates parameter then this parameter specifies the prefix that is used
for aliases that would conflict with any exsting cmdlets, functions or aliases.

.PARAMETER NoDuplicates
This parameters specifies that no alias names should be created that conflict with existing cmdlets, functions or aliases.

.EXAMPLE
 . Use-JobSchedulerAlias -Prefix JS

Creates aliases for all JobScheduler CLI cmdlets that allow to use, e.g. Use-JSMaster for Use-JobSchedulerMaster

.EXAMPLE
 . Use-JobSchedulerAlias -Exclude Get-Job,Start-Job,Stop-Job -ExcludePrefix JS

Creates aliases for all JobScheduler CLI cmdlets that allow to use, e.g. Use-Master for Use-JobSchedulerMaster.
This is specified by omitting the -Prefix parameter.

For the resulting alias names Get-Job, Start-Job and Stop-Job the alias names
Get-JSJob, Start-JSJob and Stop-JSJob are created by use of the -ExcludePrefix "JS" parameter.

.EXAMPLE
 . Use-JobSchedulerAlias -NoDuplicates -ExcludesPrefix JS

Creates aliases for all JobScheduler CLI cmdlets that allow to use e.g. Use-Master for Use-JobSchedulerMaster.
Should any alias name conflict with an existing cmdlet, function or alias then the alias will be created with the
prefix specified by the -ExcludesPrefix parameter.

The JobScheduler CLI module uses this alias setting by defalt.
.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Prefix,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string[]] $Excludes,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ExcludesPrefix,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoDuplicates
)
    Process
    {
        if ( $NoDuplicates )
        {
            $allCommands = Get-Command | Select-Object -Property Name | ForEach-Object { $_.Name }
        }

        $commands = Get-Command -Module JobScheduler -CommandType 'Function'
        foreach( $command in $commands )
        {
            $aliasName = $command.name.Replace( '-JobScheduler', "-$($Prefix)" )

            if ( $Excludes -contains $aliasName )
            {
                continue
            }

            if ( $Excludes -contains $aliasName )
            {
                if ( $ExcludesPrefix )
                {
                    $aliasName = $command.name.Replace( '-JobScheduler', "-$($ExcludesPrefix)" )
                } else {
                    continue
                }
            }

            if ( $NoDuplicates )
            {
                if ( $allCommands -contains $aliasName )
                {
                    if ( $ExcludesPrefix )
                    {
                        $aliasName = $command.name.Replace( '-JobScheduler', "-$($ExcludesPrefix)" )
                    } else {
                        continue
                    }
                }
            }

            Set-Alias -Name $aliasName -Value $command.Name

            switch( $aliasName )
            {
                'Start-JobEditor'    {
                                        Set-Alias -Name "Start-$($Prefix)JOE" -Value $command.Name
                                        break;
                                    }
                'Start-Dashboard'    {
                                        Set-Alias -Name "Start-$($Prefix)JID" -Value $command.Name
                                        break;
                                    }
            }
        }

        Set-Alias -Name Use-JobSchedulerWebService -Value Connect-JobScheduler
        Set-Alias -Name Use-JSWebService -Value Connect-JobScheduler
        Set-Alias -Name Stop-JobSchedulerJob -Value Stop-JobSchedulerTask
        Set-Alias -Name Stop-JSJob -Value Stop-JobSchedulerTask

        Export-ModuleMember -Alias "*"
    }
}

# create alias names to shorten 'JobScheduler' to 'JS'
. Use-JobSchedulerAlias -Prefix JS -Excludes 'Connect-','Disconnect-','Use-JSAlias','Use-Alias'
# create alias names that drop 'JobScheduler' in the name but avoid conflicts with existing alias names
. Use-JobSchedulerAlias -NoDuplicates -ExcludesPrefix JS -Excludes 'Connect-','Disconnect-','Use-JSAlias','Use-Alias'

# ----------------------------------------------------------------------
# Private Functions
# ----------------------------------------------------------------------

function Approve-JobSchedulerCommand( [System.Management.Automation.CommandInfo] $command )
{
    if ( !$jsWebServiceCredential )
    {
        throw "$($command.Name): no valid session, login to the JobScheduler Web Service with the Connect-JobScheduler cmdlet"
    }

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
            throw "$($command.Name): cmdlet requires a JobScheduler URL. Switch instance with the Connect-JobScheduler cmdlet and specify the -Url parameter"
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

function Start-JobSchedulerStopWatch
{
[cmdletbinding(SupportsShouldProcess)]
[OutputType([System.Diagnostics.Stopwatch])]
param
()

    if ( $PSCmdlet.ShouldProcess( 'Stopwatch' ) )
    {
        [System.Diagnostics.Stopwatch]::StartNew()
    }
}

function Trace-JobSchedulerStopWatch( [string] $CommandName, [System.Diagnostics.Stopwatch] $StopWatch )
{
    if ( $StopWatch )
    {
        Write-Verbose ".. $($CommandName): time elapsed: $($StopWatch.Elapsed.TotalMilliseconds) ms"
    }
}

function New-JobSchedulerObject
{
[cmdletbinding(SupportsShouldProcess)]
param
()

    if ( $PSCmdlet.ShouldProcess( 'JS' ) )
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
}

function New-JobSchedulerStatisticsObject
{
[cmdletbinding(SupportsShouldProcess)]
param
()

    if ( $PSCmdlet.ShouldProcess( 'Statistics' ) )
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
}

function New-JobSchedulerJobChainObject
{
[cmdletbinding(SupportsShouldProcess)]
param
()

    if ( $PSCmdlet.ShouldProcess( 'JobChain' ) )
    {
        $jobChain = New-Object PSObject

        $jobChain | Add-Member -Membertype NoteProperty -Name JobChain -Value ''
        $jobChain | Add-Member -Membertype NoteProperty -Name Path -Value ''
        $jobChain | Add-Member -Membertype NoteProperty -Name Directory -Value ''
        $jobChain | Add-Member -Membertype NoteProperty -Name Volatile -Value ''
        $jobChain | Add-Member -Membertype NoteProperty -Name Permanent -Value ''

        $jobChain
    }
}

function New-JobSchedulerOrderObject
{
[cmdletbinding(SupportsShouldProcess)]
param
()

    if ( $PSCmdlet.ShouldProcess( 'Order' ) )
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
}

function New-JobSchedulerJobObject
{
[cmdletbinding(SupportsShouldProcess)]
param
()

    if ( $PSCmdlet.ShouldProcess( 'Job' ) )
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
}

function New-JobSchedulerEventObject
{
[cmdletbinding(SupportsShouldProcess)]
param
()

    if ( $PSCmdlet.ShouldProcess( 'Event' ) )
    {
        $jsEvent = New-Object PSObject

        $jsEvent | Add-Member -Membertype NoteProperty -Name EventClass -Value ''
        $jsEvent | Add-Member -Membertype NoteProperty -Name EventId -Value ''
        $jsEvent | Add-Member -Membertype NoteProperty -Name ExitCode -Value 0
        $jsEvent | Add-Member -Membertype NoteProperty -Name Job -Value ''
        $jsEvent | Add-Member -Membertype NoteProperty -Name JobChain -Value ''
        $jsEvent | Add-Member -Membertype NoteProperty -Name Order -Value ''
        # $jsEvent | Add-Member -Membertype NoteProperty -Name MasterUrl -Value ''
        $jsEvent | Add-Member -Membertype NoteProperty -Name ExpirationDate -Value ''
        $jsEvent | Add-Member -Membertype NoteProperty -Name ExpirationCycle -Value ''
        $jsEvent | Add-Member -Membertype NoteProperty -Name ExpirationPeriod -Value ''
        $jsEvent | Add-Member -Membertype NoteProperty -Name Created -Value ''

        $jsEvent
    }
}

function New-JobSchedulerAgenObject
{
[cmdletbinding(SupportsShouldProcess)]
param
()

    if ( $PSCmdlet.ShouldProcess( 'Agent' ) )
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
}

function New-JobSchedulerWebServiceObject
{
[cmdletbinding(SupportsShouldProcess)]
param
()

    if ( $PSCmdlet.ShouldProcess( 'WebService' ) )
    {
        $jsWebService = New-Object PSObject

        $jsWebService | Add-Member -Membertype NoteProperty -Name Url -Value ''
        $jsWebService | Add-Member -Membertype NoteProperty -Name ProxyUrl -Value ''
        $jsWebService | Add-Member -Membertype NoteProperty -Name Base -Value ''
        $jsWebService | Add-Member -Membertype NoteProperty -Name Timeout -Value $script:jsOptionWebRequestTimeout
        $jsWebService | Add-Member -Membertype NoteProperty -Name SkipCertificateCheck -Value $false
        $jsWebService | Add-Member -Membertype NoteProperty -Name SSLProtocol -Value ''
        $jsWebService | Add-Member -Membertype NoteProperty -Name Certificate -Value ''
        $jsWebService | Add-Member -Membertype NoteProperty -Name JobSchedulerId -Value ''
        $jsWebService | Add-Member -Membertype NoteProperty -Name AccessToken -Value ''
        $jsWebService | Add-Member -Membertype NoteProperty -Name Masters -Value @()

        $jsWebService
    }
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

function Invoke-JobSchedulerWebRequest( [string] $Path, [string] $Body, [string] $ContentType='application/json', [hashtable] $Headers=@{'Accept' = 'application/json'}, [Uri] $Url, [string] $Method='POST' )
{
    if ( $Url )
    {
        $requestUrl = $Url.OriginalString + $Path
    } elseif ( $script:jsWebService.Url.UserInfo )
    {
        $requestUrl = $script:jsWebService.Url.scheme + '://' + $script:jsWebService.Url.UserInfo + '@' + $script:jsWebService.Url.Authority + $script:jsWebService.Base + $Path
    } else {
        $requestUrl = $script:jsWebService.Url.scheme + '://' + $script:jsWebService.Url.Authority + $script:jsWebService.Base + $Path
    }

    $requestParams = @{}
    $requestParams.Add( 'Verbose', $false )
    $requestParams.Add( 'Uri', $requestUrl )
    $requestParams.Add( 'Method', $Method )
    $requestParams.Add( 'ContentType', $ContentType )

    $Headers.Add( 'Content-Type', $ContentType )
    $Headers.Add( 'X-Access-Token', $script:jsWebService.AccessToken )
    $requestParams.Add( 'Headers', $Headers )

    if ( isPowerShellVersion 6 )
    {
        $requestParams.Add( 'AllowUnencryptedAuthentication', $true )
    }

    if ( isPowerShellVersion 7 )
    {
        $requestParams.Add( 'SkipHttpErrorCheck', $true )
    }

    if ( $script:jsWebService.Timeout )
    {
        $requestParams.Add( 'TimeoutSec', $script:jsWebService.Timeout )
    }

    if ( $script:jsWebService.SkipCertificateCheck )
    {
        $requestParams.Add( 'SkipCertificateCheck', $true )
    }

    if ( $script:jsWebService.SSLProtocol )
    {
        $requestParams.Add( 'SSLProtocol', $script:jsWebService.SSLProtocol )
    }

    if ( $script:jsWebService.Certificate )
    {
        $requestParams.Add( 'Certificate', $script:jsWebService.Certificate )
    }

    if ( $Body )
    {
        $requestParams.Add( 'Body', $Body )
    }

    try
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending request to JobScheduler Web Service $($requestUrl)"
        Write-Debug ".... Invoke-WebRequest:"

        $requestParams.Keys | ForEach-Object {
            if ( $_ -eq 'Headers' )
            {
                $item = $_
                $requestParams.Item($_).Keys | ForEach-Object {
                    Write-Debug "...... Header: $_ : $($requestParams.Item($item).Item($_))"
                }
            } else {
                if ( $_ -ne 'Certificate' )
                {
                    Write-Debug "...... Argument: $_  $($requestParams.Item($_))"
                }
            }
        }

        if ( isPowerShellVersion 7 )
        {
            $response = Invoke-WebRequest @requestParams
        } else {
            try
            {
                $response = Invoke-WebRequest @requestParams
            } catch {
                $response = $_.Exception.Response
            }
        }

        if ( $response -and $response.StatusCode -and $response.Content )
        {
            $response
        } elseif ( $response -and !(isPowerShellVersion 7) ) {
            $response
        } else {
            $message = $response | Format-List -Force | Out-String
            throw $message
        }
    } catch {
        $message = $_.Exception | Format-List -Force | Out-String
        throw $message
    }
}

function Invoke-JobSchedulerWebRequestXmlCommand( [string] $Command, [switch] $IgnoreResponse, [string] $Path='/jobscheduler/commands', [Uri] $Uri, $Method='POST', $ContentType='application/xml', [hashtable] $Headers=@{'Accept' = 'application/xml'} )
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

    if ( $IgnoreResponse )
    {
        return $response
    }

    if ( $response.Headers.'Content-Type' -eq 'application/xml' )
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
            $script:jsEnv["$($matches[1])"] = $matches[2]
        }
    }

    Remove-Item $tempFile
}

function New-JobSchedulerParamNode
{
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory = $true)]
    [xml] $XmlDoc,
    [string] $Name,
    [string] $Value
)

    if ( $PSCmdlet.ShouldProcess( 'ParamNode' ) )
    {
        $paramNode = $XmlDoc.CreateElement( 'param' )
        $paramNode.SetAttribute( 'name', $Name )
        $paramNode.SetAttribute( 'value', $Value )

        $paramNode
    }
}

function New-JobSchedulerAgentInstanceScript
{
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory = $false)]
    [string] $SchedulerHome,
    [string] $SchedulerData,
    [string] $HttpPort='127.0.0.1:4445',
    [string] $HttpsPort,
    [string] $LogDirectory,
    [string] $PidFileDirectory,
    [string] $WorkingDirectory,
    [string] $KillScript,
    [string] $JavaHome,
    [string] $JavaOptions
)

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
    if ( $PSCmdlet.ShouldProcess( 'Script' ) )
    {
        $script
    }
}

function Get-JobSchedulerJobConfiguration( [string] $Job, [string] $Mime='XML' )
{
    $body = New-Object PSObject
    Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
    Add-Member -Membertype NoteProperty -Name 'mime' -value $Mime -InputObject $body
    Add-Member -Membertype NoteProperty -Name 'job' -value $Job -InputObject $body

    [string] $requestBody = $body | ConvertTo-Json -Depth 100
    $response = Invoke-JobSchedulerWebRequest -Path '/job/configuration' -Body $requestBody

    if ( $response.StatusCode -eq 200 )
    {
        $configuration = ( $response.Content | ConvertFrom-JSON ).configuration.content.xml
    } else {
        throw ( $response | Format-List -Force | Out-String )
    }

    $configuration
}

function Get-JobSchedulerJobChainConfiguration( [string] $JobChain, [string] $Mime='XML' )
{
    $body = New-Object PSObject
    Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
    Add-Member -Membertype NoteProperty -Name 'mime' -value $Mime -InputObject $body
    Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $body

    [string] $requestBody = $body | ConvertTo-Json -Depth 100
    $response = Invoke-JobSchedulerWebRequest -Path '/job_chain/configuration' -Body $requestBody

    if ( $response.StatusCode -eq 200 )
    {
        $configuration = ( $response.Content | ConvertFrom-JSON ).configuration.content.xml
    } else {
        throw ( $response | Format-List -Force | Out-String )
    }

    $configuration
}

function Get-JobSchedulerOrderConfiguration( [string] $OrderId, [string] $JobChain, [string] $Mime='XML' )
{
    $body = New-Object PSObject
    Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
    Add-Member -Membertype NoteProperty -Name 'mime' -value $Mime -InputObject $body
    Add-Member -Membertype NoteProperty -Name 'orderId' -value $OrderId -InputObject $body
    Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $body

    [string] $requestBody = $body | ConvertTo-Json -Depth 100
    $response = Invoke-JobSchedulerWebRequest -Path '/order/configuration' -Body $requestBody

    if ( $response.StatusCode -eq 200 )
    {
        $configuration = ( $response.Content | ConvertFrom-JSON ).configuration.content.xml
    } else {
        throw ( $response | Format-List -Force | Out-String )
    }

    $configuration
}

function Get-JobSchedulerLockConfiguration( [string] $Lock, [string] $Mime='XML' )
{
    $body = New-Object PSObject
    Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
    Add-Member -Membertype NoteProperty -Name 'mime' -value $Mime -InputObject $body
    Add-Member -Membertype NoteProperty -Name 'lock' -value $Lock -InputObject $body

    [string] $requestBody = $body | ConvertTo-Json -Depth 100
    $response = Invoke-JobSchedulerWebRequest -Path '/lock/configuration' -Body $requestBody

    if ( $response.StatusCode -eq 200 )
    {
        $configuration = ( $response.Content | ConvertFrom-JSON ).configuration.content.xml
    } else {
        throw ( $response | Format-List -Force | Out-String )
    }

    $configuration
}

function ConvertFrom-JobSchedulerXmlJobStream
{
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Path,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OutputDirectory
#    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
#    [string] $BaseFolder,
#    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
#    [string] $DefaultAgentName,
#    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
#    [string] $ForcedAgentName,
#    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
#    [hashtable] $MappedAgentNames
)

    Begin
    {
        $jobStreams = @()
    }

    Process
    {
        $jobStreams += $Path
    }

    End
    {
                if ( $jobFolder -eq '/' )
                {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))".Replace( '\', '/' )
                } else {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))$($jobFolder)".Replace( '\', '/' )
                }

                if ( !(Test-Path -Path $outputFolder) )
                {
                    New-Item -Path $outputFolder -ItemType Directory | Out-Null
                }

                Write-Debug ".... writing job stream: $($outputFolder)/$($jobName).jobstream.json"

                $jsonJobStream = $objJobSream | ConvertTo-Json -Depth 100
                $jsonJobStream | Out-File "$($outputFolder)/$($jobName).jobstream.json"
    }
}

function ConvertFrom-JobSchedulerXmlJob
{
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Path,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OutputDirectory,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $BaseFolder,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $DefaultAgentName,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ForcedAgentName,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $MappedAgentNames,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $PrefixOrders,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $SubmitOrders,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $PlanOrders
)

    Begin
    {
        $jobs = @()
        Write-Debug "prefixOrders: $PrefixOrders"
    }

    Process
    {
        $jobs += $Path
    }

    End
    {
        foreach( $job in $jobs )
        {
            try
            {
                Write-Verbose ".... processing job: $job"

                $jobName = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetFileName( $job ))
                $jobFolder = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetDirectoryName( $job ).Replace( '\', '/' ))
                $objectFolder = $jobFolder

                if ( $BaseFolder )
                {
                    $jobFolder = "$($BaseFolder)$($jobFolder)"
                }

                [xml] $xmlJob = Get-JobSchedulerJobConfiguration -Job $job

# ---------- Begin: Create Workflow ----------
                $workflowInstructions = @()
                $objWorkflowJobs = New-Object PSObject

    # ---------- Begin: Create Workflow Instruction for job ----------
                $objWorkflowInstruction = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'TYPE' -value "Execute.Named" -InputObject $objWorkflowInstruction
                Add-Member -Membertype NoteProperty -Name 'jobName' -value $jobName -InputObject $objWorkflowInstruction
                Add-Member -Membertype NoteProperty -Name 'label' -value $jobName -InputObject $objWorkflowInstruction

                $objWorkflowDefaultArguments = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'defaultArguments' -value $objWorkflowDefaultArguments -InputObject $objWorkflowInstruction

        # ---------- Begin: Create Workflow Job ----------
                $objWorkflowJobProperties = New-Object PSObject

                if ( $xmlJob.job.title )
                {
                    Add-Member -Membertype NoteProperty -Name 'title' -value $xmlJob.job.title -InputObject $objWorkflowJobProperties
                }

                if ( $ForcedAgentName )
                {
                    $agentId = $ForcedAgentName
                } elseif ( $xmlJob.job.process_class ) {
                    $agentId = (Get-CanonicalObjectPath -ObjectName $xmlJob.job.process_class -ObjectFolder $objectFolder)
                } else {
                    $agentId = $DefaultAgentName
                }

                if ( $MappedAgentNames -and ($item = $MappedAgentNames.Item( $agentId ) ) )
                {
                    $agentId = $item.AgentName
                }

                Add-Member -Membertype NoteProperty -Name 'agentId' -value $agentId -InputObject $objWorkflowJobProperties

                    $objWorkflowJobExecutable = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'TYPE' -value 'ExecutableScript' -InputObject $objWorkflowJobExecutable

                    $scriptCode = Get-JobSchedulerXmlScriptInclude -IncludeNodes $xmlJob.job.script.include -ObjectFolder $objectFolder
                    Add-Member -Membertype NoteProperty -Name 'script' -value ($scriptCode + $xmlJob.job.script."#cdata-section") -InputObject $objWorkflowJobExecutable

                Add-Member -Membertype NoteProperty -Name 'executable' -value $objWorkflowJobExecutable -InputObject $objWorkflowJobProperties

                    $objWorkflowJobReturnCode = New-Object PSObject
                    $returnCodeMeaningSuccess = @( 0 )
                    Add-Member -Membertype NoteProperty -Name 'success' -value $returnCodeMeaningSuccess -InputObject $objWorkflowJobReturnCode

                Add-Member -Membertype NoteProperty -Name 'returnCodeMeaning' -value $objWorkflowJobReturnCode -InputObject $objWorkflowJobProperties

                if ( $xmlJob.job.tasks )
                {
                    Add-Member -Membertype NoteProperty -Name 'taskLimit' -value $xmlJob.job.tasks -InputObject $objWorkflowJobProperties
                } else {
                    Add-Member -Membertype NoteProperty -Name 'taskLimit' -value 1 -InputObject $objWorkflowJobProperties
                }

            # ---------- Begin: Create the Job Arguments ----------
                $objWorkflowJobDefaultArguments = New-Object PSObject

                # ---------- Begin: Create Job Arguments from <job><params><include> elements ----------
                $xmlArguments = Get-JobSchedulerXmlParamsInclude -IncludeNodes $xmlJob.job.params.include -ObjectFolder $objectFolder
                foreach( $argumentNode in $xmlArguments.params.param )
                {
                    Add-Member -Membertype NoteProperty -Name $argumentNode.name -value $argumentNode.value -InputObject $objWorkflowJobDefaultArguments -Force
                }
                # ---------- End: Create Job Arguments from <job><params><include> elements ----------

                # ---------- Begin: Create Job Arguments from <job><params><param> elements ----------
                $argumentNodes = $xmlJob.job.params.param
                foreach( $argumentNode in $argumentNodes )
                {
                    Add-Member -Membertype NoteProperty -Name $argumentNode.name -value $argumentNode.value -InputObject $objWorkflowJobDefaultArguments -Force
                }
                # ---------- Begin: Create Job Arguments from <job><params><param> elements ----------

                Add-Member -Membertype NoteProperty -Name 'defaultArguments' -value $objWorkflowJobDefaultArguments -InputObject $objWorkflowJobProperties
            # ---------- End: Create the Job Arguments ----------

                $workflowInstructions += $objWorkflowInstruction
                Add-Member -Membertype NoteProperty -Name $jobName -value $objWorkflowJobProperties -InputObject $objWorkflowJobs
        # ---------- End: Create Workflow Job ----------

        # ---------- Begin: Create Workflow Retry ----------
                if ( $xmlJob.job.delay_after_error )
                {
                    Write-Debug "...... delay_after_error found"

                    $objTryInstruction = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'instructions' -value $workflowInstructions -InputObject $objTryInstruction

                    $objRetryInstruction = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'TYPE' -value 'Retry' -InputObject $objRetryInstruction

                    $objCatchInstruction = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'instructions' -value @( $objRetryInstruction ) -InputObject $objCatchInstruction

                    $objWorkflowInstruction = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'TYPE' -value 'Try' -InputObject $objWorkflowInstruction
                    Add-Member -Membertype NoteProperty -Name 'try' -value $objTryInstruction -InputObject $objWorkflowInstruction
                    Add-Member -Membertype NoteProperty -Name 'catch' -value $objCatchInstruction -InputObject $objWorkflowInstruction

                    if ( $errorCount = ( $xmlJob.job.delay_after_error | Where-Object -Property 'delay' -match -value 'STOP' ).error_count )
                    {
                        Add-Member -Membertype NoteProperty -Name 'maxTries' -value $errorCount -InputObject $objWorkflowInstruction
                    }

                    $lastDelay = 1
                    $lastErrorCount = 1
                    $errorDelays = @()
                    $errors = ( $xmlJob.job.delay_after_error | Sort-Object -Property @{expression={$_.error_count -as [int]}} )

                    foreach( $error in $errors )
                    {
                        for( $i=$lastErrorCount+1; $i -lt ($error.error_count -as [int]); $i++ )
                        {
                            $errorDelays += $lastDelay
                        }

                        if ( $error.delay -and $error.delay -ne 'STOP' )
                        {
                            if ( ([regex]::Matches($error.delay, ':' )).count -eq 0 )
                            {
                                $error.delay = "00:00:$($error.delay)"
                            } elseif ( ([regex]::Matches($error.delay, ':' )).count -eq 1 ) {
                                $error.delay = "00:$($error.delay):00"
                            }

                            $delay = [TimeSpan]::Parse( $error.delay )
                            $errorDelays += [int] $delay.TotalSeconds
                            $lastErrorCount = ( $error.error_count -as [int] )
                            $lastDelay = [int] $delay.TotalSeconds
                        }
                    }

                    Add-Member -Membertype NoteProperty -Name 'retryDelays' -value $errorDelays -InputObject $objWorkflowInstruction

                    Write-Debug "...... adding instruction for retry"
                    $WorkflowInstructions = @( $objWorkflowInstruction )
                }

    # ---------- End: Create Workflow Instruction for job ----------

                $objWorkflow = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'instructions' -value $workflowInstructions -InputObject $objWorkflow
                Add-Member -Membertype NoteProperty -Name 'jobs' -value $objWorkflowJobs -InputObject $objWorkflow
# ---------- End: Create Workflow ----------

                if ( $jobFolder -eq '/' )
                {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))".Replace( '\', '/' )
                } else {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))$($jobFolder)".Replace( '\', '/' )
                }

                if ( !(Test-Path -Path $outputFolder) )
                {
                    New-Item -Path $outputFolder -ItemType Directory | Out-Null
                }

                Write-Debug ".... writing workflow: $($outputFolder)/$($jobName).workflow.json"

                $jsonWorkflow = $objWorkflow | ConvertTo-Json -Depth 100
                $jsonWorkflow | Out-File "$($outputFolder)/$($jobName).workflow.json"


# ---------- Begin: Create Schedule ----------
                $scheduleName = $jobName
                $scheduleFolder = $jobFolder

                Write-Verbose ".... processing schedule $scheduleName for job: $jobName in folder: $scheduleFolder"
                $objSchedule = New-Object PSObject

                if ( $scheduleFolder -eq '/' )
                {
                    Add-Member -Membertype NoteProperty -Name 'path' -value "$($scheduleName)" -InputObject $objSchedule
                } else {
                    Add-Member -Membertype NoteProperty -Name 'path' -value "$($scheduleFolder)$($scheduleName)" -InputObject $objSchedule
                }

                if ( $jobFolder -eq '/' )
                {
                    Add-Member -Membertype NoteProperty -Name 'workflowPath' -value "$($jobName)" -InputObject $objSchedule
                } else {
                    Add-Member -Membertype NoteProperty -Name 'workflowPath' -value "$($jobFolder)$($jobName)" -InputObject $objSchedule
                }

                if ( $xmlJob.job.title )
                {
                    Add-Member -Membertype NoteProperty -Name 'title' -value $xmlJob.job.title -InputObject $objSchedule
                }

                Add-Member -Membertype NoteProperty -Name 'submitOrderToControllerWhenPlanned' -value ($SubmitOrders -eq $True) -InputObject $objSchedule
                Add-Member -Membertype NoteProperty -Name 'planOrderAutomatically' -value ($PlanOrders -eq $True) -InputObject $objSchedule

                $workingDayCalendars = @()
                $nonWorkingDayCalendars = @()

                if ( $xmlJob.job.run_time.calendars )
                {
                    if ( isPowerShellVersion 6 )
                    {
                        $jsonCalendars = $xmlJob.job.run_time.calendars."#cdata-section" | ConvertFrom-Json -Depth 100
                    } else {
                        $jsonCalendars = $xmlJob.job.run_time.calendars."#cdata-section" | ConvertFrom-Json
                    }

                    if ( $jsonCalendars )
                    {
                        foreach( $calendar in $jsonCalendars.calendars )
                        {
                            foreach( $period in $calendar.periods )
                            {
                                if ( $period.whenHoliday )
                                {
                                    if ( $period.whenHoliday -eq 'suppress' )
                                    {
                                        $period.whenHoliday = 'SUPPRESS'
                                    } elseif ( $period.whenHoliday -eq 'next_non_holiday' ) {
                                        $period.whenHoliday = 'NEXTNONWORKINGDAY'
                                    } elseif ( $period.whenHoliday -eq 'previous_non_holiday' ) {
                                        $period.whenHoliday = 'PREVIOUSNONWORKINGDAY'
                                    } elseif ( $period.whenHoliday -eq 'ignore' ) {
                                        $period.whenHoliday = 'IGNORE'
                                    }
                                }
                            }

                            $objCalendar = New-Object PSObject

                            if ( $BaseFolder )
                            {
                                Add-Member -Membertype NoteProperty -Name 'calendarPath' -value ($BaseFolder + (Get-NormalizedObjectName -ObjectName $calendar.basedOn)) -InputObject $objCalendar
                            } else {
                                Add-Member -Membertype NoteProperty -Name 'calendarPath' -value (Get-NormalizedObjectName -ObjectName $calendar.basedOn) -InputObject $objCalendar
                            }

                            Add-Member -Membertype NoteProperty -Name 'timeZone' -value $xmlOrder.order.run_time.time_zone -InputObject $objCalendar
                            Add-Member -Membertype NoteProperty -Name 'periods' -value $calendar.periods -InputObject $objCalendar
                            Add-Member -Membertype NoteProperty -Name 'includes' -value $calendar.includes -InputObject $objCalendar

                            if ( $calendar.type -eq 'WORKING_DAYS' )
                            {
                                $workingDayCalendars += $objCalendar
                            } else {
                                $nonWorkingDayCalendars += $objCalendar
                            }
                        }
                    }
                }

                Add-Member -Membertype NoteProperty -Name 'calendars' -value $workingDayCalendars -InputObject $objSchedule
                Add-Member -Membertype NoteProperty -Name 'nonWorkingDayCalendars' -value $nonWorkingDayCalendars -InputObject $objSchedule
# ---------- End: Create Schedule ----------

                if ( $scheduleFolder -eq '/' )
                {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))".Replace( '\', '/' )
                } else {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))$($scheduleFolder)".Replace( '\', '/' )
                }

                if ( !(Test-Path -Path $outputFolder) )
                {
                    New-Item -Path $outputFolder -ItemType Directory | Out-Null
                }

                Write-Debug ".... writing schedule: $($outputFolder)/$($scheduleName).schedule.json"

                $jsonSchedule = $objSchedule | ConvertTo-Json -Depth 100
                $jsonSchedule | Out-File "$($outputFolder)/$($scheduleName).schedule.json"
            } catch {
                $message = $_.Exception | Format-List -Force | Out-String
                Write-Error "could not convert job: $jobName`n$message"
            }
        }
    }
}

function ConvertFrom-JobSchedulerXmlJobChain
{
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Path,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OutputDirectory,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $BaseFolder,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $DefaultAgentName,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ForcedAgentName,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $MappedAgentNames
)

    Begin
    {
        $jobChains = @()
    }

    Process
    {
        $jobChains += $Path
    }

    End
    {
        foreach( $jobChain in $jobChains )
        {
            try
            {
                Write-Verbose ".... processing job chain: $jobChain"

                $jobChainName = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetFileName( $jobChain ))
                $jobChainFolder = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetDirectoryName( $jobChain ).Replace( '\', '/' ))

                $objectFolder = $jobChainFolder

                if ( $BaseFolder )
                {
                    $jobChainFolder = "$($BaseFolder)$($jobChainFolder)"
                }


                [xml] $xmlJobChain = Get-JobSchedulerJobChainConfiguration -JobChain $jobChain

                $workflowInstructions = @{}
                $workflowJobs = @{}
                $workflowNodes = @{}
                $firstState = $null

                $forkBranchState = $null
                $forkLevel = 0
                $forkStates = @{}
                $forks = @{}

                foreach( $node in $xmlJobChain.job_chain.job_chain_node )
                {
                    if ( !$firstState )
                    {
                        $firstState = $node.state
                    }

                    if ( !$node.job )
                    {
                        $workflowNodes.Add( $node.state, @{ 'type' = 0; 'state' = $node.state } )
                        continue
                    }

                    $job = Get-CanonicalObjectPath -ObjectName $node.job -ObjectFolder $objectFolder
                    $jobName = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetFileName( $job ))

                    Write-Debug "...... processing job: $($job) for node state: $($node.state)"

                    [xml] $xmlJob = Get-JobSchedulerJobConfiguration -Job $job
                    $workflowNodes.Add( $node.state, @{ 'state' = $node.state; 'job' = $jobName; 'next_state' = $node.next_state; 'error_state' = $node.error_state; 'on_error' = $node.on_error; 'xmlJob' = $xmlJob } )

# ---------- Begin: initiate fork from Split Job ----------
                    if ( $xmlJob.job.script.java_class -eq 'com.sos.jitl.splitter.JobChainSplitterJSAdapterClass' )
                    {
                        $stateNames = ( $xmlJob.job.params.param | Where-Object -property 'name' -match -value 'state_names' ).value

                        if ( !$stateNames )
                        {
                            throw "parameter 'state_names' missing in split job: $jobName"
                        }

                        $forkLevel++
                        Write-Debug ".... split job found, adding fork branches for level: $forkLevel"

                        $forkBranches = @{}
                        $stateNamesList = $stateNames.split( ';' )

                        for( $i=0; $i -lt $stateNamesList.count; $i++ )
                        {
                            Write-Debug "...... adding fork branch with id branch_$($i+1) and state: $($stateNamesList[$i])"
                            $forkBranches.Add( $stateNamesList[$i], @{ 'id' = "branch_$($i+1)"; 'workflows' = @() } )
                        }

                        $forkBranchState = $stateNamesList[0]

                        $forkStates.Add( $forkLevel, $node.state )
                        $forks.Add( $node.state, $forkBranches )
                        continue
                    }
# ---------- End: initiate fork from Split Job ----------

# ---------- Begin: add fork branches from Join Job ----------
                    if ( $xmlJob.job.script.java_class -eq 'com.sos.jitl.join.JobSchedulerJoinOrdersJSAdapterClass' )
                    {
                        $objWorkflowInstruction = New-Object PSObject
                        Add-Member -Membertype NoteProperty -Name 'TYPE' -value "Fork" -InputObject $objWorkflowInstruction

                        $branches = @()
                        foreach( $forkBranch in $forks[$forkStates[$forkLevel]].getEnumerator() )
                        {
                            Write-Debug "........ fork branch found, id: $($forkBranch.value.id)"
                            $objBranchInstruction = New-Object PSObject
                            Add-Member -Membertype NoteProperty -Name 'id' -value (Get-NormalizedObjectName $forkBranch.value.id) -InputObject $objBranchInstruction

                            $objBranchWorkflowInstructions = New-Object PSObject
                            Add-Member -Membertype NoteProperty -Name 'instructions' -value $forkBranch.value.workflows -InputObject $objBranchWorkflowInstructions

                            Add-Member -Membertype NoteProperty -Name 'workflow' -value $objBranchWorkflowInstructions -InputObject $objBranchInstruction
                            $branches += $objBranchInstruction
                        }

                        Add-Member -Membertype NoteProperty -Name 'branches' -value $branches -InputObject $objWorkflowInstruction

                        Write-Debug "...... join job found, adding workflow instruction for state: $($node.state)"
                        $workflowInstructions.Add( $forkStates[$forkLevel], $objWorkflowInstruction )

                        $forkBranchState = $null
                        $forklevel--
                        continue
                    }
# ---------- End: add fork branches from Join Job ----------

# ---------- Begin: Create the Job Object ----------
                    $objWorkflowJobProperties = New-Object PSObject

                    if ( $xmlJob.job.title )
                    {
                        Add-Member -Membertype NoteProperty -Name 'title' -value $xmlJob.job.title -InputObject $objWorkflowJobProperties
                    }

                    if ( $ForcedAgentName )
                    {
                        $agentId = $ForcedAgentName
                    } elseif ( $xmlJob.job.process_class ) {
                        $agentId = (Get-CanonicalObjectPath -ObjectName $xmlJob.job.process_class -ObjectFolder $objectFolder)
                    } elseif ( $xmlJobChain.job_chain.process_class ) {
                        $agentId = (Get-CanonicalObjectPath -ObjectName $xmlJobChain.job_chain.process_class -ObjectFolder $objectFolder)
                    } else {
                        $agentId = $DefaultAgentName
                    }

                    if ( $MappedAgentNames -and ($item = $MappedAgentNames.Item( $agentId )) )
                    {
                        $agentId = $item.AgentName
                    }

                    Add-Member -Membertype NoteProperty -Name 'agentId' -value $agentId -InputObject $objWorkflowJobProperties

                        $objWorkflowJobExecutable = New-Object PSObject
                        Add-Member -Membertype NoteProperty -Name 'TYPE' -value 'ExecutableScript' -InputObject $objWorkflowJobExecutable

                        $scriptCode = Get-JobSchedulerXmlScriptInclude -IncludeNodes $xmlJob.job.script.include -ObjectFolder $objectFolder
                        Add-Member -Membertype NoteProperty -Name 'script' -value ($scriptCode + $xmlJob.job.script."#cdata-section") -InputObject $objWorkflowJobExecutable

                    Add-Member -Membertype NoteProperty -Name 'executable' -value $objWorkflowJobExecutable -InputObject $objWorkflowJobProperties

                        $objWorkflowJobReturnCode = New-Object PSObject
                        $returnCodeMeaningSuccess = @( 0 )
                        Add-Member -Membertype NoteProperty -Name 'success' -value $returnCodeMeaningSuccess -InputObject $objWorkflowJobReturnCode

                    Add-Member -Membertype NoteProperty -Name 'returnCodeMeaning' -value $objWorkflowJobReturnCode -InputObject $objWorkflowJobProperties

                    if ( $xmlJob.job.tasks )
                    {
                        Add-Member -Membertype NoteProperty -Name 'taskLimit' -value $xmlJob.job.tasks -InputObject $objWorkflowJobProperties
                    } else {
                        Add-Member -Membertype NoteProperty -Name 'taskLimit' -value 1 -InputObject $objWorkflowJobProperties
                    }

    # ---------- Begin: Create Job Arguments ----------
                    $objWorkflowJobDefaultArguments = New-Object PSObject

                    $xmlArguments = Get-JobSchedulerXmlParamsInclude -IncludeNodes $xmlJob.job.params.include -ObjectFolder $objectFolder
                    foreach( $argumentNode in $xmlArguments.params.param )
                    {
                        Add-Member -Membertype NoteProperty -Name $argumentNode.name -value $argumentNode.value -InputObject $objWorkflowJobDefaultArguments -Force
                    }

                    $argumentNodes = $xmlJob.job.params.param
                    foreach( $argumentNode in $argumentNodes )
                    {
                        Add-Member -Membertype NoteProperty -Name $argumentNode.name -value $argumentNode.value -InputObject $objWorkflowJobDefaultArguments -Force
                    }

                    Add-Member -Membertype NoteProperty -Name 'defaultArguments' -value $objWorkflowJobDefaultArguments -InputObject $objWorkflowJobProperties
    # ---------- End: Create Job Arguments ----------


                    if ( !$workflowJobs.Item( $jobName ) )
                    {
                        $workflowJobs.Add( $jobName, $objWorkflowJobProperties )
                    }
# ---------- End: Create the Job Object ----------


#                   TODO: return codes
#                   $node.on_return_codes mapped to junctions


# ---------- Begin: Create the Workflow Instruction ----------
                    $objWorkflowInstruction = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'TYPE' -value "Execute.Named" -InputObject $objWorkflowInstruction
                    Add-Member -Membertype NoteProperty -Name 'jobName' -value $jobName -InputObject $objWorkflowInstruction
                    Add-Member -Membertype NoteProperty -Name 'label' -value (Get-NormalizedObjectName $node.state) -InputObject $objWorkflowInstruction

                        # ---------- Begin: Add job chain node arguments ----------
                        $objWorkflowDefaultArguments = New-Object PSObject

                        $masterUrl = (Get-JobSchedulerMasterCluster -Active).url
                        $canonicalPath = Get-CanonicalObjectPath -ObjectName "$($jobChainName).config.xml" -ObjectFolder $objectFolder

                        $response = Invoke-JobSchedulerWebRequest -Url $masterUrl -Path "/jobscheduler/master/api/live$canonicalPath" -Method 'GET' -Headers @{ 'Accept' = 'application/octet-stream' }

                        if ( $response.StatusCode -eq 200 )
                        {
                            [Xml] $xmlConfig = [System.Text.Encoding]::UTF8.GetString( $response.Content )
                        } else {
                            # file might not exist
                            $xmlConfig = $null
                        }

                        if ( $xmlConfig )
                        {
                            $argumentNodes = $xmlConfig | Select-Xml -Xpath "/settings/job_chain/order/process[@state = '$($node.state)']/params/param"
                            foreach( $argumentNode in $argumentNodes.node )
                            {
                                Add-Member -Membertype NoteProperty -Name $argumentNode.name -value $argumentNode.value -InputObject $objWorkflowDefaultArguments -Force
                            }
                        }

                        Add-Member -Membertype NoteProperty -Name 'defaultArguments' -value $objWorkflowDefaultArguments -InputObject $objWorkflowInstruction
                        # ---------- End: Add job chain node arguments ----------

                    # job found for fork branch
                    if ( $forkLevel )
                    {
                        if ( !$forks[$forkStates[$forkLevel]][$node.state] )
                        {
                            Write-Debug ".... adding workflow instruction: forks[$($forkStates[$forkLevel])][$($forkBranchState)].workflows"
                            $forks[$forkStates[$forkLevel]][$forkBranchState].workflows += $objWorkflowInstruction
                        } else {
                            Write-Debug ".... adding workflow instruction: forks[$($forkStates[$forkLevel])][$($node.state)].workflows"
                            $forks[$forkStates[$forkLevel]][$node.state].workflows += $objWorkflowInstruction
                        }
                    } else {
                        Write-Debug ".... adding workflow instruction: $($node.state)"
                        $workflowInstructions.Add( $node.state, $objWorkflowInstruction )
                    }
# ---------- End: Create the Workflow Instruction ----------
                }

                $objWorkflowJobs = New-Object PSObject
                foreach( $workflowJob in $workflowJobs.GetEnumerator() )
                {
                    Add-Member -Membertype NoteProperty -Name $workflowJob.Name -value $workflowJob.Value -InputObject $objWorkflowJobs
                }

                $instructions = New-JobSchedulerInstructionNodes -Node $workflowNodes.Item( $firstState ) -WorkflowNodes $workflowNodes -WorkflowInstructions $workflowInstructions -Forks $forks -Instructions @()

                $objWorkflow = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'instructions' -value ([object[]] $instructions) -InputObject $objWorkflow
                Add-Member -Membertype NoteProperty -Name 'jobs' -value $objWorkflowJobs -InputObject $objWorkflow

                if ( $jobChainFolder -eq '/' )
                {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))".Replace( '\', '/' )
                } else {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))$($jobChainFolder)".Replace( '\', '/' )
                }


                if ( !(Test-Path -Path $outputFolder) )
                {
                    New-Item -Path $outputFolder -ItemType Directory | Out-Null
                }

                Write-Debug ".... writing workflow: $($outputFolder)/$($jobChainName).workflow.json"

                $jsonWorkflow = $objWorkflow | ConvertTo-Json -Depth 100
                $jsonWorkflow | Out-File "$($outputFolder)/$($jobChainName).workflow.json"
            } catch {
                $message = $_.Exception | Format-List -Force | Out-String
                Write-Error "could not convert job chain: $jobChainName`n$message"
            }
        }
    }
}

function Get-JobSchedulerXmlParamsInclude( [System.Xml.XmlElement] $IncludeNodes, [string] $ObjectFolder )
{
    [Xml] $xmlArguments = '<params/>'
    $masterUrl = $null

    foreach( $includeNode in $IncludeNodes )
    {
        if ( !$includeNode.file -and !$includeNode.live_file )
        {
            continue
        }

        if ( !$masterUrl )
        {
            $masterUrl = (Get-JobSchedulerMasterCluster -Active).url
        }

        if ( $includeNode.file )
        {
            $canonicalPath = Get-CanonicalObjectPath -ObjectName $includeNode.file -ObjectFolder $ObjectFolder
        } else {
            $canonicalPath = Get-CanonicalObjectPath -ObjectName $includeNode.live_file -ObjectFolder $ObjectFolder
        }

        $response = Invoke-JobSchedulerWebRequest -Url $masterUrl -Path "/jobscheduler/master/api/live$canonicalPath" -Method 'GET' -Headers @{ 'Accept' = 'application/octet-stream' }

        if ( $response.StatusCode -eq 200 )
        {
            [Xml] $xmlInclude = [System.Text.Encoding]::UTF8.GetString( $response.Content )
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }

        foreach( $argumentNode in $xmlInclude.params.param )
        {
            $xmlParam = $xmlArguments.CreateElement( 'param' )
            $xmlParam.SetAttribute( 'name', $argumentNode.name )
            $xmlParam.SetAttribute( 'value', $argumentNode.value )
            $xmlArguments.SelectSingleNode( '/params' ).AppendChild( $xmlParam )
        }
    }

    $xmlArguments
}

function Get-JobSchedulerXmlScriptInclude( [System.Xml.XmlElement] $IncludeNodes, [string] $ObjectFolder )
{
    $scriptCode = $null
    $masterUrl = $null

    foreach( $includeNode in $IncludeNodes )
    {
        if ( !$includeNode.file -and !$includeNode.live_file )
        {
            continue
        }

        if ( !$masterUrl )
        {
            $masterUrl = (Get-JobSchedulerMasterCluster -Active).url
        }

        if ( $includeNode.file )
        {
            $canonicalPath = Get-CanonicalObjectPath -ObjectName $includeNode.file -ObjectFolder $ObjectFolder
        } else {
            $canonicalPath = Get-CanonicalObjectPath -ObjectName $includeNode.live_file -ObjectFolder $ObjectFolder
        }

        $response = Invoke-JobSchedulerWebRequest -Url $masterUrl -Path "/jobscheduler/master/api/live$canonicalPath" -Method 'GET' -Headers @{ 'Accept' = 'application/octet-stream' }

        if ( $response.StatusCode -eq 200 )
        {
            $scriptCode += [System.Text.Encoding]::UTF8.GetString( $response.Content ) + "`n"
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }
    }

    $scriptCode
}

function New-JobSchedulerInstructionNodes
{
[cmdletbinding(SupportsShouldProcess)]
param
(
    $Node,
    [hashtable] $WorkflowNodes,
    [hashtable] $WorkflowInstructions,
    [hashtable] $Forks,
    [object[]] $Instructions
)

    while ( $Node )
    {
        Write-Debug ".... constructing workflow instructions, state: $($Node.state), on_error: $($Node.on_error), job: $($Node.job)"

        if ( $Node.on_error -eq 'setback' )
        {
            Write-Debug "...... setback found, state: $($Node.state), job: $($Node.job)"

            $objTryInstruction = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'instructions' -value @( $WorkflowInstructions.Item( $Node.state ) ) -InputObject $objTryInstruction

            $objRetryInstruction = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'TYPE' -value 'Retry' -InputObject $objRetryInstruction

            $objCatchInstruction = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'instructions' -value @( $objRetryInstruction ) -InputObject $objCatchInstruction

            $objWorkflowInstruction = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'TYPE' -value 'Try' -InputObject $objWorkflowInstruction
            Add-Member -Membertype NoteProperty -Name 'try' -value $objTryInstruction -InputObject $objWorkflowInstruction
            Add-Member -Membertype NoteProperty -Name 'catch' -value $objCatchInstruction -InputObject $objWorkflowInstruction

            if ( $setbackCount = ( $Node.xmlJob.job.delay_order_after_setback | Where-Object -Property 'is_maximum' -match -value 'true' ).setback_count )
            {
                Add-Member -Membertype NoteProperty -Name 'maxTries' -value $setbackCount -InputObject $objWorkflowInstruction
            }

            $lastDelay = 1
            $lastSetbackCount = 1
            $setbackDelays = @()
            $setbacks = ( $Node.xmlJob.job.delay_order_after_setback | Sort-Object -Property @{expression={$_.setback_count -as [int]}} )

            foreach( $setback in $setbacks )
            {
                for( $i=$lastSetbackCount+1; $i -lt ($setback.setback_count -as [int]); $i++ )
                {
                    $setBackDelays += $lastDelay
                }

                if ( $setback.delay )
                {
                    if ( ([regex]::Matches($setback.delay, ':' )).count -eq 0 )
                    {
                        $setback.delay = "00:00:$($setback.delay)"
                    } elseif ( ([regex]::Matches($setback.delay, ':' )).count -eq 1 ) {
                        $setback.delay = "00:$($setback.delay):00"
                    }

                    $delay = [TimeSpan]::Parse( $setback.delay )
                    $setBackDelays += [int] $delay.TotalSeconds
                    $lastSetbackCount = ( $setback.setback_count -as [int] )
                    $lastDelay = [int] $delay.TotalSeconds
                }
            }

            Add-Member -Membertype NoteProperty -Name 'retryDelays' -value $setbackDelays -InputObject $objWorkflowInstruction

            Write-Debug "...... adding instruction for state (0): $($Node.state)"
            $WorkflowInstructions[$Node.state] = $objWorkflowInstruction
        }

        if ( $Node.error_state -and $WorkflowNodes.Item( $Node.error_state ).job )
        {
            Write-Debug "...... error node found, state: $($Node.error_state), job: $($Node.job)"

            $objTryInstruction = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'instructions' -value @( $WorkflowInstructions.Item( $Node.state ) ) -InputObject $objTryInstruction

            $catchInstructions = @()

            if ( $WorkflowNodes.Item( $Node.error_state ).job )
            {
                Write-Debug "...... creating catch instruction for state: $($Node.error_state)"
                $catchInstructions += New-JobSchedulerInstructionNodes -Node $WorkflowNodes.Item( $Node.error_state ) -WorkflowNodes $WorkflowNodes -WorkflowInstructions $WorkflowInstructions -Forks $Forks -Instructions @()
            }

            $objCatchInstruction = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'instructions' -value $catchInstructions -InputObject $objCatchInstruction

            $objWorkflowInstruction = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'TYPE' -value "Try" -InputObject $objWorkflowInstruction
            Add-Member -Membertype NoteProperty -Name 'try' -value $objTryInstruction -InputObject $objWorkflowInstruction
            Add-Member -Membertype NoteProperty -Name 'catch' -value $objCatchInstruction -InputObject $objWorkflowInstruction

            Write-Debug "...... adding instruction for state (1): $($Node.error_state)"
            $Instructions += $objWorkflowInstruction
        } elseif ( $WorkflowInstructions.Item( $Node.state ) ) {
            Write-Debug "...... adding instruction for state (2): $($Node.state)"
            $Instructions += $WorkflowInstructions.Item( $Node.state )
        }

        if ( $Node.next_state -and $Node.next_state -ne $Node.error_state )
        {
            Write-Debug "...... continue with state: $($Node.next_state)"
            $Node = $WorkflowNodes.item( $Node.next_state )

            if ( !$Node.job )
            {
                break
            }
        } else {
            break
        }
    }

    if ( $PSCmdlet.ShouldProcess( 'Instructions' ) )
    {
        $Instructions
    }
}

function ConvertFrom-JobSchedulerXmlOrder
{
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OrderId,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OutputDirectory,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $BaseFolder,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $PrefixOrders,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $SubmitOrders,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $PlanOrders
)

    Begin
    {
        $orders = @()
    }

    Process
    {
        $orders += @{'orderId' = $OrderId; 'jobChain' = $JobChain }
    }

    End
    {
        foreach( $order in $orders )
        {
            try
            {
                Write-Verbose ".... processing OrderID: $($order.orderId), Job Chain: $($order.jobChain)"

                if ( $PrefixOrders )
                {
                    $scheduleName = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetFileName( $order.jobChain ) + "-$($order.orderId)")
                } else {
                    $scheduleName = Get-NormalizedObjectName -ObjectName $order.orderId
                }

                $scheduleFolder = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetDirectoryName( $order.jobChain ).Replace( '\', '/' ))
                $objectFolder = $scheduleFolder

                if ( $BaseFolder )
                {
                    $scheduleFolder = "$($BaseFolder)$($scheduleFolder)"
                }

                [xml] $xmlOrder = Get-JobSchedulerOrderConfiguration -OrderId $order.orderId -JobChain $order.jobChain

                $objSchedule = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'path' -value "$($scheduleFolder)/$($scheduleName)" -InputObject $objSchedule

                if ( $BaseFolder )
                {
                    Add-Member -Membertype NoteProperty -Name 'workflowPath' -value ($BaseFolder + (Get-NormalizedObjectName -ObjectName $order.jobChain)) -InputObject $objSchedule
                } else {
                    Add-Member -Membertype NoteProperty -Name 'workflowPath' -value (Get-NormalizedObjectName -ObjectName $order.jobChain) -InputObject $objSchedule
                }

                if ( $xmlOrder.order.title )
                {
                    Add-Member -Membertype NoteProperty -Name 'title' -value $xmlOrder.order.title -InputObject $objSchedule
                }

                Add-Member -Membertype NoteProperty -Name 'submitOrderToControllerWhenPlanned' -value ($SubmitOrders -eq $True) -InputObject $objSchedule
                Add-Member -Membertype NoteProperty -Name 'planOrderAutomatically' -value ($PlanOrders -eq $True) -InputObject $objSchedule

# ---------- Begin: Add order variables ----------
                $variables = @()

                # ---------- Begin: Add order variables from <job_chain>.config.xml ----------
                $masterUrl = (Get-JobSchedulerMasterCluster -Active).url
                $canonicalPath = Get-CanonicalObjectPath -ObjectName "$($order.jobChain).config.xml" -ObjectFolder $objectFolder
                $response = Invoke-JobSchedulerWebRequest -Url $masterUrl -Path "/jobscheduler/master/api/live$canonicalPath" -Method 'GET' -Headers @{ 'Accept' = 'application/octet-stream' }

                if ( $response.StatusCode -eq 200 )
                {
                    [Xml] $xmlConfig = [System.Text.Encoding]::UTF8.GetString( $response.Content )
                } else {
                    # file might not exist
                    $xmlConfig = $null
                }

                if ( $xmlConfig )
                {
                    $argumentNodes = $xmlConfig.settings.job_chain.order.process.params.param
                    foreach( $argumentNode in $argumentNodes.node )
                    {
                        $objVariable = New-Object PSObject
                        Add-Member -Membertype NoteProperty -Name 'name' -value $argumentNode.name -InputObject $objVariable
                        Add-Member -Membertype NoteProperty -Name 'value' -value $argumentNode.value -InputObject $objVariable
                        $variables += $objVariable
                    }
                }
                # ---------- End: Add order variables from <job_chain>.config.xml ----------

                # ---------- Begin: Add order variables from <order><params><include> elements in <order>.order.xml ----------
                $xmlArguments = Get-JobSchedulerXmlParamsInclude -IncludeNodes $xmlOrder.order.params.include -ObjectFolder $objectFolder
                foreach( $argumentNode in $xmlArguments.params.param )
                {
                    $objVariable = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'name' -value $argumentNode.name -InputObject $objVariable
                    Add-Member -Membertype NoteProperty -Name 'value' -value $argumentNode.value -InputObject $objVariable
                    $variables += $objVariable
                }
                # ---------- End: Add order variables from <order><params><include> elements in <order>.order.xlm ----------

                # ---------- End: Add order variables from <order><params><include> elements in <order>.order.xml ----------

                # ---------- Begin: Add order variables from <order><params><params> elements in <order>.order.xml ----------
                $variableNodes = $xmlOrder.order.params.param
                foreach( $variableNode in $variableNodes )
                {
                    $objVariable = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'name' -value $variableNode.name -InputObject $objVariable
                    Add-Member -Membertype NoteProperty -Name 'value' -value $variableNode.value -InputObject $objVariable
                    $variables += $objVariable
                }
                # ---------- End: Add order variables from <order><params><param> elements in <order>.order.xml ----------

                Add-Member -Membertype NoteProperty -Name 'variables' -value $variables -InputObject $objSchedule
# ---------- End: Add order variables ----------

                $workingDayCalendars = @()
                $nonWorkingDayCalendars = @()

                if ( $xmlOrder.order.run_time.calendars )
                {
                    if ( isPowerShellVersion 6 )
                    {
                        $jsonCalendars = $xmlOrder.order.run_time.calendars."#cdata-section" | ConvertFrom-Json -Depth 100
                    } else {
                        $jsonCalendars = $xmlOrder.order.run_time.calendars."#cdata-section" | ConvertFrom-Json
                    }

                    if ( $jsonCalendars )
                    {
                        foreach( $calendar in $jsonCalendars.calendars )
                        {
                            foreach( $period in $calendar.periods )
                            {
                                if ( $period.whenHoliday )
                                {
                                    if ( $period.whenHoliday -eq 'suppress' )
                                    {
                                        $period.whenHoliday = 'SUPPRESS'
                                    } elseif ( $period.whenHoliday -eq 'next_non_holiday' ) {
                                        $period.whenHoliday = 'NEXTNONWORKINGDAY'
                                    } elseif ( $period.whenHoliday -eq 'previous_non_holiday' ) {
                                        $period.whenHoliday = 'PREVIOUSNONWORKINGDAY'
                                    } elseif ( $period.whenHoliday -eq 'ignore' ) {
                                        $period.whenHoliday = 'IGNORE'
                                    }
                                }
                            }

                            $objCalendar = New-Object PSObject

                            if ( $BaseFolder )
                            {
                                Add-Member -Membertype NoteProperty -Name 'calendarPath' -value ($BaseFolder + (Get-NormalizedObjectName -ObjectName $calendar.basedOn)) -InputObject $objCalendar
                            } else {
                                Add-Member -Membertype NoteProperty -Name 'calendarPath' -value (Get-NormalizedObjectName -ObjectName $calendar.basedOn) -InputObject $objCalendar
                            }

                            Add-Member -Membertype NoteProperty -Name 'timeZone' -value $xmlOrder.order.run_time.time_zone -InputObject $objCalendar
                            Add-Member -Membertype NoteProperty -Name 'periods' -value $calendar.periods -InputObject $objCalendar
                            Add-Member -Membertype NoteProperty -Name 'includes' -value $calendar.includes -InputObject $objCalendar

                            if ( $calendar.type -eq 'WORKING_DAYS' )
                            {
                                $workingDayCalendars += $objCalendar
                            } else {
                                $nonWorkingDayCalendars += $objCalendar
                            }
                        }
                    }
                }

                Add-Member -Membertype NoteProperty -Name 'calendars' -value $workingDayCalendars -InputObject $objSchedule
                Add-Member -Membertype NoteProperty -Name 'nonWorkingDayCalendars' -value $nonWorkingDayCalendars -InputObject $objSchedule


                if ( $scheduleFolder -eq '/' )
                {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))".Replace( '\', '/' )
                } else {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))$($scheduleFolder)".Replace( '\', '/' )
                }

                if ( !(Test-Path -Path $outputFolder) )
                {
                    New-Item -Path $outputFolder -ItemType Directory | Out-Null
                }

                Write-Debug ".... writing schedule: $($outputFolder)/$($scheduleName).schedule.json"

                $jsonSchedule = $objSchedule | ConvertTo-Json -Depth 100
                $jsonSchedule | Out-File "$($outputFolder)/$($scheduleName).schedule.json"
            } catch {
                $message = $_.Exception | Format-List -Force | Out-String
                Write-Error "could not convert order: $scheduleName`n$message"
            }
        }
    }
}

function ConvertFrom-JobSchedulerXmlCalendar
{
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Path,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OutputDirectory,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $BaseFolder
)

    Begin
    {
        $calendars = @()
    }

    Process
    {
        $calendars += $Path
    }

    End
    {
        foreach( $calendar in $calendars )
        {
            try
            {
                Write-Verbose ".... processing calendar: $calendar"

                $calendarName = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetFileName( $calendar ))
                $calendarFolder = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetDirectoryName( $calendar ).Replace( '\', '/' ))

                if ( $BaseFolder )
                {
                    $calendarFolder = "$($BaseFolder)$($calendarFolder)"
                }

                $body = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
                Add-Member -Membertype NoteProperty -Name 'calendars' -value @( $calendar ) -InputObject $body

                $headers = @{ 'Accept-Encoding' = 'gzip, deflate, br' }

                [string] $requestBody = $body | ConvertTo-Json -Depth 100
                $response = Invoke-JobSchedulerWebRequest -Path '/calendars/export' -Body $requestBody -Headers $headers

                if ( $response.StatusCode -ne 200 )
                {
                    throw ( $response | Format-List -Force | Out-String )
                }

                if ( isPowerShellVersion 6 )
                {
                    $jsonCalendars = ([System.Text.Encoding]::UTF8.GetString( $response.Content )) | ConvertFrom-Json -Depth 100
                } else {
                    $jsonCalendars = ([System.Text.Encoding]::UTF8.GetString( $response.Content )) | ConvertFrom-Json
                }

                $jsonCalendar = $jsonCalendars.calendars[0]

                $objCalendar = New-Object PSObject

                if ( $calendarFolder -eq '/' )
                {
                    Add-Member -Membertype NoteProperty -Name 'path' -value "$calendarFolder$calendarName" -InputObject $objCalendar
                } else {
                    Add-Member -Membertype NoteProperty -Name 'path' -value "$calendarFolder/$calendarName" -InputObject $objCalendar
                }

                if ( $jsonCalendar.type -eq 'WORKING_DAYS' )
                {
                    Add-Member -Membertype NoteProperty -Name 'type' -value 'WORKINGDAYSCALENDAR' -InputObject $objCalendar
                } elseif ( $jsonCalendar.type -eq 'NON_WORKING_DAYS' ) {
                    Add-Member -Membertype NoteProperty -Name 'type' -value 'NONWORKINGDAYSCALENDAR' -InputObject $objCalendar
                }

                if ( $jsonCalendar.title )
                {
                    Add-Member -Membertype NoteProperty -Name 'title' -value $jsonCalendar.title -InputObject $objCalendar
                }

                if ( $jsonCalendar.from )
                {
                    Add-Member -Membertype NoteProperty -Name 'from' -value $jsonCalendar.from -InputObject $objCalendar
                }

                if ( $jsonCalendar.to )
                {
                    Add-Member -Membertype NoteProperty -Name 'to' -value $jsonCalendar.to -InputObject $objCalendar
                }

                if ( $jsonCalendar.includes )
                {
                    Add-Member -Membertype NoteProperty -Name 'includes' -value $jsonCalendar.includes -InputObject $objCalendar
                }


                if ( $calendarFolder -eq '/' )
                {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))".Replace( '\', '/' )
                } else {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))$($calendarFolder)".Replace( '\', '/' )
                }

                if ( !(Test-Path -Path $outputFolder) )
                {
                    New-Item -Path $outputFolder -ItemType Directory | Out-Null
                }

                Write-Debug ".... writing calendar: $($outputFolder)/$($calendarName).calendar.json"

                $objCalendar | ConvertTo-Json -Depth 100 | Out-File "$($outputFolder)/$($calendarName).calendar.json"
            } catch {
                $message = $_.Exception | Format-List -Force | Out-String
                Write-Error "could not convert calendar: $calendarName`n$message"
            }
        }
    }
}

function ConvertFrom-JobSchedulerXmlLock
{
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Path,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OutputDirectory,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $BaseFolder
)

    Begin
    {
        $locks = @()
    }

    Process
    {
        $locks += $Path
    }

    End
    {
        foreach( $lock in $locks )
        {
            try
            {
                Write-Verbose ".... processing lock: $lock"

                $lockName = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetFileName( $lock ))
                $lockFolder = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetDirectoryName( $lock ).Replace( '\', '/' ))

                if ( $BaseFolder )
                {
                    $lockFolder = "$($BaseFolder)$($lockFolder)"
                }

                [xml] $xmlLock = Get-JobSchedulerLockConfiguration -Lock $lock

                $objLock = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'TYPE' -value "Lock" -InputObject $objLock
                # TODO: locks with id instead of path
                Add-Member -Membertype NoteProperty -Name 'path' -value $lock -InputObject $objLock
                Add-Member -Membertype NoteProperty -Name 'id' -value $lock -InputObject $objLock

                if ( $xmlLock.lock.max_non_exclusive )
                {
                    Add-Member -Membertype NoteProperty -Name 'limit' -value $xmlLock.lock.max_non_exclusive -InputObject $objLock
                }

                if ( $lockFolder -eq '/' )
                {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))".Replace( '\', '/' )
                } else {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))$($lockFolder)".Replace( '\', '/' )
                }

                if ( !(Test-Path -Path $outputFolder) )
                {
                    New-Item -Path $outputFolder -ItemType Directory | Out-Null
                }

                Write-Debug ".... writing lock: $($outputFolder)/$($lockName).lock.json"

                $jsonLock = $objLock | ConvertTo-Json -Depth 100
                $jsonLock | Out-File "$($outputFolder)/$($lockName).lock.json"
            } catch {
                $message = $_.Exception | Format-List -Force | Out-String
                Write-Error "could not convert lock: $lockName`n$message"
            }
        }
    }
}

function ConvertFrom-JobSchedulerXmlAgentCluster
{
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Path,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OutputDirectory,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $BaseFolder,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $MappedAgentNames
)

    Begin
    {
        $agentClusters = @()
    }

    Process
    {
        $agentClusters += $Path
    }

    End
    {
        foreach( $agentCluster in $agentClusters )
        {
            try
            {
                Write-Verbose ".... processing Agent Cluster: $agentCluster"

                $objAgentCluster = Get-JobSchedulerAgentCluster -AgentCluster $agentCluster

                $agentClusterName = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetFileName( $objAgentCluster.AgentCluster ))
                $agentClusterFolder = Get-NormalizedObjectName -ObjectName ([System.IO.Path]::GetDirectoryName( $objAgentCluster.AgentCluster ).Replace( '\', '/' ))

                if ( $BaseFolder )
                {
                    $agentClusterFolder = "$($BaseFolder)$($agentClusterFolder)"
                }

                if ( $ForcedAgentName )
                {
                    $agentClusterName = $ForcedAgentName
                    $objAgentCluster.AgentCluster = "$agentClusterFolder/$agentClusterName"
                    $objAgentCluster.Directory = "$agentClusterFolder/$agentClusterName"
                }

                if ( $MappedAgentNames -and ($item = $MappedAgentNames.Item( $objAgentCluster.AgentCluster) ) ) {
                    Add-Member -Membertype NoteProperty -Name 'AgentId' -value $item.AgentId -InputObject $objAgentCluster
                    Add-Member -Membertype NoteProperty -Name 'AgentName' -value $item.AgentName -InputObject $objAgentCluster
                } else {
                    Add-Member -Membertype NoteProperty -Name 'AgentId' -value $agentClusterName -InputObject $objAgentCluster
                    Add-Member -Membertype NoteProperty -Name 'AgentName' -value $agentClusterName -InputObject $objAgentCluster
                }

                if ( $objAgentCluster.Agents.count )
                {
                    Add-Member -Membertype NoteProperty -Name 'Url' -value $objAgentCluster.Agents[0] -InputObject $objAgentCluster
                }

                if ( $agentClusterFolder -eq '/' )
                {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))".Replace( '\', '/' )
                } else {
                    $outputFolder = "$([System.IO.Path]::GetFullPath($OutputDirectory))$($agentClusterFolder)".Replace( '\', '/' )
                }

                if ( !(Test-Path -Path $outputFolder) )
                {
                    New-Item -Path $outputFolder -ItemType Directory | Out-Null
                }

                Write-Debug ".... writing Agent Cluster: $($outputFolder)/$($agentClusterName).agentcluster.json"

                $objAgentCluster | ConvertTo-Json -Depth 100 | Out-File "$($outputFolder)/$($agentClusterName).agentcluster.json"
            } catch {
                $message = $_.Exception | Format-List -Force | Out-String
                Write-Error "could not convert Agent Cluster: $agentClusterName`n$message"
            }
        }
    }
}

function Get-CanonicalObjectPath( [string] $ObjectName, [string] $ObjectFolder )
{
    $objectFolders = $ObjectFolder.split( '/' )

    if ( $ObjectName.startsWith( '/' ) )
    {
        # absolute reference, nothing to do
    } elseif ( $ObjectName.startsWith( './' ) ) {
        # relative reference for same location
        $ObjectName = $ObjectName.Substring( 2 )
    } elseif ( $ObjectName.startsWith( '../' ) ) {
        # relative reference
        $ObjectFolder = ''
        $index = 1
        do
        {
            $ObjectFolder = ''
            $ObjectName = $ObjectName.Substring( 3 )
            #$ObjectFolder = "/$($objectFolders[$objectFolders.length - $index])/$($ObjectFolder)"
            for( $i=0; $i -lt $objectFolders.length-$index; $i++ )
            {
                $ObjectFolder += $objectFolders[$i] + '/'
            }
            $index++
        } while ( $ObjectName.startsWith( '../' ) )

        $ObjectName = "$($ObjectFolder)$($ObjectName)"
    } else {
        if ( $ObjectFolder -ne '/' )
        {
            $ObjectName = "$($ObjectFolder)/$($ObjectName)"
        } else {
            $ObjectName = "/$($ObjectName)"
        }
    }

    $ObjectName.Replace( ' ', '' )
}

function Get-NormalizedObjectName( [string] $ObjectName )
{
    $ObjectName.Replace( ' ', '' ).Replace( ':', '_' )
}

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------

$script:js = New-JobSchedulerObject
$script:jsWebService = New-JobSchedulerWebServiceObject

<#
if ( $script:jsOperations )
{
    # no addtional connection to Master required
    $script:js.Url = "http://$($spooler.hostname()):$($spooler.tcp_port())"
    $script:js.Id = $spooler.id()
    $script:js.Local = $false
    $script:jsWebService.JobSchedulerId = $js.Id
}
#>

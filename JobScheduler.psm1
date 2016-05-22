<#
.SYNOPSIS
JobScheduler command line interface

For further information see

    PS C:\> about_JobScheduler

If the documentation is not available for your language then consider to use

    PS C:\> [System.Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
	
TODOs

	Add proxy support
#>

# ----------------------------------------------------------------------
# Globals
# ----------------------------------------------------------------------

# JobScheduler Master Object
$js = $null

# JobScheduler Web Request Credentials
$jsCredentials = $null

# Commands that require a local instance (Management of Windows Service)
$jsLocalCommands = @( 'Install-JobSchedulerService', 'Remove-JobSchedulerService', 'Start-JobSchedulerMaster' )

# Options
#     Debug Message: responses exceeding the max. output size are stored in temporary files
$jsOptionDebugMaxOutputSize = 1000
#    Web Request: timeout for establishing the connection in ms
$jsOptionWebRequestTimeout = 15000
#    Web Request: use default credentials of the current user?
$jsOptionWebRequestUseDefaultCredentials = $true

# ----------------------------------------------------------------------
# Public Functions
# ----------------------------------------------------------------------

$moduleRoot = Split-Path -Path $MyInvocation.MyCommand.Path
"$moduleRoot\functions\*.ps1" | Resolve-Path | ForEach-Object { . $_.ProviderPath }

Export-ModuleMember -Alias "*"
Export-ModuleMember -Function "*"

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

    if ( !$SCRIPT:js.Url )
    {
        if ( $SCRIPT:jsLocalCommands -notcontains $command.Name )
        {
            throw "$($command.Name): cmdlet requires a JobScheduler URL. Switch instance with the Use-JobSchedulerMaster cmdlet and specify the -Url parameter"
        }
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
    $js | Add-Member -Membertype NoteProperty -Name Local -Value $false

    $jsInstall | Add-Member -Membertype NoteProperty -Name Directory -Value ''
    $jsInstall | Add-Member -Membertype NoteProperty -Name ExecutableFile -Value ''
    $jsInstall | Add-Member -Membertype NoteProperty -Name Params -Value ''
    $jsInstall | Add-Member -Membertype NoteProperty -Name StartParams -Value ''
    $jsInstall | Add-Member -Membertype NoteProperty -Name ClusterOptions -Value ''
    $jsInstall | Add-Member -Membertype NoteProperty -Name PidFile -Value 0

    $jsConfig | Add-Member -Membertype NoteProperty -Name Directory -Value ''
    $jsConfig | Add-Member -Membertype NoteProperty -Name FactoryIni -Value ''
    $jsConfig | Add-Member -Membertype NoteProperty -Name SosIni -Value ''
    $jsConfig | Add-Member -Membertype NoteProperty -Name SchedulerXml -Value 0

    $jsService | Add-Member -Membertype NoteProperty -Name ServiceName -Value ''
    $jsService | Add-Member -Membertype NoteProperty -Name ServiceDisplayName -Value ''
    $jsService | Add-Member -Membertype NoteProperty -Name ServiceDescription -Value ''

    $js | Add-Member -Membertype NoteProperty -Name Install -Value $jsInstall
    $js | Add-Member -Membertype NoteProperty -Name Config -Value $jsConfig
    $js | Add-Member -Membertype NoteProperty -Name Service -Value $jsService

    # $jsDefaultProperties = @("Id", "Url")
    # $jsDefaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet( "DefaultDisplayPropertySet", [string[]] $jsDefaultProperties )
    # $jsPSStandardMembers = [System.Management.Automation.PSMemberInfo[]] @( $jsDefaultDisplayPropertySet )
    # $js | Add-Member MemberSet PSStandardMembers $jsPSStandardMembers
    
    $js
}

function Create-StatusObject()
{
    $state = New-Object PSObject

    $state | Add-Member -Membertype NoteProperty -Name Id -Value ''
    $state | Add-Member -Membertype NoteProperty -Name Url -Value ''

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

# send XML command to JobScheduler
function Send-JobSchedulerXMLCommand( [Uri] $jobSchedulerURL, [string] $command, [bool] $checkResponse=$true ) 
{
    [string] $output = ''

    $request = $null
    $requestStream = $null

    $response = $null
    $responseStream = $null
    $streamReader = $null

    try
    {     
        $request = [System.Net.WebRequest]::Create( $jobSchedulerURL )
 
        $request.Method = 'POST'
        $request.ContentType = 'text/xml'
        $request.Timeout = $SCRIPT:jsOptionWebRequestTimeout
        
        if ( $SCRIPT:jsOptionWebRequestUseDefaultCredentials )
        {
            Write-Debug ".. $($MyInvocation.MyCommand.Name): using default credentials"
            $request.UseDefaultCredentials = $SCRIPT:jsOptionWebRequestUseDefaultCredentials
        } elseif ( $SCRIPT:jsCredentials ) {
            Write-Debug ".. $($MyInvocation.MyCommand.Name): using explicit credentials"
            $request.Credentials = $SCRIPT:jsCredentials
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
            $streamReader = new-object System.IO.StreamReader $responseStream
            $output = $streamReader.ReadToEnd()
        }

        if ( $checkResponse -and $output )
        {
            if ( $DebugPreference -eq 'Continue' )
            {
                if ( $output.Length -gt $SCRIPT:jsOptionDebugMaxOutputSize )
                {
                    $tempFile = [IO.Path]::GetTempFileName()
                    $output | Out-File $tempFile -encoding ascii
                    Write-Debug ".. $($MyInvocation.MyCommand.Name): XML response available with temporary file: $($tempFile)"
                } else {
                    Write-Debug ".. $($MyInvocation.MyCommand.Name): response: $($output)"
                }
            }

            try
            {
                $errorText = Select-XML -Content $output -Xpath '/spooler/answer/ERROR/@text'
            } catch {
                throw "not a valid JobScheduler XML response: " + $_.Exception.Message
            }
            
            if ( $errorText.Node."#text" )
            {
                throw $errorText.Node."#text"
            }

            try
            {
                [xml] $output
            } catch {
                throw "not a valid JobScheduler XML response: " + $_.Exception.Message
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

# check JobScheduler response for errors and return error message
function _not_used_Get-JobSchedulerResponseError( $response )
{
    if ( $response )
    {
        $errorText = Select-XML -Content $response -Xpath '//ERROR/@text'
        if ( $errorText.Node."#text" )
        {
            $errorText.Node."#text"
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
            Set-Content "env:\$($matches[1])" $matches[2]
        }
    }

    Remove-Item $tempFile
}

# ----------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------

$js = Create-JSObject

if ( $env:SCHEDULER_URL )
{
   Use-JobSchedulerMaster -Url $env:SCHEDULER_URL -Id $env:SCHEDULER_ID -InstallPath $env:SCHEDULER_HOME
} elseif ( $env:SCHEDULER_HOME ) {
   Use-JobSchedulerMaster -InstallPath $env:SCHEDULER_HOME
} elseif ( $env:SCHEDULER_ID ) {
   Use-JobSchedulerMaster -Id $env:SCHEDULER_ID
}

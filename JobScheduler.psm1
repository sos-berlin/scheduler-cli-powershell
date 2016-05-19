<#
.SYNOPSIS
JobScheduler command line interface

For further information see about_JobScheduler
If the documentation is not avaiable for your language then consider to use

    PS C:\> [System.Threading.Thread]::CurrentThread.CurrentUICulture = 'en-US'
#>

# ----------------------------------------------------------------------
# Globals
# ----------------------------------------------------------------------

# JobScheduler Master object
$js = $null

# Debug messages exceeding the max. output size are stored in temporary files
$jsDebugMaxOutputSize = 1000

[int] $jsTCPReadDelay = 100
[int] $jsTCPWriteDelay = 100

# Socket, Stream, Writer for TCP connection
$jsSocket = $null
$jsStream = $null
$jsWriter = $null

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

function Approve-JobSchedulerCommand( $command )
{
    if ( !$js.Local )
    {
        $localCommands = @( 'Install-JobSchedulerService', 'Remove-JobSchedulerService', 'Start-JobSchedulerMaster', 'Stop-JobSchedulerMaster' )
        if ( $localCommands -contains $command.Name )
        {
            throw "$($command.Name): command not available for remote JobScheduler. Switch instance with the Use-JobSchedulerMaster command"
        }
    }
}

function Create-JSObject()
{
    $js = New-Object PSObject
    $jsInstall = New-Object PSObject
    $jsConfig = New-Object PSObject
    $jsService = New-Object PSObject
    
    $js | Add-Member -Membertype NoteProperty -Name Id -Value ""
    $js | Add-Member -Membertype NoteProperty -Name Url -Value ""
    $js | Add-Member -Membertype NoteProperty -Name Local -Value $false

    $jsInstall | Add-Member -Membertype NoteProperty -Name Directory -Value ""
    $jsInstall | Add-Member -Membertype NoteProperty -Name ExecutableFile -Value ""
    $jsInstall | Add-Member -Membertype NoteProperty -Name Params -Value ""
    $jsInstall | Add-Member -Membertype NoteProperty -Name StartParams -Value ""
    $jsInstall | Add-Member -Membertype NoteProperty -Name ClusterOptions -Value ""
    $jsInstall | Add-Member -Membertype NoteProperty -Name PidFile -Value 0

    $jsConfig | Add-Member -Membertype NoteProperty -Name Directory -Value ""
    $jsConfig | Add-Member -Membertype NoteProperty -Name FactoryIni -Value ""
    $jsConfig | Add-Member -Membertype NoteProperty -Name SosIni -Value ""
    $jsConfig | Add-Member -Membertype NoteProperty -Name SchedulerXml -Value 0

    $jsService | Add-Member -Membertype NoteProperty -Name ServiceName -Value ""
    $jsService | Add-Member -Membertype NoteProperty -Name ServiceDisplayName -Value ""
    $jsService | Add-Member -Membertype NoteProperty -Name ServiceDescription -Value ""

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

    $state | Add-Member -Membertype NoteProperty -Name Id -Value ""
    $state | Add-Member -Membertype NoteProperty -Name Hostname -Value ""
    $state | Add-Member -Membertype NoteProperty -Name Port -Value 0

    $state | Add-Member -Membertype NoteProperty -Name Version -Value ""
    $state | Add-Member -Membertype NoteProperty -Name State -Value ""
    $state | Add-Member -Membertype NoteProperty -Name Pid -Value 0
    $state | Add-Member -Membertype NoteProperty -Name RunningSince -Value ""

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

    $calAtOrder | Add-Member -Membertype NoteProperty -Name JobChain -Value ""
    $calAtOrder | Add-Member -Membertype NoteProperty -Name OrderId -Value ""
    $calAtOrder | Add-Member -Membertype NoteProperty -Name StartAt -Value ""
    
    $calAtOrder
}

function Create-CalendarPeriodOrderObject()
{
    $calPeriodOrder = New-Object PSObject

    $calPeriodOrder | Add-Member -Membertype NoteProperty -Name JobChain -Value ""
    $calPeriodOrder | Add-Member -Membertype NoteProperty -Name OrderId -Value ""
    $calPeriodOrder | Add-Member -Membertype NoteProperty -Name BeginAt -Value ""
    $calPeriodOrder | Add-Member -Membertype NoteProperty -Name EndAt -Value ""
    $calPeriodOrder | Add-Member -Membertype NoteProperty -Name Repeat -Value ""
    $calPeriodOrder | Add-Member -Membertype NoteProperty -Name AbsoluteRepeat -Value ""
    
    $calPeriodOrder
}

function Create-CalendarPeriodJobObject()
{
    $calPeriodJob = New-Object PSObject

    $calPeriodJob | Add-Member -Membertype NoteProperty -Name Job -Value ""
    $calPeriodJob | Add-Member -Membertype NoteProperty -Name BeginAt -Value ""
    $calPeriodJob | Add-Member -Membertype NoteProperty -Name EndAt -Value ""
    $calPeriodJob | Add-Member -Membertype NoteProperty -Name Repeat -Value ""
    $calPeriodJob | Add-Member -Membertype NoteProperty -Name AbsoluteRepeat -Value ""
    
    $calPeriodJob
}

function Create-JobChainObject()
{
    $jobChain = New-Object PSObject

    $jobChain | Add-Member -Membertype NoteProperty -Name JobChain -Value ""
    $jobChain | Add-Member -Membertype NoteProperty -Name Path -Value ""
    $jobChain | Add-Member -Membertype NoteProperty -Name Directory -Value ""
    $jobChain | Add-Member -Membertype NoteProperty -Name State -Value ""
    $jobChain | Add-Member -Membertype NoteProperty -Name Title -Value ""
    $jobChain | Add-Member -Membertype NoteProperty -Name Orders -Value 0
    $jobChain | Add-Member -Membertype NoteProperty -Name RunningOrders -Value 0

    $jobChain
}

function Create-OrderObject()
{
    $order = New-Object PSObject

    $order | Add-Member -Membertype NoteProperty -Name Order -Value ""
    $order | Add-Member -Membertype NoteProperty -Name Name -Value ""
    $order | Add-Member -Membertype NoteProperty -Name Path -Value ""
    $order | Add-Member -Membertype NoteProperty -Name Directory -Value ""
    $order | Add-Member -Membertype NoteProperty -Name JobChain -Value ""
    $order | Add-Member -Membertype NoteProperty -Name State -Value ""
    $order | Add-Member -Membertype NoteProperty -Name Title -Value ""
    $order | Add-Member -Membertype NoteProperty -Name LogFile -Value ""
    $order | Add-Member -Membertype NoteProperty -Name Job -Value ""
    $order | Add-Member -Membertype NoteProperty -Name NextStartTime -Value ""
    $order | Add-Member -Membertype NoteProperty -Name StateText -Value ""

    $order
}

function Create-JobObject()
{
    $job = New-Object PSObject

    $job | Add-Member -Membertype NoteProperty -Name Job -Value ""
    $job | Add-Member -Membertype NoteProperty -Name Path -Value ""
    $job | Add-Member -Membertype NoteProperty -Name Directory -Value ""
    $job | Add-Member -Membertype NoteProperty -Name State -Value ""
    $job | Add-Member -Membertype NoteProperty -Name Title -Value ""
    $job | Add-Member -Membertype NoteProperty -Name LogFile -Value ""
    $job | Add-Member -Membertype NoteProperty -Name Tasks -Value ""
    $job | Add-Member -Membertype NoteProperty -Name IsOrder -Value ""
    $job | Add-Member -Membertype NoteProperty -Name ProcessClass -Value ""
    $job | Add-Member -Membertype NoteProperty -Name NextStartTime -Value ""
    $job | Add-Member -Membertype NoteProperty -Name StateText -Value ""

    $job
}

function Create-TaskObject()
{
    $task = New-Object PSObject

    $task | Add-Member -Membertype NoteProperty -Name Task -Value 0
    $task | Add-Member -Membertype NoteProperty -Name Job -Value ""
    $task | Add-Member -Membertype NoteProperty -Name State -Value ""
    $task | Add-Member -Membertype NoteProperty -Name LogFile -Value ""
    $task | Add-Member -Membertype NoteProperty -Name Steps -Value ""
    $task | Add-Member -Membertype NoteProperty -Name EnqueuedAt -Value ""
    $task | Add-Member -Membertype NoteProperty -Name StartAt -Value ""
    $task | Add-Member -Membertype NoteProperty -Name RunningSince -Value ""
    $task | Add-Member -Membertype NoteProperty -Name Cause -Value ""

    # $taskDefaultProperties = @("Task", "Job")
    # $taskDefaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet( "DefaultDisplayPropertySet", [string[]] $taskDefaultProperties )
    # $taskPSStandardMembers = [System.Management.Automation.PSMemberInfo[]] @( $taskDefaultDisplayPropertySet )
    # $task | Add-Member MemberSet PSStandardMembers $taskPSStandardMembers
    
    $task
}

# send XML command to JobScheduler
function Send-JobSchedulerXMLCommand( [string] $jobSchedulerURL, $command, [bool] $checkResponse=$true ) 
{
    [string] $output = ""

	$request = $null
	$requestStream = $null

	$response = $null
	$responseStream = $null
	$streamReader = $null

	try
	{     
		$request = [System.Net.WebRequest]::Create( $jobSchedulerURL )
 
		$request.Method = "POST"
		$request.ContentType = "text/xml"
		$request.UseDefaultCredentials = $true
		$bytes = [System.Text.Encoding]::ASCII.GetBytes( $command )
		$request.ContentLength = $bytes.Length
		$requestStream = $request.GetRequestStream()
		$requestStream.Write( $bytes, 0, $bytes.Length )
 
		$requestStream.Close()
		$response = $request.GetResponse()

		Write-Debug "status code: $($response.StatusCode)"

		$responseStream = $response.getResponseStream() 
		$streamReader = new-object System.IO.StreamReader $responseStream
		$output = $streamReader.ReadToEnd()		

		if ( $checkResponse -and $output )
		{
			if ( $DebugPreference -eq 'Continue' )
			{
				if ( $output.Length -gt $jsDebugMaxOutputSize )
				{
					$tempFile = [IO.Path]::GetTempFileName()
					$output | Out-File $tempFile -encoding ascii
					Write-Debug ".. $($MyInvocation.MyCommand.Name): XML response available with temporary file: $($tempFile)"
				} else {
					Write-Debug ".. $($MyInvocation.MyCommand.Name): response: $($output)"
				}
			}

			$errorText = Select-XML -Content $output -Xpath "/spooler/answer/ERROR/@text"
			if ( $errorText.Node."#text" )
			{
				throw $errorText.Node."#text"
			}

			[xml] $output
		}
	} catch {
		throw $_.Exception
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
		
# send XML command to JobScheduler
function _Send-JobSchedulerXMLCommand( $remoteHost, $remotePort, $command, [bool] $checkResponse=$true ) 
{
    [bool] $useSSL = $false
    [string] $output = ""

	try
	{    
		if ( !$SCRIPT:jsSocket )
		{
			$SCRIPT:jsSocket = new-object System.Net.Sockets.TcpClient( $remoteHost, $remotePort )
		}
		
		if ( !$SCRIPT:jsStream )
		{
			$SCRIPT:jsStream = $SCRIPT:jsSocket.GetStream() 
		}
		
		if($useSSL) 
		{ 
			$sslStream = New-Object System.Net.Security.SslStream $SCRIPT:jsStream,$false 
			$sslStream.AuthenticateAsClient( $remoteHost )
			$SCRIPT:jsStream = $sslStream 
		}
	
		if ( !$SCRIPT:jsWriter )
		{
			$SCRIPT:jsWriter = new-object System.IO.StreamWriter $SCRIPT:jsStream
		}

		while($true) 
		{ 
			$SCRIPT:jsWriter.WriteLine( $command )
			$SCRIPT:jsWriter.Flush() 
			Start-Sleep -m $jsTCPWriteDelay
			$output += Get-JobSchedulerResponse

			break 
		}
	} catch {
		if ( $SCRIPT:jsWriter )
		{
			$SCRIPT:jsWriter.Close()
			$SCRIPT:jsWriter = $null
		}
		
		if ( $SCRIPT:jsStream )
		{
			$SCRIPT:jsStream.Close()
			$SCRIPT:jsStream = $null
		}
		
		$SCRIPT:jsSocket = $null
		throw $_.Exception
	}

    if ( $checkResponse -and $output )
    {
        if ( $DebugPreference -eq 'Continue' )
        {
            if ( $output.Length -gt $jsDebugMaxOutputSize )
            {
                $tempFile = [IO.Path]::GetTempFileName()
                $output | Out-File $tempFile -encoding ascii
                Write-Debug ".. $($MyInvocation.MyCommand.Name): XML response available with temporary file: $($tempFile)"
            } else {
                Write-Debug ".. $($MyInvocation.MyCommand.Name): response: $($output)"
            }
        }

        $errorText = Select-XML -Content $output -Xpath "/spooler/answer/ERROR/@text"
        if ( $errorText.Node."#text" )
        {
            throw $errorText.Node."#text"
        }

        [xml] $output
    }
}

# Receive response from JobScheduler
function Get-JobSchedulerResponse
{
    ## Create a buffer to receive the response 
    $buffer = new-object System.Byte[] 1024 
    $encoding = new-object System.Text.AsciiEncoding

    $outputBuffer = "" 
    $foundMore = $false

    ## Read all the data available from the stream, writing it to the 
    ## output buffer when done. 
    do 
    { 
        ## Allow data to buffer for a bit 
         Start-Sleep -m $jsTCPReadDelay

        ## Read what data is available 
        $foundmore = $false 
        $SCRIPT:jsStream.ReadTimeout = 1000

        do 
        { 
            try 
            { 
                $read = $SCRIPT:jsStream.Read($buffer, 0, 1024)

                if($read -gt 0) 
                { 
                    $foundmore = $true 
                    $outputBuffer += ($encoding.GetString($buffer, 0, $read)) 
                } 
            } catch { $foundMore = $false; $read = 0 } 
        } while( $read -gt 0 )
    } while( $foundmore )

    # remove trailing null bytes
    while ($outputBuffer[$outputBuffer.Length-1] -eq 0x00)
    {
        $outputBuffer = $outputBuffer.Substring( 0, $outputBuffer.Length-1 )
    }
    
    $outputBuffer
}

# check JobScheduler response for errors and return error message
function Get-JobSchedulerResponseError( $response )
{
    if ( $response )
    {
        $errorText = Select-XML -Content $response -Xpath "//ERROR/@text"
        if ( $errorText.Node."#text" )
        {
            $errorText.Node."#text"
        }
    }
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
    ## The path to the script to run
    [Parameter(Mandatory = $true)]
    [string] $Path,

    ## The arguments to the script
    [string] $ArgumentList
)

    #Set-StrictMode -Version 3

    $tempFile = [IO.Path]::GetTempFileName()

    ## Store the output of cmd.exe.  We also ask cmd.exe to output
    ## the environment table after the batch file completes
    cmd /c " `"$Path`" $argumentList && set > `"$tempFile`" "

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

if ( $env:SCHEDULER_HOME )
{
   Use-JobSchedulerMaster -InstallPath $env:SCHEDULER_HOME
} elseif ( $env:SCHEDULER_ID -and $env:SCHEDULER_URL ) {
   Use-JobSchedulerMaster -Id $env:SCHEDULER_ID -Url $env:SCHEDULER_URL -Remote
}

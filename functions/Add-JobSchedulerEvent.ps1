function Add-JobSchedulerEvent
{
<#
.SYNOPSIS
Adds an event to a JobScheduler instance.

.DESCRIPTION
Events can be added to a JobScheduler Master or Supervisor instance that implements event handling.

Should the JobScheduler Master or Supervisor not be accessible then events are stored in 
the local file %TEMP%\jobscheduler_events.xml for later dequeueing. Subsequent calls to this
cmdlet will dequeue any previously stored events.

.PARAMETER EventClass
Specifies a common name for a set of events that enable event handlers to process multiple events of the
same class. For example, "daily_closing" could be an event class for jobs that should start once day-time
business processes have drawn to a close.

Specifies a unique identifier when used together with the -EventId parameter.

.PARAMETER EventId
An identifier for an event. Allows event handlers to react to events having a particular ID.

Specifies a unique identifier when used together with the -EventClass parameter. An event id is required to be unique 
for the same event class.

.PARAMETER ExitCode
Specifies the exit code that is added to the event. Usually this signals the execution status of a job, 
however, you can assign a specific numeric exit code.

Without this parameter being used the $LastExitCode is implicitely assumed, i.e. the last exit code
that was provided from a command or program.

Consider that exit codes other than 0 signal failed execution. You can specify allowed exit codes
with the -AllowedExitCodes parameter.

Default: last script exit code or failed execution of previous command.

.PARAMETER AllowedExitCodes
Specifies a list of exit codes that signal that a job is considered as having run successfully. 
This is useful if job scripts provide return values in the form of exit codes and these codes
should not be considered as errors. When adding an event then any exit codes that match one of the
allowed exit codes are set to 0.

A range of allowed exit codes is specified by e.g -AllowedExitCodes 1..4 or -AllowedExitCodes 1,2,3,4.

.PARAMETER Job
Specifies the name of the job that is assigned to the event.

Default: the current job name if the cmdlet is used by a job.

.PARAMETER JobChain
Specifies the name of the job chain that is assigned to the event.

Default: the current job chain name if the cmdlet is used by a job chain.

.PARAMETER Order
Specifies the identifier of the order assigned to the event.

Default: the current order identification (order id) if the cmdlet is used by a job chain.

.PARAMETER MasterUrl
Specifies the Job Scheduler Master instance URL.

The URL consists of the protocol, host name and port, e.g. http://localhost:4454.

Default: If used with a job then the CLI will assign by default the JobScheduler Master that the job is running for
otherwise the JobScheduler Master as specified with the Use-Master cmdlet will be used.

.PARAMETER SupervisorUrl
Specifies a Job Scheduler Supervisor instance URL.

Job Scheduler Master instances register with a JobScheduler Supervisor (if configured to do so)
in order to synchronize job configurations. The Supervisor instance receives events, executes the
event handler and starts jobs and job chains for registered JobScheduler Master instances.

The URL consists of the protocol, host name and port, e.g. http://localhost:4454.

Default: If used with a job then the CLI will assign by default the JobScheduler Supervisor that the 
current JobScheduler Master is registered for and otherwise assign the JobScheduler Master.

.PARAMETER SupervisorJobChain
Specifies the path of the job chain in the JobScheduler Master or Supervisor instance that implements the event
processor. 

Default: /sos/events/scheduler_event_service

.PARAMETER ExpirationDate
Specifies the point in time for which an event automatically expires: this parameter is considered by the
Event Processor. A specific point in time can be specified by use of the ISO date format, i.e. yyyy-MM-dd HH:mm:ss.
The value 'never' ensures that the event does not ever expire. 

The parameters -ExpirationDate, -ExpirationCycle, -ExpirationPeriod, -NoExpiration may not be used at the same time.

Default: 00:00 on the following day.

.PARAMETER ExpirationCycle
Specifies the time for which the event will expire in the current period.
Periods start at 00:00 and end at 24:00. An expiration cycle of 21:00 
specifies 9pm of the current cycle for event expiration.

Values are specified by use of the format HH:mm:ss.

The parameters -ExpirationDate, -ExpirationCycle, -ExpirationPeriod, -NoExpiration may not be used at the same time.

.PARAMETER ExpirationPeriod
Specifies the duration after which the event will expire in the current period.
Periods start at 00:00 and end at 24:00. An expiration period of 04:00 
specifies that the event will expire 4 hours starting from the current point in time.

Values are specified by use of the format HH:mm:ss.

The parameters -ExpirationDate, -ExpirationCycle, -ExpirationPeriod, -NoExpiration may not be used at the same time.

.PARAMETER NoExpiration
Specifies that an event will not expire. Such events have to be removed by event action scripts.

.PARAMETER Parameters
Allows additional parameters for event handlers to be specified. Parameters are created using name-value
pairs from a hashmap as e.g. @\{'name1'='value1'; 'name2'='value2'\}.

Parameter names can be freely chosen and event handlers configured to
take account of values handed over. Any number of parameters can be added.

.OUTPUTS
This cmdlet returns the XML object of the JobScheduler response.

.EXAMPLE
Add-Event -EventClass daily_closing -EventId 12345678

Creates an event with the specified event class and event id.

.EXAMPLE
Add-Event -EventClass daily_closing -EventId 12345678 -AllowedExitCodes 1..4

Creates an event with the specified event class and event id. The exit code is implicitely added
from the global $LastExitCode value. Should the exit code be contained in the list of 
allowed exit codes then its value is set to 0.

.EXAMPLE
Add-Event -EventClass daily_closing -EventId 12345678 -ExpirationPeriod 04:00

Creates an event that will expire 4 hrs. from now.

.EXAMPLE
Add-Event -EventClass daily_closing -EventId 12345678 -ExpirationCycle 21:00

Creates an event that will expire at 9pm of the current day.

.EXAMPLE
Add-Event -EventClass daily_closing -EventId 12345678 -ExpirationDate (Get-Date).AddDays(2)

Creates an event that will expire two days later.

.EXAMPLE
Add-Event -EventClass daily_closing -EventId 12345678 -Parameters @\{'name1'='value1'; 'name2'='value2'\}

Creates an event with two additional parameters from a hashtable.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EventClass,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EventId,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $ExitCode,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int[]] $AllowedExitCodes,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Order,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $MasterUrl,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $SupervisorUrl,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $SupervisorJobChain = '/sos/events/scheduler_event_service',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [DateTime] $ExpirationDate,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ExpirationCycle,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ExpirationPeriod,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NoExpiration,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Parameters
)

    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch
        
        $tmpEventsLocation = "$env:TEMP/jobscheduler.events.xml"

        if ( Test-Path $tmpEventsLocation -PathType Leaf )
        {
            [xml] $xmlDoc = Get-Content $tmpEventsLocation
            $commandsNode = $xmlDoc.commands
            $eventCount = $xmlDoc.commands.SelectNodes( 'add_order' ).count
            Write-Warning ".. $($MyInvocation.MyCommand.Name): found $($eventCount) enqueued events, events are processed for dequeueing"
        } else {
            [xml] $xmlDoc  = "<?xml version='1.0' encoding='ISO-8859-1'?><commands/>"
            $commandsNode = $xmlDoc.CreateElement( 'commands' )
            $eventCount = 0
        }
        
        $countArgs = 0
        
        if ( $ExpirationDate )
        {
            $countArgs++
        }

        if ( $ExpirationCycle )
        {
            $countArgs++
        }
        
        if ( $ExpirationPeriod )
        {
            $countArgs++
        }

        if ( $NoExpiration )
        {
            $countArgs++
        }

        if ( $countArgs -gt 1 )
        {
            throw "$($MyInvocation.MyCommand.Name): only one of the parameters -ExpirationDate, -ExpirationCycle, -ExpirationPeriod, -NoExpiration can be specified"
        }        
    }

    Process
    {
        if ( !$MasterUrl )
        {
            $MasterUrl = $SCRIPT:js.Url
        }

        # exit code was not assigned
        if ( !$ExitCode -and $ExitCode -ne 0 )
        {
            # last exit code provided from a command or program
            $ExitCode = $LastExitCode
            
            # last failed execution
            if ( !$ExitCode -and !$? )
            {
                $ExitCode = 1
            }
        }
        
        if ( !$EventId )
        {
            $EventId = $ExitCode
        }
        
        if ( $ExitCode )
        {
            if ( $AllowedExitCodes -contains $ExitCode )
            {
               $ExitCode = 0
            }
        }
        
        if ( $SCRIPT:jsOperations )
        {
            if ( !$Job )
            {
                $Job = $spooler_job.name()
            }
            
            if ( $spooler_task.order() )
            {
                if ( !$JobChain )
                {
                    $JobChain = $spooler_task.order().job_chain().name()
                }
                
                if ( !$Order )
                {
                    $Order = $spooler_task.order().id()
                }
            }

            if ( !$SupervisorUrl )
            {
                if ( $spooler.supervisor_client() )
                {
                    $SupervisorUrl = "http://$($spooler.supervisor_client().hostname()):$($spooler.supervisor_client.tcp_port())"
                } else {
                    $SupervisorUrl = $MasterUrl
                }
            }
        } else {
            if ( !$Job )
            {
                $Job = $env:SCHEDULER_JOB_NAME
            }
            
            if ( $env:SCHEDULER_ORDER_ID )
            {
                if ( !$JobChain )
                {
                    $JobChain = $env:SCHEDULER_JOB_CHAIN
                }
                
                if ( !$Order )
                {
                    $Order = $env:SCHEDULER_ORDER_ID
                }
            }
            
            if ( !$SupervisorUrl )
            {
                $SupervisorUrl = $MasterUrl
            }
        }
        
        $currentDate = Get-Date

        $orderNode = $xmlDoc.CreateElement( 'add_order' )
        $orderNode.SetAttribute( 'job_chain', $SupervisorJobChain )
        
        $paramsNode = $xmlDoc.CreateElement( 'params' )
                
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'action' -Value 'add' ) ) | Out-Null
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'remote_scheduler_host' -Value $MasterUrl.Host ) ) | Out-Null
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'remote_scheduler_port' -Value $MasterUrl.Port ) ) | Out-Null
    
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'job_chain' -Value $JobChain ) ) | Out-Null
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'order_id' -Value $Order ) ) | Out-Null
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'job_name' -Value $Job ) ) | Out-Null
        
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'event_class' -Value $EventClass ) ) | Out-Null
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'event_id' -Value $EventId ) ) | Out-Null
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'exit_code' -Value $ExitCode ) ) | Out-Null
    
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'created' -Value ( Get-Date $currentDate -Format 'yyyy-MM-dd HH:mm:ss' ) ) ) | Out-Null
    
        if ( $ExpirationDate )
        {
           $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'expires' -Value ( Get-Date $ExpirationDate -Format 'yyyy-MM-dd HH:mm:ss' ) ) ) | Out-Null
        } elseif ( $NoExpiration ) {
           $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'expires' -Value 'never' ) ) | Out-Null
        } elseif ( $ExpirationCycle ) {
            $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'expiration_cycle' -Value $ExpirationCycle ) ) | Out-Null
        } elseif ( $ExpirationPeriod ) {
            $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'expiration_period' -Value $ExpirationPeriod ) ) | Out-Null
        }
        
        if ( $Parameters )
        {
            $Parameters.Keys | % { 
                $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name $_ -Value $Parameters.Item($_) ) ) | Out-Null
            }
        }
        
        $orderNode.AppendChild( $paramsNode ) | Out-Null
        $commandsNode.AppendChild( $orderNode ) | Out-Null

        $e = Create-EventObject
        $e.EventClass = $EventClass
        $e.EventId = $EventId
        $e.ExitCode = $ExitCode
        $e.Job = $Job
        $e.Order = $Order
        $e.JobChain = $JobChain
        $e.ExpirationDate = $ExpirationDate
        $e.ExpirationCycle = $ExpirationCycle
        $e.ExpirationPeriod = $ExpirationPeriod
        $e.Created = Get-Date $currentDate -Format 'yyyy-MM-dd HH:mm:ss'
        $e.MasterUrl = $MasterUrl

        $e
        $eventCount++
    }
    
    End
    {
        $xmlDoc.RemoveAll()
        $xmlDecl = $xmlDoc.CreateXmlDeclaration( '1.0', 'ISO-8859-1', $null )
        $xmlDoc.InsertBefore( $xmlDecl, $xmlDoc.DocumentElement ) | Out-Null
        $xmlDoc.AppendChild( $commandsNode ) | Out-Null

        if ( $eventCount )
        {
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($SupervisorUrl)"
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command: $($xmlDoc.outerxml)"
            try 
            {
                $response = Send-JobSchedulerXMLCommand $SupervisorUrl $xmlDoc.outerxml
                
                if ( Test-Path $tmpEventsLocation -PathType Leaf )
                {
                    Remove-Item $tmpEventsLocation -Force
                }
                
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($eventCount) events added"                
            } catch {
                $xmlDoc.Save( $tmpEventsLocation ) 
                Write-Warning ".. $($MyInvocation.MyCommand.Name): could not forward $($eventCount) events to $($SupervisorUrl), events are stored for later dequeueing in $($tmpEventsLocation)"
            }
        } else {
            Write-Warning "$($MyInvocation.MyCommand.Name): no events found to add"
        }
        
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch        
    }
}

Set-Alias -Name Add-Event -Value Add-JobSchedulerEvent

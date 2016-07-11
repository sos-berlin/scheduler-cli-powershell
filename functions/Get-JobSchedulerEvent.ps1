function Get-JobSchedulerEvent
{
<#
.SYNOPSIS
Retrieves events from a JobScheduler instance.

.DESCRIPTION
Events can be retrieved from a JobScheduler instance by specifying the event class
and optionally the event id.

.PARAMETER EventClass
Specifies a common name for a set of events that enable event handlers to process multiple events of the
same event class. For example, "daily_closing" could be an event class for jobs that should start once day-time
business processes have drawn to a close.

Specifies a unique identifier when used together with the -EventId parameter. Can, for example, be used to remove
events, e.g. remove all events of a particular event class.

.PARAMETER EventId
An identifier for an event. Allows event handlers to react to events having a particular ID.

Specifies a unique identifier when used together with the -EventClass parameter. An event id is required to be unique 
for the same event class.

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

Default: If used with a job then the CLI will by default assign the JobScheduler Supervisor that the 
current JobScheduler Master is registered for and otherwise assign the JobScheduler Master.

.PARAMETER SupervisorJobChain
Specifies the path of the job chain in the JobScheduler Master or Supervisor instance that implements the event
processor. 

Default: /sos/events/scheduler_event_service

.PARAMETER XPath
All events corresponding to the XPath expression specified when this parameter is set. Complex expressions
are possible and any attributes of an event can be addressed. This parameter allows complex queries to
be made, that would not be possible with the -EventClass, -EventId and -ExitCode parameters.

.OUTPUTS
This cmdlet returns the event objects available with a JobScheduler Master or Supervisor.

.EXAMPLE
$event = Get-JobSchedulerEvent -EventClass daily_closing -EventId 12345678

Returns an event object from the event class and event id.

.EXAMPLE
$events = Get-JobSchedulerEvent -EventClass daily_closing

Returns an array of event objects for the specified event class.

.EXAMPLE
Get-JobSchedulerEvent -Xpath "//events/event[starts-with(@event_id, 'my')]"

Returns a number of event objects that are assigned an event id starting with the characters 'my'.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EventClass,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EventId,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $ExitCode = 0,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $MasterUrl,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $SupervisorUrl,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $SupervisorJobChain = '/sos/events/scheduler_event_service',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $XPath
)

    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        
        if ( $XPath -and ( $EventClass -or $EventId ) )
        {
            throw "$($MyInvocation.MyCommand.Name): only one of the parameters -EventClass, -EventId, -XPath can be specified"
        }
                
        $eventCount = 0
    }

    Process
    {
        if ( !$MasterUrl )
        {
            $MasterUrl = $SCRIPT:js.Url
        }
            
        if ( $SCRIPT:jsOperations )
        {
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
            if ( !$SupervisorUrl )
            {
                $SupervisorUrl = $MasterUrl
            }
        }
    
        [xml] $xmlDoc  = "<?xml version='1.0' encoding='ISO-8859-1'?><params.get name='JobSchedulerEventJob.events'/>"
        
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($SupervisorUrl)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command: $($xmlDoc.outerxml)"
        
        $responseXml = Send-JobSchedulerXMLCommand $SupervisorUrl $xmlDoc.outerxml
        $responseNode = Select-XML -XML $responseXml -XPath "//param[@name='JobSchedulerEventJob.events']/@value"
        
        if ( $responseNode )
        {        
            if ( !$XPath )
            {
                $XPath = '//events/event'
                $cond = ''
                $and = ''
                
                if ( $EventClass )
                {
                    $cond += "$($and) @event_class='$($EventClass)'"
                    $and = 'and'
                }
                
                if ( $EventId )
                {
                    $cond += " $($and) @event_id='$($EventId)'"
                    $and = 'and'
                }
        
                if ( $ExitCode )
                {
                    $cond += " $($and) @exit_code='$($ExitCode)'"
                    $and = 'and'
                }
                
                if ( $cond )
                {
                    $XPath += "[$($cond)]"
                }
            }

            $eventsXml = $responseNode.Node.value.Replace( 0xfe -as [char], '<' ).Replace( 0xff -as [char], '>' )
            
            Write-Debug ".. $($MyInvocation.MyCommand.Name): using events document: $($eventsXml)"
            Write-Debug ".. $($MyInvocation.MyCommand.Name): using XPath: $($XPath)"
            $eventNodes = Select-XML -Content $eventsXml -XPath $XPath
                
            if ( $eventNodes )
            {    
                foreach( $eventNode in $eventNodes )
                {
                    if ( !$eventNode.Node.event_class )
                    {
                        continue
                    }
            
                    $e = Create-EventObject
                    $e.EventClass = $eventNode.Node.event_class
                    $e.EventId = $eventNode.Node.event_id
                    $e.ExitCode = $eventNode.Node.exit_code
                    $e.Job = $eventNode.Node.job_name
                    $e.Order = $eventNode.Node.order_id
                    $e.JobChain = $eventNode.Node.job_chain
                    $e.ExpirationDate = $eventNode.Node.expires
                    $e.Created = $eventNode.Node.created
                    $e.MasterUrl = "http://$($eventNode.Node.remote_scheduler_host):$($eventNode.Node.remote_scheduler_port)"
                    
                    $e
                    $eventCount++
                }
            }
        }
    }
        
    End
    {
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): $eventCount events found"
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

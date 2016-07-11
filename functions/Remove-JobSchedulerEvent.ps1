function Remove-JobSchedulerEvent
{
<#
.SYNOPSIS
Removes a number of events from a JobScheduler instance.

.DESCRIPTION
Events that have previously been added can be removed from a JobScheduler instance.

If events are processed by a JobScheduler Supervisor then the same instance
has to be addressed for removal of events.

.PARAMETER EventClass
Specifies a common name for a set of events enabling event handlers to process multiple events of the
same class. For example, "daily_closing" could be an event class for jobs that should start once day-time
business processes have drawn to a close.

Specifies a unique identifier when used together with the -EventId parameter. Can be used to remove
all events of a particular event class.

.PARAMETER EventId
An identifier for an event. Allows event handlers to react to events having a particular identifier.

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

Default: If used with a job then the CLI will assign by default the JobScheduler Supervisor that the 
current JobScheduler Master is registered for and otherwise assign the JobScheduler Master.

.PARAMETER SupervisorJobChain
Specifies the path of the job chain in the JobScheduler Master or Supervisor instance that implements the event
processor. 

Default: /sos/events/scheduler_event_service

.OUTPUTS
This cmdlet returns the XML object of the JobScheduler response.

.EXAMPLE
Remove-JobSchedulerEvent -EventClass daily_closing -EventId 12345678

Removes an individual event identified by its event class and event id.

.EXAMPLE
Remove-JobSchedulerEvent -EventClass daily_closing

Removes all events that are assigned the specified event class.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EventClass,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EventId,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $MasterUrl,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $SupervisorUrl,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $SupervisorJobChain = '/sos/events/scheduler_event_service'
)

    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch
        
        [xml] $xmlDoc  = "<?xml version='1.0' encoding='ISO-8859-1'?><commands/>"
        $commandsNode = $xmlDoc.CreateElement( 'commands' )

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

		$orderNode = $xmlDoc.CreateElement( 'add_order' )
        $orderNode.SetAttribute( 'job_chain', $SupervisorJobChain )
        
        $paramsNode = $xmlDoc.CreateElement( 'params' )
                
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'action' -Value 'remove' ) ) | Out-Null
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'remote_scheduler_host' -Value $MasterUrl.Host ) ) | Out-Null
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'remote_scheduler_port' -Value $MasterUrl.Port ) ) | Out-Null
    
        $paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'event_class' -Value $EventClass ) ) | Out-Null
		
		if ( $EventId )
		{
			$paramsNode.AppendChild( ( Create-ParamNode -XmlDoc $xmlDoc -Name 'event_id' -Value $EventId ) ) | Out-Null
		}
            
        $orderNode.AppendChild( $paramsNode ) | Out-Null
        $commandsNode.AppendChild( $orderNode ) | Out-Null

        $e = Create-EventObject
        $e.EventClass = $EventClass
        $e.EventId = $EventId
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
            $response = Send-JobSchedulerXMLCommand $SupervisorUrl $xmlDoc.outerxml
            
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($eventCount) events removed"                
        } else {
            Write-Warning "$($MyInvocation.MyCommand.Name): no events found to remove"
        }
        
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch                
    }
}

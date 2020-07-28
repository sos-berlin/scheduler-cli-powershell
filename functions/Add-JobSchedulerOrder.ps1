function Add-JobSchedulerOrder
{
<#
.SYNOPSIS
Adds an order to a job chain in the JobScheduler Master.

.DESCRIPTION
Creates a temporary ad hoc order for execution with the specified job chain

.PARAMETER JobChain
Specifies the path and name of a job chain for which orders should be added.

.PARAMETER OrderId
Optionally specifies the identifier of an order.

If no order identifier is specified then JobScheduler assigns a unique identifier.

.PARAMETER Directory
Optionally specifies the folder where the job chain is located. The directory is determined
from the root folder, i.e. the "live" directory.

If the -JobChain parameter specifies the name of job chain then the location specified from the 
-Directory parameter is added to the job chain location.

.PARAMETER Parameters
Specifies the parameters for the order. Parameters are created from a hashmap,
i.e. a list of names and values.

Example:
$orderParams = @{ 'param1' = 'value1'; 'param2' = 'value2' }

.PARAMETER Title
Specifies the title of the order.

.PARAMETER At
Specifies the point in time when the order should start. Values are added like this:

* now
** specifies that the order should start immediately
* now+1800
** specifies that the order should start with a delay of 1800 seconds, i.e. 30 minutes later.
* yyyy-mm-dd HH:MM[:SS]
** specifies that the order should start at the specified point in time.

.PARAMETER Timezone
Specifies the timezone to be considered for the start time that is indicated with the -At parameeter.
Without this parameter the timezone of the JobScheduler Master is assumed. 

This parameter should be used if the JobScheduler Master runs in a timezone different to the environment 
that makes use of this cmdlet.

.PARAMETER RunTime
Optionally specifies an XML configuration for the <run_time> of an order.
This makes sense should the order be scheduled based on some rule, e.g. to start on a specific day of week.

For details of the run-time configuration see https://www.sos-berlin.com/doc/en/scheduler.doc/xml/run_time.xml

.PARAMETER State
Specifies that the order should enter the job chain at the job chain node that
is assigend the specified state.

.PARAMETER EndState
Specifies that the order should leave the job chain at the job chain node that
is assigend the specified state.

.PARAMETER AuditComment
Specifies a free text that indicates the reason for the current intervention, 
e.g. "business requirement", "maintenance window" etc.

The Audit Comment is visible from the Audit Log view of JOC Cockpit.
This parameter is not mandatory, however, JOC Cockpit can be configured 
to enforece Audit Log comments for any interventions.

.PARAMETER AuditTimeSpent
Specifies the duration in minutes that the current intervention required.

This information is visible with the Audit Log view. It can be useful when integrated
with a ticket system that logs the time spent on interventions with JobScheduler.

.PARAMETER AuditTicketLink
Specifies a URL to a ticket system that keeps track of any interventions performed for JobScheduler.

This information is visible with the Audit Log view of JOC Cockpit. 
It can be useful when integrated with a ticket system that logs interventions with JobScheduler.

.INPUTS
This cmdlet accepts pipelined order objects that are e.g. returned from a Get-JobSchedulerOrder cmdlet.

.OUTPUTS
This cmdlet returns an array of order objects.

.EXAMPLE
Add-JobSchedulerOrder -JobChain /sos/reporting/Reporting

Adds an order to the indicated job chain. The order identification is generated by the JobScheduler Master.

.EXAMPLE
1..10 | Add-JobSchedulerOrder -JobChain /sos/reporting/Reporting

Adds 10 orders to the indicated job chain.

.EXAMPLE
Add-JobSchedulerOrder -Order 123 -JobChain /sos/reporting/Reporting

Adds the order "123" to the indicated job chain.

.EXAMPLE
Add-JobSchedulerOrder -Order 123 -JobChain /sos/reporting/Reporting -At "now+1800"

Adds the indicated order for a start time 30 minutes (1800 seconds) from now.

.EXAMPLE
Add-JobSchedulerOrder -JobChain /sos/reporting/Reporting -At "now+3600" -Parameters @{'param1' = 'value1'; 'param2' = 'value2'}

Adds an order to the indicated job chain. The order will start one hour later and will use the
parameters from the indicated parameters.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OrderId,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Parameters,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Title,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $At,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Timezone,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $RunTime,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $State,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EndState,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $AuditComment,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $AuditTimeSpent,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $AuditTicketLink
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        if ( !$AuditComment -and ( $AuditTimeSpent -or $AuditTicketLink ) )
        {
            throw "Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
        }

        $objOrders = @()
    }
    
    Process
    {
        if ( $Directory -and $Directory -ne '/' )
        { 
            if ( $Directory.Substring( 0, 1) -ne '/' ) {
                $Directory = '/' + $Directory
            }
        
            if ( $Directory.Length -gt 1 -and $Directory.LastIndexOf( '/' )+1 -eq $Directory.Length )
            {
                $Directory = $Directory.Substring( 0, $Directory.Length-1 )
            }
        }
    
        if ( $JobChain )
        {
            if ( (Get-JobSchedulerObject-Basename $JobChain) -ne $JobChain ) # job chain name includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $JobChain
            } else { # job chain name includes no directory
                if ( $Directory -eq '/' )
                {
                    $JobChain = $Directory + $JobChain
                } else {
                    $JobChain = $Directory + '/' + $JobChain
                }
            }
        }
    
        if ( $OrderId )
        {
            if ( (Get-JobSchedulerObject-Basename $OrderId) -ne $OrderId ) # order id includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $OrderId
                $Order = Get-JobSchedulerObject-Basename $OrderId
                if ( $Directory -eq '/' )
                {
                    $JobChain = $Directory + (Get-JobSchedulerObject-Basename $JobChain)
                } else {
                    $JobChain = $Directory + '/' + (Get-JobSchedulerObject-Basename $JobChain)
                }
            }
        }


        $objOrder = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $objOrder

        if ( $OrderId )
        {
            Add-Member -Membertype NoteProperty -Name 'orderId' -value $OrderId -InputObject $objOrder
        }

        if ( $At )
        {
            Add-Member -Membertype NoteProperty -Name 'at' -value $At -InputObject $objOrder
        }

        if ( $Timezone )
        {
            Add-Member -Membertype NoteProperty -Name 'timezone' -value $Timezone -InputObject $objOrder
        }

        if ( $State )
        {
            Add-Member -Membertype NoteProperty -Name 'state' -value $State -InputObject $objOrder
        }

        if ( $EndState )
        {
            Add-Member -Membertype NoteProperty -Name 'endState' -value $EndState -InputObject $objOrder
        }

        if ( $Parameters )
        {
            $objParams = @()
            foreach( $parameter in $Parameters.GetEnumerator() )
            {
                $objParam = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'name' -value $parameter.key -InputObject $objParam
                Add-Member -Membertype NoteProperty -Name 'value' -value $parameter.value -InputObject $objParam
                $objParams += $objParam
            }

            Add-Member -Membertype NoteProperty -Name 'params' -value $objParams -InputObject $objOrder
        }

        if ( $Title )
        {
            Add-Member -Membertype NoteProperty -Name 'title' -value $Title -InputObject $objOrder
        }

        if ( $RunTime )
        {
            Add-Member -Membertype NoteProperty -Name 'runTime' -value $RunTime -InputObject $objOrder
        }

        $objOrders += $objOrder
    }

    End
    {
        if ( $objOrders.count )
        {
            $body = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
            Add-Member -Membertype NoteProperty -Name 'orders' -value $objOrders -InputObject $body
    
            if ( $AuditComment -or $AuditTimeSpent -or $AuditTicketLink )
            {
                $objAuditLog = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'comment' -value $AuditComment -InputObject $objAuditLog
    
                if ( $AuditTimeSpent )
                {
                    Add-Member -Membertype NoteProperty -Name 'timeSpent' -value $AuditTimeSpent -InputObject $objAuditLog
                }
    
                if ( $AuditTicketLink )
                {
                    Add-Member -Membertype NoteProperty -Name 'ticketLink' -value $AuditTicketLink -InputObject $objAuditLog
                }
    
                Add-Member -Membertype NoteProperty -Name 'auditLog' -value $objAuditLog -InputObject $body
            }
    
            [string] $requestBody = $body | ConvertTo-Json -Depth 100
            $response = Invoke-JobSchedulerWebRequest '/orders/add' $requestBody
            
            if ( $response.StatusCode -eq 200 )
            {
                $requestResult = ( $response.Content | ConvertFrom-JSON )
                
                if ( !$requestResult.ok )
                {
                    throw "could not add orders: $($requestResult.message)"
                } elseif ( !$requestResult.orders ) {
                    throw ( $response | Format-List -Force | Out-String )
                }
            } else {
                throw ( $response | Format-List -Force | Out-String )
            }
        
            $requestResult.orders

            if ( $requestResult.orders.count -ne $objOrders.count )
            {
                Write-Error "$($MyInvocation.MyCommand.Name): not all orders could be added, $($objOrders.count) orders requested, $($requestResult.orders.count) orders added"
            }
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no orders found"                
        }

        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

function Start-JobSchedulerOrder
{
<#
.SYNOPSIS
Starts an order for a job chain in the JobScheduler Master.

.DESCRIPTION
Start an existing order for a job chain.

.PARAMETER JobChain
Specifies the path and name of a job chain for which orders should be started.

.PARAMETER Order
Optionally specifies the identifier of an order.

.PARAMETER Directory
Optionally specifies the folder where the job chain is located. The directory is determined
from the root folder, i.e. the "live" directory.

If the -JobChain parameter specifies the name of job chain then the location specified from the 
-Directory parameter is added to the job chain location.

.PARAMETER Parameters
Specifies the parameters for the order. Parameters are created from a hashmap,
i.e. a list of names and values.

.PARAMETER Title
Specifies the title of the order.

.PARAMETER At
Specifies the point in time when the order should start:

* now
** specifies that the order should start immediately
* now+1800
** specifies that the order should start with a delay of 1800 seconds, i.e. 30 minutes later.
* yyyy-mm-dd HH:MM[:SS]
** specifies that the order should start at the specified point in time.

Default: now

.PARAMETER State
Specifies that the order should enter the job chain at the job chain node that
is assigend the specified state.

.PARAMETER EndState
Specifies that the order should leave the job chain at the job chain node that
is assigend the specified state.

.INPUTS
This cmdlet accepts pipelined order objects that are e.g. returned from a Get-JobSchedulerOrder cmdlet.

.OUTPUTS
This cmdlet returns an array of order objects.

.EXAMPLE
Start-JobSchedulerOrder -JobChain /sos/reporting/Reporting

Starts an order of the specified job chain.

.EXAMPLE
Start-JobSchedulerOrder -Order 123 -JobChain /sos/reporting/Reporting

Starts the order "123" of the specified job chain.

.EXAMPLE
Start-JobSchedulerOrder -Order 123 -JobChain /sos/reporting/Reporting -At "now+1800"

Starts the specified order.

.EXAMPLE
Start-JobSchedulerOrder -JobChain /sos/reporting/Reporting -Order 548 -At "now+3600" -Parameters @{'param1'='value1'; 'param2'='value2'}

Starts an order of the specified job chain. The order will start one hour later and will use the
parameters from the specified hashmap.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OrderId,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Parameters,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $At = 'now',
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
    [string] $AuditTimeSpent,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $AuditTicketLink
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch
        
        if ( $AuditComment -or $AuditTimeSpent -or $AuditTicketLink )
        {
            if ( !$AuditComment )
            {
                throw "Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
            }
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
                $OrderId = Get-JobSchedulerObject-Basename $OrderId
                if ( $Directory -eq '/' )
                {
                    $JobChain = $Directory + (Get-JobSchedulerObject-Basename $JobChain)
                } else {
                    $JobChain = $Directory + '/' + (Get-JobSchedulerObject-Basename $JobChain)
                }
            }
        }

        $objOrder = New-Object PSObject

        if ( $OrderId )
        {
            Add-Member -Membertype NoteProperty -Name 'orderId' -value $OrderId -InputObject $objOrder
        }

        Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $objOrder

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
            Add-Member -Membertype NoteProperty -Name 'params' -value $Parameters -InputObject $objOrder
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
            $response = Invoke-JobSchedulerWebRequest '/orders/start' $requestBody
            
            if ( $response.StatusCode -eq 200 )
            {
                $requestResult = ( $response.Content | ConvertFrom-JSON )
                
                if ( !$requestResult.ok )
                {
                    throw ( $response | Format-List -Force | Out-String )
                }
            } else {
                throw ( $response | Format-List -Force | Out-String )
            }
        
            $requestResult.orders
            
            if ( $requestResult.orders.count -ne $objOrders.count )
            {
                Write-Error "$($MyInvocation.MyCommand.Name): not all orders could be started, $($objOrders.count) orders requested, $($requestResult.orders.count) orders started"
            }
            
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($requestResult.orders.count) orders started"                
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no orders found"                
        }

        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

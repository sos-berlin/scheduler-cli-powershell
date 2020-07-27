function Get-JobSchedulerOrder
{
<#
.SYNOPSIS
Returns a number of active orders from the JobScheduler Master.

.DESCRIPTION
Orders are returned if they are present in the JobScheduler Master.
No ad hoc orders are returned that are completed and not active
with a Master. For information on such orders consider the Get-JobSchedulerOrderHistory cmdlet.

Orders are selected from a JobScheduler Master

* by the folder of the order location including sub-folders
* by the job chain that is assigned to an order
* by an individual order.

Resulting orders can be forwarded to other cmdlets for pipelined bulk operations.

.PARAMETER Directory
Optionally specifies the folder for which orders should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

One of the parameters -Directory, -JobChain or -Order has to be specified if no pipelined order objects are provided.

.PARAMETER JobChain
Optionally specifies the path and name of a job chain for which orders should be returned.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.
Otherwise the -JobChain parameter is assumed to include the full path and name of the job chain.

One of the parameters -Directory, -JobChain or -Order has to be specified if no pipelined order objects are provided.

.PARAMETER Order
Optionally specifies the path and name of an order that should be returned.
If the name of an order is specified then the -Directory parameter is used to determine the folder.
Otherwise the -Order parameter is assumed to include the full path and name of the order.

One of the parameters -Directory, -JobChain or -Order has to be specified if no pipelined order objects are provided.

.PARAMETER WithLog
Specifies the order log to be returned. 

This operation is time-consuming and should be restricted to selecting individual orders.

.PARAMETER Nosub-folders
Specifies that no sub-folders should be looked up. By default any sub-folders will be searched for orders.

.PARAMETER NoPermanent
Specifies that no permanent orders should be looked up but instead ad hoc orders only. 
By default only permanent orders will be looked up.

.PARAMETER Suspended
Specifies that only suspended orders should be returned.

.PARAMETER Setback
Specifies that only setback orders should be returned.

.PARAMETER NoCache
Specifies that the cache for JobScheduler objects is ignored.
This results in the fact that for each Get-JobScheduler* cmdlet execution the response is 
retrieved directly from the JobScheduler Master and is not resolved from the cache.

.OUTPUTS
This cmdlet returns an array of order objects.

.EXAMPLE
$orders = Get-JobSchedulerOrder

Returns all orders.

.EXAMPLE
$orders = Get-JobSchedulerOrder -Directory / -Nosub-folders

Returns all orders that are configured with the root folder ("live" directory)
without consideration of sub-folders.

.EXAMPLE
$orders = Get-JobSchedulerOrder -JobChain /test/globals/chain1

Returns the orders for job chain "chain1" from the folder "/test/globals".

.EXAMPLE
$orders = Get-JobSchedulerOrder -Order /test/globals/order1

Returns the order "order1" from the folder "/test/globals".

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OrderId,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Compact,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $WithHistory,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $WithLog,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $MaxLastHistoryItems = 1,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Permanent,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Temporary,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $FileOrder,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Pending,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Running,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $WaitingForResource,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Suspended,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Setback,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Blacklist
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        if ( $OrderId -and !$JobChain )
        {
            throw "Use of -OrderId parameter requires to specify the -JobChain parameter"
        }

        $volatileOrders = @()
        $returnOrders = @()
        $types = @()
        $states = @()
    }
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain, OrderId=$OrderId"
    
        if ( !$Directory -and !$JobChain -and !$Order )
        {
            throw "$($MyInvocation.MyCommand.Name): no directory, no job chain or order specified, use -Directory or -JobChain  or -OrderId"
        }

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
            } # order id includes no directory
        }

        if ( $Directory -eq '/' -and !$JobChain -and !$OrderId -and !$Recursive )
        {
            $Recursive = $true
        }
        
        if ( $WithLog )
        {
            $WithHistory = $true
        }


        if ( $Permanent )
        {
            $types += 'PERMANENT'
        }

        if ( $Temporary )
        {
            $types += 'AD_HOC'
        }

        if ( $FileOrder )
        {
            $types += 'FILE_ORDER'
        }


        if ( $Pending )
        {
            $states += 'PENDING'
        }

        if ( $Running )
        {
            $states += 'RUNNING'
        }

        if ( $WaitingForResource )
        {
            $states += 'WAITINGFORRESOURCE'
        }

        if ( $Suspended )
        {
            $states += 'SUSPENDED'
        }

        if ( $Setback )
        {
            $states += 'SETBACK'
        }

        if ( $Blacklist )
        {
            $states += 'BLACKLIST'
        }


        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

        if ( $Compact )
        {
            Add-Member -Membertype NoteProperty -Name 'compact' -value $true -InputObject $body
        }
            
        if ( $OrderId -or $JobChain )
        {
            $objOrder = New-Object PSObject

            if ( $JobChain )
            {
                Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $objOrder
            }

            if ( $OrderId )
            {
                Add-Member -Membertype NoteProperty -Name 'orderId' -value $OrderId -InputObject $objOrder
            }

            Add-Member -Membertype NoteProperty -Name 'orders' -value @( $objOrder ) -InputObject $body
        } elseif ( !$JobChain -and !$Order -and $Directory ) {
            $objFolder = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'folder' -value $Directory -InputObject $objFolder
            Add-Member -Membertype NoteProperty -Name 'recursive' -value ($Recursive -eq $true) -InputObject $objFolder

            Add-Member -Membertype NoteProperty -Name 'folders' -value @( $objFolder ) -InputObject $body
        }

        if ( $states.count -gt 0 )
        {
            Add-Member -Membertype NoteProperty -Name 'processingStates' -value $states -InputObject $body
        }

        if ( $types.count -gt 0 )
        {
            Add-Member -Membertype NoteProperty -Name 'type' -value $types -InputObject $body
        }

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest '/orders' $requestBody
        
        if ( $response.StatusCode -eq 200 )
        {
            $volatileOrders += ( $response.Content | ConvertFrom-JSON ).orders
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }
    }

    End
    {
        if ( $volatileOrders )
        {
            foreach( $volatileOrder in $volatileOrders )
            {
                $returnOrder = Create-OrderObject
                $returnOrder.OrderId = $volatileOrder.orderId
                $returnOrder.JobChain = $volatileOrder.jobChain
                $returnOrder.Path = $volatileOrder.path
                $returnOrder.Directory = Get-JobSchedulerObject-Parent $volatileOrder.path
                $returnOrder.Volatile = $volatileOrder

                if ( $volatileOrder._type -eq 'permanent' )
                {
                    # ORDER PERMANENT API
    
                    $body = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
                
                    if ( $Compact )
                    {
                        Add-Member -Membertype NoteProperty -Name 'compact' -value $true -InputObject $body
                    }
                
                    Add-Member -Membertype NoteProperty -Name 'jobChain' -value $volatileOrder.jobChain -InputObject $body
                    Add-Member -Membertype NoteProperty -Name 'orderId' -value $volatileOrder.orderId -InputObject $body
        
                    [string] $requestBody = $body | ConvertTo-Json -Depth 100
                    $response = Invoke-JobSchedulerWebRequest '/order/p' $requestBody
                    
                    if ( $response.StatusCode -eq 200 )
                    {
                        $returnOrder.Permanent = ( $response.Content | ConvertFrom-JSON ).order
                    } else {
                        throw ( $response | Format-List -Force | Out-String )
                    }
                }

                if ( $WithHistory )
                {
                    # ORDER HISTORY API
            
                    $body = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

                    $objOrder = New-Object PSObject
                    Add-Member -Membertype NoteProperty -Name 'orderId' -value $volatileOrder.orderId -InputObject $objOrder
                    Add-Member -Membertype NoteProperty -Name 'jobChain' -value $volatileOrder.jobChain -InputObject $objOrder

                    Add-Member -Membertype NoteProperty -Name 'orders' -value @( $objOrder ) -InputObject $body
                    Add-Member -Membertype NoteProperty -Name 'limit' -value $MaxLastHistoryItems -InputObject $body

                    if ( $Compact )
                    {
                        Add-Member -Membertype NoteProperty -Name 'compact' -value $true -InputObject $body
                    }
    
                    [string] $requestBody = $body | ConvertTo-Json -Depth 100
                    $response = Invoke-JobSchedulerWebRequest '/orders/history' $requestBody
            
                    if ( $response.StatusCode -eq 200 )
                    {
                        $requestHistoryEntries = ( $response.Content | ConvertFrom-JSON ).history
                        $orderHistory = @()                    
                    } else {
                        throw ( $response | Format-List -Force | Out-String )
                    }
    
                    foreach( $requestHistoryEntry in $requestHistoryEntries )
                    {
                        $order = New-Object PSObject
                        Add-Member -Membertype NoteProperty -Name 'history' -value $requestHistoryEntry -InputObject $order
    
                        if ( $WithLog )
                        {
                            # ORDER LOG API
    
                            $body = New-Object PSObject
                            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
                            Add-Member -Membertype NoteProperty -Name 'orderId' -value $requestHistoryEntry.orderId -InputObject $body
                            Add-Member -Membertype NoteProperty -Name 'jobChain' -value $requestHistoryEntry.jobChain -InputObject $body
                            Add-Member -Membertype NoteProperty -Name 'historyId' -value $requestHistoryEntry.historyId -InputObject $body
    
                            [string] $requestBody = $body | ConvertTo-Json -Depth 100
                            $response = Invoke-JobSchedulerWebRequest '/order/log' $requestBody
            
                            if ( $response.StatusCode -eq 200 )
                            {
                                Add-Member -Membertype NoteProperty -Name 'log' -value $response.Content -InputObject $order
                            } else {
                                throw ( $response | Format-List -Force | Out-String )
                            }
                        }
                        
                        $orderHistory += $order
                    }
    
                    $returnOrder.OrderHistory = $orderHistory
                }
                
                $returnOrders += $returnOrder
            }
        }

        $returnOrders

        if ( $returnOrders.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($returnOrders.count) orders found"
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no orders found"
        }
        
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

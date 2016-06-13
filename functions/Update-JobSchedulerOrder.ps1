function Update-JobSchedulerOrder
{
<#
.SYNOPSIS
Updates a number of orders in the JobScheduler Master.

.DESCRIPTION
Updating orders includes operations to suspend, resume and reset orders.

Orders are selected for update

* by a pipelined object, e.g. the output of the Get-Order cmdlet
* by specifying an individual order with the -Order and -JobChain parameters.

.PARAMETER Order
Specifies the identifier of an order.

Both parameters -Order and -JobChain have to be specified if no pipelined order objects are used.

.PARAMETER JobChain
Specifies the path and name of a job chain for which orders should be updated.

Both parameters -Order and -JobChain have to be specified if no pipelined order objects are used.

.PARAMETER Directory
Optionally specifies the folder where the job chain is located. The directory is determined
from the root folder, i.e. the "live" directory.

If the -JobChain parameter specifies the name of job chain then the location specified from the 
-Directory parameter is added to the job chain location.

.PARAMETER Action
Specifies the action to be applied to an order:

* Action "start"
** starts an order, i.e. the order will proceed the next step in a job chain.
* Action "suspend"
** Suspends an order, i.e. the order is stopped and will not continue without being resumed.
* Action "resume"
** Resumes a suspended order.
* Action "reset"
** Resets an order that will be moved to its initial state in a job chain.
* Action "end_setback"
** Ends any delays that are applied to an order for repeated execution by a setback operation.

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

This parameter is considered if -Action "start" is used.

Default: now

.PARAMETER State
Specifies that the order should enter the job chain at the job chain node that
is assigend the specified state.

.PARAMETER EndState
Specifies that the order should leave the job chain at the job chain node that
is assigend the specified state.

.INPUTS
This cmdlet accepts pipelined order objects that are e.g. returned from a Get-Order cmdlet.

.OUTPUTS
This cmdlet returns an array of updated order objects.

.EXAMPLE
Update-Order -Order Reporting -JobChain /sos/reporting/Reporting -Action suspend

Suspends the order "Reporting" from the specified job chain.

.EXAMPLE
Get-Order | Update-Order -Action reset

Resets all orders and moves them to their initial state.

.EXAMPLE
Get-Order -Directory / -NoSubfolders | Update-Order -Action resume

Updates all orders that are configured with the root folder ("live" directory)
without consideration of subfolders to be resumed.

.EXAMPLE
Get-Order -JobChain /test/globals/chain1 | Update-Order -Action end_setback

Ends any delays for repeated execution for all orders for job chain "chain1" from the folder "/test/globals".

.EXAMPLE
Update-Order -JobChain /sos/reporting/Reporting -Order 548 -Action start -Parameters @{'param1'='value1'; 'param2'='value2'}

Adds an order to the specified job chain. The order will start one hour later and will use the
parameters from the specified hashmap.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Order,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [ValidateSet('start','suspend','resume','reset','end_setback')] [string] $Action,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Parameters,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Title,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $At = 'now',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $State,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $EndState
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        $command = ""
        $orderCount = 0
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
                $JobChain = $Directory + '/' + $JobChain
            }
        }

        Write-Debug ".. $($MyInvocation.MyCommand.Name): updating order with Order='$($Order)', JobChain='$($JobChain)'"

        switch ( $Action )
        {
            'start'           { $orderAttributes = "" }
            'suspend'         { $orderAttributes = "suspended='yes'" }
            'resume'          { $orderAttributes = "suspended='no'" }
            'reset'           { $orderAttributes = "action='reset'" }
            'end_setback'     { $orderAttributes = "setback='no'" }
            default           { $orderAttributes = "" }
        }

        if ( $Title )
        {
            $orderAttributes += " title='$([System.Security.SecurityElement]::Escape($Title))'"
        }
        
        if ( $At -and $Action -eq 'start' )
        {
            $orderAttributes += " at='$($At)'"
        }
        
        if ( $State )
        {
            $orderAttributes += " state='$($State)'"
        }
        
        if ( $EndState )
        {
            $orderAttributes += " end_state='$($EndState)'"
        }

        $command += "<modify_order job_chain='$($JobChain)' order='$($Order)' $($orderAttributes)>"

        if ( $Parameters )
        {
            $command += '<params>'
            foreach ($p in $Parameters.GetEnumerator()) {
                $command += "<param name='$($p.Name)' value='$([System.Security.SecurityElement]::Escape($p.Value))'/>"
            }            
            $command += '</params>'
        }
        
        $command += "</modify_order>"
        
        $updateOrder = Create-OrderObject
        $updateOrder.Order = $Order
        $updateOrder.JobChain = Get-JobSchedulerObject-Basename $JobChain
        $updateOrder.Name = $updateOrder.JobChain + ',' + $updateOrder.Order
		$updateOrder.Directory = Get-JobSchedulerObject-Parent $JobChain
		$updateOrder.Path = $updateOrder.Directory + '/' + $updateOrder.Name
        $updateOrder.Title = $Title
        $updateOrder.State = $State
        $updateOrder.EndState = $EndState
        $updateOrder
        $orderCount++
     }

    End
    {
        if ( $orderCount )
        {
            $command = "<commands>$($command)</commands>"
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to $($js.Url): $command"        
            $orderXml = Send-JobSchedulerXMLCommand $js.Url $command
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($orderCount) orders updated"
        } else {
            Write-Warning "$($MyInvocation.MyCommand.Name): no order found"
        }

        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

Set-Alias -Name Update-Order -Value Update-JobSchedulerOrder

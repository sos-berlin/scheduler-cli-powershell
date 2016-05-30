function Remove-JobSchedulerOrder
{
<#
.SYNOPSIS
Removes a number of ad hoc orders in the JobScheduler Master.

.DESCRIPTION
Only Ad hoc orders can be removed. Such orders are not permanently stored in files
but instead have been added on-the-fly. Typically ad hoc orders are created
for one-time execution of a job chain.

Orders are selected for removal

* by a pipelined object, e.g. the output of the Get-Order cmdlet
* by specifying an individual order with the -Order and -JobChain parameters.

.PARAMETER Order
Specifies the identifier of an order.

Both parameters -Order and -JobChain have to be specified if no pipelined order objects are used.

.PARAMETER JobChain
Specifies the path and name of a job chain for which an order should be removed.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.

Both parameters -Order and -JobChain have to be specified if no pipelined order objects are used.

.PARAMETER Directory
Optionally specifies the folder where the job chain is located. The directory is determined
from the root folder, i.e. the "live" directory.

If the -JobChain parameter specifies the name of job chain then the location specified from the 
-Directory parameter is added to the job chain location.

.INPUTS
This cmdlet accepts pipelined order objects that are e.g. returned from a Get-Order cmdlet.

.OUTPUTS
This cmdlet returns an array of removed order objects.

.EXAMPLE
Remove-Order -Order 234 -JobChain sos/reporting/Reporting

Removes the order from the specified job chain.

.EXAMPLE
Get-Order -NoPermanent | Remove-Order

Retrieves and removes all ad hoc orders.

.EXAMPLE
Get-Order -Directory /sos -NoPermanent | Remove-Order

Retrieves and removes all ad hoc orders from the specified directory including subfolders.

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
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Path = '/'
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

        if ( $Path -and $Path -ne '/' )
        {
            # only ad hoc orders use the path = '/', therefore we check if a different path property is provided by a pipelined object
            throw "$($MyInvocation.MyCommand.Name): no ad hoc order specified, no removal is carried out for permanent orders"
        }

        Write-Debug ".. $($MyInvocation.MyCommand.Name): removing order with Order='$($Order)', JobChain='$($JobChain)'"

        $command += "<remove_order job_chain='$($JobChain)' order='$($Order)'/>"
        $updateOrder = Create-OrderObject
        $updateOrder.Order = $Order
        $updateOrder.JobChain = $JobChain
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
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($orderCount) orders removed"
        } else {
            Write-Warning "$($MyInvocation.MyCommand.Name): no order found"
        }

        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

Set-Alias -Name Remove-Order -Value Remove-JobSchedulerOrder

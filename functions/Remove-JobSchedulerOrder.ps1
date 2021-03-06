function Remove-JobSchedulerOrder
{
<#
.SYNOPSIS
Removes ad hoc orders in the JobScheduler Master.

.DESCRIPTION
Only Ad hoc orders can be removed. Such orders are not permanently stored in files
but instead have been added on-the-fly. Typically ad hoc orders are created
for one-time execution of a job chain.

Orders are selected for removal

* by a pipelined object, e.g. the output of the Get-JobSchedulerOrder cmdlet
* by specifying an individual order with the -OrderId and -JobChain parameters.

.PARAMETER OrderId
Specifies the identifier of an order.

Both parameters -OrderId and -JobChain have to be specified if no pipelined order objects are used.

.PARAMETER JobChain
Specifies the path and name of a job chain for which an order should be removed.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.

Both parameters -OrderId and -JobChain have to be specified if no pipelined order objects are used.

.PARAMETER Directory
Optionally specifies the folder where the job chain is located. The directory is determined
from the root folder, i.e. the "live" directory.

If the -JobChain parameter specifies the name of job chain then the location specified from the
-Directory parameter is added to the job chain location.

.PARAMETER AuditComment
Specifies a free text that indicates the reason for the current intervention, e.g. "business requirement", "maintenance window" etc.

The Audit Comment is visible from the Audit Log view of JOC Cockpit.
This parameter is not mandatory, however, JOC Cockpit can be configured to enforece Audit Log comments for any interventions.

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
This cmdlet returns an array of removed order objects.

.EXAMPLE
Remove-JobSchedulerOrder -OrderId 234 -JobChain sos/reporting/Reporting

Removes the order from the indicated job chain.

.EXAMPLE
Get-JobSchedulerOrder -Temporary | Remove-JobSchedulerOrder

Retrieves and removes all ad hoc orders.

.EXAMPLE
Get-JobSchedulerOrder -Directory /sos -Recursive | Remove-JobSchedulerOrder

Retrieves and removes all ad hoc orders from the indicated directory including any sub-folders.

.LINK
about_jobscheduler

#>
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OrderId,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
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
        $stopWatch = Start-JobSchedulerStopWatch

        if ( !$AuditComment -and ( $AuditTimeSpent -or $AuditTicketLink ) )
        {
            throw "$($MyInvocation.MyCommand.Name): Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
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

        $objOrder = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'orderId' -value $OrderId -InputObject $objOrder
        Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $objOrder

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

            if ( $PSCmdlet.ShouldProcess( '/orders/delete' ) )
            {
                [string] $requestBody = $body | ConvertTo-Json -Depth 100
                $response = Invoke-JobSchedulerWebRequest '/orders/delete' $requestBody

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

                Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($objOrders.count) orders removed"
            }
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no orders found"
        }

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

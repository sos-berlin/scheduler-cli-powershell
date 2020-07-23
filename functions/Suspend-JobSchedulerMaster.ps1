function Suspend-JobSchedulerMaster
{
<#
.SYNOPSIS
Pause JobScheduler Master, i.e. prevent any tasks from starting.
Respectively the Resume-JobSchedulerMaster cmdlet will resume operations.

.DESCRIPTION
When JobScheduler Master is paused then

* no new tasks are started
* running tasks are continued to complete:
** shell jobs will continue until their normal termination.
** API jobs complete a current spooler_process() call.
* any task starts that would normally occur during the pause period are postponed until JobScheduler Master is continued.

.EXAMPLE
Suspend-JobSchedulerMaster

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
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
	}

    Process
    {
        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

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
        $response = Invoke-JobSchedulerWebRequest '/jobscheduler/pause' $requestBody
        
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

        Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($objJobChainss.count) JobScheduler Master suspended"                                
    }

    End 
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
    
}

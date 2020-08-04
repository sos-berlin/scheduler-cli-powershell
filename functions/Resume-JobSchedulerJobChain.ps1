function Resume-JobSchedulerJobChain
{
<#
.SYNOPSIS
Resumes job chains in the JobScheduler Master.

.DESCRIPTION
This cmdlet is used to resume ("unstop") previously suspended ("stopped") job chains in a JobScheduler Master.

.PARAMETER JobChain
Specifies the path and name of a job chain that should be resumed.

The parameter -JobChain has to be specified if no pipelined job chain objects are used.

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
This cmdlet accepts pipelined job chain objects that are e.g. returned from a Get-JobSchedulerJobChain cmdlet.

.OUTPUTS
This cmdlet returns an array of job chain objects.

.EXAMPLE
Resume-JobSchedulerJobChain -JobChain /sos/reporting/Reporting

Resumes the job chain "Reporting" from the specified folder.

.EXAMPLE
Get-JobSchedulerJobChain -Stopped | Resume-JobSchedulerJobChain

Resumes all job chains that were previously suspended ("stopped").

.EXAMPLE
Get-JobSchedulerJobChain -Directory /some_path -Recursive | Resume-JobSchedulerJobChain

Resumes job chains that are configured with the "some_path" 
and any sub-folders.

.EXAMPLE
Get-JobSchedulerJobChain -JobChain /test/globals/chain1 | Resume-JobSchedulerJobChain

Resumes the specified job chain.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
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
        $stopWatch = Start-StopWatch

        if ( !$AuditComment -and ( $AuditTimeSpent -or $AuditTicketLink ) )
        {
            throw "$($MyInvocation.MyCommand.Name): Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
        }

        $objJobChains = @()
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

        $objJobChain = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $objJobChain

        $objJobChains += $objJobChain
    }

    End
    {
        if ( $objJobChains )
        {
            $body = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
            Add-Member -Membertype NoteProperty -Name 'jobChains' -value $objJobChains -InputObject $body
    
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
            $response = Invoke-JobSchedulerWebRequest '/job_chains/unstop' $requestBody
            
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
            
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($objJobChains.count) job chains resumed"                            
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no job chains found"
        }

        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

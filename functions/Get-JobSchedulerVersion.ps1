function Get-JobSchedulerVersion
{
<#
.SYNOPSIS
Returns the JobScheduler Master version

.DESCRIPTION
The cmdlet returns the version of the JobScheduler Master.

.PARAMETER NoCache
Specifies that the cache for JobScheduler objects is ignored.
This results in the fact that for each Get-JobScheduler* cmdlet execution the response is 
retrieved directly from the JobScheduler Master and is not resolved from the cache.

.EXAMPLE
Get-Version

Returns the JobScheduler version.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoCache
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch        
    }
    
    Process
    {
        if ( $NoCache -or !$SCRIPT:jsHasCache )
        {
            $command = "<show_state what='job_chain_orders' max_task_history='0'/>"
            Write-Debug ". $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
            Write-Debug ". $($MyInvocation.MyCommand.Name): sending command: $command"
            
            $stateXml = Send-JobSchedulerXMLCommand $js.Url $command
            if ( $stateXml )
            {
                $stateXml.spooler.answer.state.version
            }
        } else {
            if ( $SCRIPT:jsStateCache )
            {
                $SCRIPT:jsStateCache.spooler.answer.state.version
            }
        }
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }    
}

Set-Alias -Name Get-Version -Value Get-JobSchedulerVersion

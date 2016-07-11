function Update-JobSchedulerJobChain
{
<#
.SYNOPSIS
Updates a number of job chains in the JobScheduler Master.

.DESCRIPTION
Updating job chains includes operations to suspend and resume job chains.

Job chains are selected for update

* by a pipelined object, e.g. the output of the Get-JobSchedulerJobChain cmdlet
* by specifying an individual JobChain with the -JobChain parameter.

.PARAMETER JobChain
Specifies the path and name of a job chain that should be updated.

The parameter -JobChain has to be specified if no pipelined job chain objects are used.

.PARAMETER Directory
Optionally specifies the folder where the job chain is located. The directory is determined
from the root folder, i.e. the "live" directory.

If the -JobChain parameter specifies the name of job chain then the location specified from the 
-Directory parameter is added to the job chain location.

.PARAMETER Action
Specifies the action to be applied to a job chain:

* Action "suspend"
** Suspends a job chain, i.e. the job chain is stopped and will not continue without being resumed.
* Action "resume"
** Resumes a suspended job chain.

.INPUTS
This cmdlet accepts pipelined job chain objects that are e.g. returned from a Get-JobSchedulerJobChain cmdlet.

.OUTPUTS
This cmdlet returns an array of updated job chain objects.

.EXAMPLE
Update-JobSchedulerJobChain -JobChain /sos/reporting/Reporting -Action suspend

Suspends the job chain "Reporting"

.EXAMPLE
Get-JobSchedulerJobChain | Update-JobSchedulerJobChain -Action suspend

Suspends all job chains

.EXAMPLE
Get-JobSchedulerJobChain -Directory / -NoSubfolders | Update-JobSchedulerJobChain -Action resume

Updates all job chains that are configured with the root folder ("live" directory)
without consideration of subfolders to be resumed.

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
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [ValidateSet('suspend','resume')] [string] $Action
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch

        $command = ""
        $jobChainCount = 0
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

        Write-Debug ".. $($MyInvocation.MyCommand.Name): updating job chain', JobChain='$($JobChain)'"

        switch ( $Action )
        {
            'suspend'         { $jobChainAttributes = "state='stopped'" }
            'resume'          { $jobChainAttributes = "state='running'" }
            default           { throw 'no action specified for job chain, use parameter -Action' }
        }
        
        $command += "<job_chain.modify job_chain='$($JobChain)' $($jobChainAttributes) />"
        
        $updateJobChain = Create-JobChainObject
        $updateJobChain.JobChain = Get-JobSchedulerObject-Basename $JobChain
        $updateJobChain.Directory = Get-JobSchedulerObject-Parent $JobChain
        $updateJobChain.Path = $JobChain
        if ( $Action -eq 'suspend' )
        {
            $updateJobChain.State = 'stopped'
        } else {
            $updateJobChain.State = 'running'
        }
        $updateJobChain
        $jobChainCount++
     }

    End
    {
        if ( $JobChainCount )
        {
            $command = "<commands>$($command)</commands>"
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to $($js.Url): $command"        
            $jobChainXml = Send-JobSchedulerXMLCommand $js.Url $command
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($jobChainCount) job chains updated"
        } else {
            Write-Warning "$($MyInvocation.MyCommand.Name): no job chain found"
        }

        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

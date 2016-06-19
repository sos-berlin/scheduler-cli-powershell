function Resume-JobSchedulerJobChain
{
<#
.SYNOPSIS
Resumes a number of job chains in the JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Update-JobChain -Action "resume"

.PARAMETER JobChain
Specifies the path and name of a job chain that should be suspended.

The parameter -JobChain has to be specified if no pipelined job chain objects are used.

.PARAMETER Directory
Optionally specifies the folder where the job chain is located. The directory is determined
from the root folder, i.e. the "live" directory.

If the -JobChain parameter specifies the name of job chain then the location specified from the 
-Directory parameter is added to the job chain location.

.INPUTS
This cmdlet accepts pipelined job chain objects that are e.g. returned from a Get-JobChain cmdlet.

.OUTPUTS
This cmdlet returns an array of job chain objects.

.EXAMPLE
Resume-JobChain -JobChain /sos/reporting/Reporting

Resumes the job chain "Reporting" from the specified folder.

.EXAMPLE
Get-JobChain | Resume-JobChain

Resumes all job chains.

.EXAMPLE
Get-JobChain -Directory / -NoSubfolders | Resume-JobChain

Resumes job chains that are configured with the root folder ("live" directory)
without consideration of subfolders.

.EXAMPLE
Get-JobChain -JobChain /test/globals/chain1 | Resume-JobChain

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
    [string] $Directory = '/'
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand

        $parameters = @()
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

        $resumeJobChain = Create-JobChainObject
        $resumeJobChain.JobChain = Get-JobSchedulerObject-Basename $JobChain
        $resumeJobChain.Directory = Get-JobSchedulerObject-Parent $JobChain
        $resumeJobChain.Path = $jobChain
        # output objects are created by Update-JobSchedulerJobChain
        # $resumeJobChain
        $parameters += $resumeJobChain
    }

    End
    {
        $parameters | Update-JobSchedulerJobChain -Action resume
    }
}

Set-Alias -Name Resume-JobChain -Value Resume-JobSchedulerJobChain

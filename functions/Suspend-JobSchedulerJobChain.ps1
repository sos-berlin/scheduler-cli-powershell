function Suspend-JobSchedulerJobChain
{
<#
.SYNOPSIS
Suspends a number of job chains in the JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Update-JobSchedulerJobChain -Action "suspend"

.PARAMETER JobChain
Specifies the path and name of a job chain that should be suspended.

The parameter -JobChain has to be specified if no pipelined job chain objects are used.

.PARAMETER Directory
Optionally specifies the folder where the job chain is located. The directory is determined
from the root folder, i.e. the "live" directory.

If the -JobChain parameter specifies the name of job chain then the location specified from the 
-Directory parameter is added to the job chain location.

.INPUTS
This cmdlet accepts pipelined job chain objects that are e.g. returned from a Get-JobSchedulerJobChain cmdlet.

.OUTPUTS
This cmdlet returns an array of job chain objects.

.EXAMPLE
Suspend-JobSchedulerJobChain -JobChain /sos/reporting/Reporting

Suspends the job chain "Reporting". from the specified folder.

.EXAMPLE
Get-JobSchedulerJobChain | Suspend-JobSchedulerJobChain

Suspends all job chains.

.EXAMPLE
Get-JobSchedulerJobChain -Directory / -NoSubfolders | Suspend-JobSchedulerJobChain

Suspends job chains that are configured with the root folder ("live" directory)
without consideration of subfolders.

.EXAMPLE
Get-JobSchedulerJobChain -JobChain /test/globals/chain1 | Suspend-JobSchedulerJobChain

Suspends the specified job chain.

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
                if ( $Directory -eq '/' )
                {
                    $JobChain = $Directory + $JobChain
                } else {
                    $JobChain = $Directory + '/' + $JobChain
                }
            }
        }

        $suspendJobChain = Create-JobChainObject
        $suspendJobChain.JobChain = Get-JobSchedulerObject-Basename $JobChain
        $suspendJobChain.Directory = Get-JobSchedulerObject-Parent $JobChain
        $suspendJobChain.Path = $JobChain
        # output objects are created by Update-JobSchedulerJobChain
        # $suspendJobChain
        $parameters += $suspendJobChain
    }

    End
    {
        $parameters | Update-JobSchedulerJobChain -Action suspend
    }
}

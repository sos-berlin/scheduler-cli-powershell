function Get-JobSchedulerJobChain
{
<#
.SYNOPSIS
Returns a number of job chains from the JobScheduler Master.

.DESCRIPTION
Job chains are retrieved from a JobScheduler Master.
Job chains can be selected either by the folder of the job chain location including subfolders or by an individual job chain.

Resulting job chains can be forwarded to other cmdlets for pipelined bulk operations.

.PARAMETER Directory
Optionally specifies the folder for which job chains should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

One of the parameters -Directory and -JobChain has to be specified.

.PARAMETER JobChain
Optionally specifies the path and name of a job chain that should be returned.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.
Otherwise the -JobChain parameter is assumed to include the full path and name of the job chain.

One of the parameters -Directory or -JobChain has to be specified.

.PARAMETER NoSubfolders
Specifies that no subfolders should be looked up. By default any subfolders will be searched for job chains.

.OUTPUTS
This cmdlet returns an array of job chain objects.

.EXAMPLE
$jobChains = Get-JobChain

Returns all job chains.

.EXAMPLE
$jobChains = Get-JobChain -Directory / -NoSubfolders

Returns all job chains that are configured with the root folder ("live" directory)
without consideration of subfolders.

.EXAMPLE
$jobChains = Get-JobChains -JobChain /test/globals/job_chain1

Returns the job chain job_chain1 from the folder "/test/globals".

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [switch] $NoSubfolders
)
    Begin
    {
	}		
		
    Process
    {
		Write-Verbose ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain"

		if ( !$Directory -and !$JobChain )
        {
            throw "$($MyInvocation.MyCommand.Name): no directory and no job chain specified, use -Directory or -JobChain"
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
            if ( (Get-JobSchedulerObject-Basename $JobChain) -ne $JobChain ) # job chain name includes a path
            {
                if ( $Directory -ne '/' )
                {
                    # Write-Warning "$($MyInvocation.MyCommand.Name): parameter -Directory has been specified, but is replaced by by parent folder of -JobChain parameter"
                }
                $Directory = Get-JobSchedulerObject-Parent $JobChain
            } else { # job chain name includes no directory
                $JobChain = $Directory + '/' + $JobChain
            }
        }
        
        $whatNoSubfolders = if ( $NoSubfolders ) { " no_subfolders" } else { "" }
        $command = "<show_state subsystems='folder order' what='folders job_chain_orders$($whatNoSubfolders)' path='$($Directory)'/>"
    
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Hostname):$($js.Port)"
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): sending request: $command"
        
        $jobChainXml = Send-JobSchedulerXMLCommand $js.Hostname $js.Port $command
        if ( $jobChainXml )
        {    
            $jobChainCount = 0
            $jobChainNodes = Select-XML -XML $jobChainXml -Xpath "//folder/job_chains/job_chain"
            foreach( $jobChainNode in $jobChainNodes )
            {
                if ( !$jobChainNode.Node.name )
                {
                    continue
                }
        
                $jc = Create-JobChainObject
                $jc.JobChain = $jobChainNode.Node.name
                $jc.Path = $jobChainNode.Node.path
                $jc.Directory = Get-JobSchedulerObject-Parent $jobChainNode.Node.path
                $jc.State = $jobChainNode.Node.state
                $jc.Title = $jobChainNode.Node.title
                $jc.Orders = $jobChainNode.Node.orders
                $jc.RunningOrders = $jobChainNode.Node.running_orders
                $jc
                $jobChainCount++
            }
			
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $jobChainCount job chains found"
        }
    }
}

Set-Alias -Name Get-JobChain -Value Get-JobSchedulerJobChain

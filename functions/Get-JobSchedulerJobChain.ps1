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

.PARAMETER NoCache
Specifies that the cache for JobScheduler objects is ignored.
This results in the fact that for each Get-JobScheduler* cmdlet execution the response is 
retrieved directly from the JobScheduler Master and is not resolved from the cache.

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
$jobChains = Get-JobChain -JobChain /test/globals/job_chain1

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
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoSubfolders,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $NoCache
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch
        $jobChainCount = 0
    }
        
    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain"

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
        
        $xPath = '//folder'

        if ( $Directory )
        {
            if ( $NoSubfolders )
            {
                $xPath += "[@path='$($Directory)']"
            } else {
                $xPath += "[starts-with(@path, '$($Directory)')]"
            }
        }

        if ( $JobChain )
        {
            $xPath += "/job_chains/job_chain[@path = '$($JobChain)']"
        } else {
            $xPath += '/job_chains/job_chain'
        }
        
        if ( $NoCache -or !$SCRIPT:jsHasCache )
        {
            $whatNoSubfolders = if ( $NoSubfolders ) { " no_subfolders" } else { "" }
            $command = "<show_state subsystems='folder order' what='folders job_chain_orders$($whatNoSubfolders)' path='$($Directory)'/>"
    
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Url)"
            Write-Debug ".. $($MyInvocation.MyCommand.Name): sending request: $command"
        
            $jobChainXml = Send-JobSchedulerXMLCommand $js.Url $command

            Write-Debug ".. $($MyInvocation.MyCommand.Name): using xPath: $xPath"
            $jobChainNodes = Select-XML -XML $jobChainXml -Xpath $xPath
        } else {
            Write-Debug ".. $($MyInvocation.MyCommand.Name): using cache: $xPath"
            $jobChainNodes = Select-XML -XML $SCRIPT:jsStateCache -Xpath $xPath
        }
        
        if ( $jobChainNodes )
        {
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
        }
    }
    
    End
    {
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): $jobChainCount job chains found"
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

Set-Alias -Name Get-JobChain -Value Get-JobSchedulerJobChain

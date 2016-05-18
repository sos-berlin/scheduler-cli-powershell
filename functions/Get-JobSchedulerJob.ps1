function Get-JobSchedulerJob
{
<#
.SYNOPSIS
Returns a number of jobs from the JobScheduler Master.

.DESCRIPTION
Jobs are retrieved from a JobScheduler Master.
Jobs can be selected either by the folder of the job location including subfolders or by an individual job.

Resulting jobs can be forwarded to other cmdlets for pipelined bulk operations.

.PARAMETER Directory
Optionally specifies the folder for which jobs should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

One of the parameters -Directory, -JobChain or -Job has to be specified.

.PARAMETER JobChain
Optionally specifies the path and name of a job chain that includes jobs.
If the name of a job chain is specified then the -Directory parameter is used to determine the folder.
Otherwise the -JobChain parameter is assumed to include the full path and name of the job chain.

One of the parameters -Directory, -JobChain or -Job has to be specified.

.PARAMETER Job
Optionally specifies the path and name of a job.
If the name of a job is specified then the -Directory parameter is used to determine the folder.
Otherwise the -Job parameter is assumed to include the full path and name of the job.

One of the parameters -Directory, -JobChain or -Job has to be specified.

.PARAMETER NoSubfolders
Specifies that no subfolders should be looked up. By default any subfolders will be searched for jobs.

.OUTPUTS
This cmdlet returns an array of job objects.

.EXAMPLE
$jobs = Get-Job

Returns all jobs.

.EXAMPLE
$jobs = Get-Job -Directory / -NoSubfolders

Returns all jobs that are configured with the root folder ("live" directory)
without consideration of subfolders.

.EXAMPLE
$jobs = Get-Job -JobChain /test/globals/job_chain1

Returns the jobs that are associated with job chain job_chain1 from the folder "/test/globals".

.EXAMPLE
$jobs = Get-Job -Job /test/globals/job1

Returns the job job1 from the folder "/test/globals".

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
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [switch] $NoSubfolders
)
    Begin
    {
	}		
		
    Process
    {
		Write-Verbose ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobChain=$JobChain Job=$Job"
	
        if ( !$Directory -and !$JobChain -and !$Job )
        {
            throw "$($MyInvocation.MyCommand.Name): no directory, job chain or job specified, use -Directory, -JobChain or -Job"
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
            if ( (Get-JobSchedulerObject-Basename $JobChain) -ne $JobChain ) # job chain name includes a directory
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
        
        if ( $Job )
        {
            if ( (Get-JobSchedulerObject-Basename $Job) -ne $Job ) # job name includes a directory
            {
                if ( $Directory -ne '/' )
                {
                    # Write-Warning "$($MyInvocation.MyCommand.Name): parameter -Directory has been specified, but is replaced by by parent folder of -Job parameter"
                }
                $Directory = Get-JobSchedulerObject-Parent $Job
            } else { # job name includes no directory
                $Job = $Directory + '/' + $Job
            }
        }
        
        $whatNoSubfolders = if ( $NoSubfolders ) { " no_subfolders" } else { "" }
		
		if ( $JobChain )
		{
			$command = "<show_state subsystems='folder order' what='folders job_chain_orders$($whatNoSubfolders)' path='$($Directory)'/>"
		} else {
			$command = "<show_state subsystems='folder job' what='folders jobs$($whatNoSubfolders)' path='$($Directory)'/>"
		}
    
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending command to JobScheduler $($js.Hostname):$($js.Port)"
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): sending request: $command"
        
        $jobXml = Send-JobSchedulerXMLCommand $js.Hostname $js.Port $command
        if ( $jobXml )
        {    
            $jobCount = 0

            if ( $Job )
            {
                $jobNodes = Select-XML -XML $jobXml -Xpath "//folder/jobs/job[@path = '$($Job)']"
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection by job: //folder/jobs/job[@path = '$($Job)']"
            } elseif ( $JobChain ) {
                $jobNodes = Select-XML -XML $jobXml -Xpath "//folder/job_chains/job_chain[@path = '$($JobChain)']/job_chain_node"
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection by job chain: //folder/job_chains/job_chain[@path = '$($JobChain)']/job_chain_node"
            } else {
                $jobNodes = Select-XML -XML $jobXml -Xpath "//folder/jobs/job"
                Write-Verbose ".. $($MyInvocation.MyCommand.Name): selection of jobs: //folder/jobs/job"
            }
			
            foreach( $jobNode in $jobNodes )
            {        
                $j = Create-JobObject

				if ( $Job )
				{
					if ( !$jobNode.Node.name )
					{
						continue
					}
					$j.Job = $jobNode.Node."name"
					$j.Path = $jobNode.Node.path
					$j.Directory = Get-JobSchedulerObject-Parent $jobNode.Node.path				
				} elseif ( $JobChain ) {
					if ( !$jobNode.Node.job )
					{
						continue
					}
					$j.Job = Get-JobSchedulerObject-Basename $jobNode.Node.job
					$j.Path = $jobNode.Node.job
					$j.Directory = Get-JobSchedulerObject-Parent $jobNode.Node.job
				} else {
					if ( !$jobNode.Node.name )
					{
						continue
					}
					$j.Job = $jobNode.Node."name"
					$j.Path = $jobNode.Node.path
					$j.Directory = Get-JobSchedulerObject-Parent $jobNode.Node.path
				}

                $j.State = $jobNode.Node.state
                $j.Title = $jobNode.Node.title
                $j.LogFile = $jobNode.Node.log_file
                $j.Tasks = $jobNode.Node.tasks
                $j.IsOrder = $jobNode.Node.order
                $j.ProcessClass = $jobNode.Node.process_class
                $j.NextStartTime = $jobNode.Node.next_start_time
                $j.StateText = $jobNode.Node.state_text
                $j
                $jobCount++
            }
			
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $jobCount jobs found"
        }
    }
}

Set-Alias -Name Get-Job -Value Get-JobSchedulerJob
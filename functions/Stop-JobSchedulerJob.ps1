function Stop-JobSchedulerJob
{
<#
.SYNOPSIS
Stops a number of jobs in the JobScheduler Master.

.DESCRIPTION
This cmdlet is an alias for Update-Job -Action "stop"

.PARAMETER Job
Specifies the full path and name of a job.

.PARAMETER Directory
Optionally specifies the directory of a job should the -Job parameter
not be provided with the full path and name of the job.

.INPUTS
This cmdlet accepts pipelined job objects that are e.g. returned from a Get-Job cmdlet.

.OUTPUTS
This cmdlet returns an array of job objects.

.EXAMPLE
Stop-Job -Job /sos/dailyschedule/CheckDaysSchedule

Stops an individual job.

.EXAMPLE
Get-Job -Directory /some_dir -NoSubfolders | Stop-Job

Stops all jobs from the specified directory 
without consideration of subfolders.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/'
)
    Begin
    {
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
    
        if ( $Job )
        {
            if ( (Get-JobSchedulerObject-Basename $Job) -ne $Job ) # job name includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $Job
            } else { # job name includes no directory
                $Job = $Directory + '/' + $Job
            }
        }
    
        $j = Create-JobObject
        $j.Job = $Job
        $j.Path = $Job
        $j.Directory = Get-JobSchedulerObject-Parent $Job
        $parameters += $j
    }

    End
    {
        $parameters | Update-JobSchedulerJob -Action stop
    }
}

Set-Alias -Name Stop-Job -Value Stop-JobSchedulerJob

function Get-JobSchedulerJobStream
{
<#
.SYNOPSIS
Returns Job Streams from the JOC Cockpit inventory.

.DESCRIPTION
Job Streams are returned from a JOC Cockpit inventory. Job streams can be selected by name and folder.

.PARAMETER JobStream
Optionally specifies the name of a job stream.

One of the parameters -Directory or -JobStream has to be specified.

.PARAMETER Directory
Optionally specifies the folder for which job streams should be returned. The directory is determined
from the root folder, i.e. the "live" directory.

.OUTPUTS
This cmdlet returns an array of job streams.

.EXAMPLE
$jobStreams = Get-JobSchedulerJobStreams

Returns all job streams from any directories recursively.

.EXAMPLE
$jobStreams = Get-JobSchedulerJobStream -Directory /test

Returns all job streams that are configured with the folder "test".

.EXAMPLE
$jobStreams = Get-JobSchedulerJobStream -JobStream SampleJobStream

Returns the job stream with the indicated name.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobStream,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        $jobStreams = @()
        $folders = @()
    }

    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobStream=$JobStream"

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

        if ( $JobStream )
        {
            $jobStreams += $JobStream
        }

        if ( $Directory )
        {
            $folders += $Directory
        }
    }

    End
    {
        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

        if ( $jobStreams.count )
        {
            Add-Member -Membertype NoteProperty -Name 'jobStream' -value $jobStreams[0] -InputObject $body
        }

        if ( $folders.count )
        {
            Add-Member -Membertype NoteProperty -Name 'folder' -value $folders[0] -InputObject $body
        }

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest -Path '/jobstreams/list_jobstreams' -Body $requestBody

        if ( $response.StatusCode -eq 200 )
        {
            $requestResult = ( $response.Content | ConvertFrom-Json )

            if ( !$requestResult )
            {
                throw ( $response | Format-List -Force | Out-String )
            }
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }
        
        $requestResult.jobstreams

        if ( $requestResult.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($requestResult.count) job streams found"
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no job streams found"
        }

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

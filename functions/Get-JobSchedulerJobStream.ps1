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

.PARAMETER Recursive
Specifies that any sub-folders should be looked up if the -Directory parameter is used.
By default no sub-folders will be searched for job streams.

.OUTPUTS
This cmdlet returns an array of job streams.

.EXAMPLE
$jobStreams = Get-JobSchedulerJobStream -Directory /test

Returns all job streams that are configured with the folder "test".

.EXAMPLE
$jobStreams = Get-JobSchedulerJobStream

Returns all job streams.

.EXAMPLE
$jobStream = Get-JobSchedulerJobStream -JobStream SampleJobStream

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
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Recursive
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        $objFolders = @()
    }

    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, JobStream=$JobStream"

        if ( !$JobStream -and !$Directory )
        {
            throw "$($MyInvocation.MyCommand.Name): Job Stream specification required, one of the parameters -JobStream or -Directory has to be used"
        }

        if ( $Directory -and $Directory -ne '/' )
        {
            if ( !$Directory.startsWith( '/' ) )
            {
                $Directory = '/' + $Directory
            }

            if ( $Directory.endsWith( '/' ) )
            {
                $Directory = $Directory.Substring( 0, $Directory.Length-1 )
            }
        }

        if ( $Directory -eq '/' -and !$JobStream -and !$Recursive )
        {
            $Recursive = $True
        }

        if ( $Directory )
        {
            $objFolder = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'folder' -value $Directory -InputObject $objFolder
            Add-Member -Membertype NoteProperty -Name 'recursive' -value ($Recursive -eq $True) -InputObject $objFolder
            $objFolders += $objFolder
        }
    }

    End
    {
        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

        if ( $JobStream )
        {
            Add-Member -Membertype NoteProperty -Name 'jobStream' -value $JobStream -InputObject $body
        }

        if ( $objFolders.count )
        {
            Add-Member -Membertype NoteProperty -Name 'folders' -value $objFolders -InputObject $body
        }


        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest -Path '/jobstreams/list' -Body $requestBody

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

        if ( $requestResult.jobstreams.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($requestResult.jobstreams.count) job streams found"
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no job stream found"
        }

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

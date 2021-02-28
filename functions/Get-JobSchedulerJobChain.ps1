function Get-JobSchedulerJobChain
{
<#
.SYNOPSIS
Returns job chains from the JobScheduler Master.

.DESCRIPTION
Job chains are returned from a JobScheduler Master.
Job chains can be selected either by the folder of the job chain location including sub-folders or by an individual job chain.

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

.PARAMETER Recursive
Specifies that any sub-folders should be looked up. By default no sub-folders will be searched for job chains.

.PARAMETER Compact
Specifies that fewer attributes of a job chain are returned.

.PARAMETER Active
Specifies that only active ("unstopped") job chains are returned.

.PARAMETER Stopped
Specifies that only suspended ("stopped") job chains are returned.

.OUTPUTS
This cmdlet returns an array of job chain objects.

.EXAMPLE
$jobChains = Get-JobSchedulerJobChain

Returns all job chains.

.EXAMPLE
$jobChains = Get-JobSchedulerJobChain -Directory /some_path -Recursive

Returns all job chains that are configured with the specified path
including any sub-folders.

.EXAMPLE
$jobChains = Get-JobSchedulerJobChain -JobChain /test/globals/job_chain1

Returns the job chain "job_chain1" from the folder "/test/globals".

.EXAMPLE
$jobChains = Get-JobSchedulerJobChain -Stopped

Returns all suspended ("stopped") job chains.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
[OutputType([System.Object[]])]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Compact,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Active,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Stopped
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        $volatileJobChains = @()
        $returnJobChains = @()
        $states = @()
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

        if ( $Directory -eq '/' -and !$JobChain -and !$Recursive )
        {
            $Recursive = $true
        }

        if ( $JobChain )
        {
            if ( (Get-JobSchedulerObject-Basename $JobChain) -ne $JobChain ) # job chain name includes a path
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

        if ( $Active )
        {
            $states += 'ACTIVE'
        }

        if ( $Stopped )
        {
            $states += 'STOPPED'
        }

        # JOB CHAINS VOLATILE API

        $body = New-Object PSObject
        Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

        if ( $Compact )
        {
            Add-Member -Membertype NoteProperty -Name 'compact' -value $true -InputObject $body
        }

        if ( $JobChain )
        {
            $objJobChain = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $objJobChain

            Add-Member -Membertype NoteProperty -Name 'jobChains' -value @( $objJobChain ) -InputObject $body
        }

        if ( $Directory )
        {
            $objFolder = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'folder' -value $Directory -InputObject $objFolder
            Add-Member -Membertype NoteProperty -Name 'recursive' -value ($Recursive -eq $true) -InputObject $objFolder

            Add-Member -Membertype NoteProperty -Name 'folders' -value @( $objFolder ) -InputObject $body
        }

        if ( $states )
        {
            Add-Member -Membertype NoteProperty -Name 'states' -value $states -InputObject $body
        }

        [string] $requestBody = $body | ConvertTo-Json -Depth 100
        $response = Invoke-JobSchedulerWebRequest '/job_chains' $requestBody

        if ( $response.StatusCode -eq 200 )
        {
            $volatileJobChains += ( $response.Content | ConvertFrom-JSON ).jobChains
        } else {
            throw ( $response | Format-List -Force | Out-String )
        }
    }

    End
    {
        if ( $volatileJobChains )
        {
            foreach( $volatileJobChain in $volatileJobChains )
            {
                $returnJobChain = New-JobSchedulerJobChainObject
                $returnJobChain.JobChain = $volatileJobChain.path
                $returnJobChain.Path = $volatileJobChain.path
                $returnJobChain.Directory = Get-JobSchedulerObject-Parent $volatileJobChain.path
                $returnJobChain.Volatile = $volatileJobChain

                # JOB CHAINS PERMANENT API

                $body = New-Object PSObject
                Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
                Add-Member -Membertype NoteProperty -Name 'jobChain' -value $volatileJobChain.path -InputObject $body

                if ( $Compact )
                {
                    Add-Member -Membertype NoteProperty -Name 'compact' -value $true -InputObject $body
                }

                [string] $requestBody = $body | ConvertTo-Json -Depth 100
                $response = Invoke-JobSchedulerWebRequest '/job_chain/p' $requestBody

                if ( $response.StatusCode -eq 200 )
                {
                    $returnJobChain.Permanent = ( $response.Content | ConvertFrom-JSON ).jobChain
                } else {
                    throw ( $response | Format-List -Force | Out-String )
                }

                $returnJobChains += $returnJobChain
            }

            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($returnJobChains.count) job chains found"
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no job chains found"
        }

        $returnJobChains

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}


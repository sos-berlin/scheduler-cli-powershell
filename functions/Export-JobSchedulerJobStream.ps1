function Export-JobSchedulerJobStream
{
<#
.SYNOPSIS
Exports job streams from the JOC Cockpit inventory.

.DESCRIPTION
This cmdlet exports job streams from the JOC Cockpit inventory.

.PARAMETER JobStream
Specifies the name of a job stream for export.

.PARAMETER Directory
Optionally specifies the directory for job streams that should be exported.

.PARAMETER Recursive
Specifies that any sub-folders should be looked up if the -Directory parameter is used.
By default no sub-folders will be searched for job streams.

.PARAMETER Limit
Limits the number of job streams exported.

By default a maximum of 10 000 job streams are exported.
The value -1 indicates that no limit should be applied.

.INPUTS
This cmdlet accepts pipelined job stream names.

.OUTPUTS
This cmdlet returns an array of job streams.

.EXAMPLE
$jsExport = Export-JobSchedulerJobStream -JobStream my_jobstream

Exports the indicated job stream.

.EXAMPLE
$jsExport = Export-JobSchedulerJobStream -Directory /sos/some_folder

Exports any job streams from the indicated job stream folder.

.EXAMPLE
$jsExport = Export-JobSchedulerJobStream -Directory / -Recursive

Exports all job streams.

.LINK
about_jobscheduler

#>
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobStream,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $Limit
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        $objJobStreams = @()
        $objFolders = @()
    }

    Process
    {
        if ( $Directory -and $Directory -ne '/' -and $JobStream )
        {
            throw "$($MyInvocation.MyCommand.Name): only on of the parameterrs -jobStream or -Directory can be used"
        }

        if ( $Directory -and $Directory -ne '/' )
        {
            if ( !$Directory.StartsWith( '/' ) )
            {
                $Directory = '/' + $Directory
            }

            if ( $Directory.EndsWith( '/' ) )
            {
                $Directory = $Directory.Substring( 0, $Directory.Length-1 )
            }
        }

        if ( $Directory -eq '/' -and !$JobStream -and !$Recursive )
        {
            $Recursive = $True
        }

        $objJobStream = New-Object PSObject

        if ( $JobStream )
        {
            Add-Member -Membertype NoteProperty -Name 'jobStream' -value $JobStream -InputObject $objJobStream
            $objJobStreams += $objJobStream
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

        if ( $objJobStreams.count )
        {
            Add-Member -Membertype NoteProperty -Name 'jobStreams' -value $objJobStreams -InputObject $body
        }

        if ( $objFolders.count )
        {
            Add-Member -Membertype NoteProperty -Name 'folders' -value $objFolders -InputObject $body
        }

        if ( $Limit )
        {
            Add-Member -Membertype NoteProperty -Name 'limit' -value $Limit -InputObject $body
        }

        if ( $PSCmdlet.ShouldProcess( $Service, '/jobstreams/export' ) )
        {
            [string] $requestBody = $body | ConvertTo-Json -Depth 100
            $response = Invoke-JobSchedulerWebRequest -Path '/jobstreams/export' -Body $requestBody -Headers @{ 'Accept' = 'application/octet-stream' }

            if ( $response.StatusCode -eq 200 )
            {
                $requestResult = ( $response.Content | ConvertFrom-Json )
            } else {
                throw ( $response | Format-List -Force | Out-String )
            }

            ( [System.Text.Encoding]::UTF8.GetString( $requestResult ) | ConvertFrom-Json -Depth 100 )

            Write-Verbose ".. $($MyInvocation.MyCommand.Name): job streams exported"
        }

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

function Import-JobSchedulerJobStream
{
<#
.SYNOPSIS
Imports job streams to the JOC Cockpit inventory.

.DESCRIPTION
This cmdlet imports job streams to the JOC Cockpit inventory.

.PARAMETER FilePath
Specifies the path to the archive file that includes objects for import to the JOC Cockpit inventory.

.PARAMETER AuditComment
Specifies a free text that indicates the reason for the current intervention, e.g. "business requirement", "maintenance window" etc.

The Audit Comment is visible from the Audit Log view of JOC Cockpit.
This parameter is not mandatory, however, JOC Cockpit can be configured to enforece Audit Log comments for any interventions.

.PARAMETER AuditTimeSpent
Specifies the duration in minutes that the current intervention required.

This information is visible with the Audit Log view. It can be useful when integrated
with a ticket system that logs the time spent on interventions with JobScheduler.

.PARAMETER AuditTicketLink
Specifies a URL to a ticket system that keeps track of any interventions performed for JobScheduler.

This information is visible with the Audit Log view of JOC Cockpit.
It can be useful when integrated with a ticket system that logs interventions with JobScheduler.

.INPUTS
This cmdlet accepts no inputs.

.OUTPUTS
This cmdlet returns no output.

.EXAMPLE
Import-JobSchedulerJobStream -JobStream /sos/some_starter

Starts the indicated job stream starter.

.EXAMPLE
Start-JobSchedulerJobStream -JobStreamStarter /sos/some_starter

Starts the indicated job stream starter.

.EXAMPLE
Start-JobSchedulerJobStream -JobStreamStarter /some_path/some_starter -Parameters ${ 'par1' = 'val1'; 'par2' = 'val2' }

Starts the job stream starter with parameters 'par1', 'par2' and respective values.

.LINK
about_jobscheduler

#>
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $FilePath,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $AuditComment,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $AuditTimeSpent,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [Uri] $AuditTicketLink
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        if ( !$AuditComment -and ( $AuditTimeSpent -or $AuditTicketLink ) )
        {
            throw "$($MyInvocation.MyCommand.Name): Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
        }
    }

    Process
    {
        try
        {
            # see https://get-powershellblog.blogspot.com/2017/09/multipartform-data-support-for-invoke.html
            # requires PowerShell > 6.0, version before 6.0 do not support MultipartFormDataContent in a POST bodys
            $multipartContent = [System.Net.Http.MultipartFormDataContent]::new()

            $multipartFile = $FilePath
            $fileStream = [System.IO.FileStream]::new($multipartFile, [System.IO.FileMode]::Open)
            $fileHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
            $fileHeader.Name = 'file'
            $fileHeader.FileName = [System.IO.Path]::GetFileName( $FilePath )
            $fileContent = [System.Net.Http.StreamContent]::new( $fileStream )
            $fileContent.Headers.ContentDisposition = $fileHeader
            $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("application/octet-stream")
            $multipartContent.Add( $fileContent )

            $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
            $stringHeader.Name = "format"
            $stringContent = [System.Net.Http.StringContent]::new( $Format )
            $stringContent.Headers.ContentDisposition = $stringHeader
            $multipartContent.Add( $stringContent )

            $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
            $stringHeader.Name = "targetFolder"
            $stringContent = [System.Net.Http.StringContent]::new( $TargetFolder )
            $stringContent.Headers.ContentDisposition = $stringHeader
            $multipartContent.Add( $stringContent )

            $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
            $stringHeader.Name = "overwrite"
            $StringContent = [System.Net.Http.StringContent]::new( ($Overwrite -eq $True) )
            $stringContent.Headers.ContentDisposition = $stringHeader
            $multipartContent.Add( $stringContent )

            if ( $AuditComment -or $AuditTimeSpent -or $AuditTicketLink )
            {
                $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
                $stringHeader.Name = "comment"
                $stringContent = [System.Net.Http.StringContent]::new( $AuditComment )
                $stringContent.Headers.ContentDisposition = $stringHeader
                $multipartContent.Add( $stringContent )

                $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
                $stringHeader.Name = "timeSpent"
                $stringContent = [System.Net.Http.StringContent]::new( $AuditComment )
                $stringContent.Headers.ContentDisposition = $stringHeader
                $multipartContent.Add( $stringContent )

                $stringHeader = [System.Net.Http.Headers.ContentDispositionHeaderValue]::new("form-data")
                $stringHeader.Name = "ticketLink"
                $stringContent = [System.Net.Http.StringContent]::new( $AuditComment )
                $stringContent.Headers.ContentDisposition = $stringHeader
                $multipartContent.Add( $stringContent )
            }

            $response = Invoke-JobSchedulerWebRequest -Path '/inventory/import' -Body $multipartContent -Method 'POST' -ContentType $Null

            if ( $response.StatusCode -ne 200 )
            {
                throw ( $response | Format-List -Force | Out-String )
            }

            Write-Verbose ".. $($MyInvocation.MyCommand.Name): file imported: $FilePath"
        } catch {
            $message = $_.Exception | Format-List -Force | Out-String
            throw $message
        } finally {
            if ( $fileStream )
            {
                $fileStream.Close()
                $fileStream.Dispose()
            }
        }
    }

    End
    {
        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

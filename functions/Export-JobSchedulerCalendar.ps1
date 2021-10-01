function Export-JobSchedulerCalendar
{
<#
.SYNOPSIS
Exports calendars from the JOC Cockpit inventory.

.DESCRIPTION
This cmdlet exports calendars from the JOC Cockpit inventory.

.PARAMETER Calendar
Specifies the path of a calendar for export.

.PARAMETER Directory
Optionally specifies the directory for calendars that should be exported.

.PARAMETER Recursive
Specifies that any sub-folders should be looked up if the -Directory parameter is used.
By default no sub-folders will be searched for calendars.

.PARAMETER RegularExpression
Limits export results to calendar names matching the regular expression.

.INPUTS
This cmdlet accepts pipelined calendar paths.

.OUTPUTS
This cmdlet returns an array of calendars.

.EXAMPLE
$calExport = Export-JobSchedulerCalendar -Calendar "/Any Days"

Exports the indicated calendars.

.EXAMPLE
$calExport = Export-JobSchedulerCalendar -Directory /sos/some_folder

Exports any calendars from the indicated folder.

.EXAMPLE
$calExport = Export-JobSchedulerCalendar -Directory / -Recursive

Exports all calendars.

.LINK
about_jobscheduler

#>
[cmdletbinding(SupportsShouldProcess)]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Calendar,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $RegularExpression
)
	Begin
	{
		Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        $calendars = @()
        $objFolders = @()
    }

    Process
    {
        if ( $Directory -and $Directory -ne '/' -and $Calendar )
        {
            throw "$($MyInvocation.MyCommand.Name): only on of the parameterrs -Calendar or -Directory can be used"
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

        if ( $Directory -eq '/' -and !$Calendar -and !$Recursive )
        {
            $Recursive = $True
        }

        if ( $Calendar )
        {
            $calendars += $Calendar
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

        if ( $calendars.count )
        {
            Add-Member -Membertype NoteProperty -Name 'calendars' -value $calendars -InputObject $body
        }

        if ( $objFolders.count )
        {
            Add-Member -Membertype NoteProperty -Name 'folders' -value $objFolders -InputObject $body
        }

        if ( $RegularExpression )
        {
            Add-Member -Membertype NoteProperty -Name 'regex' -value $RegularExpression -InputObject $body
        }

        if ( $PSCmdlet.ShouldProcess( $Service, '/calendars/export' ) )
        {
            [string] $requestBody = $body | ConvertTo-Json -Depth 100
            $response = Invoke-JobSchedulerWebRequest -Path '/calendars/export' -Body $requestBody -Headers @{ 'Accept' = 'application/octet-stream' }

            if ( $response.StatusCode -eq 200 )
            {
                $requestResult = ( $response.Content | ConvertFrom-Json )
            } else {
                throw ( $response | Format-List -Force | Out-String )
            }

            ( [System.Text.Encoding]::UTF8.GetString( $requestResult ) | ConvertFrom-Json -Depth 100 )

            Write-Verbose ".. $($MyInvocation.MyCommand.Name): calendars exported"
        }

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

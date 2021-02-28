function Get-JobSchedulerCalendar
{
<#
.SYNOPSIS
Returns calendars from the JOC Cockpit inventory

.DESCRIPTION
Calendars are selected from the JOC Cockpit inventory

* by the path and name of a calendar,
* by the folder of the calendar location including sub-folders,
* by a regular expression that is used to filter calendar names.

Resulting calendars can be forwarded to other cmdlets for pipelined bulk operations.

.PARAMETER CalendarPath
Optionally specifies the path and name of a calendar that should be returned.

One of the parameters -Folder, -CalendarPath or -RegularExpression has to be specified if no pipelined calendar objects are provided.

.PARAMETER Folder
Optionally specifies the folder for which calendars should be returned.

One of the parameters -Folder, -CalendarPath or -RegularExpression has to be specified if no pipelined calendar objects are provided.

.PARAMETER Recursive
Specifies that any sub-folders should be looked up if the -Folder parameter is used.
By default no sub-folders will be searched for calendars.

.PARAMETER RegularExpression
Specifies that a regular expession is applied to the calendar name to filter results.

.PARAMETER Compact
Specifies that fewer attributes of calendars are returned.

.PARAMETER WorkingDays
Specifies that only calendars for working days should be returned.
Such calendars specify days for which orders should be executed with a JS7 Controller.

Only one of the parameters -WorkingDays or -NonWorkingDays can be used.

.PARAMETER NonWorkingDays
Specifies that only calendars for non-working days should be returned.
Such calendars specify days for which no orders should be executed with a JS7 Controller.

Only one of the parameters -WorkingDays or -NonWorkingDays can be used.

.OUTPUTS
This cmdlet returns an array of calendar objects.

.EXAMPLE
$calendars = Get-JobSchedulerCalendar

Returns all calendars available with the JOC Cockpit inventory.

.EXAMPLE
$calendars = Get-JobSchedulerCalendar -Directory /some_folder -Recursive

Returns all calendars that are configured with the folder "/some_folder"
including any sub-folders.

.EXAMPLE
$calendar = Get-JobSchedulerCalendar -CalendarPath /BusinessDays

Returns the calendar that is stored with the path "/BusinessDays".

.EXAMPLE
$calendars = Get-JobSchedulerCalendar -WorkingDays

Returns the calendars that define working days only.

.LINK
about_js7

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $CalendarPath,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$False)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $RegularExpression,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Compact,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $WorkingDays,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $NonWorkingDays
)
    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        if ( $WorkingDays -and $NonWorkingDays )
        {
            throw "$($MyInvocation.MyCommand.Name): only one of the parameters -WorkingDays or -NonWorkingDays can be used"
        }

        $returnCalendars = @()
        $calendarPaths = @()
        $folders = @()
        $type = $null
    }

    Process
    {
        Write-Debug ".. $($MyInvocation.MyCommand.Name): parameter Directory=$Directory, CalendarPath=$CalendarPath"

        if ( $CalendarPath.endsWith( '/') )
        {
            throw "$($MyInvocation.MyCommand.Name): the -CalendarPath parameter has to specify the folder and name of a calendar"
        }

        if ( $CalendarPath -and !$CalendarPath.startsWith( '/') )
        {
            $CalendarPath = '/' + $CalendarPath
        }

        if ( !$Directory -and !$CalendarPath -and !$RegularExpression )
        {
            throw "$($MyInvocation.MyCommand.Name): no directory, no calendar or regular expression is specified, use -Directory or -CalendarPath or -RegularExpression"
        }

        if ( $Directory -and $Directory -ne '/' -and $CalendarPath )
        {
            throw "$($MyInvocation.MyCommand.Name): only on of the parameterrs -CalendarPath or -Directory can be used"
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

        if ( $Directory -eq '/' -and !$WorkflowPath -and !$RegularExpression -and !$Recursive )
        {
            $Recursive = $True
        }

        if ( $WorkingDays )
        {
            $type = 'WORKINGDAYSCALENDAR'
        }

        if ( $NonWorkingDays )
        {
            $type = 'NONWORKINGDAYSCALENDAR'
        }

        if ( $CalendarPath )
        {
            $calendarPaths += $CalendarPath
        } elseif ( $Directory ) {
            $objFolder = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'folder' -value $Directory -InputObject $objFolder
            Add-Member -Membertype NoteProperty -Name 'recursive' -value ($Recursive -eq $True) -InputObject $objFolder

            $folders += $objFolder
        }
    }

    End
    {
        if ( $calendarPaths.count -or $folders.count )
        {
            $body = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body

            if ( $Compact )
            {
                Add-Member -Membertype NoteProperty -Name 'compact' -value $True -InputObject $body
            }

            if ( $calendarPaths.count )
            {
                Add-Member -Membertype NoteProperty -Name 'calendars' -value $calendarPaths -InputObject $body
            }

            if ( $folders.count )
            {
                Add-Member -Membertype NoteProperty -Name 'folders' -value $folders -InputObject $body
            }

            if ( $type )
            {
                Add-Member -Membertype NoteProperty -Name 'type' -value $type -InputObject $body
            }

            if ( $RegularExpression )
            {
                Add-Member -Membertype NoteProperty -Name 'regex' -value $RegularExpression -InputObject $body
            }

            [string] $requestBody = $body | ConvertTo-Json -Depth 100
            $response = Invoke-JobSchedulerWebRequest -Path '/calendars' -Body $requestBody

            if ( $response.StatusCode -eq 200 )
            {
                $returnCalendars = ( $response.Content | ConvertFrom-JSON ).calendars
            } else {
                throw ( $response | Format-List -Force | Out-String )
            }

            $returnCalendars | Select-Object -Property `
                               @{name='calendarPath'; expression={$_.path}}, `
                               from, `
                               id, `
                               includes, `
                               name, `
                               path, `
                               title, `
                               to, `
                               type
        }

        if ( $returnCalendars.count )
        {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): $($returnCalendars.count) calendars found"
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no calendars found"
        }

        Trace-JobSchedulerStopWatch -CommandName $MyInvocation.MyCommand.Name -StopWatch $stopWatch
    }
}

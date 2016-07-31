Function New-JobSchedulerHolidays
{
<#
.SYNOPSIS
This cmdlet creates an XML holiday document that can be used to specifiy
non-working days for start time calculation of jobs and orders.

.DESCRIPTION
There are some use cases for start time calculation that exceed the
scope of run-time settings offered by JobScheduler:

* run a job each second first/last working day of a month, quarter or year
** JobScheduler considers the second first/last day (not: working day)
** JobScheduler considers working days based on individual calendars only after having applied the countdown
* run a job every second day during a period of e.g. a month, quarter, year
** JobScheduler re-calculates the run-time with the begin of a new period
** Periods start each day at midnight, therefore no longer periods can be used.

This cmdlet can be used to create an XML document with non-working days that are considered

* before counting a number of first/last working days.
* for start dates that are repeated each number of days, e.g. start a job every 3 days.

The recommended steps include to 

* use this cmdlet to create a holiday output file with complementary non-working days.
** PS C:\> New-Holidays -Select last -Days 2 -Interval month -ToDate '2016-12-31'
* store the output file below the "live" directory with the subfolder that contains the respective job or order.
** PS C:\> New-Holidays -Select last -Days 2 -Interval month -ToDate '2016-12-31' -OutputFile ./my_jobs/my_jobs_holidays.xml
* have the job, order or schedule run-time 
** specify a run-time rule for "any weekday", optionally limited to a number of weekdays as e.g. Mon-Fri.
** include the output file via <include/>, optionally in addition to some global holiday file like this:

    <holidays>
        <include  live_file="public_holidays.xml"/>
        <include  live_file="some_order_holidays.xml"/>
    </holidays>

With the assignment of the complementary holidays output file it is sufficient to set the start date
of a run-time to e.g. the 1st day before ultimo and to include the when_holiday="previous_non_holiday"
setting like this:

    <ultimos>
        <day  day="1">
            <period  single_start="05:00"  when_holiday="previous_non_holiday"/>
        </day>
    </ultimos>

.PARAMETER Select
Specifies the selection of days that is either counted from the begin or from the end of 
the given interval, e.g. a week, a month, a year:

* first: select days to be counted from the begin of the interval
* last: select days to be counted from the end of the interval
* next: select days to be repeatedly counted within the interval

This parameter is used with the -Days and -Interval parameters to specify the direction in which 
start dates are calculated for an interval, e.g. days at begin of each month or days before the end of each month.

.PARAMETER Days
Specifies the number of days starting from or ending with each interval 
that are used to calculate the next start date.

This parameter is used with the -Select and -Interval parameters to specify the number of days that 
are calculated for an interval.

.PARAMETER Interval
Specifies the interval for which start dates are calculated:

* week: calculates the selected working days starting from or ending with each week
* month: calculates the selected working days starting from or ending with each month
* quarter: calculates the selected working days starting from or ending with each quarter
* year: calculates the selected working days starting from or ending with each year

This parameter is used with the -Select and -Days parameters to specify 
the interval for which start dates are caluclated, e.g. a number of working days before end of each month.

.PARAMETER Weekdays
Optionally specifies a list of weekdays for which jobs or job chains can be started.

Weekdays kann be specified either by numbers 1..7 or by literals that are separated by a comma:

* -Weekdays 1,2,3,4,5
* -Weekdays Monday,Tuesday,Wednesday,Thursday,Friday

Both settings exclude Saturday and Sunday for which days the cmdlet will create non-working days.

.PARAMETER NonWorkingWeekdays
Optionally specifies a list of weekdays for which jobs or job chains cannot be started.

Weekdays kann be specified either by numbers 1..7 or by literals that are separated by a comma:

* -NonWorkingWeekdays 6,7
* -NonWorkingWeekdays Saturday,Sunday

Both settings specify Saturday and Sunday for which days the cmdlet will create non-working days.

This parameter is used as an alternative to the -Weekdays parameter. Both parameters provide the
same result, however, in some use cases it might be more appropriate to specify included weekdays
whereas for other use cases specifying excluded weekdays might be preferable.

.PARAMETER FromDate
Specifies the lower bound of the date range for which non-working days are calculated.

If this parameter is not specified then the current date is assumed.

Default: current date

.PARAMETER ToDate
Specifies the upper bound of the date range for which non-working days are calculated.

.PARAMETER HolidayFiles
Optionally specifies the path and name for a number of global holiday files that are in use by JobScheduler.
Global non-working days from a holiday file are applied to the calculation of the next start date
by this cmdlet without being added to its output.

.PARAMETER OutputFile
Optionally specifies an output file that contains the resulting XML configuration 
for non-working days.

.PARAMETER Append
Optionally specifies the newly calculated non-working days to be appended
to an existing output file that is specified by use of the -OutputFile parameter.

.EXAMPLE
New-JobSchedulerHolidays -Select first -Days 2 -Interval year -ToDate '2018-12-31'

Calculates the non-working days for the second woring kday of each year from the current date until end of 2018.

.EXAMPLE
New-JobSchedulerHolidays -Select first -Days 3 -Interval quarter -FromDate '2016-01-01' -ToDate '2018-12-31'

Calculates the non-working days for the third working day of each quarter from the specified date until end of 2018.

.EXAMPLE
New-JobSchedulerHolidays -Select first -Days 3 -Interval month -FromDate '2016-01-01' -ToDate '2018-12-31'

Calculates the non-working days for the third working day of each month from the specified date until end of 2018.

.EXAMPLE
New-JobSchedulerHolidays -Select last -Days 3 -Interval quarter -FromDate '2016-01-01' -ToDate '2018-12-31'

Calculates the non-working days for the third last working day of each quarter from the specified date until end of 2018.

.EXAMPLE
New-JobSchedulerHolidays -Select last -Days 3 -Interval month -FromDate '2016-01-01' -ToDate '2018-12-31'

Calculates the non-working days for the third last working day of each month from the specified date until end of 2018.

.EXAMPLE
New-JobSchedulerHolidays -Select last -Days 3 -Interval year -FromDate '2016-01-01' -ToDate '2018-12-31'

Calculates the non-working days for the third last working day of each year from the specified date until end of 2018.

.EXAMPLE
New-JobSchedulerHolidays -Select last -Days 2 -Interval week -NonWorkingWeekdays 6,7 -FromDate '2016-01-01' -ToDate '2018-12-31'

Calculates the non-working days for the second last working day of each week (excluding Saturday and Sunday) from the specified date until end of 2018.

.EXAMPLE
$holidayFile = "$($env:ProgramFiles)\sos-berlin.com\jobscheduler\scheduler110\scheduler_data\config\live\globals\global_holidays.xml"
New-JobSchedulerHolidays -Select first -Days 2 -Interval year -FromDate '2016-01-01' -ToDate '2018-12-31' -HolidayFiles $holidayFile

Calculates the non-working days for the second working day of each year from the specified date until end of 2018
and considers non-working days from a global holidays file.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateSet('first','last','next')] [string] $Select,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [int] $Days,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateSet('week','month','quarter','year')] [string] $Interval,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string[]] $Weekdays,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string[]] $NonWorkingWeekdays,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [datetime] $FromDate = (Get-Date).Date,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [datetime] $ToDate,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string[]] $HolidayFiles,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OutputFile,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Append
)

    Begin
    {
        if ( $Days -le 0 )
        {
            throw "$($MyInvocation.MyCommand.Name): positive value for number of days expected, use -Days"
        }

        $globalHolidays = New-Object PSObject
        $globalHolidays | Add-Member -Membertype NoteProperty -Name Weekdays -Value @()
        $globalHolidays | Add-Member -Membertype NoteProperty -Name Dates -Value @()

        [xml] $SCRIPT:xmlDoc  = "<?xml version='1.0' encoding='ISO-8859-1'?><holidays/>"
        $SCRIPT:holidaysNode = $xmlDoc.CreateElement( 'holidays' )

        function get-HolidaysIndex( [string] $selectIndex, [int] $daysIndex, [datetime] $fromDateIndex, [datetime] $toDateIndex )
        {
            Write-Debug ".. $($MyInvocation.MyCommand.Name): get-Holidays -SelectIndex $selectIndex -daysIndex $daysIndex -fromDateIndex $fromDateIndex -toDateIndex $toDateIndex"

            if ( $selectIndex -eq 'first' )
            {
                for( $workingDayIndex = 0; $workingDayIndex -lt $daysIndex; $workingDayIndex++ )
                {
                    $isWorkingDay = $false
        
                    while( !$isWorkingDay -and ( $fromDateIndex -lt $toDateIndex ) )
                    {
                        if ( ( $globalHolidays.Weekdays -contains $fromDateIndex.DayOfWeek ) -or ( $globalHolidays.Dates -contains (Get-Date $fromDateIndex -format 'yyyy-MM-dd') ) )
                        {
                            $fromDateIndex = $fromDateIndex.AddDays( 1 )
                        } else {
                            $isWorkingDay = $true

                            if ( $workingDayIndex -lt $daysIndex-1 )
                            {
                                $holidayNode = $xmlDoc.CreateElement( 'holiday' )
                                $holidayNode.SetAttribute( 'date', (Get-Date $fromDateIndex -format 'yyyy-MM-dd') )
                                $SCRIPT:holidaysNode.AppendChild( $holidayNode ) | Out-Null
                            }
                        }
                    }
    
                    $fromDateIndex = $fromDateIndex.AddDays( 1 )
                }

                Write-Verbose ".... $($MyInvocation.MyCommand.Name): next start date: $($fromDateIndex.AddDays( -1 ) )"

            } elseif ( $selectIndex -eq 'last' ) {
                for( $workingDayIndex = $daysIndex; $workingDayIndex -gt 0; $workingDayIndex-- )
                {
                    $isWorkingDay = $false
        
                    while( !$isWorkingDay -and ( $toDateIndex -gt $fromDateIndex ) )
                    {
                        if ( ( $globalHolidays.Weekdays -contains $toDateIndex.DayOfWeek ) -or ( $globalHolidays.Dates -contains (Get-Date $toDateIndex -format 'yyyy-MM-dd') ) )
                        {
                            $toDateIndex = $toDateIndex.AddDays( -1 )
                        } else {
                            $isWorkingDay = $true
                            
                            if ( $workingDayIndex -gt 1 )
                            {
                                $holidayNode = $xmlDoc.CreateElement( 'holiday' )
                                $holidayNode.SetAttribute( 'date', (Get-Date $toDateIndex -format 'yyyy-MM-dd') )
                                $SCRIPT:holidaysNode.AppendChild( $holidayNode ) | Out-Null
                            }
                        }
                    }
    
                    $toDateIndex = $toDateIndex.AddDays( -1 )
                }

                Write-Verbose ".... $($MyInvocation.MyCommand.Name): next start date: $($toDateIndex.AddDays( 1 ) )"
                
            } elseif ( $selectIndex -eq 'next' ) {
                while( $fromDateIndex -lt $toDateIndex )
                {
                    for( $workingDayIndex = 0; $workingDayIndex -lt $daysIndex; $workingDayIndex++ )
                    {
                        $isWorkingDay = $false
            
                        while( !$isWorkingDay -and ( $fromDateIndex -lt $toDateIndex ) )
                        {
                            if ( ( $globalHolidays.Weekdays -contains $fromDateIndex.DayOfWeek ) -or ( $globalHolidays.Dates -contains (Get-Date $fromDateIndex -format 'yyyy-MM-dd') ) )
                            {
                                $fromDateIndex = $fromDateIndex.AddDays( 1 )
                            } else {
                                $isWorkingDay = $true
                                
                                if ( $workingDayIndex -lt $daysIndex-1 )
                                {
                                    $holidayNode = $xmlDoc.CreateElement( 'holiday' )
                                    $holidayNode.SetAttribute( 'date', (Get-Date $fromDateIndex -format 'yyyy-MM-dd') )
                                    $SCRIPT:holidaysNode.AppendChild( $holidayNode ) | Out-Null
                                } else {
                                }
                            }
                        }
                        $fromDateIndex = $fromDateIndex.AddDays( 1 )
                    }
                }

                Write-Verbose ".... $($MyInvocation.MyCommand.Name): next execution date: $($fromDateIndex.AddDays( 1 ) )"
            }
        }
        
        function Write-Xml( $xmlDoc, $filePath )
        {
            # Due to a bug with the XMLWriter we have to expand relative paths
            if ( $filePath.startsWith( '.' ) )
            {
                $filePath = $pwd.path + '/' + $filePath
            }
        
            [System.XML.XmlWriterSettings] $xmlSettings = New-Object System.XML.XmlWriterSettings
            $xmlSettings.Encoding = [System.Text.Encoding]::GetEncoding("ISO-8859-1")
            $xmlSettings.Indent = $true
            $xmlSettings.NewLineChars = "`n"
            $xmlWriter = [Xml.XmlWriter]::Create( $filePath, $xmlSettings )
            $xmlDoc.Save( $xmlWriter )
            $xmlWriter.Close()
        }
    }
    
    Process
    {
        if ( $Weekdays )
        {
            [System.Collections.ArrayList] $defaultWeekdays = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')
            foreach( $weekday in $Weekdays )
            {
                switch( $weekday )
                {
                    '1'    {
                            $weekday = 'Monday'
                            break
                        }
                    '2' {
                            $weekday = 'Tuesday'
                            break
                        }
                    '3' {
                            $weekday = 'Wednesday'
                            break
                        }
                    '4' {
                            $weekday = 'Thursday'
                            break
                        }
                    '5' {
                            $weekday = 'Friday'
                            break
                        }
                    '6' {
                            $weekday = 'Saturday'
                            break
                        }
                    '7' {
                            $weekday = 'Sunday'
                            break
                        }
                }
                
                if ( $defaultWeekdays -contains $weekday )
                {
                    $defaultWeekdays.remove( $weekday )
                } else {
                    throw "$($MyInvocation.MyCommand.Name): illegal value for weekday specified: -Weekday $($weekday)"
                }
            }
            
            foreach( $weekday in $defaultWeekdays )
            {
                $globalHolidays.Weekdays += $weekDay
            }
        }
 
        if ( $NonWorkingWeekdays )
        {
            [System.Collections.ArrayList] $defaultWeekdays = @('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')
            foreach( $weekday in $NonWorkingWeekdays )
            {
                switch( $weekday )
                {
                    '1'    {
                            $weekday = 'Monday'
                            break
                        }
                    '2' {
                            $weekday = 'Tuesday'
                            break
                        }
                    '3' {
                            $weekday = 'Wednesday'
                            break
                        }
                    '4' {
                            $weekday = 'Thursday'
                            break
                        }
                    '5' {
                            $weekday = 'Friday'
                            break
                        }
                    '6' {
                            $weekday = 'Saturday'
                            break
                        }
                    '7' {
                            $weekday = 'Sunday'
                            break
                        }
                }
        
                if ( $defaultWeekdays -contains $weekday )
                {
                    $globalHolidays.Weekdays += $weekDay
                } else {
                    throw "$($MyInvocation.MyCommand.Name): illegal value for non-working weekday specified: -NonWorkingWeekday $($weekday)"
                }
            }
        }
 
        foreach( $holidayFile in $HolidayFiles )
        {
            [xml] $holidaysDocXml = Get-Content $holidayFile

            $weekdayHolidayNodes = Select-XML -XML $holidaysDocXml -Xpath '/holidays/weekdays/day'
            foreach( $weekdayHolidaysNode in $weekdayHolidayNodes )
            {
                if ( !$weekdaHolidayNode.Node.day )
                {
                    break
                }
                
                $holidayWeekdays = ($weekdayHolidaysNode.Node.day).split(' ')
                foreach( $holidayWeekday in $holidayWeekdays )
                {
                    switch( $holidayWeekday )
                    {
                        '0' {
                                $globalHolidays.Weekdays += 'Sunday'
                                break
                            }
                        '1' {
                                $globalHolidays.Weekdays += 'Monday'
                                break
                            }
                        '2' {
                                $globalHolidays.Weekdays += 'Tuesday'
                                break
                            }
                        '3' {
                                $globalHolidays.Weekdays += 'Wednesday'
                                break
                            }
                        '4' {
                                $globalHolidays.Weekdays += 'Thursday'
                                break
                            }
                        '5' {
                                $globalHolidays.Weekdays += 'Friday'
                                break
                            }
                        '6' {
                                $globalHolidays.Weekdays += 'Saturday'
                                break
                            }
                        '7' {
                                $globalHolidays.Weekdays += 'Sunday'
                                break
                            }
                    }
                }
            }

            $dateHolidayNodes = Select-XML -XML $holidaysDocXml -Xpath '/holidays/holiday'
            foreach( $dateHolidayNode in $dateHolidayNodes )
            {
                $globalHolidays.Dates += $dateHolidayNode.Node.date
            }
        }

        if ( $Append -and $OutputFile -and ( Test-Path $OutputFile -PathType Leaf ) )
        {
            [xml] $SCRIPT:xmlDoc = Get-Content $OutputFile
            $SCRIPT:holidaysNode = $xmlDoc.holidays
            $holidayCount = $SCRIPT:holidaysNode.SelectNodes( 'Holiday' ).count
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): found $($holidayCount) holiday entries from existing output file: $($OutputFile)"
        }
            
        switch( $Interval )
        {
            'week'      {
                            $fromDateIndex = $FromDate
                            switch( $fromDateIndex.DayOfWeek )
                            {
                                'Tuesday'     {
                                                $fromDateIndex = $fromDateIndex.AddDays(-1)
                                                break
                                            }
                                'Wednesday'    {
                                                $fromDateIndex = $fromDateIndex.AddDays(-2)
                                                break
                                            }
                                'Thursday'     {
                                                $fromDateIndex = $fromDateIndex.AddDays(-3)
                                                break
                                            }
                                'Friday'     {
                                                $fromDateIndex = $fromDateIndex.AddDays(-4)
                                                break
                                            }
                                'Saturday'     {
                                                $fromDateIndex = $fromDateIndex.AddDays(-5)
                                                break
                                            }
                                'Sunday'     {
                                                $fromDateIndex = $fromDateIndex.AddDays(-6)
                                                break
                                            }
                            }

                            for( $fromDateIndex = $FromDate; $fromDateIndex -le $ToDate; $fromDateIndex = $fromDateIndex.AddDays( 7 ) )
                            {
                                $startDate = $fromDateIndex
                                if ( $startDate -lt $FromDate )
                                {
                                    $startDate = $FromDate
                                }
                                
                                $endDate = $startDate.AddDays(7)
                                if ( $endDate -gt $ToDate )
                                {
                                    break
                                }
                                
                                get-HolidaysIndex -SelectIndex $Select -DaysIndex $Days -FromDateIndex $startDate -ToDateIndex $endDate
                            }
                            
                            break
                        }
            'month'     {
                            for( $fromDateIndex = $FromDate; $fromDateIndex -le $ToDate; $fromDateIndex = $fromDateIndex.AddMonths(1) )
                            {
                                $startDate = Get-Date -Date "$($fromDateIndex.Year)-$($fromDateIndex.Month)-01"
                                $endDate = $startDate.AddMonths(1).AddDays(-1)
                                if ( $endDate -gt $ToDate )
                                {
                                    break
                                }
                                get-HolidaysIndex -SelectIndex $Select -DaysIndex $Days -FromDateIndex $startDate -ToDateIndex $endDate
                            }
                            
                            break
                        }
            'quarter'   {
                            $fromDateIndex = $FromDate
                            switch( $fromDateIndex )
                            {
                                '2'     {
                                            $fromDateIndex.AddMonths(-1)
                                            break
                                        }
                                '3'     {
                                            $fromDateIndex.AddMonths(-2)
                                            break
                                        }
                                '5'     {
                                            $fromDateIndex.AddMonths(-1)
                                            break
                                        }
                                '6'     {
                                            $fromDateIndex.AddMonths(-2)
                                            break
                                        }
                                '8'     {
                                            $fromDateIndex.AddMonths(-1)
                                            break
                                        }
                                '9'     {
                                            $fromDateIndex.AddMonths(-2)
                                            break
                                        }
                                '11'    {
                                            $fromDateIndex.AddMonths(-1)
                                            break
                                        }
                                '12'    {
                                            $fromDateIndex.AddMonths(-2)
                                            break
                                        }
                            }
                            
                            $fromDateIndex = Get-Date -Date "$($fromDateIndex.Year)-$($fromDateIndex.Month)-01"

                            for( $fromDateIndex; $fromDateIndex -le $ToDate; $fromDateIndex = $fromDateIndex.AddMonths(3) )
                            {
                                $startDate = Get-Date -Date "$($fromDateIndex.Year)-$($fromDateIndex.Month)-01"
                                $endDate = $startDate.AddMonths(3).AddDays(-1)
                                if ( $endDate -gt $ToDate )
                                {
                                    break
                                }
                                
                                get-HolidaysIndex -SelectIndex $Select -DaysIndex $Days -FromDateIndex $startDate -ToDateIndex $endDate
                            }
                            
                            break
                        }
            'year'      {
                            for( $fromDateIndex = $FromDate; $fromDateIndex -le $ToDate; $fromDateIndex = $fromDateIndex.AddYears(1) )
                            {
                                $startDate = $fromDateIndex
                                $endDate = Get-Date -Date "$($startDate.Year)-12-31"
                                if ( $endDate -gt $ToDate )
                                {
                                    break
                                }

                                get-HolidaysIndex -SelectIndex $Select -DaysIndex $Days -FromDateIndex $startDate -ToDateIndex $endDate
                            }
                            
                            break
                        }
        }
        
        $xmlDoc.RemoveAll()
        $xmlDecl = $xmlDoc.CreateXmlDeclaration( '1.0', 'ISO-8859-1', $null )
        $xmlDoc.InsertBefore( $xmlDecl, $xmlDoc.DocumentElement ) | Out-Null
        $xmlDoc.AppendChild( $SCRIPT:holidaysNode ) | Out-Null
        
        if ( $OutputFile )
        {
            Write-Xml $xmlDoc $OutputFile
        }
        
        $xmlDoc
    }
}

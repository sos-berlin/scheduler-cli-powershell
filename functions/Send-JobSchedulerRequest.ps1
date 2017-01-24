function Send-JobSchedulerRequest
{
<#
.SYNOPSIS
Sends a JSON request or XMl command to the JobScheduler Web Service.

.DESCRIPTION
The JobScheduler Web Service accepts JSON requests and a number of XML commands.

This cmdlet accepts 

* JSON requests and forwards them to the JOC Cockpit REST Web Service.
* XML commands and forwards them to the JobScheduler REST Web Service.

.PARAMETER Path
The Path specifies the part of URL that states the operation that is used for the request,
see http://test.sos-berlin.com/JOC/raml-doc/JOC-API/ for a complete list of Paths.

The Path is prefixed by the Base parameter.

* Example: http://localhost:4446/joc/api/tasks/history
* The URL scheme (http) and authority (localhost:4446) are used from the connection
that is specified to the Web Service by the Use-JobSchedulerWebService cmdlet.
* The Base (/joc/api) is used for all web service requests.
* The Path (/tasks/history) is used to query the JobScheduler history.

.PARAMETER Base
The Base is used as a prefix to the Path for the URL and is configured with the web server
that hosts the JobScheduler Web Service.

This value is fixed and should not be modified for most use cases.

Default: /joc/api

.PARAMETER Body
Specifies the JSON elements or XML command to be executed.

* Example JSON request
** URL: http://localhost:4446/joc/api/tasks/history
** JSON Body
{
    "jobschedulerId": "jobscheduler_prod",
    "compact": "true",
    "limit": 1000
}
** The JobScheduler ID is specified to which the request is addressed. The request queries the recent task history for a maximum of 1000 entries.
* Example XML command
** URL: http://localhost:4446/joc/api/jobscheduler/commands
** XML Body
<show_state/>
** XML Body
<jobscheduler_commands jobschedulerId="jobscheduler_prod"><show_state/></jobscheduler_commands>
** The XML body can use the <jobscheduler_commands> element to specify the JobScheduler ID,
otherwise the JobScheduler ID is used from the Use-JobSchedulerWebService cmdlet or from the Id parameter.

.PARAMETER Id
The Id specifies the JobScheduler ID that identifies an individual JobScheduler Master.

This Id is used to addresse the JobScheduler Master that should execute the request.

If no Id is specified then the JobScheduler ID is used from the Use-JobSchedulerWebService cmdlet. 

.PARAMETER Method
This parameter specifies the HTTP method in use.

There should be no reason to modify the default value.

Default: POST

.PARAMETER ContentType
The HTTP content type is

* application/json for JSON requests
* application/xml for XML commands

The content type is automatically adjusted by the cmdlet if XML commands are used.

Default: application/json

.PARAMETER Headers
A hashmap can be specified with name/value pairs for HTTP headers.

.OUTPUTS
This cmdlet returns the JobScheduler response.

.EXAMPLE
$historyJson = Send-JobSchedulerRequest -Path '/tasks/history' -Body '{"jobschedulerId": "jobscheduler_prod", "compact": "true", "limit": 1000}'

Returns the recent task history entries up to a limit of 1000 items for a JobScheduler Master with ID "jobscheduler_prod"

.EXAMPLE
$stateXml = Send-JobSchedulerRequest '/jobscheduler/commands' '<show_state/>'

Returns summary information and inventory of jobs and job chains.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Path,
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Body,
    [Parameter(Mandatory=$false,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Id,
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Base = '/joc/api',
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $Method = 'POST',
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [string] $ContentType = 'application/json',
    [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Headers = @{}
)

    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-StopWatch
    }

    Process
    {
        if ( !$Path )
        {
            throw "$($MyInvocation.MyCommand.Name): no path specified, use -Path"
        }
        
        if ( !$Body )
        {
            throw "$($MyInvocation.MyCommand.Name): no body specified, use -Body"
        }
        
        if ( !$Path.startsWith( '/' ) )
        {
            $Path = '/' + $Path
        }

        if ( $Id )
        {
            $requestId = $Id
        } else {
            $requestId = $jsWebService.ID
        }
        
        # handle XML and JSON requests
        if ( $Body.startsWith( '<' ) )
        {
            if ( $Body -contains '<jobscheduler_commands' )
            {
                # leave body untouched
            } else {
                $Body = "<jobscheduler_commands jobschedulerId='$($requestId)'>$($Body)</jobscheduler_commands>"
            }

            $ContentType = 'application/xml'
        }
        
        $requestUrl = $jsWebService.Url.scheme + '://' + $jsWebService.Url.Authority + $Base + $Path
        
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending request to JobScheduler $($requestUrl)"
        Write-Debug ".. $($MyInvocation.MyCommand.Name): sending request: $body"
        
        Send-JobSchedulerWebServiceRequest -Url $requestUrl -Method $Method -ContentType $ContentType -Body $Body -Headers $Headers
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }

}

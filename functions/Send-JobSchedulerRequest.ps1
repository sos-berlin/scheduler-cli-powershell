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
  that is specified to the Web Service by the Connect-JobScheduler cmdlet.
* The Base (/joc/api) is used for all web service requests.
* The Path (/tasks/history) is used to query the JobScheduler task history.

.PARAMETER Body
Specifies the JSON elements or XML command that are sent to the Web Service.

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
otherwise the JobScheduler ID is used from the Connect-JobScheduler cmdlet or from the -Id parameter.

.PARAMETER Id
The Id specifies the JobScheduler ID that identifies an individual JobScheduler Master.
This Id is used to addresse the JobScheduler Master that should execute the request.

If no Id is specified then the JobScheduler ID is used from the Connect-JobScheduler cmdlet. 

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
Typicall the Accept header is required for use of the REST API.

.PARAMETER AuditComment
Specifies a free text that indicates the reason for the current intervention, 
e.g. "business requirement", "maintenance window" etc.

The Audit Comment is visible from the Audit Log view of JOC Cockpit.
This parameter is not mandatory, however, JOC Cockpit can be configured 
to enforece Audit Log comments for any interventions.

.PARAMETER AuditTimeSpent
Specifies the duration in minutes that the current intervention required.

This information is visible with the Audit Log view. It can be useful when integrated
with a ticket system that logs the time spent on interventions with JobScheduler.

.PARAMETER AuditTicketLink
Specifies a URL to a ticket system that keeps track of any interventions performed for JobScheduler.

This information is visible with the Audit Log view of JOC Cockpit. 
It can be useful when integrated with a ticket system that logs interventions with JobScheduler.

.OUTPUTS
This cmdlet returns the REST Web Service response.

.EXAMPLE
$response = Send-JobSchedulerRequest -Path '/tasks/history' -Body '{"jobschedulerId": "jobscheduler_prod", "compact": "true", "limit": 1000}' -Headers @{'Accept' = 'application/json'}

Returns the recent task history entries up to a limit of 1000 items for a JobScheduler Master with ID "jobscheduler_prod"

.EXAMPLE
$response = Send-JobSchedulerRequest -Path '/jobscheduler/commands' -Body '<show_state/>'

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
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Id,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Method = 'POST',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ContentType = 'application/xml',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $Headers = @{'Accept' = 'application/xml'},
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
        $stopWatch = Start-StopWatch

        if ( !$AuditComment -and ( $AuditTimeSpent -or $AuditTicketLink ) )
        {
            throw "Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
        }
    }

    Process
    {
        if ( !$Path.startsWith( '/' ) )
        {
            $Path = '/' + $Path
        }

        if ( $Id )
        {
            $requestId = $Id
        } else {
            $requestId = $script:jsWebService.jobSchedulerId
        }

        # gradefully modify Content-Type and Accept headers for JSON-based requests
        if ( $ContentType -eq 'application/xml' -and $Body.startsWith( '{') )
        {
            $ContentType = 'application/json'
            
            if ( $Headers.Accept -eq 'application/xml' )
            {
                $Headers.Accept = 'application/json'
            }
        }

        if ( $ContentType -eq 'application/xml' )
        {
            Invoke-JobSchedulerWebRequestXmlCommand -Method $Method -ContentType $ContentType -Command $Body -Headers $Headers -IgnoreResponse
        } else {
            Invoke-JobSchedulerWebRequest -Path $Path -Method $Method -ContentType $ContentType -Body $Body -Headers $Headers
        }
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

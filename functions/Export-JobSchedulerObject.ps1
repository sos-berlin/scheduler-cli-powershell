function Export-JobSchedulerObject
{
<#
.SYNOPSIS
Export an XML configuration object such as a job, a job chain etc. from JOC Cockpit.

.DESCRIPTION
This cmdlet exports an XML configuration object that is stored with JOC Cockpit.

.PARAMETER Name
Specifies the name of the object, e.g. a job name.

.PARAMETER Directory
Specifies the directory in JOC Cockpit in which the object is available.

.PARAMETER Type
Specifies the object type which is one of: 

* JOB
* JOBCHAIN
* ORDER
* PROCESSCLASS
* AGENTCLUSTER
* LOCK
* SCHEDULE
* MONITOR
* NODEPARAMS
* HOLIDAYS

.PARAMETER File
Specifies the XML file that the exported configuration object is written to.

.PARAMETER ForeLive
Specifies that the XML configuration object is not used from JOC Cockpit but is retrieved from the Master's "live" folder. 
This option can be used to ensure that no draft versions of configurations objects are exported but objects only that
have been deployed to a Master.

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
This cmdlet accepts pipelined job objects that are e.g. returned from a Get-Job cmdlet.

.OUTPUTS
This cmdlet returns the XML configuration object.

.EXAMPLE
$jobXml = Export-JobSchedulerObject -Name job174 -Directory /some/directory -Type JOB

Returns the exported job configuration from the specified directory.

.EXAMPLE
Export-JobSchedulerObject -Name job174 -Directory /some/directory -Type JOB -File /tmp/job174.job.xml | Out-Null

Exports the XML job configuration to the specified file.

.LINK
about_jobscheduler

#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Name,
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$True,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [ValidateSet('JOB','JOBCHAIN','ORDER','PROCESSCLASS','AGENTCLUSTER','LOCK','SCHEDULE','WORKINGDAYSCALENDAR','NONWORKINGDAYSCALENDAR','FOLDER','JOBSCHEDULER','DOCUMENTATION','MONITOR','NODEPARAMS','HOLIDAYS','JOE','OTHER')]
    [string] $Type,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $File,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $ForceLive,
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
            throw "$($MyInvocation.MyCommand.Name): Audit Log comment required, use parameter -AuditComment if one of the parameters -AuditTimeSpent or -AuditTicketLink is used"
        }
    }
    
    Process
    {
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
    
        if ( $Name )
        {
            if ( (Get-JobSchedulerObject-Basename $Name) -ne $Name ) # name includes a directory
            {
                $Directory = Get-JobSchedulerObject-Parent $Name
            } else { # name includes no directory
            }


            $body = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'jobschedulerId' -value $script:jsWebService.JobSchedulerId -InputObject $body
            
            if ( $Directory.endsWith('/') )
            {
                Add-Member -Membertype NoteProperty -Name 'path' -value "$($Directory)$($Name)" -InputObject $body
            } else {
                Add-Member -Membertype NoteProperty -Name 'path' -value "$($Directory)/$($Name)" -InputObject $body
            }
            
            Add-Member -Membertype NoteProperty -Name 'objectType' -value $Type -InputObject $body

            if ( $ForceLive )
            {
                Add-Member -Membertype NoteProperty -Name 'forceLive' -value $True -InputObject $body
            }
    
            [string] $requestBody = $body | ConvertTo-Json -Depth 100
            $response = Invoke-JobSchedulerWebRequest -Path '/joe/read/file' -Body $requestBody
            
            if ( $response.StatusCode -eq 200 )
            {
                $objCustom = ( $response.Content | ConvertFrom-JSON ).configuration
                
                if ( !$objCustom )
                {
                    throw ( $response | Format-List -Force | Out-String )
                }
            } else {
                throw ( $response | Format-List -Force | Out-String )
            }

            [string] $requestBody = $objCustom | ConvertTo-Json -Depth 100
            $response = Invoke-JobSchedulerWebRequest -Path "/joe/$Type/toxml" -Body $requestBody
            
            if ( $response.StatusCode -eq 200 )
            {
                [XML] $objXml = $response.Content
                
                if ( !$objXml )
                {
                    throw ( $response | Format-List -Force | Out-String )
                }
            } else {
                throw ( $response | Format-List -Force | Out-String )
            }
            
            if ( $File )
            {
                [System.XML.XmlWriterSettings] $xmlWriterSettings = New-Object System.XML.XmlWriterSettings
                $xmlWriterSettings.Encoding = [System.Text.Encoding]::GetEncoding("UTF-8")
                $xmlWriterSettings.Indent = $true
                $xmlWriterSettings.NewLineChars = "`n"
                $xmlWriter = [Xml.XmlTextWriter]::Create( $File, $xmlWriterSettings )
                $objXml.WriteTo( $XmlWriter )
                $xmlWriter.Close()
            }
            
            $objXml

            Write-Verbose ".. $($MyInvocation.MyCommand.Name): object exported"                
        } else {
            Write-Verbose ".. $($MyInvocation.MyCommand.Name): no object exported"                
        }
    }

    End
    {
        Log-StopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

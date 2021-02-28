function ConvertFrom-JobSchedulerXml
{
<#
.SYNOPSIS
Converts JobScheduler 1.x objects to a JSON format for migration to JS7 releases (JobScheduler 2.x)

.DESCRIPTION
JS7 (JobScheduler 2.0) is the successor product to JobScheduler 1.x. As JS7 makes use of a JSON format
for workflows and related objects a conversion is performed by this cmdlet.

The cmdlet converts and exports JobScheduler 1.x objects to an OS directory and stores them in a JSON format.
In addition, the converted objects can be added to a .zip archive for direct import into JS7.

PREREQUISITES

The cmdlet makes use of API version 1.13.5 or later, i.e. it can be used with a JobScheduler release 1.13.5 or later.
Use with earlier JobScheduler releases is possible within limits of converted object types, however,
this is not in scope of testing of the cmdlet by SOS.

The cmdlet can be operated from any machine with a PowerShell version 5.1, 6.x and 7.x.

The cmdlet will access JOC Cockpit and JobScheduler Master running on the same or on a remote machine.
For operation of the cmdlet both ports for JOC Cockpit and for JobScheduler Master have to be accessible.

OBJECT SELECTION

The cmdlet supports a number of selections of objects based on folders and recursion, by direct specification
of object paths and by pipelining from other cmdlets, e.g. using

    ConvertFrom-JobSchedulerXml -ArchivePath /tmp/export.zip -JobChain /product_demo/shell_chain
    ConvertFrom-JobSchedulerXml -ArchivePath /tmp/export.zip -Directory /product_demo -Recursive
    Get-JobSchedulerJob -IsStandaloneJob -Directory /product_demo | ConvertFrom-JobSchedulerXml -ArchivePath /tmp/export.zip

STANDALONE JOBS

JS7 considers standalone jobs being workflows with a single job node.
Therefore, migrating standalone jobs results in one workflow per job.
For each workflow created a schedule is added with the path and name of the job.

JOB CHAINS

JobScheduler 1.x job chains are migrated to JS7 workflows. A JS7 workflow includes both the job nodes
and the job configurations. Therefore, migrating job chains includes that the jobs that are referenced
by the respective job chain nodes are migrated to the JS7 workflow.

ORDERS

Consider the change in wording: JobScheduler 1.x orders are migrated to JS7 schedules.
Therefore an order for a job chain maps to a schedule for a workflow in JS7.
Such schedules are used by the Daily Plan service to generate individual orders for the respective dates and times of the Daily Plan.

AGENT CLUSTERS

Consider that converted JobScheduler 1.x Agent Clusters cannot be directly imported with the
import functionality of the JS7 GUI or with the respective Import-JS7InventoryItem cmdlet. Instead, the export archive
created by this cmdlet can be used with the Set-JS7Agent cmdlet to populate the Agent inventory.

For migrating Agent Cluster configuratoins consider two approaches:

* Manually map Agent Cluster to JS7 Agents:
**  $map = @{}
** $map.Add( '/product_demo/Agent_Linux',    @{ 'AgentId' = 'primaryAgent'; 'AgentName' = 'Agent_Linux' } )
**  $map.Add( '/global/Agent_Cluster_Linux',  @{ 'AgentId' = 'primaryAgent'; 'AgentName' = 'Agent_Cluster_Linux_Active_Passive' } )
* Map Agent Clusters from existing configuration:
** $agentMapping = @{}
** $agentClusters = Get-JobSchedulerAgentCluster
** foreach( $agentCluster in $agentClusters )
** {
*** if ( $agentCluster.volatile.agents[0].os.name -eq 'Windows' )
*** {
**** $agentMapping.Add( $agentCluster.agentCluster,  @{ 'AgentId' = 'wintestPrimaryAgent'; 'AgentName' = ([System.IO.Path]::GetFileName( $agentCluster.AgentCluster )) } )
*** } else {
**** $agentMapping.Add( $agentCluster.agentCluster,  @{ 'AgentId' = 'primaryAgent'; 'AgentName' = ([System.IO.Path]::GetFileName( $agentCluster.AgentCluster )) } )
*** }
** }

CONVERSION OUTPUT

The cmdlet can be used to store converted objects in a local directory and to create a .zip archive with converted objects.
The .zip archive can be used for import with JS7.

.PARAMETER ArchivePath
Specifies the name and path of an archive file in .zip format to which converted JobScheduler objects are added.

Independent from the archive file the directory specified with the -OutputDirectory parameter contains converted objects.
The output directory is automatically removed if an archive file is specified with the -ArchivePath parameter.

.PARAMETER Directory
Optionally specifies the folder for which JobScheduler objects should be converted. The directory is determined
from the root folder, i.e. the "live" directory of a JobScheduler Master.

.PARAMETER Recursive
Specifies that any sub-folders should be looked up when used with the -Directory parameter.
By default no sub-folders will be looked up for jobs.

.PARAMETER Job
Optionally specifies the path of a job that should be converted.

Jobs can be retrieved with the Get-JobSchedulerJob cmdlet and can be pipelined
to this cmdlet.

.PARAMETER JobChain
Optionally specifies the path of a job chain that should be converted.

Job Chains can be retrieved with the Get-JobSchedulerJobChain cmdlet and can be pipelined
to this cmdlet.

.PARAMETER JobStream
Optionally specifies the path of a job stream that should be converted.

Job Streams can be retrieved with the Get-JobSchedulerJobStream cmdlet and can be pipelined
to this cmdlet.

.PARAMETER OrderId
Optionally specifies the order ID of of an order that should be converted.

This parameter requires use of the -JobChain parameter to specify the order's job chain.

Orders can be retrieved with the Get-JobSchedulerOrder cmdlet and can be pipelined
to this cmdlet.

.PARAMETER Calendar
Optionally specifies a calendar that should be converted.

Calendars can be retrieved with the Get-JobSchedulerCalendar cmdlet and can be pipelined
to this cmdlet.

.PARAMETER Lock
Optionally specifies a lock that should be converted.

Locks can be retrieved with the Get-JobSchedulerLock cmdlet and can be pipelined
to this cmdlet.

.PARAMETER AgentCluster
Optionally specifies an Agent cluster that should be converted.

Agent Clusters can be retrieved with the Get-JobSchedulerAgentCluster cmdlet and can be pipelined
to this cmdlet.

.PARAMETER OutputDirectory
Specifies the OS directory to which converted JobScheduler objects files (.json) are stored.

By default the directory for temporary files and a unique sub-directory is used.
The output directory can be removed after conversion of objects by use of the
-RemoveOutputDirectory parameter.

.PARAMETER BaseFolder
Optionally specifies a base folder that preceeds the folders created for files with converted objects
and for references within the objects.

This allows to export converted objects to a new folder structure that includes the base folder.

.PARAMETER DefaultAgentName
JS7 requires any jobs to be executed with Agents. Therefore jobs that are executed with a Master
from a JobScheduler 1.x release will use the Agent Name that is specified with this parameter.
Jobs or job chains that are assigned an Agent are not affected by this parameter.

.PARAMETER ForcedAgentName
Specifies an Agent Name that overwrites any Agent assignments in jobs and job chains.

.PARAMETER MappedAgentNames
This parameter performs a mapping of JobScheduler 1.x Agent Clusters to JS7 Agent identifiers.

* In JobScheduler 1.x a number of Agent Clusters can be created on top of a single Agent installation
* In JS7 Agents and their URLs are unique

Therefore a number of JobScheduler 1.x Agent Clusters have to be mapped to a single JS7 Agent.
A JS7 Agent is identified by its Agent ID (that is unchangeable after Agent installation)
and is assigned an Agent Name. Additional Agent Names can be assigned an Agent to specify alias names.

The value of this parameter accepts a hashmap that is e.g. created like this:

    $map = @{}
    $map.Add( '/product_demo/Agent_Linux_Active_Active',  @{ 'AgentId' = 'AgentLinux_0023'; 'AgentName' = 'Agent_Linux_Active_Active' } )
    $map.Add( '/product_demo/Agent_Linux_Active_Passive', @{ 'AgentId' = 'AgentLinux_0023'; 'AgentName' = 'Agent_Linux_Active_Passive' } )

The key of the hashmap is the JobScheduler 1.x Agent Cluster, e.g. '/product_demo/Agent_Linux_Active_Active'.
The value of the hashmap is a nested hashmap that is expected to contain the "AgentId" and "AgentName" entries.

In the above example multiple Agent Clusters map to the same Agent ID but use different Agent Names that
can be used as alias names for the same Agent ID in the JS7 GUI.

.PARAMETER PrefixOrders
Order IDs are unique for a given job chain only. Therefore, when converting a number of orders
then duplicate converted objects could result. For later import of converted objects to JS7
uniqueness of Order IDs (Schedules) is required.

This switch specifies to prefix the order ID with the name of the job chain when an order is converted to a schedule.

.PARAMETER PlanOrders
When converting order objects then this switch specifies if the orders should be planned automatically
by the Daily Plan service or if the planning of orders is performed by users with the Daily Plan GUI.

.PARAMETER SubmitOrders
When converting order objects then this switch specifies if the orders should be submitted automatically to a Controller
by the Daily Plan service or if the submission of orders is performed by users with the Daily Plan GUI.

.PARAMETER UseJobs
When used with the -Directory parameter then this switch specifies to convert job objects.

If none of the -Use* switches is used then all object types are exported.

.PARAMETER UseJobChains
When used with the -Directory parameter then this switch specifies to convert job chain objects.

If none of the -Use* switches is used then all object types are exported.

.PARAMETER UseJobStreams
When used with the -Directory parameter then this switch specifies to convert job stream objects.

If none of the -Use* switches is used then all object types are exported.

.PARAMETER UseOrders
When used with the -Directory parameter then this switch specifies to convert order objects.

If none of the -Use* switches is used then all object types are exported.

.PARAMETER UseCalendars
When used with the -Directory parameter then this switch specifies to convert calendar objects.

If none of the -Use* switches is used then all object types are exported.

.PARAMETER UseLocks
When used with the -Directory parameter then this switch specifies to convert lock objects.

If none of the -Use* switches is used then all object types are exported.

.PARAMETER UseAgentClusters
When used with the -Directory parameter then this switch specifies to convert Agent Cluster objects.

If none of the -Use* switches is used then all object types are exported.

.PARAMETER UpdateArchive
Specifies that any converted objects will be added to an existing archive file that is specified with the
-ArchivePath parameter. Without this parameter an existing archive file will be overwritten.

.PARAMETER RemoveOutputDirectory
Specifies that the output directory that is indicated with the -OutputDirectory parameter will be
removed after JobScheduler objects have been converted and the archive file that is specified with the
-ArchivePath parameter has been created.

.INPUTS
This cmdlet accepts pipelined objects.

.OUTPUTS
This cmdlet does not return any output

.EXAMPLE
ConvertFrom-JobSchedulerXml -ArchivePath /tmp/export.zip

Converts any JobScheduler objects to a JSON format and stores them in an archive file for import with JS7.

.EXAMPLE
ConvertFrom-JobSchedulerXml -ArchivePath /tmp/export.zip -RemoveOutputDirectory

Converts any JobScheduler objects to a JSON format and stores them in an archive file for import with JS7.
The temporary directory used to store converted objects is removed after adding converted files to the archive file.

.EXAMPLE
ConvertFrom-JobSchedulerXml -Job /some_path/myJob -ArchivePath /tmp/export.zip

Converts the indicated standalone job and stores the converted JSON file to an archive.

.EXAMPLE
ConvertFrom-JobSchedulerXml -JobChain /product_demo/shell_chain -ArchivePath /tmp/export.zip

Converts the indicated job chain and stores the converted JSON file to an archive.

.EXAMPLE
ConvertFrom-JobSchedulerXml -Directory /product_demo -Recursive -OutputDirectory /tmp/js7/jobchain2js7/js7

Selects any JobScheduler objects from the indicated directory and sub-directories and stores converted objects
with the indicated OS directory.

.EXAMPLE
ConvertFrom-JobSchedulerXml -Directory /product_demo -Recursive -UseJobChains -UseJobs -OutputDirectory /tmp/js7/jobchain2js7/js7

Selects standalone job objects and job chains objects from the indicated directory and sub-directories and stores converted objects
with the indicated OS directory.

.EXAMPLE
ConvertFrom-JobSchedulerXml -Directory /product_demo -OutputDirectory /tmp/js7/jobchain2js7/js7

.EXAMPLE
Get-JobSchedulerJob -IsStandaloneJob -Directory /product_demo | ConvertFrom-JobSchedulerXml -ArchivePath /tmp/export.zip

Reads standalone jobs from the specified directory and pipes the result to the converter cmdlet.

.EXAMPLE
Get-JobSchedulerJobChain -Directory /product_demo -Recursive | ConvertFrom-JobSchedulerXml -ArchivePath /tmp/export.zip

Reads job chains from the specified directory and any sub-directories and pipes the result to the converter cmdlet.
#>
[cmdletbinding()]
param
(
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ArchivePath,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Directory = '/',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $Recursive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Job,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobChain,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $JobStream,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OrderId,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Calendar,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $Lock,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $AgentCluster,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $OutputDirectory = [System.IO.Path]::GetTempPath() + (New-Guid).guid,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $BaseFolder,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $DefaultAgentName = 'primaryAgent',
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [string] $ForcedAgentName,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [hashtable] $MappedAgentNames,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $PrefixOrders,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $SubmitOrders,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $PlanOrders,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UseJobs,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UseJobChains,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UseJobStreams,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UseOrders,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UseCalendars,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UseLocks,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UseAgentClusters,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $UpdateArchive,
    [Parameter(Mandatory=$False,ValueFromPipeline=$False,ValueFromPipelinebyPropertyName=$True)]
    [switch] $RemoveOutputDirectory
)

    Begin
    {
        Approve-JobSchedulerCommand $MyInvocation.MyCommand
        $stopWatch = Start-JobSchedulerStopWatch

        $directories = @()
        $jobs = @()
        $jobChains = @()
        $jobStreams = @()
        $orders = @()
        $calendars = @()
        $agentClusters = @()
        $locks = @()
    }

    Process
    {
        Write-Verbose ".. $($MyInvocation.MyCommand.Name): parameter FilePath=$FilePath, Directory=$Directory, Job=$Job, JobChain=$JobChain, JobStream=$JobStream, Lock=$Lock, OutputDirectory=$OutputDirectory"

        if ( $Directory )
        {
            if ( !$Directory.endsWith( '/' ) )
            {
                $Directory += '/'
            }
        }

        if ( $BaseFolder.endsWith( '/' ) )
        {
            $BaseFolder = $BaseFolder.Substring( 0, $BaseFolder.Length-1 )
        }

        if ( $OutputDirectory.endsWith( '/' ) )
        {
            $OutputDirectory = $OutputDirectory.Substring( 0, $OutputDirectory.Length-1 )
        }

        if ( !(Test-Path $OutputDirectory -PathType container -ErrorAction continue) )
        {
            New-Item -Path $OutputDirectory -ItemType Directory | Out-Null
        }

        if ( !$UseJobs -and !$UseJobChains -and !$UseJobStreams -and !$UseOrders -and !$UseCalendars -and !$UseLocks -and !$UseAgentClusters )
        {
            $UseJobs = $True
            $UseJobChains = $True
            $UseJobStreams = $True
            $UseOrders = $True
            $UseCalendars = $True
            $UseLocks = $True
            $UseAgentClusters = $True
        }


        if ( $Directory )
        {
            $directories += $Directory
        }

        if ( $Job )
        {
            $objPath = New-Object PSObject
            if ( $Job.startsWith( '/' ) )
            {
                Add-Member -Membertype NoteProperty -Name 'Path' -value $Job -InputObject $objPath
            } else {
                Add-Member -Membertype NoteProperty -Name 'Path' -value "$($Directory)$($Job)" -InputObject $objPath
            }
            $jobs += $objPath
        }

        if ( $JobChain )
        {
            $objPath = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'Path' -value $JobChain -InputObject $objPath
            $jobChains += $objPath
        }

        if ( $JobStream )
        {
            $objPath = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'Path' -value $JobStream -InputObject $objPath
            $jobStreams += $objPath
        }

        if ( $OrderId )
        {
            if ( !$JobChain )
            {
                 throw "use of -OrderId parameter requires to specify the -JobChain parameter"
            }

            $objPath = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'orderId' -value $OrderId -InputObject $objPath
            Add-Member -Membertype NoteProperty -Name 'jobChain' -value $JobChain -InputObject $objPath
            $orders += $objPath
        }

        if ( $Calendar )
        {
            $objPath = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'Path' -value $Calendar -InputObject $objPath
            $calendars += $objPath
        }

        if ( $Lock )
        {
            $objPath = New-Object PSObject
            if ( $Lock.startsWith( '/' ) )
            {
                Add-Member -Membertype NoteProperty -Name 'Path' -value $Lock -InputObject $objPath
            } else {
                Add-Member -Membertype NoteProperty -Name 'Path' -value "$($Directory)$($Lock)" -InputObject $objPath
            }
            $locks += $objPath
        }

        if ( $AgentCluster )
        {
            $objPath = New-Object PSObject
            Add-Member -Membertype NoteProperty -Name 'Path' -value $AgentCluster -InputObject $objPath
            $agentClusters += $objPath
        }
    }

    End
    {
        Write-Verbose ".. exporting objects to output directory: $OutputDirectory"

        $arguments = @{}
        $arguments.Add( 'OutputDirectory', $OutputDirectory )
        $arguments.Add( 'BaseFolder', $BaseFolder )

        if ( $Directory -and !$jobs -and !$jobChains -and !$jobStreams -and !$calendars -and !$locks -and !$agentClusters )
        {
            if ( $UseJobs )
            {
                Get-JobSchedulerJob -Directory $Directory -Recursive:$Recursive -IsStandaloneJob | ConvertFrom-JobSchedulerXmlJob -DefaultAgentName $DefaultAgentName -ForcedAgentName $ForcedAgentName -MappedAgentNames $MappedAgentNames -PrefixOrders:$PrefixOrders -SubmitOrders:$SubmitOrders -PlanOrders:$PlanOrders @arguments
            }

            if ( $UseJobChains )
            {
                Get-JobSchedulerJobChain -Directory $Directory -Recursive:$Recursive | ConvertFrom-JobSchedulerXmlJobChain -DefaultAgentName $DefaultAgentName -ForcedAgentName $ForcedAgentName -MappedAgentNames $MappedAgentNames @arguments
            }

            if ( $UseJobStreams )
            {
                # Get-JobSchedulerJobStream -Directory $Directory -Recursive:$Recursive | ConvertFrom-JobSchedulerXmlJobStream -DefaultAgentName $DefaultAgentName -ForcedAgentName $ForcedAgentName -MappedAgentNames $MappedAgentNames @arguments
            }

            if ( $UseOrders )
            {
                Get-JobSchedulerOrder -Directory $Directory -Recursive:$Recursive -Permanent | ConvertFrom-JobSchedulerXmlOrder -PrefixOrders:$PrefixOrders -SubmitOrders:$SubmitOrders -PlanOrders:$PlanOrders @arguments
            }

            if ( $UseCalendars )
            {
                Get-JobSchedulerCalendar -Directory $Directory -Recursive:$Recursive | ConvertFrom-JobSchedulerXmlCalendar @arguments
            }

            if ( $UseLocks )
            {
                Get-JobSchedulerLock -Directory $Directory -Recursive:$Recursive | ConvertFrom-JobSchedulerXmlLock @arguments
            }

            if ( $UseAgentClusters )
            {
                Get-JobSchedulerAgentCluster -Directory $Directory -Recursive:$Recursive | ConvertFrom-JobSchedulerXmlAgentCluster -MappedAgentNames $MappedAgentNames @arguments
            }
        }


        if ( $jobs )
        {
            $jobs | ConvertFrom-JobSchedulerXmlJob -DefaultAgentName $DefaultAgentName -ForcedAgentName $ForcedAgentName -MappedAgentNames $MappedAgentNames -PrefixOrders:$PrefixOrders -SubmitOrders:$SubmitOrders -PlanOrders:$PlanOrders @arguments
        }

        if ( $jobChains )
        {
            $jobChains | ConvertFrom-JobSchedulerXmlJobChain -DefaultAgentName $DefaultAgentName -ForcedAgentName $ForcedAgentName -MappedAgentNames $MappedAgentNames @arguments
        }

        if ( $jobStreams )
        {
           # $jobStreams | ConvertFrom-JobSchedulerXmlJobStream -DefaultAgentName $DefaultAgentName -ForcedAgentName $ForcedAgentName -MappedAgentNames $MappedAgentNames @arguments
        }

        if ( $orders )
        {
           $orders | ConvertFrom-JobSchedulerXmlOrder -SubmitOrders:$SubmitOrders -PlanOrders:$PlanOrders @arguments
        }

        if ( $calendars )
        {
           $calendars | ConvertFrom-JobSchedulerXmlCalendar @arguments
        }

        if ( $locks )
        {
           $locks | ConvertFrom-JobSchedulerXmlLock @arguments
        }

        if ( $agentClusters )
        {
           $agentClusters | ConvertFrom-JobSchedulerXmlAgentCluster -MappedAgentNames $MappedAgentNames @arguments
        }


        if ( $ArchivePath )
        {
            if ( $UpdateArchive )
            {
                Write-Verbose ".. updating archive file: $ArchivePath"
                Compress-Archive -DestinationPath $ArchivePath -Path "$($OutputDirectory)/*" -Update
            } else {
                Write-Verbose ".. creating archive file: $ArchivePath"
                Compress-Archive -DestinationPath $ArchivePath -Path "$($OutputDirectory)/*" -Force
            }

            if ( $RemoveOutputDirectory )
            {
                Write-Verbose ".. removing output directory: $OutputDirectory"
                Remove-Item -Path $OutputDirectory -Recurse -Force
            }
        }

        Trace-JobSchedulerStopWatch $MyInvocation.MyCommand.Name $stopWatch
    }
}

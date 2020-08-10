@{

# Script module or binary module file associated with this manifest.
ModuleToProcess = 'JobScheduler.psm1'

# Version number of this module.
ModuleVersion = '1.2.0'

# ID used to uniquely identify this module
GUID = 'fcc31359-6e84-425a-9338-49ed7a807bf9'

# Author of this module
Author = 'Andreas Pueschel'

# Company or vendor of this module
CompanyName = 'SOS GmbH'

# Copyright statement for this module
Copyright = 'Copyright (c) 2016 by SOS GmbH, licensed under Apache 2.0 License.'

# Description of the functionality provided by this module
Description = 'JobScheduler provides a set of cmdlets to control a JobScheduler Master and Agents from the command line.'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.1'

# Functions to export from this module
FunctionsToExport = @( 
    'Add-JobSchedulerEvent',
    'Add-JobSchedulerOrder',
	'Connect-JobScheduler',
    'Disconnect-JobScheduler',
    'Get-JobSchedulerAgentCluster',
    'Get-JobSchedulerAgentReport',
    'Get-JobSchedulerAgentStatus',
    'Get-JobSchedulerDailyPlan',
    'Get-JobSchedulerEvent',
    'Get-JobSchedulerJob',
    'Get-JobSchedulerJobChain',
    'Get-JobSchedulerJobHistory',
    'Get-JobSchedulerJobStreamHistory',
    'Get-JobSchedulerMasterCluster',
    'Get-JobSchedulerOrder',
    'Get-JobSchedulerOrderHistory',
    'Get-JobSchedulerStatus',
    'Get-JobSchedulerSystemCredentials',
    'Get-JobSchedulerTask',
    'Get-JobSchedulerTaskHistory',
    'Get-JobSchedulerVersion',
    'Install-JobSchedulerService',
    'New-JobSchedulerHolidays',
    'Remove-JobSchedulerEvent',
    'Remove-JobSchedulerOrder',
    'Remove-JobSchedulerService',
    'Reset-JobSchedulerOrder',
    'Restart-JobSchedulerMaster',
    'Resume-JobSchedulerJob',
    'Resume-JobSchedulerJobChain',
    'Resume-JobSchedulerMaster',
    'Resume-JobSchedulerOrder',
    'Send-JobSchedulerCommand',
    'Send-JobSchedulerRequest',
    'Set-JobSchedulerCredentials',
    'Set-JobSchedulerOption',
    'Start-JobSchedulerExecutableFile',
    'Start-JobSchedulerJob',
    'Start-JobSchedulerJobEditor',
    'Start-JobSchedulerMaster',
    'Start-JobSchedulerOrder',
    'Stop-JobSchedulerMaster',
    'Stop-JobSchedulerTask',
    'Suspend-JobSchedulerJob',
    'Suspend-JobSchedulerJobChain',
    'Suspend-JobSchedulerMaster',
    'Suspend-JobSchedulerOrder',
    'Use-JobSchedulerMaster'
)

# # Cmdlets to export from this module
# CmdletsToExport = '*'

# Variables to export from this module
# VariablesToExport = @()

# # Aliases to export from this module
# AliasesToExport = '*'

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

PrivateData = @{
    # PSData is module packaging and gallery metadata embedded in PrivateData
    # It's for rebuilding PowerShellGet (and PoshCode) NuGet-style packages
    # We had to do this because it's the only place we're allowed to extend the manifest
    # https://connect.microsoft.com/PowerShell/feedback/details/421837
    PSData = @{
        # The primary categorization of this module (from the TechNet Gallery tech tree).
        Category = "Scripting Techniques"

        # Keyword tags to help users find this module via navigations and search.
        Tags = @('powershell','job scheduling','workload automation')

        # The web address of an icon which can be used in galleries to represent this module
        IconUri = "https://kb.sos-berlin.com/download/attachments/3638359/JobScheduler_logo_wiki.jpg?version=1&modificationDate=1413144531000&api=v2"

        # The web address of this module's project or support homepage.
        ProjectUri = "https://www.sos-berlin.com/jobscheduler"

        # The web address of this module's license. Points to a page that's embeddable and linkable.
        LicenseUri = "http://www.apache.org/licenses/LICENSE-2.0.html"

        # Release notes for this particular version of the module
        # ReleaseNotes = False

        # If true, the LicenseUrl points to an end-user license (not just a source license) which requires the user agreement before use.
        # RequireLicenseAcceptance = ""

        # Indicates this is a pre-release/testing version of the module.
        IsPrerelease = 'False'
    }
}

# HelpInfo URI of this module
# HelpInfoURI = 'https://kb.sos-berlin.com/x/cID4'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

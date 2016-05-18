# JobScheduler PowerShell Command Line Interface

The JobScheduler Command Line Interface (CLI) can be used to control
JobScheduler instances (start, stop, status) and job-related objects
such as jobs, job chains, orders, tasks.

The JobScheduler CLI module supports Windows PowerShell 2.0 and above.

# Purpose

The JobScheduler Command Line Interface is used for the following 
areas of operation:

* work as a replacement for the command script .bin\jobscheduler.cmd:
  * provide operations for installing and removing the JobScheduler Windows service
  * starting and stopping JobScheduler instances including active and passive clusters
* provide bulk operations:
  * select jobs, job chains, orders and tasks
  * manage orders with operations for start, stop and removal
  * terminate tasks
* schedule jobs and orders:
  * add orders to job chains
  * start jobs
 
Find more information and documentation of cmdlets at [PowerShell Command Line Interface](https://kb.sos-berlin.com/x/ZID4)

# Getting Started

* PS C:\> Import Module JobScheduler
  * makes the module available in a PowerShell session
* PS C:\> Use-Master *JobSchedulerID*   or   PS C:\> Use-Master *InstallationPath*
  * as a first operation after importing the module it is required to execute the Use-Master cmdlet.
  * Either specify a JobScheduler ID or the installation path.
    * The JobScheduler ID is determined during setup and is added to the installation base path.: A typical installation bath would be C:\Program Files\sos-berlin.com\jobscheduler\scheduler1.10 with *scheduler1.10* being the JobScheduler ID.
    * Otherwise specify the full installation path, e.g. C:\Program Files\sos-berlin.com\jobscheduler\scheduler1.10
* PS C:\> Show-Status
  * Shows the summary information of a JobScheduler Master.
* PS C:\> (Get-Task).count
  * Shows the number of tasks that are currently running.
* PS C:\> Get-Job /sos | Get-Task | Stop-Task
  * Stops all running tasks from the specified folder.
* PS C:\> $orders = Get-Order /sos
  * Collect the list of orders from a directory and stores it in a variable.
* PS C:\> $orders = ( Get-Order /my_jobs -NoPermanent | Suspend-Order )
  * Retrieve temporary ad hoc orders from the *my_jobs* directory and any subfolders.
  * All temporary orders are suspended and the list of order objects is stored in a variable.
* PS C:\> Get-Command -Module JobScheduler
  * Provides the complete list of cmdlets.
* PS C:\> Get-Help Get-Task -detailed
  * Displays help information for each cmdlet.
 
# Further Reading

* [PowerShell Command Line Interface - Introduction](https://kb.sos-berlin.com/x/cID4)
* [PowerShell Command Line Interface - Cmdlets](https://kb.sos-berlin.com/x/aID4)

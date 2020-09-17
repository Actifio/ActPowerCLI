# ActPowerCLI
A Powershell module to manage Actifio Appliances


## What versions of PowerShell and Operating Systems will this module work with?

* It will work with Windows PowerShell Version 4 that has .NET 4.5 installed
* It will work with Windows PowerShell Version 5 (no requirement for .NET)
* It should work with PowerShell Version 6 on Linux, Mac OS and Windows Operating Systems (no requirement for .NET).  No testing is being done on PS6.
* It will work with PowerShell Version 7 on Linux, Mac OS and Windows Operating Systems (no requirement for .NET) 

In this repository are two separate versions of ActPowerCLI, but you don't need to work out which one to use.
It will be handled automatically by the included installer.

The installer will install one of two versions:

* ActPowerCLI Version 10.0.1.x  is for Windows PowerShell 5 and PowerShell 6/7 and can be installed from the GitHub zip file or PowerShell Gallery
* ActPowerCLI Version 10.0.0.x  is for Windows PowerShell 4 and can be installed from the GitHub zip file

#### What about Windows PowerShell 3?

It should work with Windows PowerShell Version 3 on the Windows Operating System that have .NET 4.5 installed, but no further testing is being done on this version

## Install

You have two choices:   PowerShell Gallery or GitHub download.

### Windows PowerShell 5 and PowerShell 6 and 7 - Install from the PowerShell Gallery 

Install from PowerShell Gallery.   If Running PowerShell 5, set to Tls12 to avoid NuGet errors.

```
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-Module -Name ActPowerCLI
```

If you had a previously manually created install, where you downloaded from GitHub and want to convert to using PowerShell Gallery (strongly recommended), then delete the previous manual install (just delete the module folder) and run the install from PS Gallery using the command above.  Otherwise you will get an error like this:

```
Update-Module: Module 'ActPowerCLI' was not installed by using Install-Module, so it cannot be updated.
```

###  PowerShell 7 only - Upgrades from PowerShell Gallery 

Note if you run 'Install-Module' to update an installed module, it will complain.  You need to run:
```
Update-Module -name ActPowerCLI
```
It will install the latest version and leave the older version in place.  To see the version in use versus all versions downloaded use these two commands:
```
Get-InstalledModule actpowercli
Get-InstalledModule actpowercli -AllVersions
```
To uninstall all older versions run this command:
```
$Latest = Get-InstalledModule actpowercli; Get-InstalledModule actpowercli -AllVersions | ? {$_.Version -ne $Latest.Version} | Uninstall-Module
```

### All Supported Versions of PowerShell - Install from GitHub download

Many corporations will not allow downloads from PowerShell gallery or direct access to GitHub, so for these we have the following process:

1.  From GitHub, use the Green Code download button to download the ActPowerCLI repo as a zip file
1.  Copy the Zip file to the server where you want to install it
1.  For Windows, Right select on the zip file, choose  Properties and then use the Unblock button next to the message:  "This file came from another computer and might be blocked to help protect your computer."
1.  For Windows, now right select and use Extract All to extract the contents of the zip file to a folder.  It doesn't matter where you put the folder.  For Mac it should automatically unzip.  For Linux use the unzip command to unzip the folder.
1.  Now start PWSH and change directory to the  ActPowerCLI-main directory that should contain the module files.   
1.  There is an installer, Install-ActPowerCLI.   So run that with ./Install-ActPowerCLI.ps1
If you find multiple installs, we strongly recommend you delete them all and run the installer again to have just one install.
1.  Once the installer has finished, you can delete the unpacked zip file and the zip file itself.


If the install fails with:
```
.\Install-ActPowerCLI.ps1: File C:\Users\av\Downloads\ActPowerCLI-main\ActPowerCLI-main\Install-ActPowerCLI.ps1 cannot be loaded. 
The file C:\Users\av\Downloads\ActPowerCLI-main\ActPowerCLI-PS7-main\Install-ActPowerCLI.ps1 is not digitally signed. You cannot run this script on the current system. 
For more information about running scripts and setting execution policy, see about_Execution_Policies at https://go.microsoft.com/fwlink/?LinkID=135170.
```
Then  run this command:
```
Get-ChildItem .\Install-ActPowerCLI.ps1 | Unblock-File
```
Then re-run the installer.  The installer will unblock all the other files.


If the install fails with:
```
New-Item : Access to the path 'ActPowerCLI' is denied.
```
Then you need to start your PowerShell session as Administrator.


### All Supported Versions of PowerShell - Upgrade from GitHub download

To upgrade any existing install, follow the Install instructions above. 
The Installer will detect an existing installation and offer you an option to upgrade it.
If you have more then one installation, choose the option to delete them all and install just one version in one location.

Common upgrade issues are solved by:

* Closing open PowerShell Sessions that are using the module.   Make sure to close all other sessions.   Sometimes you literally need to close every session and open one fresh one.
* Unblocking the downloaded zip file.
* Running the PowerShell session as Administrator, depending on where current installs are and where you want to install to.

#### GITHUB Install fails with Access to the path 'ActPowerCLI.dll' is denied.

We have seen a case where many PowerShell processes were blocking removal of the old PowerShell module:
```
Cannot remove item C:\Windows\system32\WindowsPowerShell\v1.0\Modules\ActPowerCLI\ActPowerCLI.dll: Access to the path 'ActPowerCLI.dll' is denied.
At C:\Users\av\Downloads\ActPowerCLI-dev\ActPowerCLI-dev\Install-ActPowerCLI.ps1:70 char:5
+     throw "$($_.ErrorDetails)"
+     ~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : OperationStopped: (Cannot remove i...dll' is denied.:String) [], RuntimeException
    + FullyQualifiedErrorId : Cannot remove item C:\Windows\system32\WindowsPowerShell\v1.0\Modules\ActPowerCLI\ActPowerCLI.dll: Access to the path 'ActPowerCLI.dll' is denied.
```
Check to see if there are many powershell processes running:
```
 PS C:\Users\av\Downloads\ActPowerCLI-dev\ActPowerCLI-dev> get-process | where-object {$_.ProcessName -eq "powershell"}

Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
-------  ------    -----      -----     ------     --  -- -----------
    566      30    55664      34748     340.31     60   0 powershell
    565      30    55836      65056     342.69    392   0 powershell
    566      30    55464      34576     334.48    396   0 powershell
    566      30    55436      37700     334.45    704   0 powershell
    565      30    55988      65148     328.70    864   0 powershell
    561      30    55424      64784     332.88    868   0 powershell
    566      30    55544      64904     332.86   1536   0 powershell
    565      30    55632      65032     339.95   1628   0 powershell
    565      30    55728      36544     340.53   1636   0 powershell
    565      30    55512      64904     334.56   2108   0 powershell
    566      30    55580      37252     339.52   2928   0 powershell
    566      30    55596      64884     336.70   3044   0 powershell
    566      30    55544      39048     334.88   3544   0 powershell
    565      30    55512      64868     331.56   4236   0 powershell
    565      30    55856      65080     341.38   4992   0 powershell
    565      30    55476      34908     334.23   5192   0 powershell
    565      30    55588      64936     332.36   5396   0 powershell
```
Use stop-process to kill them all.  Note this will kill your local powershell session.
```
PS C:\Users\av\Downloads\ActPowerCLI-dev\ActPowerCLI-dev> get-process | where-object {$_.ProcessName -eq "powershell"} | stop-process

Confirm
Are you sure you want to perform the Stop-Process operation on the following item: powershell(60)?
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"): A
```
Start a new powershell session and you should see just on instance:
```
PS C:\Windows\system32> get-process | where-object {$_.ProcessName -eq "powershell"}

Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName
-------  ------    -----      -----     ------     --  -- -----------
    773      31    62112      75044       1.41  20160  19 powershell
```
Now you can try and install again.


## Usage


###  Get some help


List the available commands in the ActPowerCLI module:
```
Get-Command -module ActPowerCLI
```
Find out the syntax and how you can use a specific command. For instance:
```
Get-Help Connect-Act
```
If you need some examples on the command:
```
Get-Help Connect-Act -examples
```

The following command specific help is available:

* udsinfo     -->   if run without any parameters will list all available udsinfo commands
* udsinfo -h  -->   if run without any parameters will list all available commands
* udstask     -->   if run without any parameters will list all available udstask commands
* udstask -h  -->   if run without any parameters will list all available udstask commands

Then for each command you can get help, for instance:

* udsinfo lsversion -h    --> will show help for this command
* udstask mkhost -h       --> will show help for this command

For report commands, help will be available from Appliance release 10.0.2, prior to this you will get this message:
```
PS /Users/anthonyv/Documents/github/ActPowerCLI> reportapps -h

errormessage                errorcode
------------                ---------
Help not supported for API.     10008
```


###  Save your password

Create an encrypted password file using the ActPowerCLI Save-ActPassword function:
```
Save-ActPassword -filename "C:\temp\password.key"
```

The Save-ActPassword function creates an encyrpted password file on Windows, but on Linux and Mac it only creates an encoded password file.  

##### Sharing Windows key files

Currently if a Windows key file is created by a specific user, it cannot be used by a different user.    You will see an error like this:
```
Key not valid for use in specified state.
```
This will cause issues when running saved scripts when two differerent users want to run the same script with the same keyfile.    To work around this issue, please have each user create a keyfile for their own use.   Then when running a shared script, each user should execute the script specifying their own keyfile.  This can be done by using a parameter file for each script.


###  Login to your appliance

To login to an Actifio appliance (10.61.5.114) as admin and enter password interactively:
```
Connect-Act 10.61.5.114 admin -ignorecerts
```
Or login to the Actifio cluster using the password file created in the previous step:
```
Connect-Act 10.61.5.114 -actuser admin -passwordfile "c:\temp\password.key" -ignorecerts
```

Note you can use **-quiet** to supress messages.   This is handy when scripting.

###  Find out the current version of ActPowerCLI:

```
(Get-Module ActPowerCLI).Version

Major  Minor  Build  Revision
-----  -----  -----  --------
10     0      1      12
```

###  Example commands

To list all the Actifio clusters using the udsinfo command:
```
udsinfo lscluster
```
To list only the operative IP address:
```
(udsinfo lscluster).operativeip 
```
To grab the operative IP address for a specific Appliance (called *appliance1* in this example):
```
(udsinfo lscluster -filtervalue name=appliance1).operativeip
```
To list all the advanced options related to SQL server:
```
udsinfo lsappclass -name SQLServer
```
To list all the advanced options related to SQL server and display the results in a graphical popup window:
```
udsinfo lsappclass -name SQLServer | out-gridview
```
To list all the fields for all the SQL server databases:
```
udsinfo lsapplication | where-object {$_.appclass -eq "SQLServer"} 
```
To list selected fields for all the SQL server databases:
```
udsinfo lsapplication | where-object {$_.appclass -eq "SQLServer"} | select appname, id, hostid
```
To list all the snapshot jobs for appid 18405:
```
udsinfo lsbackup -filtervalue "jobclass=snapshot&appid=18405"
```
To list the above in a table format
```
udsinfo lsbackup -filtervalue "jobclass=snapshot&appid=18405" | format-table
```
To get a list of available SARG reports, run either:
```
reportlist 
get-sargreport reportlist
```
To list all available storage pools on the Actifio appliance, run the reportpools command:
```
reportpools 
```
Run the SARG reportimages command:
```
get-sargreport reportimages -a 0 | select jobclass, hostname, appname | format-table
```
To export to CSV we use the PowerShell export-csv option and then specify the path.   In this example you can see the path and filename that was used.
```
reportsnaps | export-csv -path c:\Users\av\Documents\reportsnaps.csv
```
To learn the latest snapshot date for each application we could do this:
```
reportrpo | select apptype, hostname, appname, snapshotdate
```
To learn the latest snapshot date for each VM we could do this:
```
reportrpo | where {$_.Apptype -eq "VMBackup"} | select appname, snapshotdate
```
udsinfo lshost provides us with high level information on a host. To find out the detail information on each host:
```
udsinfo lshost | select id | foreach-object { udsinfo lshost $_.id } | select svcname, hostname, id, iscsi_name, ipaddress
```
To list out all the workflow configurations on an appliance, use a combination of reportworkflows and udsinfo lsworkflow:
```
reportworkflows | select id | foreach-object {udsinfo lsworkflow $_.id}
```

###  Disconnect from your appliance
Once you are finished, make sure to disconnect (logout).   If you are running many scripts in quick succession, each script should connect and then disconnect, otherwise each session will be left open to time-out on its own.
```
Disconnect-Act
```


## Concise Command Primer

#### Check your versions 
```
$host.version        (need version 3.0 to 5.1)
$PSVersionTable.CLRVersion       (need .NET 4.0 or above if using Windows PowerShell 4)
```
#### Check your plugins
```
Get-ChildItem Env:\PSModulePath | format-list
Get-module -listavailable 
Import-module ActPowerCLI
(Get-Module ActPowerCLI).Version    
```

#### List all commands get help
```
Get-Command -module ActPowerCLI
Get-Help Connect-Act
Get-Help Connect-Act -examples
```

#### Store your password (choose just one)
```
(Get-Credential).Password | ConvertFrom-SecureString | Out-File "C:\Users\av\Documents\password.key"
"password" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString | Out-File "C:\Users\av\Documents\password.key"
Save-ActPassword -filename "C:\Users\av\Documents\password.key"
```

#### Login
```
Connect-Act 172.24.1.180 av -ignorecerts
Connect-Act 172.24.1.180 -actuser av -passwordfile "C:\Users\av\Documents\password.key" -ignorecerts
Connect-Act 172.24.1.180 -actuser av -password passw0rd -ignorecerts 
Connect-Act 172.24.1.180 -actuser av -password passw0rd -ignorecerts -quiet
```

#### Example commands
```
udsinfo lscluster
(udsinfo lscluster).operativeip 
udsinfo lsappclass -name SQLServer
udsinfo lsappclass -name SQLServer | out-gridview
udsinfo lsapplication | where-object {$_.appclass -eq "SQLServer"} 
udsinfo lsapplication | where-object {$_.appclass -eq "SQLServer"} | select appname, id, hostid
udsinfo lsbackup -filtervalue "jobclass=snapshot&appid=18405"
udsinfo lsbackup -filtervalue "jobclass=snapshot&appid=18405" | format-table
Get-LastSnap -?
Get-LastSnap -app 18405 -jobclass snapshot
get-sargreport reportlist
reportpools 
get-sargreport reportimages -a 0 | select jobclass, hostname, appname | format-table
reportsnaps | export-csv -path C:\Users\av\Documents\reportsnaps.csv
reportrpo | select apptype, hostname, appname, snapshotdate
reportrpo | where {$_.Apptype -eq "VMBackup"} | select appname, snapshotdate
reportmountedimages | where {$_.Label -eq "$Name"} | foreach { $_.MountedHost }
```
#### Logout
```
Disconnect-Act
Disconnect-Act -quiet
```


## report sorting 

In PowerShell 5-7 the output of all report commands is autosorted to make the data more readable.   
You do disable this function by adding -p to the Connect-Act command.
```
Connect-Act 172.24.1.80 av -i -p
```
You can display the auto sort method by displaying this exported variable
```
$ACTSORTORDER
```
Sorting is loaded by running reportlist -s, but this is onyl supported in Appliance versions 10.0.2   For earlier versions a CSV file is supplied, ActPowerCLI_SortOrder.csv    If you want to, you can edit this file and force the module to only look in the file by adding -f to the Connect-Act command:
```
Connect-Act 172.24.1.80 av -i -f
```

## API Limit

By default, the module has no API limit which means if you run 'udsinfo lsjobhistory' you can easily get results in the thousands or millions.   We offer a  command to prevent giant lookups by setting a limit on the number of returned objects, although by default this limit is off.  You can set the limit with:   Set-ActAPILimit

In the example below, we login and search for snapshot jobs and find there are over sixty thousand.  A smart move would be to use more filters (such as date or appname), but we could also limit the number of results using an APIlimit, so we set it to 100 and only get 100 jobs back:

```
PS /Users/anthony/git/ActPowerCLI> Connect-Act 172.24.1.180 av -passwordfile avpass.key -ignorecerts
Login Successful!
PS /Users/anthony/git/ActPowerCLI> $jobs = udsinfo lsjobhistory -filtervalue jobclass=snapshot
PS /Users/anthony/git/ActPowerCLI> $jobs.jobname.count
60231
PS /Users/anthony/git/ActPowerCLI> Set-ActAPILimit 100
PS /Users/anthony/git/ActPowerCLI> $jobs = udsinfo lsjobhistory -filtervalue jobclass=snapshot
PS /Users/anthony/git/ActPowerCLI> $jobs.jobname.count
100
```

You can reset the limit to 'unlimited' by setting it to '0'.

# FAQ

### Best practices with report commands

When using report commands like reportapps or reportsnaps, there are many parameters you can use.   There are two important rules to follow for the best results:

If a parameter uses a value, leave a space.  So if you are searching with -a for an app named smalldb or an app with ID 4771, use this syntax:
```
-a smalldb
-a 4471
```
Don't use this syntax
```
-asmalldb
-a4771
```
If apps have names with spaces, such as 'File Server', then you need to use double quotes, like this:
```
reportapps -a "File Server"
```


### How can I detect errors and failures

One design goal of ActPowerCLI is for all user messages to be easy to understand and formatted nicely.   However when a command fails, the return code shown by $? will not indicate this.  For instance in these two examples I try to connect and check $? each time.  However the result is the same for both cases ($? being 'True', as opposed to 'False', meaning the last command was successfully run).

Successful login:
```
PS /Users/anthony/git/ActPowerCLI> Connect-Act 172.24.1.180 av passw0rd -i
Login Successful!
PS /Users/anthony/git/ActPowerCLI> $?
True
```

Unsuccessful login:
```
PS /Users/anthony/git/ActPowerCLI> Connect-Act 172.24.1.180 av password -i

errormessage                               errorcode
------------                               ---------
java.lang.SecurityException: Login failed.     10011

PS /Users/anthony/git/ActPowerCLI> $?
True
```

The solution for the above is to check for errormessage for every command. 
Lets repeat the same exercise but using -q for quiet login

In a successful login the variable $loginattempt is empty

```
PS /Users/anthony/git/ActPowerCLI> $loginattempt = Connect-Act 172.24.1.180 av passw0rd -i -q
PS /Users/anthony/git/ActPowerCLI> $loginattempt
```

But an unsuccessful login can be 'seen'.  

```
PS /Users/anthony/git/ActPowerCLI> $loginattempt = Connect-Act 172.24.1.180 av password -i -q
PS /Users/anthony/git/ActPowerCLI> $loginattempt

errormessage                               errorcode
------------                               ---------
java.lang.SecurityException: Login failed.     10011

PS /Users/anthony/git/ActPowerCLI> $loginattempt.errormessage
java.lang.SecurityException: Login failed.
```

So we could test for failure by looking for the .errormessage

```
if ($loginattempt.errormessage)
{
  write-host "Login failed"
}
```

We can then take this a step further in a script.   If a script has clearly failed, then if we set an exit code, this can be read using $LASTEXITCODE.  We put this into a script (PS1).   NOTE!  If you run this inside a PWSH window directly, it will exit the PWSH session (rather than the PS1 script):

```
if ($loginattempt.errormessage)
{
  write-host "Login failed"'
  exit 1
}
```

We can then read for this exit code like this:

```
PS /Users/anthony/git/ActPowerCLI> $LASTEXITCODE
1
```

### How do I avoid white space and multiple lines in array output
A common requirement is that you may want to get the latest image name for an application, but the command returns white space and/or multiple lines.   In this example the output not only has multiple image names, but white space.  This could result in errors when trying to use this image name in other commands like udstask mountimage
```
PS C:\Users\av> $imagename = udsinfo lsbackup -filtervalue "backupdate since 124 hours&appname=SQL-Masking-Prod&jobclass=snapshot" | where {$_.componenttype -eq "0"} | select backupname | ft -HideTableHeaders
PS C:\Users\av> $imagename

Image_4393067
Image_4410647
Image_4426735


PS C:\Users\av>
```
If we use a slightly different syntax, we can guarantee both no white space and only one image name:
```
PS C:\Users\av> $imagename =  $(udsinfo lsbackup -filtervalue "backupdate since 124 hours&appname=SQL-Masking-Prod&jobclass=snapshot" | where {$_.componenttype -eq "0"} | select -last 1 ).backupname
PS C:\Users\av> $imagename
Image_4426735
PS C:\Users\av>
```


### Why don't the report commands auto-load ?

When you first start pwsh, the ActPowerCLI module will auto-import, meaning you can run Connect-Act, udsinfo, udstask, etc.  but if you try and run a report command it cannot be found:

```
PS /Users/anthony/.local/share/powershell/Modules/ActPowerCLI> reportapps
reportapps: The term 'reportapps' is not recognized as the name of a cmdlet, function, script file, or operable program.
Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
```

You need to run Connect-Act and connect to an appliance.   When you do this, the report commands are auto generated.

### Can I specify a PowerShell (PS1) script in an Actifio Workflow?

Actifio workflows allow you to specify a pre and post script.   For Windows these scripts need to be in either .CMD or .BAT format and have relevant extension.   In other words, these have to be files that can be executed by a Windows Command Prompt.   

However these scripts can call PS1 scripts.  So if the postscript field specifies a bat file called postmount.bat which is located in  **C:\Program Files\Actifio\scripts**, it could could contain a script like this:
```
cd /d "C:\Program Files\Actifio\scripts"

start /wait powershell -ExecutionPolicy Bypass "& .\postmountactions.ps1"
```
You can find a working example here:   https://github.com/Actifio/powershell/tree/master/workflow_email_notifications


### I am getting this error message: "the module could not be loaded" 

If you are running PowerShell version 5 then extra steps will be needed if you get an error like this:
```
PS C:\Users\av> connect-act
connect-act : The 'connect-act' command was found in the module 'ActPowerCLI', but the module could not be loaded. For
more information, run 'Import-Module ActPowerCLI'.
At line:1 char:1
+ connect-act
+ ~~~~~~~~~~~
    + CategoryInfo          : ObjectNotFound: (connect-act:String) [], CommandNotFoundException
    + FullyQualifiedErrorId : CouldNotAutoloadMatchingModule

```
If you get this error we will need to modify the downloaded zip file and copy the folder again.
1. Delete the actpowercli folder in c:\windows\system32\windowspowershell\v1.0\modules  or where ever you placed it
1. Right select the downloaded zip file and choose properties
1. At the bottom of the properties window select the Unblock button next to the message: *This file came from another computer and might be blocked to help protect this computer*
1. Unzip and again copy the folder into c:\windows\system32\windowspowershell\v1.0\modules or which ever path you are using

### I am getting this error message:  "Could not load file or assembly"


If you are running 64-bit Windows 7, Professional Edition you may get an error like this:
```
Import-Module : Could not load file or assembly
'file:///C:\Windows\system32\WindowsPowerShell\v1.0\Modules\ActPowerCLI\ActPowerCLI.dll' or one of its dependencies.
Operation is not supported. (Exception from HRESULT: 0x80131515)
At line:1 char:1
+ Import-Module ActPowerCLI
+ ~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (:) [Import-Module], FileLoadException
    + FullyQualifiedErrorId : FormatXmlUpdateException,Microsoft.PowerShell.Commands.ImportModuleCommand
```
If you get this error we will need to modify the downloaded zip file and copy the folder again.
1. Delete the actpowercli folder in c:\windows\system32\windowspowershell\v1.0\modules  or where ever you placed it
1. Right select the downloaded zip file and choose properties
1. At the bottom of the properties window select the Unblock button next to the message: *This file came from another computer and might be blocked to help protect this computer*
1. Unzip and again copy the folder into c:\windows\system32\windowspowershell\v1.0\modules or which ever path you are using



### I am getting this error message:  "running scripts is disabled on this system"
```
Import-module : File C:\Users\avandewerdt\Documents\WindowsPowerShell\Modules\ActPowerCLI\ActPowerCLI.psm1 cannot be loaded because running scripts is disabled on this system. For more information,
see about_Execution_Policies at http://go.microsoft.com/fwlink/?LinkID=135170.
At line:1 char:1
+ Import-module ActPowerCLI
+ ~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : SecurityError: (:) [Import-Module], PSSecurityException
    + FullyQualifiedErrorId : UnauthorizedAccess,Microsoft.PowerShell.Commands.ImportModuleCommand
```
If you get this there are several possible solutions, here are two:
*  When starting powershell, use this command:
```
powershell -executionpolicy unrestricted
```
*  Change Group Policy setting.  To do this:
```
Open Run Command/Console (Win + R)
Type: gpedit.msc (Group Policy Editor)
Browse to Local Computer Policy -> Computer Configuration -> Administrative Templates -> Windows Components -> Windows Powershell.
Enable "Turn on Script Execution"
Set the policy to "Allow all scripts".
```


## What about Self Signed Certs?

You only have the choice to ignore the certificate.   Clearly you can manually import the certificate and trust it, or you can install a trusted cert on the Appliance to avoid the issue altogether.
  
#### Importing or viewing the certificates on your Windows host:

1. Open a Command Prompt window.
1. Type mmc and press the ENTER key. Note that to view certificates in the local machine store, you must be in the Administrator role.
1. On the File menu, click Add/Remove Snap In.
1. Click Add.
1. In the Add Standalone Snap-in dialog box, select Certificates.
1. Click Add.
1. In the Certificates snap-in dialog box, select Computer account and click Next. Optionally, you can select My User account or Service account. If you are not an administrator of the computer, you can manage certificates only for your user account.
1. In the Select Computer dialog box, click Finish.
1. In the Add Standalone Snap-in dialog box, click Close.
1. On the Add/Remove Snap-in dialog box, click OK.
1. In the Console Root window, click Certificates (Local Computer) to view the certificate stores for the computer.

In this example you can the trusted certificate that was added:

![alt text](https://github.com/Actifio/powershell/blob/master/images/2018-06-20_15-23-38.jpg)

If we export the certificate using a webbrowser, we could import using the Certificates snapin.


### I am getting a 7.0.0 version error 

After upgrading your appliance to 10.0.0.x or higher you will get this error:

```Error: The current platform version: (10.0) 10.0.0.xxx does not support SARG reports via ActPowerCLI. The minimum version for SARG reports via ActPowerCLI is with Actifio CDS/Sky 7.0.0 and higher```

To resolve this you need to upgrade to version 10.0.0.227 of ActPowerCLI or higher.

### I am getting file not found errors

After installing a newer version of the module, you may start getting errors like these:

```
The term 'C:\Program Files (x86)\WindowsPowerShell\Modules\ActPowerCLI C:\Windows\system32\WindowsPowerShell\v1.0\Modules\ActPowerCLI\ActPowerCLI.ArgumentCompleters.ps1' is not recognized 
as the name of a cmdlet, function, script file, or operable program. Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
At C:\Program Files (x86)\WindowsPowerShell\Modules\ActPowerCLI\ActPowerCLI.psm1:239 char:6
```

This happens if you have installed two different versions of ActPowerCLI in two different locations.  For instance you have modules in more than one of the following and some of them are different versions:

```
C:\Program Files (x86)\WindowsPowerShell\Modules
C:\Program Files\WindowsPowerShell\Modules
C:\Windows\System32\WindowsPowerShell\v1.0\Modules
C:\Windows\SysWOW64\WindowsPowerShell\v1.0\Modules
```

You can also use this command to try and find all the versions:
```
(Get-Module -ListAvailable ActPowerCLI).path
```

Ideally delete all copies and install just the latest to a single location.

### Out-GridView for Mac

We have found that Out-GridView on Mac does not work for most report(SARG_ commands.   This is a bug in OGV and not the report,  as OGV with PS7 on Windows works fine.   As an alternative download and use Out-HTMLview  on Mac

# Tailing the UDSAgent.log file

On Unix hosts, we can follow the UDSAgent.log file by using: 
```
tail -f /var/act/log/UDSAgent.log
```
To do this in Windows, open a PowerShell window and run this command:
```
Get-Content -Path "C:\Program Files\Actifio\log\UDSAgent.log" -Tail 10 -Wait
```
This will show the last 10 lines of the logs and then tail the log.

We have added this as a function into our PowerShell Module.  So run this command for the same outcome:
```
Get-ActifioLogs
```



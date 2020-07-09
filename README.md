# ActPowerCLI
A Powershell module for Powershell V7 that is compatible/replacement for the older Windows only ActPowerCLI that has been available for some time from here:  https://github.com/Actifio/powershell

### Why write a new Module?

The old module was written in C to handle Windows PowerShell not being 'REST API' friendly, but it is not fully compatible with newer PowerShell versions.  PowerShell 7 needs new syntax to handle new functionality.  By writing a new module we also get one that is significantly smaller and multi-platform.

### What about an AGM module?

It is being created.   Look here:  https://github.com/Actifio/AGMPowerCLI-Beta

### What versions of PowerShell will this module work with?

It was written and tested for PowerShell V7 with Linux, Mac OS and Windows

### Is it compatible with the old ActPowerCLI?

It is a 100% replacement that is intended to be 100% compatible, meaning any existing PS1 scripts that rely on ActPowerCLI should continue to work.  Don't have the old (10.0.0 or 7.0.0.x versions) installed with the new 10.0.1.x version.


## Usage

### 1)    Install or Upgrade ActPowerCLI

Install from PowerShell Gallery:

```
Install-Module -Name ActPowerCLI
```

If the install worked, you can now move to Step 2.
If you had a previously manually created install, where you downloaded from GitHub and want to convert to using PowerShell Gallery (strongly recommended), then delete the previous manual install (just delete the module folder) and run the install from PS Gallery using the command above.  Otherwise you will get an error like this:

```
Update-Module: Module 'ActPowerCLI' was not installed by using Install-Module, so it cannot be updated.
```

#### Upgrades using PowerShell Gallery

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

#### Install Direct from GitHub

If you cannot access Powershell gallery then use these instructions:

The commands are basically the same for each OS.
To upgrade simply run the two Invoke-WebRequest commands.  If you get permission denied because the existing files are read only, delete the old files first.

#####  Determine where to place ActPowerCLI if needed

Find out where we should place the ActPowerCLI PowerShell module in the environment by querying the PSModulePath environment variable:
```
Get-ChildItem Env:\PSModulePath | format-list
```
Try to avoid installing ActPowerCLI into multiple folders.  You can check for existing installs with this command:
```
(Get-Module -ListAvailable ActPowerCLI).path
```

##### Linux OS Install directions

```
pwsh
mkdir /opt/microsoft/powershell/7/Modules/ActPowerCLI
cd /opt/microsoft/powershell/7/Modules/ActPowerCLI
```
##### Mac OS Install directions
```
pwsh
mkdir ~/.local/share/powershell/Modules/ActPowerCLI
cd ~/.local/share/powershell/Modules/ActPowerCLI
```
##### Windows OS Install directions
```
pwsh
mkdir "C:\Program Files\PowerShell\7\Modules\ActPowerCLI"
cd "C:\Program Files\PowerShell\7\Modules\ActPowerCLI"
```
#####  File download:
Now run these two commands:
```
Invoke-WebRequest -Uri https://raw.githubusercontent.com/Actifio/ActPowerCLI-PS7/main/ActPowerCLI.psd1 -OutFile ActPowerCLI.psd1
Invoke-WebRequest -Uri https://raw.githubusercontent.com/Actifio/ActPowerCLI-PS7/main/ActPowerCLI.psm1 -OutFile ActPowerCLI.psm1
```

#### Manual install

Serious corporate servers will not allow downloads from PowerShell gallery or even access to GitHub, so for these we have the following process:

1.  From GitHub, use the Green Code download button to download the ActPowerCLI-PS7 repo as a zip file
1.  Copy the Zip file to the server where you want to install it
1.  For Windows, Right select on the zip file, choose  Properties and then use the Unblock button next to the message:  "This file came from another computer and might be blocked to help protect  your computer."
1.  For Windows, now right select and use Extract All to extract the contents of the zip file to a folder.  It doesn't matter where you put the folder.  For Mac it should automatically unzip.  For Linux use the unzip command to unzip the folder.
1.  Now start PWSH and change directory to the  ActPowerCLI-PS7-main directory that should contain our module files.   
1.  There is an installer, Install-ActPowerCLI.   So run that with ./Install-ActPowerCLI.ps1
If you find multiple installs, we strongly recommend you delete them all and run the installer again to have just one install.


If the install fails with:
```
.\Install-ActPowerCLI.ps1: File C:\Users\av\Downloads\ActPowerCLI-PS7-main\ActPowerCLI-PS7-main\Install-ActPowerCLI.ps1 cannot be loaded. The file C:\Users\av\Downloads\ActPowerCLI-PS7-main\ActPowerCLI-PS7-main\Install-ActPowerCLI.ps1 is not digitally signed. You cannot run this script on the current system. For more information about running scripts and setting execution policy, see about_Execution_Policies at https://go.microsoft.com/fwlink/?LinkID=135170.
```
Then  run this command:
```
Get-ChildItem .\Install-ActPowerCLI.ps1 | Unblock-File
```
Then re-run the installer.  The installer will unblock all the files.



### 2)  Get some help


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

Note the original Windows only version has offline help files.   The PowerShell V7 version gets all help on-line.   Report commands will be able to get online help from Appliance release 10.1.0   The usvc commands have limited help at this time.

### 3)  Save your password

Create an encrypted password file using the ActPowerCLI Save-ActPassword cmdlet:
```
Save-ActPassword -filename "C:\temp\password.key"
```

The Save-ActPassword cmdlet creates an encyrpted password file on Windows, but on Linux and Mac it only creates an encoded password file.  This is not a shortcoming with the new Module since existing function is matched but ideally we should find an encryption method for non-Windows OS.   This is a 'to-do'

##### Sharing Windows key files

Currently if a Windows key file is created by a specific user, it cannot be used by a different user.    You will see an error like this:
```
Key not valid for use in specified state.
```
This will cause issues when running saved scripts when two differerent users want to run the same script with the same keyfile.    To work around this issue, please have each user create a keyfile for their own use.   Then when running a shared script, each user should execute the script specifying their own keyfile.  This can be done by using a parameter file for each script.


### 4)  Login to your appliance

To login to an Actifio appliance (10.61.5.114) as admin and enter password interactvely:
```
Connect-Act 10.61.5.114 admin -ignorecerts
```
Or login to the Actifio cluster using the password file created in the previous step:
```
Connect-Act 10.61.5.114 -actuser admin -passwordfile "c:\temp\password.key" -ignorecerts
```
You will need to store the certificate during first login if you don't use **-ignorecerts**

Note you can use **-quiet** to supress messages.   This is handy when scripting.

### 5)  Find out the current version of ActPowerCLI:

```
(Get-Module ActPowerCLI).Version

Major  Minor  Build  Revision
-----  -----  -----  --------
10     0      1      12
```

### 6) Example commands

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
#### Avoiding white space and multiple lines in array output
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

### 7)  Disconnect from your appliance
Once you are finished, make sure to disconnect (logout).   If you are running many scripts in quick succession, each script should connect and then disconnect, otherwise each session will be left open to time-out on its own.
```
Disconnect-Act
```





# What else do I need to know?


## API Limit

The old module has no API limit which means if you run 'udsinfo lsjobhistory' you can easily get results in the thousands or millions.   So we added a new command to prevent giant lookups by setting a limit on the number of returned objects, although by default this limit is off.  You can set the limit with:   Set-ActAPILimit

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

## Out-GridView for Mac

We have found that Out-GridView on Mac does not work for most SARG commands.   This is a bug in OGV and not the report,  as OGV with PS7 on Windows works fine.   As an alternative download and use Out-HTMLview  on Mac



## What about Self Signed Certs?

The old version had the ability to import SSL Certs.   The method used doesn't work in PowerShell 7 and also wouldn't work for other platforms (Mac, Linux).   So at this time you only have the choice to ignore the cert.   Clearly you can manually import the cert and trust it, or you can install a trusted cert on the Appliance to avoid the issue altogether.



## Why don't the report commands auto-load ?

When you first start pwsh, the ActPowerCLI module will auto-import, meaning you can run Connect-Act, udsinfo, udstask, etc.  but if you try and run a report command it cannot be found:

```
PS /Users/anthony/.local/share/powershell/Modules/ActPowerCLI> reportapps
reportapps: The term 'reportapps' is not recognized as the name of a cmdlet, function, script file, or operable program.
Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
```

You need to run Connect-Act and connect to an appliance.   When you do this, the report commands are auto generated.

## Best practices with report commands

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
Equally if you have multiple parameters, don't stack them.  So if we want to to specify -x and -y, then use this syntax:
```
-x -y
```
Don't use this syntax:
```
-xy
```

# Detecting errors and failures

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

# I have more questions!

Have you looked here?

https://github.com/Actifio/powershell/blob/master/FAQ.md

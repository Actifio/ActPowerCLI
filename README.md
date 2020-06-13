# ActPowerCLI
A Powershell module for Powershell V7 that is compatible/replacement for the older Windows only ActPowerCLI that has been available for some time.

# Why write a new Module?

The old module was written in C as it had to handle Windows PowerShell not being 'REST API' friendly.  This made it large and hard to maintain.
The old module is also not fully compatible with newer PowerShell versions.  PowerShell 7 needs new syntax to handle new functionality.  By using these functions we can make a much smaller module that is both modern and multiplatform.

# What about an AGM module?

It is being created.

# What versions of PowerShell will this module work with?

It was written and tested for PowerShell V7.   It has been tested on Mac OS and Windows, although it should also work fine on Linux.

Is is compatible with the old ActPowerCLI

It is a 100% replacement (don't have them both installed) that is intended to be 100% compatible, meaning any existing PS1 scripts that rely on ActPowerCLI should continue to work.



## Mac OS Install directions

Make a directory for it:

``
mkdir ~/.local/share/powershell/Modules/ActPowerCLI
``
Copy from GitHub

``
cp /Volumes/GoogleDrive/Shared\ drives/SA\ Team\ Drive/Powershell/ActPowerCLI/Act* ~/.local/share/powershell/Modules/ActPowerCLI/.
``
Start PowerShell:
``
pwsh
``
Connect (the module should auto import)
``
Connect-Act 172.24.1.180
``

# What else do I need to know?

## Supported Commands:

Right now it supports all udsinfo, udstask, usvcinfo and usvctask and report (SARG) commands.

## API Limit

The old module has no API limit which means if you run 'udsinfo lsjobhistory' you can easily get results in the thousands or millions.   So we added a new command to prevent giant lookups by setting a limit on the number of returned objects, although by default this limit is off.  You can set the limit with:   Set-ActAPILimit

## Out-GridView for Mac

We have found that Out-GridView on Mac does not work for most SARG commands.   This is a bug in OGV and not the report,  as OGV with PS7 on Windows works fine.   As an alternative download and use Out-HTMLview  on Mac

## How do I check the version?

```
PS /Users/anthony/git/ActPowerCLI> (Get-Module ActPowerCLI).Version

Major  Minor  Build  Revision
-----  -----  -----  --------
10     0      1      12
```

## What about help?

The old version has offline help files.   The current version gets all help on-line.   SARG commands will be able to get online help from Appliance release 10.0.1.   The usvc commands have limited help at this time  

## What about Self Signed Certs?

The old version had the ability to import SSL Certs.   The method used doesn't work in PowerShell 7 and also wouldn't work for other platforms (Mac, Linux).   So at this time you only have the choice to ignore the cert.   Clearly you can manually import the cert and trust it, or you can install a trusted cert on the Appliance to avoid the issue altogether.

## Saved passwords on non Windows

The Save-ActPassword cmdlet creates an encyrpted password file on Windows (just as it did before), but on Linux and Mac it only creates an encoded password file.  This is not a shortcoming with the new Module since existing function is matched but ideally we should find an encryption method for non-Windows OS.   This is a 'to-do'

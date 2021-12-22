#
# Module manifest for module 'ActPowerCLI'
#
# Generated by: Anthony Vandewerdt
#
# Generated on: 7/6/2020
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'ActPowerCLI.psm1'

# Version number of this module.
ModuleVersion = '10.0.1.38'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '324870bc-9376-4e44-837e-940d5489c12a'

# Author of this module
Author = 'Anthony Vandewerdt'

# Company or vendor of this module
CompanyName = 'Actifio'

# Copyright statement for this module
Copyright = '(c) 2021 Actifio, Inc. All rights reserved'

##################################################################################################################
# Description of the functionality provided by this module
Description = 'This is a community generated PowerShell Module that can be used to manage Actifio VDP Appliances.  
It provides a method to issue udsinfo, udstask and report commands, and Actifio CDS specific task/info commands.
More information can be found here:  https://github.com/Actifio/ActPowerCLI'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.0'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = @('Connect-Act','Disconnect-Act','udsinfo','udstask','usvcinfo','usvctask','Save-ActPassword','Set-ActAPILimit','Get-ActAPILimit','Get-Privileges','Get-ActAppID','Get-LastSnap','reportlist','Get-ActifioLogs')

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = '*'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @("Actifio","AGM","Sky","CDS","CDX","VDP")

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/Actifio/ActPowerCLI/blob/main/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/Actifio/ActPowerCLI'

        # A URL to an icon representing this module.
        IconUri = 'https://i.imgur.com/QAaK5Po.jpg'

        # ReleaseNotes of this module
        ReleaseNotes = '
        ## [10.0.1.38] 2021-12-22
        Get-SARGReport should not be run by users, they can just run the SARG report directly. if commands use parms, they will be lost.   Changing to make Get-SARGReport  private (unexported).  
        If you are using it in scripts, you will need to update those scripts before updating to this version of ActPowerCLI

        ## [10.0.1.37] 2021-12-16
        Handle case where response is null and timed out long running operation.  Clean error message will appears if empty response is received.  Timeout now applies to every single command

        ## [10.0.1.36] 2021-11-16
        The check for env:acthost was swapped with env:actsessionid at some point, resulting in a double check for env:actsessionid 

        ## [10.0.1.35] 2021-11-08
        Finally removed all PS4 content.  The DLL is now finally gone.  This module will only support PS5 going forward
        Added configurable timeout using -timeout with connect-act
        Added silent install
        Corrected issue where timeout was not being reported as an error due to missing * in the like statements

        ## [10.0.1.34] 2020-11-09
        Make PS version appear in appliance audit log

        ## [10.0.1.33] 2020-11-04
        Added command completion for udsinfo and udstask commands

        ## [10.0.1.32] 2020-10-18
        Handle role field in reportlist when it appears
        Installer was allowing install into PS3, but PSD1 file was then refusing to allow the module to start.   So instead do not allow the install.
        Get-Privileges output was blank, corrected this and heading typo

        ## [10.0.1.31] 2020-09-30
        If a uds command offers an empty variable as an argument, ignore it, let appliance complain if command is not valid.  This prevents .psm1:1608 char:17 error

        ## [10.0.1.30] 2020-09-20
        Improved module description for PowerShell Gallery users

        ## [10.0.1.27] 2020-09-18
        Set-ActAPILimit was using a PS7 test that failed on PS5,  added Get-ActAPILimit

        ## [10.0.1.26] 2020-09-13
        Updates to allow this version to run on PS5.  

        ## [10.0.1.25] 2020-09-15
        Fix typo in SARG sort order logic that was making some searches find nothing
 
        ## [10.0.1.24] 2020-09-02
        Add Get-ActifioLogs

        ## [10.0.1.24] 2020-09-02
        Add Get-ActifioLogs

        ## [10.0.1.23] 2020-08-16
        udstask testconnection commands were having .result stripped off.  This change also means udstask commands may return a status.

        ## [10.0.1.22] 2020-08-03
        Added sort order logic to bring order to the output
        Handle apps with space in their names

        ## [10.0.1.21] 2020-07-16
        usvctask rmmdisk only worked if -force was the first parameter.   Added check for this, so both of these now work (previously only the upper one worked):
        usvctask rmmdisk -force -mdisk mdisk1 mdiskgrp1 
        usvctask rmmdisk -mdisk mdisk1 -force mdiskgrp1 
        
        ## [10.0.1.20] 2020-06-24
        Added Tags to PSD file so module can be found in PowerShell Gallery
        
        ## [10.0.1.19] 2020-06-23
        Corrected issue where udsinfo -h printed every command twice.
        
        ## [10.0.1.18] 2020-06-20
        No functional changes.  This version is uploaded to PSGallery: https://www.powershellgallery.com/packages/ActPowerCLI
        
        ## [10.0.1.17] 2020-06-19
        Because report commands do not load as functions until after Connect-Act, this causes confusion.   Added reportlist as a discreet function to give useful error message.
        
        ## [10.0.1.16] 2020-06-18
        All error messages that are locally generated will use the same format as appliance generated, making the behavior more consistent and script able.
        
        ## [10.0.1.15] 2020-06-16
        Added helpful exit message when Get-SARGReport is run without a sub-command, rather than no message
        When Get-SARGReport is run with -h will now show reportlist output rather than no message
        Corrected issue where when Connect-Act was run with -quiet, user could not run any SARG reports 
        Added URL encoding to SARG payload
        Added code to support SARG help when it is supported on Appliance Side
        
        ## [10.0.1.14] 2020-06-14
        Stop exporting private functions
        
        ## [10.0.1.13] 2020-06-14
        Added missing cmdlets: Get-Privileges, Get-LastSnap, Get-ActAppID  as functions
        Improved help
        
        ## [10.0.1.12] 2020-06-13
        Initial release'

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}


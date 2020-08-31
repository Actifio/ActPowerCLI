# function to set module path.
Function setModulePath() 
{
	# module can be installed anywhere. in users homedir or in the system module path
	# lets find the location and return it so that the help test will work nicely.
	$actmodules = Get-Module -ListAvailable ActPowerCLI
	if ($actmodules.count -eq 1)
	{
		return (Get-Module -ListAvailable ActPowerCLI).ModuleBase;
	}
	else 
	{
		return (Get-Module -ListAvailable ActPowerCLI).ModuleBase[0];
	}
}

<#
.SYNOPSIS
Login to a VDP appliance.

.EXAMPLE
connect-act -acthost 172.25.2.110 -actuser admin -passwordfile C:\users\Anoop\actpass
Using a password file to login. Path to password file can be absolute or relative path.

.EXAMPLE
connect-act -acthost 172.25.2.110 -actuser admin -password Password123
Example using the password on the command line itself to login.

.DESCRIPTION
Connect to VDP Appliance using a username and password or by specifying -passwordfile
which will use stored credentials.

If no password is provided and no passwordfile flag is set, then the cmdlet will
 prompt for a password

Using -quiet suppresses all successful messages

Before authentication, the certificate for the appliance must be installed into the 

"Trusted Root Certification Authorities"

store on the computer where the connection is being initiated.

To install the certificate, browse to https://IP where IP is the IP/name of the appliance
and then install the certificate using the installation wizard. 

With Internet Explorer, you may have to run IE as Administrator in order to install
the certificate.

.PARAMETER acthost
Required. Hostname or IP to connect to.ACTPRIVILEGES

.PARAMETER cdsuser
Required. Username to connect to VDP as. Same username that is used in the 
Actifio Desktop login screen.

.PARAMETER password
Optional. If not provided, a prompt will be presented. If provided, it can be provided
as clear text.

example: connect-act -acthost 172.25.2.110 -actuser admin -password Password123

.PARAMETER passwordfile
Optional. This is a string that instructs Connect-Act to use stored credentials as 
opposed to interactive login. In order to use -passwordfile, you must use 
save-actpassword first to save the password.

example: connect-act -acthost 172.25.2.110 -actuser admin -passwordfile C:\users\Anoop\actpass
example: connect-act 172.25.2.110 admin -passwordfile .\actpass
example: connect-act 172.25.2.110 admin -passwordfile actpass


The password file can be a relative path or a fully qualified path to the file

.PARAMETER quiet
Optional. Suppresses all success messages. Use this in scripting when you
don't want to see a successful login message. To validate the connection, check
for variable $ACTSESSIONID


#>
# this function will execute Connect-ActAppliance with the proper variables.
Function Connect-Act([string]$acthost, [string]$actuser, [string]$password, [string]$passwordfile, [switch][alias("q")]$quiet, [switch]$ignorecerts) 
{
    # if OS is not Windows and Powershell is higher than 5, then we should get a value for this and be able quit early rather than fail later


	# set the security protocol to be TLS12 in Powershell
	$env:CUR_PROTS = [Net.ServicePointManager]::SecurityProtocol
	[Net.ServicePointManager]::SecurityProtocol =  [Net.SecurityProtocolType]::Tls12

	# if OS is not Windows and Powershell is higher than 5, then we should get a value for this and be able quit early rather than fail later
	$platform=$PSVersionTable.platform
	if ( $platform -match "Unix" )
	{
		Echo "ActPowerCLI does not support non-Windows Powershell"
		return; 
	}

	# if no host is provided, error and exit
	if ( $acthost -eq $null -or $acthost -eq "" ) 
	{
		$acthost = Read-Host "IP or Name of VDP Appliance"
	}

	# if the powershell is CORE then we need to catch invalid certs now 
	$hostVersionInfo = (get-host).Version.Major
    if ( $hostVersionInfo -gt "5" )
	{
		$RestError = $null
		Try 
		{
  			Invoke-RestMethod -Uri https://$acthost/actifio/api/version > $null	
		} 
		Catch 
		{ 
			$RestError = $_
		}
		if ($RestError) 
		{
			Echo "PowerShell version $hostVersionInfo is higher than Windows Powershell 5 and the VDP Appliance certificate is not valid."
			Echo "You need to manually import the SSL Certificate before using this plugin.";
		}
	}


	# if ignore certs is not set, then bother with certificate validation. 
	# if not, then set the env:IGNOREACTCERTS and move on.
	if ( -not $ignorecerts ) 
	{
		# try to connect and catch exceptions for trust failures, and connection failures and then any other generic exception
		try {
			Connecthttps($acthost);
		}
		catch [System.Net.WebException]
		{
			# catch a trustfailure and prompt for ignore & continue, accept & install, cancel
			if ( $_.Exception.Message.ToString() -eq "TrustFailure" ) 
			{
				Write-Host -ForeGroundColor Yellow "The SSL certificate from https://$acthost is not trusted. Please choose one of the following options";
				Write-Host -ForeGroundColor Yellow "(I)gnore & continue";
				Write-Host -ForeGroundColor Yellow "(A)ccept & install certificate";
				Write-Host -ForeGroundColor Yellow "(C)ancel";
				$validresp = ("i", "I", "a", "A", "c", "C");
				$certaction = $null
			
				# prompt until we get a proper response.	
				while ( $validresp.Contains($certaction) -eq $false )
				{
					$certaction = Read-Host "Please select an option";
				}

				# based on the action, do the right thing.
				if ( $certaction -eq "i" -or $certaction -eq "I" )
				{
					# set IGNOREACTCERTS so that the CDSAPI ignores bad certs
					$env:IGNOREACTCERTS = $acthost;
				}
				elseif ( $certaction -eq "a" -or $certaction -eq "A" ) 
				{	
					# ignore the cert error and continue
					try {
						InstallCertificate($acthost);
						$env:IGNOREACTCERTS = $acthost;
					} catch [System.Security.Cryptography.CryptographicException]
					{
						Echo "An error occurred."
						Echo $_.Exception.Message;
						return;
					}
				} elseif ( $certaction -eq "c" -or $certaction -eq "C" ) 
				{
					# just exit
					return;
				}

			} else {
				Echo "An error occurred.";
				Echo $_.Exception.Message;
				return;
			}

		}
	} else {
		$env:IGNOREACTCERTS = $acthost;
	}

	# if no user is provided, error and exit
	if ( $actuser -eq $null -or $actuser -eq "" ) 
	{
		$actuser = Read-Host "VDP Appliance user"
	}

	# if passwordfile is not set and password is not set, prompt for password.
	# if passworfile is set, then go look for the password file in that special place.
	if ( $passwordfile -eq $null -or $passwordfile -eq "" ) 
	{
		if ($password -eq $null -or $password -eq "")
		{
			# prompt for a password
			[SecureString]$passwordenc = Read-Host -AsSecureString "Password";
		}
		else 
		{
			[SecureString]$passwordenc = (ConvertTo-SecureString $password -AsPlainText -Force)
		}
	} 
	else 
	{
		# if the password file provided is relative or absolute doesn't matter. Test for it first
		if ( Test-Path $passwordfile )
		{
			[SecureString]$passwordenc = Get-Content $passwordfile | ConvertTo-SecureString;
		} 
		else 
		{
			Write-Error "Password file: $passwordfile could not be opened."
			return;
		}
	}

	# Connect to CDS Appliance
	if ( $quiet ) 
	{
		Connect-ActAppliance -cdshost $acthost -cdsuser $actuser -Password $passwordenc -Quiet;
	}
	else 
	{
		Connect-ActAppliance -cdshost $acthost -cdsuser $actuser -Password $passwordenc;
	}


	# if we have a session id, then lets create a bunch of functions that allows for nice
	# things like "reportapps" to work natively.
	if (Test-Path ENV:\ACTSESSIONID)  
	{
		# get the location of the installed module
		$mp = setModulePath;

		if ( Get-Command Register-ArgumentCompleter -ea Ignore )
		{

			# in powershell 5, register-argumentcompleter is included and works the same as 
			# tabexpansionplusplus but doesn't have the -Description field.

			# source the files that have all the functions listed for the argument completion
			. $mp\ActPowerCLI.ArgumentCompleters.ps1

			# set the environment variables for the auto completers to help make it faster
			$env:UDSINFOCMDS=(udsinfo -h).name
			$env:UDSTASKCMDS=(udstask -h).name
			$env:USVCINFOCMDS=(Get-Content $mp\help\usvcinfo_commands.txt)
			$env:USVCTASKCMDS=(Get-Content $mp\help\usvctask_commands.txt)

			# register the argument completers
			# udsinfo
			Register-ArgumentCompleter -CommandName udsinfo -Parameter subcommand -ScriptBlock $function:udsinfoSubCommandCompletion 
			# udstask
			Register-ArgumentCompleter -CommandName udstask -Parameter subcommand -ScriptBlock $function:udstaskSubCommandCompletion 
			
			# usvcinfo
			Register-ArgumentCompleter -CommandName usvcinfo -Parameter subcommand -ScriptBlock $function:usvcinfoSubCommandCompletion 
			# usvctask
			Register-ArgumentCompleter -CommandName usvctask -Parameter subcommand -ScriptBlock $function:usvctaskSubCommandCompletion 

		}

		# create sarg functions
		makeSARGCmdlets;
	}
}

<#
.SYNOPSIS
Disconnect and end the session with the VDP Appliance.

.EXAMPLE
Disconnect-Act

.DESCRIPTION
Disconnect from the VDP appliance and end the session nicely.

#>
# this function disconnects from the VDP Appliance
function Disconnect-Act([switch][alias("q")]$quiet)
{



		if ( Get-Command Register-ArgumentCompleter -ea Ignore )
		{
			# unset the environment variables for the auto completers to help make it faster
			$env:UDSINFOCMDS=$null
			$env:UDSTASKCMDS=$null
			$env:USVCINFOCMDS=$null
			$env:USVCTASKCMDS=$null
		}

	# reserved for any pre steps before disconnecting

	# Connect to CDS Appliance
	if ( $quiet ) 
	{
		Disconnect-ActAppliance -Quiet;
	}
	else 
	{
		Disconnect-ActAppliance
	}

	# Set the security protocol back to the old defaults
	[Net.ServicePointManager]::SecurityProtocol = $env:CUR_PROTS
	Remove-Item env:\CUR_PROTS 
}

<#
.SYNOPSIS
Save credentials so that scripting is easy and interactive login is no longer 
needed.

.EXAMPLE
Save-ActPassword -filename ./5b-admin-pass
Save the password for use later.

.DESCRIPTION
Store the credentials in a file which can be used to login to VDP Appliance.

Providing a acthost and a cdsuser will prompt for a password which will then be 
stored in the file location provided.

To change the credentials, simply re-run the cmdlet.

.PARAMETER filename
Required. Absolute or relative location where the file should be saved. 
example: .\actpass
example: C:\Users\Anoop\actpass

#>
# this function will save a cds password so that ActPowerCLI can be used in scripts.
Function Save-ActPassword([string]$filename)
{
	# if no file is provided, prompt for one
	if ( $filename -eq $null -or $filename -eq "" )
	{
		$filename = Read-Host "Filename";
	}

	# if the filename already exists. don't overwrite it. error and exit.
	if ( Test-Path $filename ) 
	{
		Write-Error "The file: $filename already exists. Please delete it first.";
		return;
	}

	# prompt for password 
	$password = Read-Host -AsSecureString "Password"

	$password | ConvertFrom-SecureString | Out-File $filename

	if ( $? )
	{
		echo "Password saved to $filename."
		echo "You may now use -passwordfile with Connect-Act to provide a saved password file."
	}
	else 
	{
		Write-Error "An error occurred in saving the password";
	}
}

<#
.SYNOPSIS
Executes udsinfo commands via a rest API hosted on VDP Appliance.

.EXAMPLE
udsinfo lsuser
list users on connect VDP appliance.

.EXAMPLE
udsinfo lsapplication 12345
List details about application id 12345

.EXAMPLE
udsinfo lsapplication -filtervalue appname=*db*
List any applications that contain "db" in the name

.EXAMPLE
udsinfo lsapplication -filtervalue "appname=*db*&hostid=333620"
List any applications that contain "db" in the appname and are a match 
for hostid 333620. The filtervalue here needs to be quoted because & is 
a reserved special character in Powershell. 

.EXAMPLE
udsinfo -h
See all the available subcommands to udsinfo

.EXAMPLE
udsinfo lsapplication -h
See the help information for lsapplication subcommand.

.DESCRIPTION
Once you have connected to a VDP Appliance using Connect-Act, you can execute 
udsinfo with a subcommand to return information from a VDP Appliance . Udsinfo commands
allow you to retrieve information and settings from a VDP Appliance. These commands can be
safely executed without any danger to the system.

Output from CDS Is always presented as a PSObject. Unlike the ssh CLI, -delim does
not work and is not an accepted argument.

use udsinfo -h to get the list of possible subcommands.

udsinfo SUBCOMMAND -h will provide help on that specific topic.

Note: you must connect to a VDP Appliance  using Connect-Act after version 1.1.0.0. 
Help is retrieved dynamically from a VDP Appliance .

.PARAMETER subcommand
Required. Subcommand to udsinfo. Example: lshost, lsuser, lsapplication.

.PARAMETER argument
Optional. Use argument to get more information about a specific object. 
Example: lshost sql01 or lshost 2342

.PARAMETER filtervalue
Optional. Can be used to filter the information received from a VDP Appliance. 
Filtervalue is ignored when argument is provided.

Example: lshost -filtervalue hostanme=exch*

.PARAMETER help
Optional. Use this for getting subcommand help. Needs no value. 
Example: lshost -h

.PARAMETER args
Arguments to be provided to the function that do not meet the requirements above. 
Example: getgcschedule -type gc
#>
# this function will imitate udstask so that users don't need to remember each individual cmdlet
Function udsinfo([string]$subcommand, [string]$argument, [string]$filtervalue, [switch][alias("h")]$help)
{
	# get the location of the installed module
	$mp = setModulePath;

	# if no subcommand is provided, display the list of subcommands and exit
	if ( $subcommand -eq "" )
	{
		Invoke-Expression "Get-ActHelp udsinfo"
		return;
	}

	# Help will always be given at Hogwarts to those who ask for it. -Dumbledore
	if ( $help )
	{
		# if there's no subcommand, then get help for udsinfo -h. If not, udsinfo subcommand -h
		if ( $subcommand -ne "")
		{
			$expression = "Get-ActHelp udsinfo $subcommand"
		} else 
		{
			$expression = "Get-ActHelp udsinfo"
		}

		# get the output
		Invoke-Expression "$expression" | more
		return;
	} 

	# args length can be 0. Means no arguments are passed but filtervalue can still be used
	if ( $args.Length -le 0 ) 
	{
		$expression = "Get-ActInfo $subcommand";
		if ( $filtervalue -ne "" )
		{
			$expression = $expression + " -filtervalue " + '"' + $filtervalue + '"';
		}
	} else 
	{
		$arghash = generateHashtable($args);
		$expression = "Get-ActInfo $subcommand $arghash";
	}

	if ( $argument -ne "" )
	{
		$arghash = '@{ "argument" = "' + $argument + '";}';
		$expression = "Get-ActInfo $subcommand $arghash";
	} 

	#$arghash
	$output = Invoke-Expression "$expression";
	
	if ( $output -ne $null ) 
	{
		echo $output
	}
	
}

<#
.SYNOPSIS
Executes usvcinfo commands via a rest API hosted on CDS only. Usvcinfo is not supported on a Virtual Appliance.

.EXAMPLE
usvcinfo -h
List out the possible subcommands for usvcinfo

.EXAMPLE
usvcinfo lsvdisk 1
List details about vdisk id 1

.EXAMPLE
usvcinfo lsmdisk
List out all the mdisks on a CDS appliance.

.DESCRIPTION
Usvcinfo commands are like udsinfo commands. They provide a view into settings and the current state
of an Actifio CDS appliance. Usvcinfo commands are safe to run without causing any harm to the system.

#>
# function to imititate usvcinfo so that users don't need to remember each individual cmdlet
Function usvcinfo([string]$subcommand,[string]$argument, [string]$filtervalue, [switch][alias("h")]$help) 
{
	# get the location of the installed module
	$mp = setModulePath;

	# display help if that's what is requested
	if ( $help ) 
	{
		if ( $subcommand -eq "" ) 
		{
			Get-Content "$mp\help\usvcinfo_commands.txt";
			return;
		} 
		else 
		{
			$expression = "Get-ActHelp usvcinfo $subcommand"
		}

    	# get the output
		Invoke-Expression "$expression" | more
		return;
	} 

	# if the platform is Virtual, then usvcinfo doesn't work. so stop right here.
	if ( $env:ACTPLATFORM.toLower() -ne "cds" ) 
	{
		echo "Error: usvcinfo command is only available on Actifio CDS. Current platform is $env:ACTPLATFORM"
		return
	}

	$expression = "Get-SHInfo $subcommand $argument"

	if ( $filtervalue -ne "" )
	{
		$expression = $expression + " -filtervalue " + '"' + $filtervalue + '"';
	}
	
	$output = Invoke-Expression "$expression";
	if ( $output -ne "" ) 
	{
		echo $output 
	}
}

<#
.SYNOPSIS
Executes udstask commands via a rest API hosted on a VDP Appliance. 

.EXAMPLE
udstask mkuser -h
See help for the mkuser subcommand. 

.EXAMPLE
udstask mkuser -name john.doe -password Password12345
Create a new user named "john.doe" with a password. Additional optional fields can be specified as well. See help.

.EXAMPLE
udstask backup -app 4222 -policy 4111
Run an on demand backup job for app id 4222 with policy 4111.

.EXAMPLE
udstask -h
See all the available subcommands to udstask

.DESCRIPTION
Once you have connected to a VDP Appliance using Connect-Act, you can execute 
udstask with a subcommand to make changes on a VDP Appliance. Udstask commands conduct
actions on an VDP Appliance. Actions such as creation of hosts, users, running
jobs, etc.

Output from CDS Is always presented as an object.

use udstask -h to get the list of possible subcommands.

udstask SUBCOMMAND -h will provide help on that specific topic.

Note: you must connect to a VDP Appliance using Connect-Act after version 1.1.0.0. 
Help is retrieved dynamically from a VDP Appliance.

.PARAMETER subcommand
Required. Subcommand to udstask. Example: mkhost, mkuser, mksla.

.PARAMETER help
Optional. Use this for getting subcommand help. Needs no value. 
Example: mkuser -h

.PARAMETER args
Arguments to be provided to the function that do not meet the requirements above. 
Example: setparameter -param systemlocation -value Chicago
#>
# this function will imitate udstask so that users don't need to remember each
# individual cmdlet.
Function udstask ([string]$subcommand, [switch][alias("h")]$help) 
{
	# get the path of the module install directory
	$mp = setModulePath;

	# if no subcommand is provided, get the list of udstask commands and exit.
	if ( $subcommand -eq "" )
	{
		Invoke-Expression "Get-ActHelp udstask"
		return;
	}

	# Help will always be given at Hogwarts to those who ask for it. -Dumbledore
	if ( $help )
	{
		# if there's no subcommand, then get help for udsinfo -h. If not, udsinfo subcommand -h
		if ( $subcommand -ne "")
		{
			$expression = "Get-ActHelp udstask $subcommand"
		} else 
		{
			$expression = "Get-ActHelp udstask"
		}

		# get the output
		Invoke-Expression "$expression" | more
		return;
	} 

	# Set the cmdlet and subcommand
	$cmdlet = "New-ActTask"
	$expression = "$cmdlet $subcommand"

	# if a subcommand is provided but no arguments are provided, display the help for that subcommand if it exists in the list.
	# does this section ever get used? Who just calls udstask subcommand? no one. THat's who.
	if ( $args.Length -le 0 ) 
	{
		$output = Invoke-Expression "$expression";
		echo $output;
		return;
	}

		$arguments = generateHashtable($args)
		$output = Invoke-Expression "$cmdlet $subcommand $arguments";

	if ( $output -ne $null ) 
	{
		echo $output
	}
}

<#
.SYNOPSIS
Executes usvctask commands via a rest API hosted on CDS only. Usvctask is not supported on a Virtual Appliance.

.EXAMPLE
usvctask -h
List out the possible subcommands for usvctask

.EXAMPLE
usvctask mkmdiskgrp -h
Display the help contents for the mkmdiskgrp subcommand.

.DESCRIPTION
Usvctask commands are very dangerous and should only be executed by an administrator who has deep
knowledge of IO and SAN storage. Usvctask commands can have undesired consequences if used incorrectly.

Proceed with caution.

#>
# this command will allow users to run specific usvctask commands.
Function usvctask([string]$subcommand, [switch][alias("h")]$help)
{
	# get the path of the module install directory
	$mp = setModulePath;

	# display help if that's what is requested
	if ( $help ) 
	{
		if ( $subcommand -eq "" ) 
		{
			Get-Content "$mp\help\usvctask_commands.txt";
			return;
		} 
		else 
		{
			$expression = "Get-ActHelp usvctask $subcommand"
		}

    	# get the output
		Invoke-Expression "$expression" | more
		return;
	} 


	# if the platform is not CDS, then usvcinfo doesn't work. so stop right here.
	if ( $env:ACTPLATFORM.toLower() -ne "cds" ) 
	{
		echo "Error: usvctask command is only available on Actifio CDS. Current platform is $env:ACTPLATFORM"
		return
	}

	$cmdlet = "New-SHTask";

	# if arguments are provided, lets create a hash out of them.
	if ( $args.Length -le 0 ) 
	{
		$expression = "$cmdlet $subcommand"
	} else 
	{
		$arguments = generateHashtable($args)
		$expression = "$cmdlet $subcommand $arguments"
	}

	# execute the expression against the API
	$output = Invoke-Expression "$expression";

	if ( $output -ne $null ) 
	{
		echo $output
	}

}

<#
.SYNOPSIS
Executes SARG commands via a rest API hosted on a VDP Appliance.

.EXAMPLE
get-sargreport reportlist
List out the possible reports available.

.EXAMPLE
get-sargreport reportimages -a 123456
Runs reportimages report for the appid 123456

.DESCRIPTION
report commands that were available only in a VDP Appliance via ssh for a very long time
are now available via ActPowerCLI module.

#>
# get-sargreport function
Function get-sargreport([string]$reportname, [switch][alias("h")]$help)
{

	# get the location of the installed module
	$mp = setModulePath;

	# if no subcommand is provided, display the list of subcommands and exit
	if ( $reportname -eq "" )
	{
		Echo "No reportname was provided. Please provide a reportname."
		return;
	}

	# display help if that's what is requested
	if ( $reportname -ne "" -and $help )
	{
		if ( (Test-Path "$mp\help\SARG\$reportname-help.txt") -eq $true ) 
		{ 
			Get-Content "$mp\help\SARG\$reportname-help.txt" | more;
		} else 
		{
			echo "Error: Command: $reportname not found or help does not exist.";
		}
		return;
	}


	# help code goes here. Help for sargreports are stored as part of the module 
	# 
	# end help code

	# args length can be 0. Means no arguments are passed but filtervalue can still be used
	if ( $args.Length -le 0 ) 
	{
		$expression = "Get-ActReport $reportname";
	} else 
	{
		$arghash = generateHashtable($args);
		$expression = "Get-ActReport $reportname $arghash";
	}

	$output = Invoke-Expression "$expression";
	
	if ( $output -ne $null ) 
	{
		echo $output
	}
}

# create the functions so that report* commands work like they do with SSH CLI
function makeSARGCmdlets()
{
	# set reportlist
	set-item -path function:global:reportlist -value {get-sargreport reportlist -p};

	# get the list of sarg commands and set an item for each
	$sargcmdlist = (get-sargreport reportlist -p).ReportName
	
	foreach ($cmd in $sargcmdlist) 
	{
		set-item -path function:global:$cmd -value { get-sargreport $cmd @args}.getNewClosure(); 
	}

}

# takes a list of arguments and returns it as a string
#Function generateArguments($arglist) 
#{
#	$argstr;
#	foreach( $arg in $arglist) f
#	{
#		$argstr = $argstr + $arg + " ";	
#	}
#	return $argstr;
#}

# generate a hashtable
Function generateHashtable($arglist) 
{
	# holds if the previous argument analyzed was a param or a value
	# so if someone passes -physicalrdm -nowait, this should be smart enough to		
	# make it -physicalrdm true -nowait true
	$currargtype = $null;
	$prevargtype = $null;

	# but if only one argument is passed, we should return "argument" = arg
	if ( $arglist.Length -eq 1 )
	{
		if (  $arglist[0].ToString().StartsWith("-") -eq $false) 
		{
			return '@{ "argument" = "' + $arglist[0] + '"; }'
		} 
		else
		{
			return '@{ "' + $arglist[0] + '" = "true"; }'
		}
	} 

	$arghash = "@{ ";
	foreach ($arg in $arglist) 
	{
		if ( $arg.ToString().StartsWith("-") ) 
		{
			# current argument is parameter
			$currargtype = "param";

			if ( $prevargtype -eq $currargtype -and $currargtype -eq "param" ) 
			{
				$arghash = $arghash + '"' + "true" + '"; ';
			}

			$temparg = '"' + $arg.TrimStart("-") + '"';
			$arghash = $arghash + $temparg + " = ";
		} 
		else 
		{
			# current argument is a value
			$currargtype = "value";
			# if two values are together, then insert "argument" before the last one.
			if ( $prevargtype -eq $currargtype -and $currargtype -eq "value" )
			{
				$arghash = $arghash + '"' + "argument" + '" = ';
			}
			$temparg = '"' + $arg + '"';
			$arghash = $arghash + $temparg + "; ";
		}

		$prevargtype = $currargtype;
	}

	# add a true if the last argument is a parameter
	# why would the last argument be a parameter???

	if ( $arglist[-1].ToString().StartsWith("-") ) 
	{
		$arghash = $arghash + '"' + "true" + '"; '
	}

	$arghash = $arghash + " }";

	return $arghash;
}

# function that will validate the connection to VDP Appliance
# return if there's a connection failure
# or if the certificate is untrusted
Function Connecthttps([string]$acthost) 
{
	$uri = [Uri]"https://$acthost/actifio/api/version";

	$request = [System.Net.HttpWebRequest]::Create($uri);

	try
    {
        #Make the request but ignore (dispose it) the response, since we only care about the service point
        $request.GetResponse().Dispose()
    }
    catch [System.Net.WebException]
    {
	    # if we fail to connect, display that
		if ($_.Exception.Status.toString() -eq "ConnectFailure")
		{
			throw [System.Net.WebException] "Could not connect to https://$acthost";
		}
		# if the cert is not trusted. display that.
        if ($_.Exception.Status.toString() -eq "TrustFailure")
        {
			throw [System.Net.WebException] "TrustFailure";
        }
		# if the IP/host is alive but is not actually a VDP Appliance, display that
		if ($_.Exception.Status.toString() -eq "ProtocolError")
		{
			throw [System.Net.WebException] $_.Exception.Message;
		}
    }
}

# This function will install the untrusted certificate for the VDP Appliance host so that it will no longer prompt
Function InstallCertificate($acthost)
{
	$untrustedcert = getCertificateDetails($acthost);
	$certbytes = $untrustedcert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert);

	# write the details temporarily to a file so we can import it. Will delete file after
	[System.IO.File]::WriteAllBytes("$acthost-certificate.cer", $certbytes);

	Echo "Certificate details"
	
	Write-Host -ForegroundColor Yellow "Issuer: " $untrustedcert.Issuer.ToString();
	Write-Host -ForegroundColor Yellow "Subject: " $untrustedcert.Subject.ToString();
	Write-Host -ForegroundColor Yellow "Effective: " $untrustedcert.GetEffectiveDateString();
	Write-Host -ForegroundColor Yellow "Expiration: " $untrustedcert.GetExpirationDateString();
	Echo "This certificate will be installed into the Trusted Root Certication Authorities store";
	Echo "Please choose the location where the certificate should be installed";
	Echo "[M] LocalMachine";
	Echo "[U] CurrentUser";
	$loclist = ("M", "U");
	$loc = $null;

	# loop until the right option is selected
	while ( $loc -eq $null  -or $loclist.Contains($loc.ToUpper()) -eq $false )
	{
		$loc = Read-Host "Choose location"
	}

	# M = LocalMachine, U = CurrentUser
	if ( $loc.ToUpper() -eq "M" )
	{
		$location = "LocalMachine";
	} else {
		$location = "CurrentUser";
	}

	# Choose the Root store which is where Trusted Root Certification Authorities lives
	$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root",$location);
	$store.open("MaxAllowed");

	# try to add the certificate and catch an exception and throw it back
	try {
		$store.add("$acthost-certificate.cer");
		Echo "Certificate added successfully and will be used in the next session.";
	}
	catch [System.Security.Cryptography.CryptographicException]
	{
		throw $_;
	}
	finally
	{
		$store.Close();
		[System.IO.File]::Delete("$acthost-certificate.cer");
	}
}

# just get the certificate details.
Function getCertificateDetails($acthost) 
{
	$uri = [Uri]"https://$acthost/actifio/api/version";

	$request = [System.Net.HttpWebRequest]::Create($uri);

	try
    {
        #Make the request but ignore (dispose it) the response, since we only care about the service point
        $request.GetResponse().Dispose()
    }
    catch [System.Net.WebException]
    {
        if ($_.Exception.Status.toString() -eq "TrustFailure")
        {
			$cert = $request.ServicePoint.Certificate;
			return $cert;
        }
    }
}

Export-ModuleMember -Alias * -Function udsinfo,udstask,usvcinfo,usvctask,connect-act,save-actpassword,get-sargreport,Disconnect-Act -Cmdlet Get-LastSnap,Get-Privileges,Get-ActAppID -Variable *

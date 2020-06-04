<#
.SYNOPSIS
Login to a VDP appliance.

.EXAMPLE
connect-act -acthost 172.25.2.110 -actuser admin -passwordfile pass.key
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

.PARAMETER acthost
Required. Hostname or IP to connect to.ACTPRIVILEGES

.PARAMETER actuser
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

example: connect-act -acthost 172.25.2.110 -actuser admin -passwordfile pass.key
example: connect-act 172.25.2.110 admin -passwordfile .\pass.key
example: connect-act 172.25.2.110 admin -passwordfile pass.key


The password file can be a relative path or a fully qualified path to the file

.PARAMETER quiet
Optional. Suppresses all success messages. Use this in scripting when you
don't want to see a successful login message. To validate the connection, check
for variable $vdpsessionid


#>
function  Connect-Act([string]$acthost, [string]$actuser, [string]$password, [string]$passwordfile, [switch][alias("q")]$quiet, [switch][alias("p")]$printsession) 
{

    if ( $acthost -eq $null -or $acthost -eq "" )
    {
    $vdpip = Read-Host "IP or Name of VDP"
    }
    else
    {
        $vdpip = $acthost
    }

    if ( $actuser -eq $null -or $actuser -eq "" )
    {
    $vdpuser = Read-Host "VDP user"
    }
    else
    {
        $vdpuser = $actuser
    }

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


    $UnsecurePassword = ConvertFrom-SecureString -SecureString $passwordenc -AsPlainText
    $Url = "https://$vdpip/actifio/api/login?name=$vdpuser&password=$UnsecurePassword&vendorkey=1955-4670-2506-0A51-0841-5829-0622-4418-5A07-1146-0343-5444"
    $RestError = $null
    Try
    {
        $resp = Invoke-RestMethod -SkipCertificateCheck -Method POST -Uri $Url  -TimeoutSec 15
    }
    Catch
    {
        $RestError = $_
    }
    if ($RestError) 
    {
        $RestError | ConvertFrom-JSON
    }
    else
    {
        $global:vdpsessionid = $resp.sessionid
        $global:vdpip = $vdpip
        if ($quiet)
        { 
            return 
        } 
        elseif ($printsession)
        {
            Write-Host "$vdpsessionid" 
        }
        else
        { 
            Write-Host "Login Successful!"
        }
        makeSARGCmdlets
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
    $Url = "https://$vdpip/actifio/api/logout" + "?&sessionid=$vdpsessionid"
    $RestError = $null
    Try
    {
        $resp = Invoke-RestMethod -SkipCertificateCheck -Method POST -Uri $Url  -TimeoutSec 15
    }
    Catch
    {
        $RestError = $_
    }
    if ($RestError) 
    {
        $RestError | ConvertFrom-JSON
    }
    else
    {
        if ($quiet)
        { 
            return 
        } 
        else
        { 
            Write-Host "Success!"
        }
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
The majority of report commands that are available in a VDP Appliance are available via ActPowerCLI module.

#>
# get-sargreport function
function get-sargreport([string]$reportname)
{
    if ($args) 
	{
        # we are going to send all the SARG command opts in REST format as sargopts
        $sargopts = $null
        $argprint = $args | Out-String
        # we will split on dashes.   This means if there are dashes in a search object, this will break the process.  We dump blank lines
        $dashsep = $argprint.Split("-") -notmatch '^\s*$'
        foreach ($arg in $dashsep) 
            {
                # remove any whitespace at the end
                $trimm = $arg.TrimEnd()
                # do we have a single letter.  If so this is out parm.   If the user didn't use a dash this will also work,  so -i and i both work
                $length = $trimm.length
                if ( $length -eq 1 )
                {
                        $sargopts =  $sargopts + "$trimm" + "=true" + "&"
                }
                # if length is greater than one then we either have a parm with search  like -a 1232  or we have grouped parms like -ty
                if ( $length -gt 1 )
                {
                    $parmcount = $trimm | measure-object -word
                    # if we find only one word then all the parms are together like -ty so we process them one at a time
                    if ( $parmcount.words -eq 1 )
                    { 
                        $splitblob = $trimm.tochararray()
                        foreach ($arg in $splitblob) 
                        {
                            $sargopts =  $sargopts + "$arg" + "=true" + "&"
                        }
                    }
                    # if we have more then one word then we have a search like  -a 1234
                    if ( $parmcount.words -gt 1 )
                    { 
                        # the first word will be the parm   If the first word is more than one character long then there is an issue and we ignore it
                        $firstword = $trimm.Split([Environment]::NewLine) | Select -First 1
                        $length = $firstword.length
                        if ( $length -eq 1 )
                        {
                            # the second word should be the search term   Spaces are not an issue
                            $secondword = $trimm.Split([Environment]::NewLine) | Select -last 1
                            $sargopts =  $sargopts + "$firstword" + "=" + "$secondword" + "&"
                        }
                    }
                }
            }
        $Url = "https://$vdpip/actifio/api/report/$reportname" + "?" + "$sargopts" + "sessionid=$vdpsessionid"
        Try
        {
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
        }
        Catch
        {
            $RestError = $_
        }
        if ($RestError) 
        {
            $RestError | ConvertFrom-JSON
            Return
        }
        else
        {
            $resp.result
            Return
        }
    } 
    else 
	{
        $Url = "https://$vdpip/actifio/api/report/$reportname" + "?sessionid=$vdpsessionid" 
        Try
        {
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
        }
        Catch
        {
            $RestError = $_
        }
        if ($RestError) 
        {
            $RestError | ConvertFrom-JSON
            Return
        }
        else
        {
            $resp.result
            Return
        }
	}
}


# create the functions so that report* commands work like they do with SSH CLI
function makeSARGCmdlets()
{
    
    $Url = "https://$vdpip/actifio/api/report/reportlist?p=true&sessionid=$vdpsessionid"
    Try
    {    
        $reportlistout = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
    }
    Catch
    {
        $RestError = $_
    }
    if ($RestError) 
    {
        $RestError | ConvertFrom-JSON
        Return
    }
    else
    {
        $sargcmdlist = $reportlistout.result.ReportName
    }    
    
	# get the list of sarg commands and set an item for each
	foreach ($cmd in $sargcmdlist) 
	{
		set-item -path function:global:$cmd -value { get-sargreport $cmd $args}.getNewClosure(); 
    }
    # handle reportlist since it wont report itself
    set-item -path function:global:reportlist -value { get-sargreport reportlist -p}.getNewClosure();
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


use udsinfo -h to get the list of possible subcommands.

udsinfo SUBCOMMAND -h will provide help on that specific topic.

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
# this function will imitate udsinfo so that users don't need to remember each individual cmdlet
# handle request for udsinfo command
Function udsinfo([string]$subcommand, [string]$argument, [string]$filtervalue, [switch][alias("h")]$help)
{
	# if no subcommand is provided, display the list of subcommands and exit
	if ( $subcommand -eq "" )
	{
        Try
        {
        $Url = "https://$vdpip/actifio/api/info/help" + "?sessionid=$vdpsessionid"
        $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
        }
        Catch
        {
            $RestError = $_
        }
        if ($RestError) 
        {
            $RestError | ConvertFrom-JSON
            Return
        }
        else
        {
            $resp.result
            Return
        }
    }
    
   if ( $help )
	{
		# if there's no subcommand, then get help for udsinfo -h. If not, udsinfo subcommand -h
		if ( $subcommand -ne "")
		{
            Try
            {
			    $Url = "https://$vdpip/actifio/api/info/help/$subcommand" + "?sessionid=$vdpsessionid"
                $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            }
            Catch
            {
                $RestError = $_
            }
            if ($RestError) 
            {
                $RestError | ConvertFrom-JSON
                Return
            }
            else
            {
                $resp.result | more
                Return
            }
		} else 
		{
            Try
            {
			    $Url = "https://$vdpip/actifio/api/info/help" + "?sessionid=$vdpsessionid"
                $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            }
            Catch
            {
                $RestError = $_
            }
            if ($RestError) 
            {
                $RestError | ConvertFrom-JSON
                Return
            }
            else
            {
                $resp.result | more
                Return
            }
        }		
    } 
  
    # we didn't get asked for help so lets grab the output
    # we start at apistart of 0.  For nearly all searches this will be fine
    $apistart = 0 
    # we will keep looping up till done = 1
    $done = 0
    Do
    {
        if ($argument -and $filtervalue)
        {
            $Encodedfilter = [System.Web.HttpUtility]::UrlEncode($filtervalue)
            $Url = "https://$vdpip/actifio/api/info/$subcommand" + "?sessionid=$vdpsessionid" + "&filtervalue=" + "$Encodedfilter" + "&argument=" + "$argument" + "&apistart=$apistart" 
            Try
            {
                $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            }
            Catch
            {
                $RestError = $_
            }
            if ($RestError) 
            {
                $RestError | ConvertFrom-JSON
                Return
            }
            else
            {
                $output = $resp.result
            }
        }
        elseif ($argument)
        {
            $Url = "https://$vdpip/actifio/api/info/$subcommand" + "?sessionid=$vdpsessionid" + "&argument=" + "$argument" + "&apistart=$apistart" 
            Try    
            {
                $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            }
            Catch
            {
                $RestError = $_
            }
            if ($RestError) 
            {
                $RestError | ConvertFrom-JSON
                Return
            }
            else
            {
                $output = $resp.result
            }
        }
        elseif ($filtervalue)
        {
            $Encodedfilter = [System.Web.HttpUtility]::UrlEncode($filtervalue)
            $Url = "https://$vdpip/actifio/api/info/$subcommand" + "?sessionid=$vdpsessionid" + "&filtervalue=" + "$Encodedfilter" + "&apistart=$apistart" 
            Try    
            {
                $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            }
                Catch
            {
                $RestError = $_
            }
            if ($RestError) 
            {
                $RestError | ConvertFrom-JSON
                Return
            }
            else
            {
                $output = $resp.result
            }
        }
        else
        {
            $Url = "https://$vdpip/actifio/api/info/$subcommand" + "?sessionid=$vdpsessionid"  + "&apistart=$apistart" 
            Try    
            {
                $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url 
            }
            Catch
            {
                $RestError = $_
            }
            if ($RestError) 
            {
                $RestError | ConvertFrom-JSON
                Return
            }
            else
            {
                $output = $resp.result
            }
        }
        # count the results and add 4096 to apistart.  If we got less than 4096 we are done and can finish by settting done to 1
        $objcount = $output.count
        $output
        if ( $objcount -lt 4096)
        {
            $done = 1
        }
        else
        {
        $apistart = $apistart + 4096
        }
    } while ($done -eq 0)

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

	# if no subcommand is provided, get the list of udstask commands and exit.
	if ( $subcommand -eq "" )
	{
        $Url = "https://$vdpip/actifio/api/task/help" + "?&sessionid=$vdpsessionid"
        Try
        {
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
        }
        Catch
        {
            $RestError = $_
        }
        if ($RestError) 
        {
            $RestError | ConvertFrom-JSON
        }
        else
        {
            $resp.result 
        }
		return;
	}

	if ($help) 
	{
		# if there's no subcommand, then get help for udsinfo -h. If not, udsinfo subcommand -h
		if ( $subcommand -ne "")
		{
            $Url = "https://$vdpip/actifio/api/task/help/$subcommand" + "?&sessionid=$vdpsessionid"
            Try
            {
                $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            }
            Catch
            {
                $RestError = $_
            }
            if ($RestError) 
            {
                $RestError | ConvertFrom-JSON
            }
            else
            {
                $resp.result | more
            }
		} else 
		{
            $Url = "https://$vdpip/actifio/api/task/help" + "?&sessionid=$vdpsessionid"
            Try
            {
                $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            }
            Catch
            {
                $RestError = $_
            }
            if ($RestError) 
            {
                $RestError | ConvertFrom-JSON
            }
            else
            {
                $resp.result | more
            }
		}
		return;
    }
    # if we got to here we are going to try a udstask command
    if ($args) 
    {
        # we are going to send all the UDS command opts in REST format as udsopts
        $udsopts = $null
        $argprint = $args | Out-String
        $parmcount = $argprint | measure-object -word
        # if we got a single item this is the object.  Sometimes this works
        if ( $parmcount.words -eq 1)
        {
            $udsopts = "&argument=" + $argprint
            $udsopts
            $Url = "https://$vdpip/actifio/api/task/$subcommand" + "?sessionid=$vdpsessionid" + "$udsopts"
            Try
            {
                $resp = Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri $Url
            }
            Catch
            {
                $RestError = $_
            }
            if ($RestError) 
            {
                $RestError | ConvertFrom-JSON
            }
            else
            {
                $resp.result
            }
        }
        else
        #  we got more than one word
        # we will split on dashes.   This means if there are dashes in a search object, this will break the process.  
        {
            $dashsep = $argprint.Split("-") -notmatch '^\s*$'
            foreach ($arg in $dashsep) 
            {
                # remove any whitespace at the end
                $trimm = $arg.TrimEnd()
                # is there on word here or two?  If one word we have a single word parameter
                $parmcount = $trimm | measure-object -word
                if ( $parmcount.words -eq 1)
                {
                    $udsopts =  $udsopts + "&" + "$trimm" + "=" + "true" 
                }
                else
                {   
                    write-host "we got $"
                    $firstword = $trimm.Split([Environment]::NewLine) | Select -First 1
                    $secondword = $trimm.Split([Environment]::NewLine) | Select -First 2 | Select -last 1
                    $thirdword = $trimm.Split([Environment]::NewLine) | Select -First 3 | Select -last 1
                    write-host "we got first $firstword"
                    write-host "we got second $secondword"
                    write-host "we got third $thirdword"
                    # we are going to encode secondword 
                    $Encodedsecondword = [System.Web.HttpUtility]::UrlEncode($secondword)
                    if ($thirdword)
                    {
                        $udsopts =  $udsopts + "&" + "$firstword" + "=" + '"' + "$Encodedsecondword" + '"' + "&argument=" + "$thirdword" 
                    }
                    else
                    {
                        $udsopts =  $udsopts + "&" + "$firstword" + "=" + "$Encodedsecondword" 
                    }
                }
            }
            write-host "we got opts:  $udsopts"
            $Url = "https://$vdpip/actifio/api/task/$subcommand" + "?sessionid=$vdpsessionid" + "$udsopts"
            $url
            Try
            {
                $resp = Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri $Url
            }
            Catch
            {
                $RestError = $_
            }
            if ($RestError) 
            {
                $RestError | ConvertFrom-JSON
            }
            else
            {
                $resp.result
            }
        }
    }
    else
    # a udstask command with args is going to fail, but we will let the appliance generate the error and print it nicely
    {
        $Url = "https://$vdpip/actifio/api/task/$subcommand" + "?sessionid=$vdpsessionid"
        Try
        {
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri $Url
        }
        Catch
        {
            $RestError = $_
        }
        if ($RestError) 
        {
            $RestError | ConvertFrom-JSON
        }
        else
        {
            $resp.result
        }
    }   
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
example: C:\Users\admin\actpass

#>
# this function will save a VDP password so that ActPowerCLI can be used in scripts.
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


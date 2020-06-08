<#
.SYNOPSIS
Login to a VDP appliance.

.EXAMPLE
connect-act -acthost 10.65.5.35 -actuser admin -passwordfile pass.key
Using a password file to login. Path to password file can be absolute or relative path.

.EXAMPLE
connect-act -acthost 10.65.5.35 -actuser admin -password Password123
Example using the password on the command line itself to login.

.EXAMPLE
connect-act 10.65.5.35 admin -ignorecerts
Example where certificate checking is disabled.


.DESCRIPTION
Connect to VDP Appliance using a username and password or by specifying -passwordfile
which will use stored credentials.

If no password is provided and no passwordfile flag is set, then the cmdlet will
 prompt for a password

Using -quiet suppresses all successful messages

SSL Certificate checking is performed during Connect-Act
To always accept and skip the check use -ignorecerts


.PARAMETER acthost
Required. Hostname or IP to connect to.ACTPRIVILEGES

.PARAMETER actuser
Required. Username to connect to VDP as. Same username that is used in the 
Actifio Desktop login screen.

.PARAMETER password
Optional. If not provided, a prompt will be presented. If provided, it can be provided
as clear text.

example: connect-act -acthost 10.65.5.35 -actuser admin -password Password123

.PARAMETER passwordfile
Optional. This is a string that instructs Connect-Act to use stored credentials as 
opposed to interactive login. In order to use -passwordfile, you must use 
save-actpassword first to save the password.

example: connect-act -acthost 10.65.5.35 -actuser admin -passwordfile pass.key
example: connect-act 10.65.5.35 admin -passwordfile .\pass.key
example: connect-act 10.65.5.35 admin -passwordfile pass.key


The password file can be a relative path or a fully qualified path to the file

.PARAMETER quiet
Optional. Suppresses all success messages. Use this in scripting when you
don't want to see a successful login message. To validate the connection, check
for variable $ACTSESSIONID


#>
function  Connect-Act([string]$acthost, [string]$actuser, [string]$password, [string]$passwordfile, [switch][alias("q")]$quiet, [switch][alias("p")]$printsession,[switch]$ignorecerts,[int]$actmaxapilimit) 
{
    # max objects returned will be limited to 12288, 3 x 4096 objects.  We do this by setting a limit which is 3 x 4096 +1.   Otherwise user can supply a limit
    if ($actmaxapilimit -eq "")
    {
        $actmaxapilimit = 12288
    }
    $global:actmaxapilimit = $actmaxapilimit

    if ( $acthost -eq $null -or $acthost -eq "" )
    {
    $acthost = Read-Host "IP or Name of VDP"
    }
    else
    {
        $acthost = $acthost
    }
    
    # test  for valid cert unless user said not to
    if ( -not $ignorecerts ) 
    {
        Try 
        {
            $resp = Invoke-RestMethod -Uri https://$acthost/actifio/api/version -TimeoutSec 15
        } 
        Catch 
        { 
            $RestError = $_
        }
        if ($RestError -like "The operation was canceled.")
        {
            Write-Host "No response was received from $acthost after 15 seconds"
            return;
        }
        elseif ($RestError -like "Connection refused")
        {
            Write-Host "Connection refused received from $acthost"
            return;
        }
        elseif ($RestError) 
        {
            Write-Host -ForeGroundColor Yellow "The SSL certificate from https://$acthost is not trusted. Please choose one of the following options";
            Write-Host -ForeGroundColor Yellow "(I)gnore & continue";
            Write-Host -ForeGroundColor Yellow "(C)ancel";
            $validresp = ("i", "I", "c", "C");
            $certaction = $null
        
            # prompt until we get a proper response.	
            while ( $validresp.Contains($certaction) -eq $false )
            {
                $certaction = Read-Host "Please select an option";
            }
            # based on the action, do the right thing.
            if ( $certaction -eq "i" -or $certaction -eq "I" )
            {
                # set IGNOREACTCERTS so that we ignore self-signed certs
                $env:IGNOREACTCERTS = $acthost;
            }
            elseif ( $certaction -eq "c" -or $certaction -eq "C" ) 
            {
                # just exit
                return;
            }
        }
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
    # build a vendorkey
    $moduledetails = Get-Module ActPowerCLI
    $vendorkey = "ActPowerCLI-" + $moduledetails.version.ToString()

    # password needs to be sent as base64 per API Guide
    $UnsecurePassword = ConvertFrom-SecureString -SecureString $passwordenc -AsPlainText
    $Header = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($vdpuser+":"+$UnsecurePassword))}
    $Url = "https://$acthost/actifio/api/login?name=$vdpuser&password=$UnsecurePassword&vendorkey=$vendorkey"
    $RestError = $null
    Try
    {
        $resp = Invoke-RestMethod -SkipCertificateCheck -Method POST -Uri $Url -Headers $Header -ContentType $Type -TimeoutSec 15
    }
    Catch
    {
        $RestError = $_
    }
    if ($RestError -like "The operation was canceled.")
    {
        Write-Host "No response was received from $acthost after 15 seconds"
        return;
    }
    elseif ($RestError -like "Connection refused")
    {
        Write-Host "Connection refused received from $acthost"
        return;
    }
    elseif ($RestError) 
    {
        $RestError | ConvertFrom-JSON
    }
    else
    {
        $global:ACTSESSIONID = $resp.sessionid
        $global:acthost = $acthost
        if ($quiet)
        { 
            return 
        } 
        elseif ($printsession)
        {
            Write-Host "$ACTSESSIONID" 
        }
        else
        { 
            Write-Host "Login Successful!"
        }
        Make-SARGCmdlets
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
    # make sure we have something to disconnect from
    Test-ActConnection
    # disconnect
    $Url = "https://$acthost/actifio/api/logout" + "?&sessionid=$ACTSESSIONID"
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
            $global:ACTSESSIONID = ""
        }
    }
}

<#
.SYNOPSIS
Executes SARG commands via a rest API hosted on a VDP Appliance.

.EXAMPLE
Get-SARGReport reportlist
List out the possible reports available.

.EXAMPLE
Get-SARGReport reportimages -a 123456
Runs reportimages report for the appid 123456

.DESCRIPTION
The majority of report commands that are available in a VDP Appliance are available via ActPowerCLI module.

#>
# Get-SARGReport function
function Get-SARGReport([string]$reportname,[String]$sargparms)
{
    # make sure we have something to connect to
    Test-ActConnection

    if ($sargparms) 
	{
        # we are going to send all the SARG command opts in REST format as sargopts
        $sargopts = $null
        # we will split on dashes.   This means if there are dashes in a search object, this will break the process.  We dump blank lines
        $sargparms = " " + $sargparms 
        $dashsep = $sargparms.Split(" -") -notmatch '^\s*$'
        foreach ($line in $dashsep) 
            {
                # remove any whitespace at the end
                $trimm = $line.TrimEnd()
                # do we have a single letter.  If so this is out parm.   If the user didn't use a dash this will also work,  so -i and i both work
                $length = $trimm.length
                if ( $length -eq 1 )
                {
                        $sargopts = $sargopts + "&" + "$trimm" + "=true" 
                }
                # if length is greater than one then we either have a parm with search  like -a 1232  or we have grouped parms like -ty
                if ( $length -gt 1 )
                {
                    $parmcount = $trimm | measure-object -word
                    # if we find only one word then all the parms are together like -ty so we process them one at a time
                    if ( $parmcount.words -eq 1 )
                    { 
                        $splitblob = $trimm.tochararray()
                        foreach ($blob in $splitblob) 
                        {
                            $sargopts =  $sargopts + "&" + "$blob" + "=true"
                        }
                    }
                    # if we have more then one word then we have a search like  -a 1234
                    if ( $parmcount.words -gt 1 )
                    { 
                        # the first word will be the parm   If the first word is more than one character long then there is an issue and we ignore it
                        $firstword = $trimm.Split([Environment]::Space) | Select -First 1
                        $length = $firstword.length
                        if ( $length -eq 1 )
                        {
                            # the second word should be the search term   Spaces are not an issue
                            $secondword = $trimm.substring(2)
                            $sargopts =  $sargopts + "&" + "$firstword" + "=" + "$secondword" 
                        }
                    }
                }
            }
        $Url = "https://$acthost/actifio/api/report/$reportname" + "?" + "sessionid=$ACTSESSIONID"  + "$sargopts"
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
        $Url = "https://$acthost/actifio/api/report/$reportname" + "?sessionid=$ACTSESSIONID" 
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
function Make-SARGCmdlets()
{
    # make sure we have something to connect to
    Test-ActConnection
    $Url = "https://$acthost/actifio/api/report/reportlist?p=true&sessionid=$ACTSESSIONID"
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
		set-item -path function:global:$cmd -value { Get-SARGReport $cmd $args}.getNewClosure(); 
    }
    # handle reportlist since it wont report itself
    set-item -path function:global:reportlist -value { Get-SARGReport reportlist -p}.getNewClosure();
}

# offer a way to limit the maximum number of results in a single lookup
function Set-ActAPILimit([int]$userapilimit)
{
    if ( $userapilimit -eq "" )
    {
        [int]$userapilimit = Read-Host "Number of objects to return in one command (must be a number, use 0 to reset to default of 12288)"
    }
    if ( $userapilimit -eq 0 )
    {
        $userapilimit = 12288
    }
    $global:actmaxapilimit = $userapilimit
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
    # make sure we have something to connect to
    Test-ActConnection
	# if no subcommand is provided, display the list of subcommands and exit
	if ( $subcommand -eq "" )
	{
        Try
        {
        $Url = "https://$acthost/actifio/api/info/help" + "?sessionid=$ACTSESSIONID"
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
			    $Url = "https://$acthost/actifio/api/info/help/$subcommand" + "?sessionid=$ACTSESSIONID"
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
			    $Url = "https://$acthost/actifio/api/info/help" + "?sessionid=$ACTSESSIONID"
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
    # we always start at apistart of 0 which is the first result
    $apistart = 0 
    # if somehow the default actmaxapilimit set at connect-act is gone, we set it again
    if ( $actmaxapilimit -eq "" )
    {
        $actmaxapilimit = 12288
    }
    if ( $actmaxapilimit  -gt 4096 )
    { 
        $maxlimitpercommand = 4096
    }
    else
    {
        $maxlimitpercommand = $actmaxapilimit
    }

    # we will keep looping grabbing 4096 objects per loop up till done = 1
    $done = 0
    $nextlimit=0
    Do
    {
        if ($argument -and $filtervalue)
        {
            $Encodedfilter = [System.Web.HttpUtility]::UrlEncode($filtervalue)
            $Url = "https://$acthost/actifio/api/info/$subcommand" + "?sessionid=$ACTSESSIONID" + "&filtervalue=" + "$Encodedfilter" + "&argument=" + "$argument" + "&apistart=$apistart" + "&apilimit=$maxlimitpercommand"
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
            $Url = "https://$acthost/actifio/api/info/$subcommand" + "?sessionid=$ACTSESSIONID" + "&argument=" + "$argument" + "&apistart=$apistart" + "&apilimit=$maxlimitpercommand"
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
            $Url = "https://$acthost/actifio/api/info/$subcommand" + "?sessionid=$ACTSESSIONID" + "&filtervalue=" + "$Encodedfilter" + "&apistart=$apistart" + "&apilimit=$maxlimitpercommand"
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
            $Url = "https://$acthost/actifio/api/info/$subcommand" + "?sessionid=$ACTSESSIONID"  + "&apistart=$apistart" + "&apilimit=$maxlimitpercommand"
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
        # if less than 4096 we are either finished or hit the max and we can drop out
        if ( $objcount -lt 4096)
        {
            $done = 1
        }
        # we add 4096 by default for the next grab of data
        else
        {
        $apistart = $apistart + 4096
        }
        # if the API start is exactly the limit we can stop
        if ( $apistart -eq $actmaxapilimit)
        {
            $done = 1
        }
        # but if the new apistart will push us past max results we set an apilimit to truncate the last grab
        $nextlimit = $apistart + 4096
        if ( $nextlimit -gt $actmaxapilimit )
        {
            $maxlimitpercommand = $actmaxapilimit - $apistart
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
    # make sure we have something to connect to
    Test-ActConnection
    # if no subcommand is provided, get the list of udstask commands and exit.
	if ( $subcommand -eq "" )
	{
        $Url = "https://$acthost/actifio/api/task/help" + "?&sessionid=$ACTSESSIONID"
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
            $Url = "https://$acthost/actifio/api/task/help/$subcommand" + "?&sessionid=$ACTSESSIONID"
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
            $Url = "https://$acthost/actifio/api/task/help" + "?&sessionid=$ACTSESSIONID"
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
        $taskparms = "$args"
        $parmcount = $taskparms | measure-object -word
        # if we got a single item this is the object.  Sometimes this works
        if ( $parmcount.words -eq 1)
        {
            $udsopts = "&argument=" + $taskparms
            $Url = "https://$acthost/actifio/api/task/$subcommand" + "?sessionid=$ACTSESSIONID" + "$udsopts"
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
        # we will split on dashes.   We pop a space in first of the first parm so we split on " -"  This should handle dashes in variables
        # ch commands have a value at the very end that is the ID we are working on,  all other commands dont have this quirk
        {
            if ( $subcommand.Substring(0, 2) -eq "ch" )
            { 
                $chobject = $taskparms.Split([Environment]::Space) | Select -Last 1
                $chparmcount = $taskparms | measure-object -word
                $parmcountwewant = $chparmcount.words -1
                $taskparms = $taskparms.Split([Environment]::Space) | Select -first $parmcountwewant
            }
            $taskparms = " " + $taskparms
            $dashsep = $taskparms.Split(" -") -notmatch '^\s*$'
            foreach ($line in $dashsep) 
            {
                # remove any whitespace at the end
                $trimm = $line.TrimEnd()
                # is there on word here or two?  If one word we have a single word parameter
                $innerparmcount = $trimm | measure-object -word
                if ( $innerparmcount.words -eq 1)
                {
                    $udsopts =  $udsopts + "&" + "$trimm" + "=" + "true" 
                }
                else
                {
                    $firstword = $trimm.Split([Environment]::Space) | Select -First 1
                    $secondword = $trimm.Split([Environment]::Space) | Select -skip 1
                    $Encodedsecondword = [System.Web.HttpUtility]::UrlEncode($secondword)
                    $udsopts =  $udsopts + "&" + "$firstword" + "="  + "$Encodedsecondword"
                }
            }
            if ( $subcommand.Substring(0, 2) -eq "ch" )
            {
                $udsopts = $udsopts + "&argument=" + "$chobject"
            }
            $Url = "https://$acthost/actifio/api/task/$subcommand" + "?sessionid=$ACTSESSIONID" + "$udsopts"
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
        $Url = "https://$acthost/actifio/api/task/$subcommand" + "?sessionid=$ACTSESSIONID"
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

# this function prevents errors trying to  run commands without these variables set.
Function Test-ActConnection
{
    if ( (!($ACTSESSIONID)) -or (!($acthost)) )
    {
        Write-host ""
        Write-Host "Error"
        Write-Host "-----"
        Write-Host "Not logged in or session expired. Please login using Connect-Act"
        Write-Host ""
        break;
    }
}
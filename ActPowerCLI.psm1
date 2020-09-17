# # Version number of this module.
# ModuleVersion = '10.0.1.26'
function psfivecerthandler
{
    if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
    {
    $certCallback = @"  
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
    }
    [ServerCertificateValidationCallback]::Ignore()
    
    # ensure TLS12 is in use.  We set it back when disconnect-act is run
    $env:CUR_PROTS = [System.Net.ServicePointManager]::SecurityProtocol
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
}

function  Connect-Act([string]$acthost, [string]$actuser, [string]$password, [string]$passwordfile, [switch][alias("q")]$quiet,[switch][alias("p")]$printsession,[switch][alias("i")]$ignorecerts,[switch][alias("s")]$sortoverride,[switch][alias("f")]$sortoverfile,[int]$actmaxapilimit) 
{
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

    If no password is provided and no passwordfile flag is set, then the function will
    prompt for a password

    Using -quiet suppresses all successful messages

    SSL Certificate checking is performed during Connect-Act
    To always accept and skip the check use -ignorecerts


    .PARAMETER acthost
    Required. Hostname or IP to connect to.

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
    for variable $env:ACTSESSIONID
    #>
  
    

    # max objects returned will be unlimited.   Otherwise user can supply a limit
    if (!($actmaxapilimit))
    {
        $env:actmaxapilimit = 0
    }

    if (!($acthost))
    {
    $acthost = Read-Host "IP or Name of VDP"
    }
    
    # if user didnt tell us at start to ignore cert, we need to test it
    if (!($ignorecerts))
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
            Get-ActErrorMessage -messagetoprint  "No response was received from $acthost after 15 seconds"
            return;
        }
        elseif ($RestError -like "Connection refused")
        {
            Get-ActErrorMessage -messagetoprint  "Connection refused received from $acthost"
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
                $hostVersionInfo = (get-host).Version.Major
                if ( $hostVersionInfo -lt "6" )
                {
                    psfivecerthandler
                }
                else 
                {
                    # set IGNOREACTCERTS so that we ignore self-signed certs
                    $env:IGNOREACTCERTS = "y"
                }
            }
            elseif ( $certaction -eq "c" -or $certaction -eq "C" ) 
            {
                # just exit
                break;
            }
        }
    }
    else
    {
        $hostVersionInfo = (get-host).Version.Major
        if ( $hostVersionInfo -lt "6" )
        {
            psfivecerthandler
        }
        else 
        {
            $env:IGNOREACTCERTS = "y"
        }
    }

    # we need a user name
    if (!($actuser))
    {
    $vdpuser = Read-Host "VDP user"
    }
    else
    {
        $vdpuser = $actuser
    }

    if (!($passwordfile)) 
	{
		if (!($password))
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
			Get-ActErrorMessage -messagetoprint "Password file: $passwordfile could not be opened."
			return;
		}
    }
    # build a vendorkey
    $moduledetails = Get-Module ActPowerCLI
    $vendorkey = "ActPowerCLI-" + $moduledetails.version.ToString()

    # password needs to be sent as base64 per API Guide
    $UnsecurePassword = [System.Net.NetworkCredential]::new("", $passwordenc).Password
    # $UnsecurePassword = ConvertFrom-SecureString -SecureString $passwordenc -AsPlainText
    $Header = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($vdpuser+":"+$UnsecurePassword))}
    $Url = "https://$acthost/actifio/api/login?name=$vdpuser&password=$UnsecurePassword&vendorkey=$vendorkey"
    $RestError = $null
    Try
    {
        if ( ($env:IGNOREACTCERTS -eq "y") -and ($((get-host).Version.Major) -gt 5) )
        {
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method POST -Uri $Url -Headers $Header -ContentType $Type -TimeoutSec 15
        }
        else 
        {
            $resp = Invoke-RestMethod -Method POST -Uri $Url -Headers $Header -ContentType $Type -TimeoutSec 15
        }
    }
    Catch
    {
        $RestError = $_
    }
    if ($RestError -like "The operation was canceled.")
    {
        Get-ActErrorMessage -messagetoprint "No response was received from $acthost after 15 seconds"
        return;
    }
    elseif ($RestError -like "Connection refused")
    {
        Get-ActErrorMessage -messagetoprint "Connection refused received from $acthost"
        return;
    }
    elseif ($RestError) 
    {
        $loginfailure = Test-ActJSON $RestError
        if ( ($loginfailure.err_code) -and (!($loginfailure.errormessage)) )
        {
            Get-ActErrorMessage -messagetoprint "Login failed.  You may be trying to login to an AGM"
        }
        else
        {
            $loginfailure
        }
    }
    else
    {
        $env:ACTPRIVILEGES = $resp.rights
        $env:ACTSESSIONID = $resp.sessionid
        $env:acthost = $acthost
        if ($printsession)
        {
            Write-Host "$env:ACTSESSIONID" 
        }
        elseif (!($quiet))
        { 
            Write-Host "Login Successful!"
        }
        # since login was successful, lets create some environment variables about the Appliance we connected to
        Try 
        {
            if ( ($env:IGNOREACTCERTS -eq "y") -and ($((get-host).Version.Major) -gt 5) )
            {
                $resp = Invoke-RestMethod -SkipCertificateCheck -Uri https://$acthost/actifio/api/fullversion
            }
            else 
            {
                $resp = Invoke-RestMethod -Uri https://$acthost/actifio/api/fullversion
            }
        } 
        Catch 
        { 
            $RestError = $_
        }
        if ($RestError) 
        {
            Test-ActJSON $RestError
        }
        else 
        {
            if ($resp.result)
            {
                $env:ACTPLATFORM = $resp.result.platform.SubString(0,3)
            }
            else 
            {
                $env:ACTPLATFORM = "UNKNOWN"
            }
            if ($resp.result.version)
            {
                $env:ACTVERSION = $resp.result.version
            }
            else 
            {
                $env:ACTVERSION = "0.0.0.0"
            }
        }
        #  if user issued -s they can override sort fetching
        if ($sortoverride)
        {
            $env:ACTSORTOVERRIDE = "y"   
            $global:ACTSORTORDER = ""      
        }
        elseif ($sortoverfile)
        {
            $env:ACTSORTOVERRIDE = "f"  
        }
        else
        {
            $env:ACTSORTOVERRIDE = "n"   
        }
        
        # now we create functions for SARG
        New-SARGFuncs
    }
} 


# this function disconnects from the VDP Appliance
function Disconnect-Act([switch][alias("q")]$quiet)
{   
    <#
    .SYNOPSIS
    Disconnect and end the session with the VDP Appliance.

    .EXAMPLE
    Disconnect-Act

    .DESCRIPTION
    Disconnect from the VDP appliance and end the session nicely.

    #>
 

    if ( (!($env:ACTSESSIONID)) -or (!($env:acthost)) ) 
    { 
        Get-ActErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-Act"  
        return;
    }
    # disconnect
    $Url = "https://$env:acthost/actifio/api/logout" + "?&sessionid=$env:ACTSESSIONID"
    $RestError = $null
    Try
    {
        if ( ($env:IGNOREACTCERTS -eq "y") -and ($((get-host).Version.Major) -gt 5) )
        {
            $null = Invoke-RestMethod -SkipCertificateCheck -Method POST -Uri $Url  -TimeoutSec 15
        }
        else 
        {
            $null = Invoke-RestMethod -Method POST -Uri $Url  -TimeoutSec 15
        }
    }
    Catch
    {
        $RestError = $_
    }
    if ($RestError) 
    {
        Test-ActJSON $RestError
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
    $env:acthost = $null
    $env:ACTVERSION = $null
    $env:ACTPLATFORM = $null
    $env:ACTSESSIONID = $null
    $env:ACTPRIVILEGES = $null
    $env:ACTSORTOVERRIDE = $null
    $env:actmaxapilimit = $null
    $env:IGNOREACTCERTS = $null
    $global:ACTSORTORDER = $null
    # Set the security protocol back to the old defaults
    if ($env:CUR_PROTS) 
    {
        [Net.ServicePointManager]::SecurityProtocol = $env:CUR_PROTS
        $env:CUR_PROTS = $null
    }
}


# internal function to pull SARG sort order
function Get-SARGSortOrder([string]$parmletter,[string]$reportname)
{
    if ($env:ACTPLATFORM -eq "CDS")
    {
        $ACTSORTORDER | where-object {$_.option -eq $parmletter -and $_.reportname -eq $reportname -and $_.CDS -eq "Y"} | select-object SortOrder
    }
    elseif ($env:ACTPLATFORM -eq "Sky")  
    {
        $ACTSORTORDER | where-object {$_.option -eq $parmletter -and $_.reportname -eq $reportname -and $_.VDP -eq "Y"} | select-object SortOrder
    }
    elseif ($env:ACTPLATFORM -eq "CDX")  
    {
        $ACTSORTORDER | where-object {$_.option -eq $parmletter -and $_.reportname -eq $reportname -and $_.CDX -eq "Y"} | select-object SortOrder
    }
    else 
    {
        $ACTSORTORDER | where-object {$_.option -eq $parmletter -and $_.reportname -eq $reportname -and $_.VDP -eq "Y"} | select-object SortOrder
    }
}

# Get-SARGReport function
function Get-SARGReport([string]$reportname,[string]$sargparms,[switch][alias("h")]$help)
{
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


    # make sure we have something to connect to
    if ( (!($env:ACTSESSIONID)) -or (!($env:ACTSESSIONID)) ) 
    { 
        Get-ActErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-Act"  
        return;
    }

    if ( (!($reportname)) -and ($help))
    {
        $reportname = "reportlist"
    }

    if (!($reportname))
    {
        Get-ActErrorMessage -messagetoprint "No reportname was provided. Please provide a reportname."
        return;
    }
    if ($sargparms) 
	{
        # we are going to send all the SARG command opts in REST format as sargopts
        $sargopts = $null
        $sargreportsortorder = $null
        $sargsortordertest =  $null
        $trimm = $null
        # we will split on dashes.   This means if there are dashes in a search object, this will break the process.  We dump blank lines
        $sargparms = " " + "$sargparms"
        $dashsep = $sargparms -split " -" -notmatch '^\s*$'
        foreach ($line in $dashsep) 
        {
            # remove any whitespace at the end
            $trimm = $line.TrimEnd()
            # do we have a single letter.  If so this is our parm.   If the user didn't use a dash this will also work,  so -i and i both work
            $length = $trimm.length
            if ( $length -eq 1 )
            {
                $sargopts = $sargopts + "&" + "$trimm" + "=true" 
                if ($trimm -eq "h")
                { 
                    $helprequest = "y"
                }
                $sargsortordertest = Get-SARGSortOrder -parmletter $trimm -reportname $reportname
                if ( ($sargsortordertest -ne $null) -and ($sargsortordertest.sortorder -ne "") )
                {
                    $sargreportsortorder = $sargsortordertest
                }

            }
            # if length is greater than one then we either have a parm with search  like -a 1232  or we have grouped parms like -ty
            if ( $length -gt 1 )
            {
                $parmcount = $trimm | measure-object -word
                # if we get one word and the first letter is a or d we are are going to assume its appID or days.   
                # its better for the user to always leave a space between letter and search object, so -a 123 rather than -a123  
                if ( $parmcount.words -eq 1 )
                { 
                    if ( ($trimm[0] -eq "a") -or ($trimm[0] -eq "d") )
                    {
                        $namepayload = "'" + $trimm.substring(1) + "'"
                        $sargopts =  $sargopts + "&" + $trimm[0] + "=" + [System.Web.HttpUtility]::UrlEncode($namepayload)
                    }
                    # if we find only one word then all the parms are together like -ty so we process them one at a time
                    else
                    {
                        $splitblob = $trimm.tochararray()
                        foreach ($blob in $splitblob) 
                        {
                            $sargopts =  $sargopts + "&" + "$blob" + "=true"
                            if ($blob -eq "h")
                            { 
                                $helprequest = "y"
                            }
                            # test if we have a matching sort order parm
                            $sargsortordertest = Get-SARGSortOrder -parmletter $blob -reportname $reportname
                            if ( ($sargsortordertest -ne $null) -and ($sargsortordertest.sortorder -ne "") )
                            {
                                $sargreportsortorder = $sargsortordertest
                            }
                        }
                    }
                }
                # if we have more then one word then we have a search like  -a 1234
                if ( $parmcount.words -gt 1 )
                { 
                    # the first word will be the parm   If the first word is more than one character long then there is an issue and we ignore it
                    $firstword = $trimm.Split([Environment]::Space) | Select-Object -First 1
                    $length = $firstword.length
                    if ( $length -eq 1 )
                    {
                        # the second word should be the search term   Spaces are not an issue
                        $namepayload = "'" + $trimm.substring(2) + "'"
                        $sargopts =  $sargopts + "&" + "$firstword" + "=" + [System.Web.HttpUtility]::UrlEncode($namepayload) 
                        # test if we have a matching sort order parm
                        $sargsortordertest = Get-SARGSortOrder -parmletter $firstword -reportname $reportname
                        if ( ($sargsortordertest -ne $null) -and ($sargsortordertest.sortorder -ne "") )
                        {
                            $sargreportsortorder = $sargsortordertest
                        }
                    }
                }
            }
        }
        if ($helprequest -eq "y")
        {
            $Url = "https://$env:acthost/actifio/api/report/$reportname" + "?" + "sessionid=$env:ACTSESSIONID" + "&h=true"
            $helpgrab = Get-ActAPIData  $Url
            if (!($helpgrab.information))
            {
                $helpgrab
            }
            else
            {
                # we will remove any options that don't apply to PowerShell  -w for column width -c for CSV -l for appname length and -n for no header
                $helpgrab.information -notmatch ".column width to exactly match.|.comma separated variable.|.length of the app name.|.not print the header lines"
            }
        }
        else
        {
            $Url = "https://$env:acthost/actifio/api/report/$reportname" + "?" + "sessionid=$env:ACTSESSIONID"  + "$sargopts"
            $sargoutput = Get-ActAPIData  $Url
            if (($sargoutput).errorcode -eq $null)
            {
                # if we got here we must have output we can sort,  if we don't have a sort order yet, this is our last chance to get one
                if ($sargreportsortorder -eq $null)
                {
                    $sargreportsortorder = Get-SARGSortOrder -parmletter "-" -reportname $reportname
                }
                # if we still don't have a sort order, just give the output without it
                if (($sargreportsortorder.SortOrder -eq "") -or ($sargreportsortorder.SortOrder -eq $null) )
                {
                    $sargoutput
                }
                else 
                {
                    $sargoutput | select-object $sargreportsortorder.SortOrder.split(",")
                }
            }
            else 
            {
                $sargoutput
                return
            }
        }
    } 
    else
	{
        $Url = "https://$env:acthost/actifio/api/report/$reportname" + "?sessionid=$env:ACTSESSIONID" 
        $sargoutput = Get-ActAPIData  $Url
        if (($sargoutput).errorcode -eq $null)
        {
            $sargreportsortorder = Get-SARGSortOrder -parmletter "-" -reportname $reportname
            if (($sargreportsortorder.SortOrder -eq "") -or ($sargreportsortorder.SortOrder -eq $null) )
            {
                $sargoutput
            }
            else 
            {
                $sargoutput | select-object $sargreportsortorder.SortOrder.split(",")
            }
        }
        else
        {
            $sargoutput
        }
	}
}

# we dont want to precreate all the SARG functions, but reportlist is a good one to help the client understand if SARG commands dont work.
function reportlist ()
{
    if ( (!($env:ACTSESSIONID)) -or (!($env:ACTSESSIONID)) ) 
    { 
        Get-ActErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-Act.  Report commands are only loaded after you login to an Appliance."  
        return;
    }
    if (!($args))
    {
        Get-SARGReport reportlist "-p"
    } 
    else {
        Get-SARGReport reportlist $args
    }
}

# create the functions so that report* commands work like they do with SSH CLI
function New-SARGFuncs()
{
    <#
    .SYNOPSIS
    This is an internal function used to fetch report commands from the appliance.  You do not use this function directly
    #>


    # make sure we have something to connect to
    if ( (!($env:ACTSESSIONID)) -or (!($env:ACTSESSIONID)) ) 
    { 
        Get-ActErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-Act"  
        return;
    }
    $Url = "https://$env:acthost/actifio/api/report/reportlist?p=true&sessionid=$env:ACTSESSIONID"
    Try
    {  
        if ( ($env:IGNOREACTCERTS -eq "y") -and ($((get-host).Version.Major) -gt 5) )
        {  
            $reportlistout = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
        }
        else
        {
            $reportlistout = Invoke-RestMethod -Method Get -Uri $Url
        }
    }
    Catch
    {
        $RestError = $_
    }
    if ($RestError) 
    {
        Test-ActJSON $RestError
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

    if ($env:ACTSORTOVERRIDE -eq "n")
    {
        $sortorderfetch = reportlist -s
        if ($sortorderfetch.SortOrder -ne $null)
        {
            $global:ACTSORTORDER = $sortorderfetch
        }
        else
        {
            $mp = (Get-Module -ListAvailable ActPowerCLI).ModuleBase
            if ( Test-Path $mp\ActPowerCLI_SortOrder.csv ) 
            {
                $global:ACTSORTORDER = Import-Csv -Path $mp\ActPowerCLI_SortOrder.csv -Delimiter ","
            }
        }
    }
    if ($env:ACTSORTOVERRIDE -eq "f")
    {
        $mp = (Get-Module -ListAvailable ActPowerCLI).ModuleBase
        if ( Test-Path $mp\ActPowerCLI_SortOrder.csv ) 
        {
            $global:ACTSORTORDER = Import-Csv -Path $mp\ActPowerCLI_SortOrder.csv -Delimiter ","
        }   
    }
    if ($env:ACTSORTOVERRIDE -eq "y")
    {
        $global:ACTSORTORDER = ""
    }
}


# this function will imitate udsinfo so that users don't need to remember each individual function
# handle request for udsinfo command
Function udsinfo([string]$subcommand, [switch][alias("h")]$help)
{
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

    # make sure we have something to connect to
    if ( (!($env:ACTSESSIONID)) -or (!($env:ACTSESSIONID)) ) 
    { 
        Get-ActErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-Act"  
        return;
    }
	# if no subcommand is provided, display the list of subcommands and exit
	if ( $subcommand -eq "" )
	{
        $Url = "https://$env:acthost/actifio/api/info/help" + "?sessionid=$env:ACTSESSIONID"
        Get-ActAPIData  $Url
        return
    }
   if ( $help )
	{
		# if there's no subcommand, then get help for udsinfo -h. If not, udsinfo subcommand -h
		if ( $subcommand -ne "")
		{
            $Url = "https://$env:acthost/actifio/api/info/help/$subcommand" + "?sessionid=$env:ACTSESSIONID"
            Get-ActAPIData  $Url
		} else 
		{
            $Url = "https://$env:acthost/actifio/api/info/help" + "?sessionid=$env:ACTSESSIONID"   
            Get-ActAPIData  $Url
        }		
        return
    } 
    # we are going to send all the args that is not the argument or filtervalue in REST format as udsopts
    $udsopts = $null
    if ($args) 
    {
        $udsopts = generatepayload($args)
    }

    # we didn't get asked for help so lets grab the output
    # we always start at apistart of 0 which is the first result
    $apistart = 0 
    # if somehow the default actmaxapilimit set at connect-act is gone, we set it again
    if ( $env:actmaxapilimit -eq "" )
    {
        $env:actmaxapilimit = 0
    }
    # the api limit per command should be either 4096 or if the user set actmaxapilimit to a number 1-4095 then use that value
    if (( $env:actmaxapilimit  -gt 0 ) -and ( $env:actmaxapilimit  -le 4096 ))
    { 
        $maxlimitpercommand = $env:actmaxapilimit
    }
    else
    {
        $maxlimitpercommand = 4096
    }

    # we will keep looping grabbing 4096 objects per loop up till done = 1
    $done = 0
    Do
    {
        if ($udsopts -and $filtervalue)
        {
            $Encodedfilter = [System.Web.HttpUtility]::UrlEncode($filtervalue)
            $Url = "https://$env:acthost/actifio/api/info/$subcommand" + "?sessionid=$env:ACTSESSIONID" + "&filtervalue=" + "$Encodedfilter" + "$udsopts" + "&apistart=$apistart" + "&apilimit=$maxlimitpercommand"
            $output = Get-ActAPIData  $Url
        }
        elseif ($udsopts)
        {
            $Url = "https://$env:acthost/actifio/api/info/$subcommand" + "?sessionid=$env:ACTSESSIONID" + "$udsopts" + "&apistart=$apistart" + "&apilimit=$maxlimitpercommand"
            $output = Get-ActAPIData  $Url
        }
        elseif ($filtervalue)
        {
            $Encodedfilter = [System.Web.HttpUtility]::UrlEncode($filtervalue)
            $Url = "https://$env:acthost/actifio/api/info/$subcommand" + "?sessionid=$env:ACTSESSIONID" + "&filtervalue=" + "$Encodedfilter" + "&apistart=$apistart" + "&apilimit=$maxlimitpercommand"
            $output = Get-ActAPIData  $Url
        }
        else
        {
            $Url = "https://$env:acthost/actifio/api/info/$subcommand" + "?sessionid=$env:ACTSESSIONID"  + "&apistart=$apistart" + "&apilimit=$maxlimitpercommand"   
            $output = Get-ActAPIData  $Url
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
        $nextlimit = $apistart + 4096
        }
        if ( $apistart -eq $env:actmaxapilimit)
        {
            $done = 1
        }
        # we now need to consider if the maxlimit should be trimmed
        if (($env:actmaxapilimit -gt 4096) -and ( $nextlimit -gt $env:actmaxapilimit))
        {
            $maxlimitpercommand = $env:actmaxapilimit - $apistart
        }
    } while ($done -eq 0)
}



Function udstask ([string]$subcommand, [switch][alias("h")]$help) 
{
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
    actions on a VDP Appliance. Actions such as creation of hosts, users, running
    jobs, etc.

    Output from VDP APpliances is always presented as an object.

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
    # individual function.
    # make sure we have something to connect to
    if ( (!($env:ACTSESSIONID)) -or (!($env:ACTSESSIONID)) ) 
    { 
        Get-ActErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-Act"  
        return;
    }

    # if no subcommand is provided, get the list of udstask commands and exit.
	if ( $subcommand -eq "" )
	{
        $Url = "https://$env:acthost/actifio/api/task/help" + "?&sessionid=$env:ACTSESSIONID"
        Get-ActAPIData  $Url
		return;
	}

	if ($help) 
	{
		# if there's no subcommand, then get help for udstask -h. If not, udstask subcommand -h
		if ( $subcommand -ne "")
		{
            $Url = "https://$env:acthost/actifio/api/task/help/$subcommand" + "?&sessionid=$env:ACTSESSIONID"
            Get-ActAPIData $Url
		} else 
		{
            $Url = "https://$env:acthost/actifio/api/task/help" + "?sessionid=$env:ACTSESSIONID"
            Get-ActAPIData $Url
		}
		return;
    }

    # if we got to here we are going to try a udstask command
    $udsopts = $null
    if ($args) 
    {
        $udsopts = generatepayload($args)
    }
    if ($udsopts) 
    {
        $Url = "https://$env:acthost/actifio/api/task/$subcommand" + "?sessionid=$env:ACTSESSIONID" + "$udsopts"
        Get-ActAPIDataPost  $Url
    }
    else
    # a udstask command without argument or args is likely to fail, but let the appliance do the talking
    {
        $Url = "https://$env:acthost/actifio/api/task/$subcommand" + "?sessionid=$env:ACTSESSIONID"
        Get-ActAPIDataPost $Url
    }   
}


# this function will save a VDP password so that ActPowerCLI can be used in scripts.
Function Save-ActPassword([string]$filename)
{
    <#
    .SYNOPSIS
    Save credentials so that scripting is easy and interactive login is no longer 
    needed.

    .EXAMPLE
    Save-ActPassword -filename ./5b-admin-pass
    Save the password for use later.

    .DESCRIPTION
    Store the credentials in a file which can be used to login to VDP Appliance.

    To change the credentials, simply re-run the function.

    .PARAMETER filename
    Required. Absolute or relative location where the file should be saved. 
    example: .\actpass
    example: C:\Users\admin\actpass

    #>

	# if no file is provided, prompt for one
	if (!($filename))
	{
		$filename = Read-Host "Filename";
	}

	# if the filename already exists. don't overwrite it. error and exit.
	if ( Test-Path $filename ) 
	{
		Get-ActErrorMessage -messagetoprint "The file: $filename already exists. Please delete it first.";
		return;
	}

	# prompt for password 
	$password = Read-Host -AsSecureString "Password"

	$password | ConvertFrom-SecureString | Out-File $filename

	if ( $? )
	{
		write-host "Password saved to $filename."
		write-host "You may now use -passwordfile with Connect-Act to provide a saved password file."
	}
	else 
	{
		Get-ActErrorMessage -messagetoprint "An error occurred in saving the password";
	}
}



 # function to imitate usvcinfo so that users don't need to remember each individual function
Function usvcinfo([string]$subcommand)
{
    <#
    .SYNOPSIS
    Executes usvcinfo commands via a rest API hosted on CDS only. Usvcinfo is not supported on a Virtual Appliance.

    .EXAMPLE
    usvcinfo lsvdisk 1
    List details about vdisk id 1

    .EXAMPLE
    usvcinfo lsmdisk
    List out all the mdisks on a CDS appliance.

    .DESCRIPTION
    Usvcinfo commands are like udsinfo commands. They provide a view into settings and the current state
    of an Actifio CDS appliance. Usvcinfo commands do not change any settings or perform any actions.

    #>

   
    # no help is available for this command
    # make sure we have something to connect to
    if ( (!($env:ACTSESSIONID)) -or (!($env:ACTSESSIONID)) ) 
    { 
        Get-ActErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-Act"  
        return;
    }
    # if the platform is Virtual, then usvcinfo doesn't work. so stop right here.
    if (!($env:ACTPLATFORM))
    {
        Get-ActErrorMessage -messagetoprint "Error: usvcinfo command is only available on Actifio CDS. Current platform is Unknown"
        return
    }
	if ( $env:ACTPLATFORM.toLower() -ne "cds" ) 
	{
		Get-ActErrorMessage -messagetoprint "Error: usvcinfo command is only available on Actifio CDS. Current platform is $env:ACTPLATFORM"
		return
	}
	# if no subcommand is provided, display the list of subcommands and exit
	if ( $subcommand -eq "" )
	{
        Get-ActErrorMessage -messagetoprint "Please supply a command such as lsvdisk or lsmdisk"
        return
    }
    # if we got to here we are going to try a udsinfo command
    $udsopts = $null

    if ($args) 
    {
        $udsopts = generatepayload($args)
    }
    # we proceed to try and run the command
    if ($udsopts)
    {
        $Url = "https://$env:acthost/actifio/api/shinfo/$subcommand" + "?sessionid=$env:ACTSESSIONID" + "$udsopts" 
        Get-ActAPIData  $Url
    }
    else
    {
        $Url = "https://$env:acthost/actifio/api/shinfo/$subcommand" + "?sessionid=$env:ACTSESSIONID"  
        Get-ActAPIData  $Url
    }
}


Function usvctask([string]$subcommand)
{
    <#
    .SYNOPSIS
    Executes usvctask commands via a rest API hosted on CDS only. Usvctask is not supported on a Virtual Appliance.

    .DESCRIPTION
    Usvctask commands should only be executed by an administrator who has deep
    knowledge of the CDS platform. Usvctask commands can have undesired consequences if used incorrectly.

    Proceed with caution.

    #>


    # this command will allow users to run specific usvctask commands.
    # make sure we have something to connect to
    if ( (!($env:ACTSESSIONID)) -or (!($env:ACTSESSIONID)) ) 
    { 
        Get-ActErrorMessage -messagetoprint "Not logged in or session expired. Please login using Connect-Act"  
        return;
    }
    # if the platform is Virtual, then usvcinfo doesn't work. so stop right here.
    if (!($env:ACTPLATFORM))
    {
        Get-ActErrorMessage -messagetoprint "Error: usvctask command is only available on Actifio CDS. Current platform is Unknown"
        return
    }
	if ( $env:ACTPLATFORM.toLower() -ne "cds" ) 
	{
		Get-ActErrorMessage -messagetoprint "Error: usvctask command is only available on Actifio CDS. Current platform is $env:ACTPLATFORM"
		return
	}
	# if no subcommand is provided, display the list of subcommands and exit
	if (!($subcommand))
	{
        Get-ActErrorMessage -messagetoprint "Please supply a command such as detectmdisk"
        return
    }
     # if we got to here we are going to try a usvctask command
     $udsopts = $null
     if ($args) 
     {
         $udsopts = generatepayload($args)
     }

     if ($udsopts)
     {
        $Url = "https://$env:acthost/actifio/api/shtask/$subcommand" + "?sessionid=$env:ACTSESSIONID" + "$udsopts"
         Get-ActAPIDataPost $Url
    }
    else
    # run the command without args.  Most commands require an arg, but the appliance will let the user know
    {
        $Url = "https://$env:acthost/actifio/api/shtask/$subcommand" + "?sessionid=$env:ACTSESSIONID"
        Get-ActAPIDataPost $Url
    }   
}


    # offer a way to limit the maximum number of results in a single lookup
function Set-ActAPILimit([Parameter(Mandatory = $true)]
[ValidateRange("NonNegative")][int]$userapilimit )
{
    <#
    .SYNOPSIS
    Limits the number of objects returned by udsinfo commands.  If you set it to 1 you will only get 1 object, such as a backup or job history.

    .EXAMPLE
    Set-ActAPILimit 1
    Sets the limit to 1

    .EXAMPLE
    Set-ActAPILimit 0
    Resets the limit to unlimited

    .DESCRIPTION
    By default udsinfo commands will continue to fetch data, 4096 objects at a time until all objects are fetched.
    This could take a long time for jobhistory.   Using filters is a good choice, but if you just want example output, then you can set a limit.
    If you set it to 1 you will only get 1 object, such as a backup or job history.
    To reset to default, set the value to 0

    #>


    $env:actmaxapilimit = $userapilimit
}

# errors can either have JSON and be easy to format or can be text,  we need to sniff
Function Test-ActJSON()
{
    <#
    .SYNOPSIS
    This is an internal function used to check output to see if it is JSON.  You do not use this function directly
    #>


    if ($args) 
    {
        Try
        {
            $null = $args | Test-Json -ErrorAction Stop
            $validJson = $true
        }
        Catch
        {
            $validJson = $false
        }
        if (!$validJson) 
        {
            Write-Host "$args"
        }
        else
        {
            $args | ConvertFrom-JSON
        }
        Return
    }
}

# this function takes the generated URL and tries to pull back the API Data
Function Get-ActAPIData 
{
    <#
    .SYNOPSIS
    This is an internal function used to check fetch data from the appliance.  You do not use this function directly
    #>
    

    if ($args)
    {

        if ( $((get-host).Version.Major) -gt 5 )
        {
            Try    
            {
                if ($env:IGNOREACTCERTS -eq "y") 
                {  
                    $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri "$args" 
                }
                else 
                {
                    $resp = Invoke-RestMethod -Method Get -Uri "$args" 
                }
            }
            Catch
            {
                $RestError = $_
            }
            if ($RestError) 
            {
                Test-ActJSON $RestError
            }
            else
            {
                $resp.result
            }
        }
        else 
        {
            Try    
            {
                $resp = Invoke-RestMethod -Method Get -Uri "$args" 
            }
            Catch
            {
                $result = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($result)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();
            }
            if ($responseBody) 
            {
                $responseBody | ConvertFrom-Json
            }
            else
            {
                $resp.result
            }
        }
    }
}

# this function takes the generated URL and tries to pull back the API Data   It does Post rather than Get.  
Function Get-ActAPIDataPost
{
    <#
    .SYNOPSIS
    This is an internal function used to check fetch data from the appliance.  You do not use this function directly
    #>

    if ($args)
    {
        if ( $((get-host).Version.Major) -gt 5 )
        {
            Try    
            {
                if ($env:IGNOREACTCERTS -eq "y")  
                {
                    $resp = Invoke-RestMethod -SkipCertificateCheck -Method Post -Uri "$args" 
                }
                else 
                {
                    $resp = Invoke-RestMethod -Method Post -Uri "$args" 
                }
            }
            Catch
            {
                $RestError = $_
            }
            if ($RestError) 
            {
                Test-ActJSON $RestError
            }
            else
            {
                if ($resp.result)
                {
                    if (($resp.result).GetType().Name -eq "String")
                    {
                        $resp
                    }
                    else 
                    {
                        $resp.result
                    }
                }
                else 
                {
                    $resp    
                }
            }
        }
        else 
        {
            Try    
            {
                $resp = Invoke-RestMethod -Method Post -Uri "$args" 
            }
            Catch
            {
                $result = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($result)
                $reader.BaseStream.Position = 0
                $reader.DiscardBufferedData()
                $responseBody = $reader.ReadToEnd();
            }
            if ($responseBody) 
            {
                $responseBody | ConvertFrom-Json
            }
            else
            {
                if ($resp.result)
                {
                    if (($resp.result).GetType().Name -eq "String")
                    {
                        $resp
                    }
                    else 
                    {
                        $resp.result
                    }
                }
                else 
                {
                    $resp    
                }
            }
        }
    }
}

# generate an error message
function Get-ActErrorMessage ([string]$messagetoprint)
{

        $acterror = @()
        $acterrorcol = "" | Select-Object errormessage
        $acterrorcol.errormessage = "$messagetoprint"
        $acterror = $acterror + $acterrorcol
        $acterror
}


# offer a way to display user rights
Function Get-Privileges
{
    <#
    .SYNOPSIS
    Displays the rights that the logged in user has

    .EXAMPLE
    Get-Privileges

    .DESCRIPTION
    This command shows all the rights that are allowed to the user who is currently logged in

    #>

    if ($env:ACTPRIVILEGES)
    {
        $privs = @()
        $privcolumn = "" | Select-Object Priviledges
        foreach ($line in $ACTPRIVILEGES) {
        $privcolumn.Priviledges = "$line"
        $privs = $privs + $privcolumn
        $privcolumn = "" | Select-Object Priviledges
        }
    }
    if ($privs)
    {
        $privs
    }
}

# offer a way to get the AppID for an app
Function Get-ActAppID([string]$hostname, [string]$appname) 
{
    <#
    .SYNOPSIS
    Displays the appID for an application

    .EXAMPLE
    Get-ActAppID
    You will be prompted for hostname and appname

    .EXAMPLE
    Get-ActAppID -hostname windows -appname Windows
    If the app is found you will get the ID returned

    .DESCRIPTION
    A function to find the App ID of an app based on supplied hostname and appname
    Both fields are case sensitive and no wildcards are allowed.

    #>


    if (!($hostname))
    {
        $hostname = Read-Host "hostname"
    }
    if (!($appname))
    {
        $appname = Read-Host "appname"
    }
    if (($appname -match '\*') -or ($hostname -match '\*'))
    {
        Get-ActErrorMessage -messagetoprint "Wildcards are not allowed for this Function"
        return;
    }
    $returnedapp = udsinfo lsapplication -filtervalue "appname=$appname&hostname=$hostname"
    if ($returnedapp.id)
    {
        $returnedapp | Select-Object id
    }
    else
    {
        $returnedapp
    }
}

Function Get-LastSnap([string]$app, [string]$jobclass, [int]$backupinlast) 
{
    <#
    .SYNOPSIS
    Displays the most recent image for an app

    .EXAMPLE
    Get-LastSnap
    You will be prompted for appname

    .EXAMPLE
    Get-LastSnap -app Windows
    Get the last image created for the app named Windows

    .EXAMPLE
    Get-LastSnap -app 4771
    Get the last image created for the app with ID 4771

    .EXAMPLE
    Get-LastSnap -app Windows -jobclass snapshot
    Get the last snapshot created for the app named Windows

    .EXAMPLE
    Get-LastSnap -app Windows -jobclass snapshot -backupinlast 24
    Get the last snapshot created for the app named Windows but only if the backup date is in the last 24 hours

    .DESCRIPTION
    A function to find the last image created for an app
    Despite the function name, it will return the last image regardless of class.   If you want snapshots, use -jobclass snapshot
    App field can be a name or an ID.   Wild cards are not allowed and case is sensitive.

    #>


    if (!($app))
    {
        $app = Read-Host "app"
    }
    if (($app -match '\*') -or ($jobclass -match '\*'))
    {
        Get-ActErrorMessage -messagetoprint "Wildcards are not allowed for this Function"
        return;
    }
    if ($app -match '^[0-9]+$')
    {
        $fv = "appid=$app"
    }
    else
    {
        $fv = "appname=$app"
    }
    if ($jobclass)
    {
        $fv = $fv + "&jobclass=$jobclass"
    }
    if (($backupinlast) -and ($backupinlast -gt 0))
    {
        $fv = $fv +  "&backupdate since " + $backupinlast + " hours"
    }
    $backups = udsinfo lsbackup -filtervalue "$fv" | Select-Object -Last 1 
    if ($backups.id)
    {
        $backups | Select-Object id, appname, appid, backupname, backupdate, label, hostname, policyname, sltname, slpname, jobclass
    }
    else
    {
        $backups
    }
}

Function Get-ActifioLogs ([int]$tail)
{
    <#
    .SYNOPSIS
    Tails the Connector logs on a Windows host

    .EXAMPLE
    Get-ActifioLogs  

    .EXAMPLE
    Get-ActifioLogs -tail 100

    Shows the previous 100 lines of logs and then begins tailing

    .DESCRIPTION
    A function to tail the Connector Logs of the Actifio UDSAgent process

    #>
    
    if (!($tail))
    { 
        $tail = 10
    }


    Get-Content -Path "C:\Program Files\Actifio\log\UDSAgent.log" -Tail $tail -Wait

}

Function generatepayload($arglist) 
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
			return $udsopts = "&argument=" + $arglist[0]
		} 
		else
		{
			return $udsopts = $arglist[0] +  "=true"
		}
	} 

	foreach ($arg in $arglist) 
	{
        # we handle force separately as it wont have a value and will steal the arg if we let it
        if ($arg -eq "-force")
        {
            $currargtype = "value";
            $udsopts = $udsopts + "&force=true"
        } 
        elseif ($arg.ToString().StartsWith("-")) 
		{
			# current argument is parameter
			$currargtype = "param";

			if ( $prevargtype -eq $currargtype -and $currargtype -eq "param" ) 
			{
				$udsopts = $udsopts + "true" 
            }
			$temparg = "&" + $arg.TrimStart("-")
			$udsopts = $udsopts + $temparg + "=";
		} 
		else 
		{
			# current argument is a value
			$currargtype = "value";
			# if two values are together, then insert "argument" before the last one.
			if ( $prevargtype -eq $currargtype -and $currargtype -eq "value" )
			{
				$udsopts = $udsopts + "&argument=" 
            }
            $namepayload =  $arg
            $encodedpayload = [System.Web.HttpUtility]::UrlEncode($namepayload)
			$udsopts = $udsopts + $encodedpayload 
		}

		$prevargtype = $currargtype;
	}

	# add a true if the last argument is a parameter 
	if (( $arglist[-1].ToString().StartsWith("-") )  -and ($arg -ne "-force"))
	{
		$udsopts = $udsopts + "true" 
	}
	return $udsopts
}

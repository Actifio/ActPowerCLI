# send report command to appliance
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
        $Url = "https://$vdpip/actifio/api/report/$reportname" + "?" + "$sargopts" + "sessionid=$sessionid"
        $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
        $resp.result
	} else 
	{
        $Url = "https://$vdpip/actifio/api/report/$reportname" + "?sessionid=$sessionid" 
        $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
        $resp.result
	}
}


# create report command lets using reportlist
function makeSARGCmdlets()
{
    
    $Url = "https://$vdpip/actifio/api/report/reportlist?p=true&sessionid=$sessionid"
    
    $reportlistout = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
    $sargcmdlist = $reportlistout.result.ReportName


	# get the list of sarg commands and set an item for each
	foreach ($cmd in $sargcmdlist) 
	{
		set-item -path function:global:$cmd -value { get-sargreport $cmd $args}.getNewClosure(); 
    }
    # handle reportlist since it wont report itself
    set-item -path function:global:reportlist -value { get-sargreport reportlist -p}.getNewClosure();
}


# handle request for udsinfo command
Function udsinfo([string]$subcommand, [string]$argument, [string]$filtervalue, [switch][alias("h")]$help)
{
	# if no subcommand is provided, display the list of subcommands and exit
	if ( $subcommand -eq "" )
	{
        $Url = "https://$vdpip/actifio/api/info/help" + "?sessionid=$sessionid"
        $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
        $resp.result
		return;
	}

	if ( $help )
	{
		# if there's no subcommand, then get help for udsinfo -h. If not, udsinfo subcommand -h
		if ( $subcommand -ne "")
		{
			$Url = "https://$vdpip/actifio/api/info/help/$subcommand" + "?sessionid=$sessionid"
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            $resp.result | more
		} else 
		{
			$Url = "https://$vdpip/actifio/api/info/help" + "?sessionid=$sessionid"
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            $resp.result | more
		}		
		return;
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
            $Url = "https://$vdpip/actifio/api/info/$subcommand" + "?sessionid=$sessionid" + "&filtervalue=" + "$Encodedfilter" + "&argument=" + "$argument" + "&apistart=$apistart" 
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            $output = $resp.result
        }
        elseif ($argument)
        {
            $Url = "https://$vdpip/actifio/api/info/$subcommand" + "?sessionid=$sessionid" + "&argument=" + "$argument" + "&apistart=$apistart" 
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            $output = $resp.result
        }
        elseif ($filtervalue)
        {
            $Encodedfilter = [System.Web.HttpUtility]::UrlEncode($filtervalue)
            $Url = "https://$vdpip/actifio/api/info/$subcommand" + "?sessionid=$sessionid" + "&filtervalue=" + "$Encodedfilter" + "&apistart=$apistart" 
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            $output = $resp.result
        }
        else
        {
            $Url = "https://$vdpip/actifio/api/info/$subcommand" + "?sessionid=$sessionid"  + "&apistart=$apistart" 
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url 
            $output = $resp.result
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


Function udstask ([string]$subcommand, [switch][alias("h")]$help) 
{

	# if no subcommand is provided, get the list of udstask commands and exit.
	if ( $subcommand -eq "" )
	{
        $Url = "https://$vdpip/actifio/api/task/help" + "?&sessionid=$sessionid"
        $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
        $resp.result
		return;
	}

	# Help will always be given at Hogwarts to those who ask for it. -Dumbledore
	if ( $help )
	{
		# if there's no subcommand, then get help for udsinfo -h. If not, udsinfo subcommand -h
		if ( $subcommand -ne "")
		{
            $Url = "https://$vdpip/actifio/api/task/help/$subcommand" + "?&sessionid=$sessionid"
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            $resp.result | more
		} else 
		{
            $Url = "https://$vdpip/actifio/api/task/help" + "?&sessionid=$sessionid"
            $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
            $resp.result | more
		}

		return;
	} 

    $Url = "https://$vdpip/actifio/api/task/$subcommand" + "?sessionid=$sessionid"
    $resp = Invoke-RestMethod -SkipCertificateCheck -Method Get -Uri $Url
    $resp.result
}


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

    if ( $acthost -eq $null -or $acthost -eq "" )
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
        if ( $RestError -like '*10011*' )
        {
            Write-Host "Failed to login to $vdpip.  Check username and password"
        }
        elseif ( $RestError -like '*10017*' )
        {
            Write-Host "Failed to login to $vdpip.  Is this really an VDP?"
        }
        else 
        {
            Write-Host "Failed to login to VDP with $RestError"
        }
    }
    else
    {
        $global:sessionid = $resp.sessionid
        $global:vdpip = $vdpip
        if ($quiet)
        { 
            return 
        } 
        elseif ($printsession)
        {
            Write-Host "$sessionid" 
        }
        else
        { 
            Write-Host "Login Successful!"
        }
        makeSARGCmdlets
    }
} 


function Disconnect-Act([switch][alias("q")]$quiet)
{
    $Url = "https://$vdpip/actifio/api/logout" + "?&sessionid=$sessionid"
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
            Write-Host "Failed to logout"
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
function GetActPowerCLIInstall
{
  # Returns the known installation locations for the ActPowerCLI Module
  return Get-Module -ListAvailable -Name ActPowerCLI -ErrorAction SilentlyContinue | Select-Object -Property Name, Version, ModuleBase
}

function GetPSModulePath 
{
    # Returns all available PowerShell Module paths  
    # Windows uses semi-colons, Linux and Mac use colons, go figure.
    $platform=$PSVersionTable.platform
	if ( $platform -match "Unix" )
	{
		return $env:PSModulePath.Split(':')
    }
    else 
    {
        return $env:PSModulePath.Split(';')
    }

}

function InstallMenu 
{
  # Creates a menu of available install or upgrade locations for the module
  Param(
    [Array]$InstallPathList,
    [ValidateSet('installation','upgrade or delete')]
    [String]$InstallAction
  )
  $i = 1
  foreach ($Location in $InstallPathList)
  {
    Write-Host -Object "$i`: $Location"
    $i++
  }

  While ($true) 
  {
    [int]$LocationSelection = Read-Host -Prompt "`nPlease select an $InstallAction path"
    if ($LocationSelection -lt 1 -or $LocationSelection -gt $InstallPathList.Length)
    {
      Write-Host -Object "Invalid selection. Please enter a number in range [1-$($InstallPathList.Length)]"
    } 
    else
    {
      break
    }
  }
  
  return $InstallPathList[($LocationSelection - 1)]
}

function RemoveModuleContent 
{
  # Attempts to remove contents from an existing installation
  try 
  {
    Remove-Item -Path $InstallPath -Recurse -Force -ErrorAction Stop -Confirm:$true
  }
  catch 
  {
    throw "$($_.ErrorDetails)"
  }
}

function CreateModuleContent
{
  # Attempts to create a new folder and copy over the ActPowerCLI Module contents
  try
  {
    $null = Get-ChildItem -Path $PSScriptRoot\ActPowerCLI* -Recurse | Unblock-File
    $null = New-Item -ItemType Directory -Path $InstallPath -Force -ErrorAction Stop
    $null = Copy-Item $PSScriptRoot\ActPowerCLI* $InstallPath -Force -Recurse -ErrorAction Stop
    $null = Test-Path -Path $InstallPath -ErrorAction Stop
    
    Write-Host -Object "`nInstallation successful."
  }
  catch 
  {
    throw $_
  }
}

function ReportActPowerCLI
{
  # Removes the ActPowerCLI Module from the active session and displays a list of all current install locations
  Remove-Module -Name ActPowerCLI -ErrorAction SilentlyContinue
  GetActPowerCLIInstall
}

### Code
Clear-Host

$hostVersionInfo = (get-host).Version.Major
if ( $hostVersionInfo -lt "5" )
{
    Write-Host "This installer is for PowerShell Version 7"
    break
}

[Array]$ActInstall = GetActPowerCLIInstall
if ($ActInstall.Length -gt 0)
{
    Write-Host 'Found an existing ActPowerCLI Module installation in the following locations:' 
    ReportActPowerCLI | Format-Table
    write-host ""
    Write-host "Upgrade or uninstall menu (choose a folder to upgrade or the delete option):"
    $ActInstall += @{
        Name       = 'Delete All'
        Version    = 0.0.0.0
        ModuleBase = 'DELETE all listed installations of the ActPowerCLI Module'
        }
    $InstallPath = InstallMenu -InstallPathList $ActInstall.ModuleBase -InstallAction 'upgrade or delete'
    
    if ($InstallPath.Split(' ')[0] -eq 'DELETE')
    {
        foreach ($Location in ([Array]$ActInstall = GetActPowerCLIInstall).ModuleBase)
        {
        $InstallPath = $Location
        RemoveModuleContent      
        }
        break
    }
    else
    {
        RemoveModuleContent
        CreateModuleContent
    }
    }
    else
    {
    Write-Host "Could not find an existing ActPowerCLI Module installation."
    Write-Host "Where would you like to install it?"
    Write-Host ""
    $InstallPath = InstallMenu -InstallPathList (GetPSModulePath) -InstallAction installation
    $InstallPath = $InstallPath + '\ActPowerCLI\'
    CreateModuleContent
}

Write-Host -Object "`nActPowerCLI Module installation location(s):"
ReportActPowerCLI | Format-Table

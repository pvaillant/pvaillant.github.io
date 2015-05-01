<#
.SYNOPSIS
	Downloads and installs Lync Room System admin web interface, along with all dependencies. 
	
.PARAMETER LrsAppUser
	Name of the user who the app will run as. This user will be created if it doesn't exist.

.PARAMETER LrsAppUserOU
	Active Directory OU to create the user in. This must already exist.

.PARAMETER LrsSupportAdminGroup
	Name of the group that will get read-only support role assigned. This group will be created if it doesn't exist.

.PARAMETER LrsSupportAdminGroupOU
	Active Directory OU to create the group in. This must already exist.

.PARAMETER LrsFullAccessAdminGroup
	Name of the group that will get full admin role assigned. This group will be created if it doesn't exist.

.PARAMETER LrsFullAccessAdminGroupOU
	Active Directory OU to create the group in. This must already exist.

.PARAMETER PoolName
	Name of the Lync pool the LrsAppUser will be enabled in. This will be auto-detected if it isn't specified.

.PARAMETER SipDomain
	SIP Domain to assign to LrsAppUser when it's enabled for Lync.
	
.NOTES
	Version 1.0.0 (2015-01-05)
	Written by Paul Vaillant
	http://technet.microsoft.com/en-us/library/dn436324.aspx
	
.LINK
	http://paul.vaillant.ca/help/Install-LrsAdmin.html
#>

[CmdletBinding()]
param(
	[Parameter()][string]$LrsAppUser = "LRSApp",
	[Parameter()][string]$LrsAppUserOU = "CN=Users",
	[Parameter()][string]$LrsSupportAdminGroup = "LRSSupportAdminGroup",
	[Parameter()][string]$LrsSupportAdminGroupOU = "CN=Users",
	[Parameter()][string]$LrsFullAccessAdminGroup = "LRSFullAccessAdminGroup",
	[Parameter()][string]$LrsFullAccessAdminGroupOU = "CN=Users",
	[Parameter()][string]$PoolName,
	[Parameter()][string]$SipDomain
)

###############################################################################
## VALIDATE PRE-REQS
###############################################################################

$badBoundParam = $false
foreach($a in $pscmdlet.MyInvocation.BoundParameters.GetEnumerator()) {
	if($a.Key.StartsWith("Lrs") -and [string]::IsNullOrEmpty($a.Value)) {
		Write-Error "$($a.Key) is required"
		$badBoundParam = $true
	}
}
if($badBoundParam) {
	exit
}

$modules = Get-Module -ListAvailable -Verbose:$false
$adMod = $modules | where {$_.Name -eq 'ActiveDirectory'}
if(!$adMod) {
	Write-Error "ActiveDirectory PowerShell module is not installed on this machine"
	exit
}

Import-Module ActiveDirectory -Verbose:$false

$lyncMod = $modules | where {$_.Name -eq 'Lync'}
if(!$lyncMod) {
	Write-Error "Lync PowerShell module is not installed on this machine"
	exit
}

Import-Module Lync -Verbose:$false

$installPath = "$env:ProgramFiles\Microsoft Lync Server 2013\Web Components\Meeting Room Portal\Int\Handler\"
if(Test-Path $installPath) {
	Write-Error "LRS Admin install Path $installPath already exists"
	exit
}

if(!$PoolName) {
	Write-Verbose "Auto-detecting Lync Pool..."
	[array]$registrars = Get-CsService -Registrar -Verbose:$false
	if($registrars.count -eq 1) {
		$PoolName = $registrars[0].PoolFQDN
		Write-Verbose "    found $PoolName"
	} else {
		$pools = $($registrars | %{ $_.PoolFQDN }) -join " "
		Write-Error "Failed to auto-detect registrar pool; please specify LyncRegistrarPool and try again [$pools]"
		exit
	}
}

if(!$SipDomain) {
	Write-Verbose "Auto-detecting SIP Domain..."
	$sipDomains = Get-CsSipDomain -Verbose:$false
	if(!$sipDomains -or $sipDomains -is [array]) {
		Write-Error "Failed to auto-detect proper SIP domain"
		exit
	} else {
		$SipDomain = $sipDomains.Name
		Write-Verbose "    found $SipDomain"
	}
}

$fe = Get-WmiObject -query 'select * from win32_product' | where {$_.name -like "Microsoft Lync Server 2013, Front End Server"}
if(!$fe) {
	Write-Error "This machine is not a Lync Front End"
	exit
}
$feVer = $fe.Version
[int]$feVerBuild = $feVer -split '\.' | select -last 1
if(!$feVer.StartsWith("5.0.8308.") -or $feVerBuild -lt 557) {
	Write-Error "Lync Front End is not minimum Lync 2013 CU2 (July/2013)"
	exit
}

$tempPath = [System.IO.Path]::GetTempPath()
function DownloadAndInstall($url) {
	$file = $url -split '/' | select -last 1
	$path = [System.IO.Path]::Combine($tempPath,$file)
	Write-Verbose "Downloading $url"
	Start-BitsTransfer $url $path
	Write-Verbose "Installing $path"
	Start-Process $path "/q" -Wait
}

$dnc = $([adsi]"LDAP://RootDSE").defaultNamingContext.Value
function ToAbsoluteLdap($ou) {
	if($ou -match ',dc=') {
		$ou
	} else {
		$ou + "," + $dnc
	}
}

$dc = Get-ADDomainController | %{ $_.HostName } | random
Write-Verbose "Using AD DC $dc"

###############################################################################
## STEP 1 - create SIP enabled AD User (eg LRSApp)
###############################################################################

$appUser = Get-ADUser -filter {sAMAccountName -eq $LrsAppUser} -Verbose:$false # work around not supporting -ErrorAction SilentlyContinue
if($appUser) {
	Write-Warning "LRS App User $LrsAppUser already exists"
} else {
	$appUserOu = ToAbsoluteLdap $LrsAppUserOU
	$appUser = New-AdUser $LrsAppUser -GivenName LRS -Surname User -DisplayName $LrsAppUser -SamAccountName $LrsAppUser -Path $appUserOu -Server $dc -PassThru 
}
if(!$appUser) {
	Write-Error "Failed to create AD user $LrsAppUser"
	exit
}
$csUser = Get-CsUser $appUser.DistinguishedName -Verbose:$false -ErrorAction SilentlyContinue
if($csUser) {
	if($csUser.Enabled) {
		Write-Warning "LRS App User $LrsAppUser already enabled for Lync"
	} else {
		Write-Warning "LRS App User $LrsAppUser exists but is disabled for Lync"
	}
} else {
	$csUser = Enable-CsUser $appUser.DistinguishedName -RegistrarPool $PoolName -SipAddress "sip:$LrsAppUser@$SipDomain" -DomainController $dc -PassThru
}
if(!$csUser) {
	Write-Error "Failed to SIP enable LRS App User $LrsAppUser"
	exit
}

###############################################################################
## STEP 2 - create AD global security groups (LRSSupportAdminGroup, LRSFullAccessAdminGroup)
###############################################################################

$supportAdminsGrp = Get-ADGroup -filter {sAMAccountName -eq $LrsSupportAdminGroup} -Verbose:$false # because no -ErrorAction SilentlyContinue
if($supportAdminsGrp) {
	Write-Warning "LRS Support Admin Group $LrsSupportAdminGroup already exists"
} else {
	$supportAdminsGrpOu = ToAbsoluteLdap $LrsSupportAdminGroupOU
	$supportAdminsGrp = New-ADGroup $LrsSupportAdminGroup -GroupScope Global -GroupCategory Security -SamAccountName $LrsSupportAdminGroup -Path $supportAdminsGrpOu -Server $dc -PassThru
}
if(!$supportAdminsGrp) {
	Write-Error "Failed to create AD group $LrsSupportAdminGroup"
	exit
}

$fullAdminsGrp = Get-ADGroup -filter {sAMAccountName -eq $LrsFullAccessAdminGroup} -Verbose:$false # because no -ErrorAction SilentlyContinue
if($fullAdminsGrp) {
	Write-Warning "LRS Full Access Admin Group $LrsFullAccessAdminGroup already exists"
} else {
	$fullAdminsGrpOu = ToAbsoluteLdap $LrsFullAccessAdminGroupOU
	$fullAdminsGrp = New-ADGroup $LrsFullAccessAdminGroup -GroupScope Global -GroupCategory Security -SamAccountName $LrsFullAccessAdminGroup -Path $fullAdminsGrpOu -Server $dc -PassThru
}
if(!$fullAdminsGrp) {
	Write-Error "Failed to create AD group $LrsFullAccessAdminGroup"
	exit
}

$supportAdminsGrpMbrs = $supportAdminsGrp | Get-AdGroupMember | %{ $_.distinguishedName }
if(-not $($supportAdminsGrpMbrs -contains $fullAdminsGrp.distinguishedName)) {
	Write-Verbose "Adding LRS Full Access Admin Group as member of LRS Support Admin Group"
	Add-ADGroupMember $supportAdminsGrp.distinguishedName $fullAdminsGrp.distinguishedName -Server $dc
} else {
	Write-Warning "LRS Full Access Admin Group is already a member of LRS Support Admin Group"
}

###############################################################################
## STEP 3 - install ASP.NET MVC 4 (4.0.20710.0)
###############################################################################

$aspMvc4 = Get-WmiObject -Class Win32_Product | where {$_.Name -eq 'Microsoft ASP.NET MVC 4 Runtime'}
if($aspMvc4) {
	Write-Warning "ASP.NET MVC 4 Runtime is already installed"
} else {
	$url = "http://download.microsoft.com/download/2/F/6/2F63CCD8-9288-4CC8-B58C-81D109F8F5A3/AspNetMVC4Setup.exe"
	DownloadAndInstall $url
	$aspMvc4 = Get-WmiObject -Class Win32_Product | where {$_.Name -eq 'Microsoft ASP.NET MVC 4 Runtime'}
}
if(!$aspMvc4) {
	Write-Error "Failed to install ASP.NET MVC 4 Runtime"
	exit
}

###############################################################################
## STEP 4 - configure trusted application port
###############################################################################

Set-CsWebServer -Identity $PoolName `
		-MeetingRoomAdminPortalInternalListeningPort 4456 `
		-MeetingRoomAdminPortalExternalListeningPort 4457

$webSrv = Get-CsService -WebServer -PoolFqdn $PoolName
if($webSrv.MeetingRoomAdminPortalInternalListeningPort -ne 4456) {
	Write-Error "Failed to set MeetingRoomAdminPortalInternalListeningPort"
	exit
}
if($webSrv.MeetingRoomAdminPortalExternalListeningPort -ne 4457) {
	Write-Error "Failed to set MeetingRoomAdminPortalExternalListeningPort"
	exit
}
		
###############################################################################
## STEP 5 - install LyncRoomAdminPortal.exe
###############################################################################

$url = "http://download.microsoft.com/download/8/7/8/878DA290-F608-4297-B1C7-4A5FC8245EA3/LyncRoomAdminPortal.exe"
DownloadAndInstall $url
if(-not $(Test-Path $installPath)) {
	Write-Error "Failed to install Lync Room Admin Portal"
	exit
}

###############################################################################
## STEP 6 - update web.config
###############################################################################

$webConfig = "$installPath\web.config"
$cfgOrig = '<add key="PortalUserName" value="sip:LRSApp@microsoft.com" />'
$cfgNew = '<add key="PortalUserName" value="sip:' + $LrsAppUser + "@" + $SipDomain + '" />' + "`n" +
	'    <add key="PortalUserRegistrarFQDN" value="' + $PoolName + '" />' + "`n" +
	'    <add key="PortalUserRegistrarPort" value="5061" />'
$(gc $webConfig) -replace $cfgOrig,$cfgNew | Out-File $webConfig -Encoding ASCII

###############################################################################
## STEP 7 - verify installation https://<fe-server>/lrs
###############################################################################

$fqdn = $env:COMPUTERNAME + "." + $env:USERDNSDOMAIN
$wc = New-Object System.Net.Webclient
try {
	$wc.DownloadString("https://$fqdn/lrs") | Out-Null
} catch {
	Write-Error "Failed to open Lync Room Admin Portal: $_"
	exit
}

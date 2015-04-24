---
layout: post
title: "Installing LRS Admin The Easy Way"
comments: true
tags: ["Lync","LRS","PowerShell"]
---

Maybe that should be _The Easy Way &trade;_? Oh, it's probably too generic to trademark anyways. Besides, by now I'm sure you know what my easy way is don't you? If you guessed anything other than PowerShell then I'm sad and you should spend more time reading my other blog posts.

I really love [Lync Room Systems](http://catalog.lync.com/en-us/hardware/lync-room-systems/index.aspx#/locale=en-us&categoryid=3&sortby=3&subcategoryid=&filter=&manufacture=&version=&isQualified=&region=&language=&page=1&apptype=&tags=). Not the blind-for-no-reason kind of love, the customers-see-and-experience-ROI-so-easily kind of love which is also the first-hand-makes-my-life-easier-and-better kind of love if you have ever used an LRS. "Start meetings faster" seems like such a simple value proposition but it's so powerful. Anyway, love of LRS aside, if you have any LRS then you should also be using the [LRS admin tool](http://www.microsoft.com/en-us/download/details.aspx?id=40329). Unfortunately this isn't built into Lync but there are some fairly details [deployment instructions](https://technet.microsoft.com/en-us/library/dn436324.aspx) if you're into that whole [RTFM](http://en.wikipedia.org/wiki/RTFM). Puff... why read a manual on how to deploy something when someone else has written a script to do all that! Well that's what I've done for you.

I'll post the link for this script right here in case people don't want to go any further.

<a class="download" href="/content/Install-LrsAdmin.ps1"><i class="fa fa-file-text-o"></i> Install-LrsAdmin.ps1 <i class="fa fa-download"></i></a>

For those of you who are interested, thanks for continuing to read <i class="fa fa-smile-o"></i>.

There are a number of parameters that you can specify but they all have defaults.

<pre class="hljs powershell"><code>
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

</code></pre>

For _$PoolName_ and _$SipDomain_, if they aren't specified the script tries to auto-detect a value.

<pre class="hljs powershell"><code>
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

</code></pre>

Then we check that the script is being run on a Lync Front End with at least CU2.

<pre class="hljs powershell"><code>
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

</code></pre>

The first step is to create a SIP enabled user for the app.

<pre class="hljs powershell"><code>
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

</code></pre>

The second step is to create the global security groups in AD.

<pre class="hljs powershell"><code>
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

</code></pre>

The third step is to install ASP.NET MVC 4.

<pre class="hljs powershell"><code>
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

</code></pre>

*NOTE*: the snippet above refers to a function _DownloadAndInstall_ that is defined in the script file you can download but that I haven't shown in the post. Download the script and use that if you want to copy and paste step by step.

The fourth step is to set the application ports.

<pre class="hljs powershell"><code>
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

</code></pre>

The fifth step is to actually download and install the LRS Admin app.

<pre class="hljs powershell"><code>
$url = "http://download.microsoft.com/download/8/7/8/878DA290-F608-4297-B1C7-4A5FC8245EA3/LyncRoomAdminPortal.exe"
DownloadAndInstall $url
if(-not $(Test-Path $installPath)) {
	Write-Error "Failed to install Lync Room Admin Portal"
	exit
}

</code></pre>

Then finally the last step is to write the web.config file for the app.

<pre class="hljs powershell"><code>
$webConfig = "$installPath\web.config"
$cfgOrig = '<add key="PortalUserName" value="sip:LRSApp@microsoft.com" />'
$cfgNew = '<add key="PortalUserName" value="sip:' + $LrsAppUser + "@" + $SipDomain + '" />' + "`n" +
	'    <add key="PortalUserRegistrarFQDN" value="' + $PoolName + '" />' + "`n" +
	'    <add key="PortalUserRegistrarPort" value="5061" />'
$(gc $webConfig) -replace $cfgOrig,$cfgNew | Out-File $webConfig -Encoding ASCII

</code></pre>

Now wasn't that easier then doing it all by hand?
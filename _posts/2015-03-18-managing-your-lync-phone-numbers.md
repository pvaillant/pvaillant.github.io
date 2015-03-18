--- 
layout: post
title: "Managing Your Lync Phone Numbers"
comments: true
tags: ["PowerShell","Lync","ThinkTel","uControl"]
---

I love PowerShell! There, I said it, just in case anyone was wondering. I love that it let's you dig in, mix and match data and get even more useful data out then what you started with. Case in point: I was working with a customer with a fairly large Lync deployment and a SIP trunk from ThinkTel who wanted to review the numbers they had on their SIP trunk and compare it to numbers assigned in Lync so they could identify any missing or available numbers. There are several example scripts around on how to do this. The key is that you have to pull from all the different kinds of objects that could be assigned phone numbers in Lync:

<pre><code class="hljs powershell">
Get-CsUser -Filter {LineURI -ne $Null}
Get-CsUser -Filter {PrivateLine -ne $Null}
Get-CsAnalogDevice -Filter {LineURI -ne $Null}
Get-CsCommonAreaPhone -Filter {LineURI -ne $Null}
Get-CsRgsWorkflow | ?{ $_.LineURI }
Get-CsDialInConferencingAccessNumber -Filter {LineURI -ne $Null}
Get-CsExUmContact -Filter {LineURI -ne $Null}
Get-CsTrustedApplicationEndpoint -Filter {LineURI -ne $Null}
Get-CsMeetingRoom -Filter {LineURI -ne $Null}

</code></pre>

I love RESTful APIs too! That's the second part of this story. There's a RESTful API for uControl, the ThinkTel web portal for managing SIP trunks, that let's you get all of the DIDs on a SIP Trunk. Much easier than scraping a web page and trying to parse out the data from HTML.

<pre><code class="hljs powershell">
$wc = New-Object System.Net.WebClient
$wc.Credentials = $(Get-Credential).GetNetworkCredential()
$sipTrunkDidsUri = "https://api.thinktel.ca/REST.svc/SipTrunks/{0}/Dids?PageFrom=0&PageSize=100000"
$sipTrunkDidsUrl = $sipTrunkDidsUri -f 7005551212
[xml]$didsXml = $wc.DownloadString($sipTrunkDidsUrl)
if($didsXml -and $didsXml.ArrayOfTerseNumber) {
	$didsXml.ArrayOfTerseNumber.TerseNumber | %{ $_.Number }
}

</code></pre>

Replace _7005551212_ in the example above with your own SIP trunk pilot number.

Now that we have all the assigned numbers and all the numbers on the trunk, it's easy to loop through both and produce a list. 

One more RESTful API while we're at it; you can use [Local Calling Guide](http://localcallingguide.com) to lookup the city for each of the numbers so that you can more easily find an available number for a new user based on where they need the number.

<pre><code class="hljs powershell">
function LookupCity($tel) {
	$lcgUri = "http://www.localcallingguide.com/xmlprefix.php?npa={0}&nxx={1}"

	# we need a 10 digit number to extract the NPA/NXX from
	if($tel -match '^tel:+1(\d{10})(;ext=\d+)?$') {
		$tel = $tel = $tel.Substring(6,10)
	}
	if($tel -notmatch '^\d{10}$') {
		Write-Error "Couldn't identify NPA/NXX in $tel"
	}
	$npa = $tel.Substring(0,3)
	$nxx = $tel.Substring(3,3)

	if($npa -match "^8(00|88|77|66|55|44|33|22)$") {
		"Toll-free"
	} else {
		$lcgUrl = $lcgUri -f $npanxx.Substring(0,3),$npanxx.Substring(3,3)
		[xml]$lcgXml = $wc.DownloadString($lcgUrl)
		if($lcgXml -and $lcgXml.root.prefixdata) {
			$lcgXml.root.prefixdata.rc + ", " + $lcgXml.root.prefixdata.region
		} else {
			Write-Warning "Failed to identify city of $tel"
			"UNKNOWN"
		}
	}
}

</code></pre>

I've put that all together into a script (couldn't see that coming huh?): [Get-LyncNumbers.ps1](/content/Get-LyncNumbers.ps1). Unless you have very few numbers, I definitely recommend piping the output of this script through [Export-CSV](https://technet.microsoft.com/en-us/library/hh849932.aspx) and viewing the data in Excel, or maybe [Out-GridView](https://technet.microsoft.com/en-us/library/hh849920.aspx) if you prefer that.

Side plug: if you are a .NET developer looking to do rate center lookups by NPA/NXX, be sure to check out my other project [ThinkTel.LocalCallingGuide](https://github.com/ThinkTel/ThinkTel.LocalCallingGuide) on GitHub and also in [NuGet](http://www.nuget.org/packages/ThinkTel.LocalCallingGuide/).
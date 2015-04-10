---
layout: post
title: "Keeping Lync Unassigned Numbers Updated"
comments: true
tags: ["Lync","PowerShell","ThinkTel","uControl"]
---

Here's a perfect example of something a human should never half to do: maintain a list of unassigned phone numbers. The only problem is where to get an authoritative source of the numbers that are in Lync? Hmmm... we could use an Excel spreadsheet but that just moves the burden of suffering to maintaining the spreadsheet instead of removing it. Instead of doing that by hand, let's use the uControl API I talked about earlier (see [Managing Your Lync Phone Numbers](/2015/03/18/managing-your-lync-phone-numbers.html)) and some PowerShell.

The first thing we need to do is get a list of all the phone numbers on the SIP trunk. Using the uControl RESTful API:

<pre class="hljs powershell"><code>
$wc = New-Object System.Net.WebClient
$wc.Credentials = $Credential.GetNetworkCredential()
$sipTrunkDidsUrl = "https://api.thinktel.ca/REST.svc/SipTrunks/{0}/Dids?PageFrom=0&PageSize=100000" -f $SipPilotNumber
$didsXml = $wc.DownloadString($sipTrunkDidsUrl)
if(-not $didsXml) {
	Write-Error "Failed to list DIDs on SIP Pilot $SipPilotNumber"
	exit
}
$didsList = [xml]$didsXml
if(-not $didsList -or -not $didsList.ArrayOfTerseNumber) {
	Write-Error "Failed to load or parse DIDs on SIP Pilot $SipPilotNumber"
	exit
}
$didsList.ArrayOfTerseNumber.TerseNumber | %{ $_.Number }

</code></pre>

With those in hand, let's get all the current unassigned numbers:

<pre class="hljs powershell"><code>
Get-CsUnassignedNumber | %{
  [long]$start = $_.NumberRangeStart.Substring(2)
  [long]$end = $_.NumberRangeEnd.Substring(2)
  $start..$end
}

</code></pre>

Lastly, let'd assume that there is already an announcement available for the unassigned numbers, so you can get it with [Get-CsAnnouncement](https://technet.microsoft.com/en-us/library/gg398937.aspx). Or, if you didn't have an announcement, you could create one as follows:

<pre class="hljs powershell"><code>
New-CsAnnouncement -identity $(Get-CsService -ApplicationServer | select -first 1).identity `
  -Name "Unassigned" -Language en-us `
  -TextToSpeechPrompt "The number you're trying to reach is unassigned. Please try again"

</code></pre>

With all that information, it's just a little [set math](http://en.wikipedia.org/wiki/Set_\(mathematics\)) to find the entries we need to add and remove.

Like always, you can download this script [Update-LyncUnassignedNumbers.ps1](/content/Update-LyncUnassignedNumbers.ps1).

Keep in mind that because unassigned numbers are processed last in the Lync routing, we don't have to worry about removing an unassigned number if you assign it to a user or contact in Lync. If you really want to, say because you really want to keep your unassigned numbers purely for unassigned numbers, take solace: you are not alone. There is an option in the script above (-Force) that will do just that.

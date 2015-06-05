---
layout: post
title: "Document Your ThinkTel DIDs"
comments: true
tags: ["SkypeForBusiness","PowerShell","ThinkTel","uControl"]
---

Documentation is important. It's key to being able to work together in teams and not have to rely on information based informally from person to person. I've talked before about how to [document your PowerShell scripts](/2015/05/01/document-your-powershell-scripts.html) but did you know you can also label each DID on your ThinkTel SIP trunk? This lets you record who or what the DID is for and can be very useful since it is shown in CDR reports, letting you know who originated or received individual calls. This can also be a big step towards not needing to document your phone number assignments in a separate Excel spreadsheet.

While the script below is specifically for Microsoft Lync or Skype for Business, it could easily be adapted for any system where the information on the allocated DID and the assigned user was available using PowerShell. This could be a backend database, a directory of some kind or web service API.

## Get uControl Labels

Using previously shown PowerShell (see [Keeping Lync Unassigned Numbers Updated](/2015/04/10/keeping-lync-unassigned-numbers-updated.html)), we start by downloading all the DIDs and their labels from uControl.

<pre class="hljs powershell"><code>
$sipTrunkDidsUrl = "https://api.thinktel.ca/REST.svc/SipTrunks/{0}/Dids?PageFrom=0&PageSize=100000" -f $SipPilotNumber
$didsList = Invoke-RestMethod -URI $sipTrunkDidsUrl -Credential $Credential -Method GET -ContentType "text/xml"
if(-not $didsList -or -not $didsList.ArrayOfTerseNumber) {
	Write-Error "Failed to load or parse DIDs on SIP Pilot $SipPilotNumber"
	exit
}

$existingLabels = @{}
$didsList.ArrayOfTerseNumber.TerseNumber | foreach {
  $existingLabels.Add($\_.Number, $\_.Label)
}

</code></pre>

One note, and you'll see this below too, I'm using Invoke-RestMethod here so this will need to be run on a machine with PowerShell 3.0+ since that's when this cmdlet was introduced. This was released with Windows 2012 R1 so hopefully you have at least that. If you did have Windows 2008 R2 for some reason, my sympathies, but you could use System.Net.WebClient instead. If anyone has this situation, and is interested in a version of this script for PowerShell 2.0, let me know.

## Get Labels From Skype for Business

Next step, again using previously shown PowerShell (see [Managing Your Lync Phone Numbers](/2015/03/18/managing-your-lync-phone-numbers.html)), we get a list of all numbers assigned and a label to represent to what they are assigned to.

<pre class="hljs powershell"><code>
$currentLabels = @()
function AddCurrentLabel($telUri, $label) {
  if($telUri -notmatch '^tel:+1') {
    Write-Warning "Skipping $telUri ($label) because it doesn't start with tel:+1"
  } elseif($telUri -match ';ext=') {
    Write-Warning "Skipping $telUri ($label) because it contains an extension"
  } else {
    # $telUri will start with tel:+1 so let's skip that
    $number = $telUri.Substring(6)
    $currentLabels.Add($number, $label)
  }
}
Get-CsUser -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($\_.LineURI, "User " + $\_.SipAddress)
}
Get-CsUser -Filter {PrivateLine -ne $Null} | foreach {
  AddCurrentLabel($\_.PrivateLine, "User " + $\_.SipAddress + " (private line)")
}
Get-CsAnalogDevice -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($\_.LineURI, "Analog Device " + $\_.DisplayName)
}
Get-CsCommonAreaPhone -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($\_.LineURI, "Common Area Phone " + $\_.DisplayName)
}
Get-CsRgsWorkflow | ?{ $\_.LineURI } | foreach {
  AddCurrentLabel($\_.LineURI, "RGS Workflow " + $\_.PrimaryAddress)
}
Get-CsDialInConferencingAccessNumber -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($\_.LineURI, "Dial In Conf Number " + $\_.DisplayName)
}
Get-CsExUmContact -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($\_.LineURI, "ExUmContact " + $\_.DisplayName)
}
Get-CsTrustedApplicationEndpoint -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($\_.LineUri, "Trusted App Endpoint " + $\_.SipAddress)
}
Get-CsMeetingRoom -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($\_.LineURI, "Meeting Room " + $\_.SipAddress)
}

</code></pre>

For users, the choice of label is obvious (name and SIP address), and for other objects there is generally a description or display name available. In a worse case scenario, I find it sufficient to just note the kind of usage.

## Find Updates

Then we compare the two hashes:
 * We check for any labels that are only in the current set; those are ones that don't exist on the SIP trunk since at worse an empty label would be returned for each DID,
 * We check for any labels that are only in the existing set; those are old ones that don't exist in Skype for Business,
 * We check all the labels in both to see if they match, other wise we update it

<pre class="hljs powershell"><code>
$newLabels = @{}
foreach($num in $currentLabels.Keys) {
  if($existingLabels.ContainsKey($num)) {
    # this is a valid number on the trunk
    if($currentLabels[$num] -ne $existingLabels[$num]) {
      # the label needs to be updated
      $newLabels.Add($num, $currentLabels[$num])
    }
  } else {
    # this is not a number on the trunk
    Write-Warning "Skipping $num since it isn't on the trunk"
  }
}

</code></pre>

## PUT data back to uControl

Last, but not least, we then send this data back to uControl.

<pre class="hljs powershell"><code>
foreach($num in $newLabels.Keys) {
  $label = $newLabels[$num]
  Write-Verbose "Updating $num ($label)"

  # we actually need to start by getting the current number information
  # this ensures we don't clear out an existing number translation
  $sipTrunkDidUrl = "https://api.thinktel.ca/REST.svc/SipTrunks/{0}/Dids/{1}" -f $SipPilotNumber,$num
  $d = Invoke-RestMethod -URI $sipTrunkDidUrl -Credential $Credential -Method GET -ContentType "application/json"
  if(-not $d -or $d.Number -ne $num) {
		Write-Error "Failed to load information for DID $num"
		continue
  }

  # update the DID label
  $d.Label = $label

  # now POST this back to $sipTrunkDidUrl
  if($PSCmdlet.ShouldProcess($num,"Update DID label")) {
		Invoke-RestMethod -URI $sipTrunkDidUrl -Credential $Credential -Method "POST" -ContentType "application/json" -Body $d
  }
}

</code></pre>

You might wonder why I'm downloading each DID instead of just building it the response in memory. The initial GET query we did for all the DIDs doesn't have all the information for the DID. So features like number translation would be over-written if we didn't include it in the PUT body. You can see the difference since the initial GET query doesn't return an ArrayOfDid, instead it's an ArrayOfTerseNumber, with TerseNumber only having Number and Label instead of all the DID information.

Note too the [$PSCmdlet.ShouldProcess](https://msdn.microsoft.com/en-us/library/ms568271%28v=vs.85%29.aspx) used above. That, plus [[CmdletBinding(SupportShouldProcess=$true)]](https://msdn.microsoft.com/en-us/library/system.management.automation.cmdletbindingattribute%28v=vs.85%29.aspx) above param() is what makes -WhatIf work so that you can see what changes would be made before actually committing to making the changes.

And that's all there is to it. Now, if you set this up as a scheduled task, your current number assignments will be reflected automatically into the uControl web portal.

## Download the Script

<a class="download" href="/content/Update-ThinkTelDidLabels.ps1"><i class="fa fa-file-text-o"></i> Update-ThinkTelDidLabels.ps1 <i class="fa fa-download"></i></a>

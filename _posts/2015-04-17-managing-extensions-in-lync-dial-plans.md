---
layout: post
title: "Managing extensions in Lync dial plans"
comments: true
tags: ["Lync","PowerShell"]
---

The title of this article should probably include the works _"without having to tear your hair out"_. Extensions are one of those things that are synonymous with PBX for a lot of people. And extensions are something that also can be a point of frustration with Lync, not only because of how they are managed, but also with the duplication that can occur given that extensions have to be separately entered into Lync and Exchange. Well here's some PowerShell to make your day better if you deal with extensions.

First some context: this script was developed while working with a customer who wanted to have both DIDs as well as maintain legacy extensions. It was developed to make the extensions more manageable since the same effort could have been achieved manually at the cost of less hair at the end of the day or whenever a change was required (add extension, change extension, etc).

Second, a little segway first into [E.164](http://www.itu.int/rec/T-REC-E.164-201011-I/en) and [RFC3966](https://tools.ietf.org/html/rfc3966). This are the relevant standards for the tel: URI used in Lync for the LineURI value assigned to a user. I like standards and for DIDs that means tel:+17005551212 all the time. In this case what we're adding is the extension for each user to the LineURI itself in the form of tel:+17005551212;ext=1234. If you're interested in E.164 and Lync I'd suggest also reading a nice post by Ken Lasko on the subject of how to format service numbers ([Service Number Formatting in Lync](http://ucken.blogspot.ca/2015/01/service-number-formatting-in-lync.html)).

Now to the script! First we grab all the users.

<pre class="hljs powershell"><code>$users = Get-CsUser -Filter {EnterpriseVoiceEnabled -eq $true}</code></pre>

Then we make sure that the same extension hasn't been assigned more than once (it happens, easily, hence the check).

<pre class="hljs powershell"><code>
$assignedDups = new-object 'system.collections.generic.dictionary[int,system.collections.generic.list[string]]'
$assignedExts = new-object 'system.collections.generic.dictionary[int,string]'
# for every user who has an extension assigned
$users | where LineURI -match ';ext=' | foreach {
	$sip = $_.SipAddress
	$line = $_.LineURI.Substring(4) # remove tel:
	[int]$ext = $line -split ';ext=' | select -last 1
	# check if we've seen this extension already
	if($assignedDups.ContainsKey($ext)) {
		# seen this before multiple times
		$assignedDups[$ext].Add($line)
	}
	else if($assignedExts.ContainsKey($ext)) {
		# this is the second time we've seen this extension
		# create a list of duplicates; the first one and this one
		$dups = new-object 'system.collections.generic.list[string]' @($assignedExts[$ext],$line)
		# save the duplicates
		$assignedDups.Add($ext, $dups)
		# and remove this extension from the unique list
		$assignedExts.Remove($ext)
	}
	else {
		# this is the first time we've seen this extension
		$assignedExts.Add($ext, $line)
	}
}

# if we've seen any duplicates
if($assignedDups.Count -gt 0) {
	# for each duplicate
	$assignedDups.GetEnumerator() | foreach {
		# print a warning that shows all the phone numbers assigned this duplicate
		$dups = $_.Value -join ', '
		Write-Warning "Skipping $($_.Key) which has duplicates ($dups)" 
	}
}

</code></pre>

Once we have a list of extensions that aren't duplicates it's just a matter of getting all the dial plan normalization rules and checking for any rules that are missing.

<pre class="hljs powershell"><code>
$rules = Get-CsVoiceNormalizationRule -Identity $DialPlan | where Name -match $NormalizationRulePrefix
$currentExts = new-object 'system.collections.generic.dictionary[int,string[]]'
$rules | foreach {
	[int]$ext = $_.Pattern.Substring(1, $_.Pattern.Length - 2) # remove leading ^ and trailing $
	$line = $_.Translation
	$identity = $_.Identity
	$currentExts.Add($ext, [string[]]@($line,$identity))
}

$assignedKeys = $assignedExts.Keys
$currentKeys = $currentExts.Keys

# adds = assigned keys - current keys
$newExts = $assignedKeys | where { $currentKeys -notcontains $_ }
Write-Verbose "$($newExts.count) new extensions"

# deletes = current keys - assigned keys
$oldExts = $currentKeys | where { $assignedKeys -notcontains $_ }
Write-Verbose "$($oldExts.count) old extensions"

# updates = existing current keys that don't match assigned keys
$setExts = $assignedKeys | where { $currentKeys -contains $_ -and $assignedExts[$_] -ne $currentKeys[$_][0] }
Write-Verbose "$($setExts.count) updated extensions"

</code></pre>

I do this because I expect this script to be run over and over and it wouldn't make sense to recreate the dial plan from scratch each time when we can just make the small number of changes that will happen, if any, between runs. The most likely scenario is that we there's only a small number of adds/changes each time.

Now that we know the changes we need to make, make them!

<pre class="hljs powershell"><code>
$batch = Get-Date -Format "yyyy-MM-dd HH:mm"

# new-csvoicenormalizationrule w/ date as description
$newExts | foreach {
	New-CsVoiceNormalizationRule -Identity "$DialPlan/$NormalizationRulePrefix $_" -Pattern $('^' + $_ + '$') -Translation $assignedExts[$_] -Description "Created $batch" -Confirm:$false
}

# set-csvoicenormalizationrule w/ date as description
$setExts | foreach {
	$rule = $currentKeys[$_][1]
	Set-CsVoiceNormalizationRule -Identity $rule -Translation $assignedExts[$_] -Description "Updated $batch" -Confirm:$false
}

# remove-csvoicenormalizationrule
$oldExts | foreach {
	$rule = $currentKeys[$_][1]
	Remove-CsVoiceNormalizationRule -Identity $rule -Confirm:$false
}

</code></pre>

If you have the need to manage extensions, download this script today!

<a class="download" href="/content/Update-LyncExtensionDialing.ps1"><i class="fa fa-file-text-o"></i> Update-LyncExtensionDialing.ps1 <i class="fa fa-download"></i></a>
<#
.SYNOPSIS
	Updates a Lync dial plan to include normalization rules for all users with assigned extensions.
	
.PARAMETER DialPlan
	Identity of the DialPlan to update

.PARAMETER NormalizationRulePrefix
	Prefix used to identify normalization rules to be managed

.EXAMPLE
	Update-LyncExtensionDialing.ps1
	It's so straight forward, you don't need any parameters

.EXAMPLE
	Update-LyncExtensionDialing.ps1 -DialPlan RedmondOffice
	This will update the RedmondOffice dial plan. 
	
.NOTES
	Version 1.0.0 (2015-04-17)
	Written by Paul Vaillant
	
.LINK
	http://paul.vaillant.ca/help/Get-LyncExtensionDialing.html
#>

[CmdletBinding()]
param(
	[string]$DialPlan = "Global",
	[string]$NormalizationRulePrefix = "Ext "
)

###############################################################################
## VALIDATE PARAMS
###############################################################################
if(!$(Get-CsDialPlan $DialPlan -ErrorAction SilentlyContinue -Verbose:$false)) {
	Write-Error "Invalid dial plan $DialPlan"
	exit
}

###############################################################################
## Read the extensions assigned to users
###############################################################################
$users = Get-CsUser -Filter {EnterpriseVoiceEnabled -eq $true}
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

###############################################################################
## Read the current normalization rules
###############################################################################
$rules = Get-CsVoiceNormalizationRule -Identity $DialPlan | where Name -match $NormalizationRulePrefix
$currentExts = new-object 'system.collections.generic.dictionary[int,string[]]'
$rules | foreach {
	[int]$ext = $_.Pattern.Substring(1, $_.Pattern.Length - 2) # remove leading ^ and trailing $
	$line = $_.Translation
	$identity = $_.Identity
	$currentExts.Add($ext, [string[]]@($line,$identity))
}

###############################################################################
## Create a delta (adds / updates / deletes)
###############################################################################
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

###############################################################################
## Modify dial plan normalization rules
###############################################################################
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
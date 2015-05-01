<#
.SYNOPSIS
	Queries Active Directory and returns a list of required licensing detected for each enabled Lync user.

.OUTPUTS
	Returns a PSCustomObject for each user with the following properties:
	Identity, lyncStandardCAL, lyncEnterpriseCAL, lyncPlusCAL, exchangeStandardCAL, exchangeEnterpriseCAL

.EXAMPLES
	Get-LyncUserLicensing.ps1 | measure lyncStandardCAL,lyncEnterpriseCAL,lyncPlusCAL | group Property | select Name,@{n='Count';e={$_.Group[0].Count}}
	This will get all the individual user licensing and count the number of each of the types of Lync CALs and return a summary count for each CAL type.

.NOTES
	Version 1.0.0 (2015-03-24)
	Written by Paul Vaillant
	
.LINK
	http://paul.vaillant.ca/help/Get-LyncUserLicensing.html
#>

[CmdletBinding()]
param ()
# FUTURE: add a parameter so that we can request licensing for a specific user
#	[Parameter(ValueFromPipeline=$true,Mandatory=$true)][array]$Identity

# find the AD object with class=msRTCSIP-GlobalTopologySetting and read msRTCSIP-BackEndServer
$rootdse = [adsi]"LDAP://RootDSE"
$cnc = $rootdse.configurationNamingContext
# use $cnc as the search base for msRTCSIP-GlobalTopologySetting
$searchBase = New-Object System.DirectoryServices.DirectoryEntry "LDAP://$cnc"
$searcher = New-Object System.DirectoryServices.DirectorySearcher $searchBase,"(objectClass=msRTCSIP-GlobalTopologySetting)",@("msRTCSIP-BackEndServer")
$globalTopo = $searcher.FindAll()
$dataSrc = $globalTopo[0].Properties["msrtcsip-backendserver"][0]

# connect to that server (assuming we have the required permissions)
$connStr = "Data Source=$dataSrc; Initial Catalog=xds;  Integrated Security=SSPI"
$conn = New-Object System.Data.SqlClient.SqlConnection $connStr
$conn.Open()

# connect to the dataSrc and run the following query to get the MeetingPolicy objects
$sql = "SELECT Doc.Name,Item.Data FROM [Item] Item join Document Doc on Item.DocId = Doc.DocId where Doc.Name like '%MeetingPolicy%'"
$cmd = New-Object System.Data.SqlClient.SqlCommand $sql,$conn
$da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
$ds = New-Object System.Data.DataSet
[void]$da.fill($ds) 
$conn.Close()

# there should be 1+ entries; one for global, one for site policies and one for user policies
# if there is only a single site, and a site policy is defined, it replaces the global policy
[array]$meetingPolicies = $ds.Tables[0].Rows | foreach {
	# parse the XML version of the policy
	[xml]$data = $_.Data
	$policyType = $data.AnchoredXml.Key.ScopeClass # Global, Site or Tag
	
	$data.AnchoredXml.Dictionary.GetElementsByTagName("Item") | foreach {
		if($policyType -eq "Tag") {
			[int]$anchor = $_.Key.TagId
			$name = $policyType + ":" + $_.Key.Name
		} elseif($policyType -eq "Site") {
			[int]$anchor = $_.Key.SiteId
			$name = $policyType + ":" + $_.Key.Name
		} else {
			$anchor = $null
			$name = "Global"
		}
		$p = @{Identity = $name; ScopeClass = $policyType; Anchor = $anchor}
		$policyElem = 
		$_.Value.MeetingPolicy.Attributes | foreach {
			$k = $_.Name
			if($k -ne 'xmlns') {
				$v = $_.Value
				if($v -eq 'true') { $v = $true }
				elseif($v -eq 'false') { $v = $false }
				$p.$k = $v
			}
		}
		[pscustomobject]$p
	}
}

function isEnterpriseConfPolicy($p) {
	!$(!$p.AllowIPAudio -and !$p.AllowIPVideo -and !$p.AllowUserToScheduleMeetingsWithAppSharing -and
		!$p.AllowAnonymousParticipantsInMeetings -and !$p.AllowPolls -and 
		$p.EnableAppDesktopSharing -eq 'None' -and !$p.EnableDialinConferencing)
}

# this is just a short cut for creating a System.DirectoryServices.DirectorySearcher object
$adSearch = [adsisearcher]"(|(msRTCSIP-Line=*)(msRTCSIP-PrimaryUserAddress=*))"
@("distinguishedName","msrtcsip-primaryhomeserver","msrtcsip-userenabled","msrtcsip-userpolicies","msrtcsip-optionflags","msexchmailboxguid","msexchumenabledflags") | foreach {
	$adSearch.PropertiesToLoad.Add($_) | Out-Null
}

$adSearch.FindAll() | foreach {
	$u = @{Identity = $_.Properties["distinguishedName"][0]}
	
	# Lync Standard CAL check
	$u.lyncStandardCAL = $true -and $_.Properties["msrtcsip-userenabled"] -ne $null
	
	# Lync Enterprise CAL check
	$confPolicyId = $null
	if($_.Properties["msrtcsip-userpolicies"]) {
		for($i = 0; $i -lt $_.Properties["msrtcsip-userpolicies"].Count; $i++) {
			if($_.Properties["msrtcsip-userpolicies"][$i].StartsWith("1=")) {
				$policyType,$confPolicyId = $_.Properties["msrtcsip-userpolicies"][$i].Split('=')
			}
		}
	}
	$confPolicy = $null
	if($confPolicyId) {
		# user has a tag policy; check those first
		$confPolicy = $meetingPolicies | where { $_.ScopeClass -eq "Tag" -and $_.Anchor -eq $confPolicyId }
	}
	if(!$confPolicy) {
		# user is subject to site policy (if it exists)
		[int]$siteID = $_.Properties["msrtcsip-primaryhomeserver"][0].Split(',')[2].Split('=')[1].Split(':')[0]
		$confPolicy = $meetingPolicies | where { $_.ScopeClass -eq "Site" -and $_.Anchor -eq $siteID }
	}
	if(!$confPolicy) {
		# user is subject to the global policy
		$confPolicy = $meetingPolicies | where { $_.ScopeClass -eq "Global" }
	}
	if(!$confPolicy) {
		Write-Error "$($u.Identity) doesn't have a valid conferencing policy"
		continue
	}
	$u.lyncEnterpriseCAL = isEnterpriseConfPolicy $confPolicy

	# Lync Plus CAL check
	# 16 = RCC enabled, 128 = EnterpriseVoiceEnabled, 512 = RCC Dual Mode
	if($_.Properties["msrtcsip-optionflags"]) {
		[int]$of = $_.Properties["msrtcsip-optionflags"][0]
		$u.lyncPlusCAL = ((($of -band 16) -eq 16) -or (($of -band 128) -eq 128) -or (($of -band 512) -eq 512))
	} else {
		$u.lyncPlusCAL = $false
	}
	
	# while we're at it...
	# Exchange Standard CAL check
	$u.exchangeStandardCAL = $true -and $_.Properties["msexchmailboxguid"] -ne $null
		
	# Exchange Enterprise CAL check
	$u.exchangeEnterpriseCAL = $true -and $_.Properties["msexchumenabledflags"] -ne $null
	
	[pscustomobject]$u
}

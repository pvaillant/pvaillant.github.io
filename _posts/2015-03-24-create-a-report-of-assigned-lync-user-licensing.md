--- 
layout: post
title: "Create a Report of Assigned Lync User Licensing"
comments: true
tags: ["Lync", "licensing", "PowerShell", "sql"]
---

I've talked about the importance of having data when making decisions before. Decisions isn't the only thing data is good for. Another great us is checking to make sure things are as you expect them to be. So today we're going to talk about licensing, specifically Lync user licensing. Lync licensing can be challenging because there is no magic check box in the product that correspond to the difference between a _"Standard"_ and _"Enterprise"_ CAL. Those features are governed by the conference policy assigned to the user. To complicate matters, that policy can be global, site or user scoped, so in some cases it may depend on what site the user is logged in at.

There is a reference from Microsoft available, the [Lync pricing and licensing guide](http://products.office.com/en-us/lync/microsoft-lync-licensing-overview-lync-for-multiple-users), that details the various features of each CAL. You can also consult the [Microsoft Product Use Rights Document](http://pur.microsoft.com/products.aspx) for further information.

Those are big docs, so I'll summarize the differences between the two here.

*STANDARD CAL*

 * Presence & P2P IM/audio/video/file transfer (no application sharing or white boarding)
 * Multi-party IM and file transfer (can't initiate audio or video)
 * Attend conferences as an attendee (not a presenter)

*ENTERPRISE CAL*

 * Ad-hoc multi-party meetings with audio and video, including PSTN dial out
 * P2P application sharing and white boarding
 * Scheduling & inviting attendees to meetings
 * Lync Room Systems

I've omitted the Plus CAL above for brevity since, unlike the Enterprise CAL, there's a clear setting _"Enterprise Voice Enabled"_ on the Lync user object.

So how do we check for this? We evaluate the conferencing policies in Lync to see if they properly limit the user to only the Standard CAL features.

<pre class="hljs powershell"><code>
$enterpriseConferencingPolicies = Get-CsConferencingPolicy | where {
	!$(!$_.AllowIPAudio -and !$_.AllowIPVideo -and !$_.AllowUserToScheduleMeetingsWithAppSharing -and
		!$_.AllowAnonymousParticipantsInMeetings -and !$_.AllowPolls -and 
		$_.EnableAppDesktopSharing -eq 'None' -and !$_.EnableDialinConferencing)
}

</code></pre>

This looks for conferencing policies that allow for either audio or video, or scheduled meetings, or any of the other features listed above. Once we have this list, then we can evaluate all users to see if they are assigned on of these policies in order to determine what licensing they should have.

<pre class="hljs powershell"><code>
[array]$enterpriseConfPolicyIds = $enterpriseConferencingPolicies | %{ $_.Identity }
$assignedUserLicenses = Get-CsUser | foreach {
	$confPolicy = $($_ | Get-CsEffectivePolicy).ConferencingPolicy.ToString()
	[pscustomobject]@{
		user = $_; 
		lyncStandardCAL = $true; 
		lyncEnterpriseCAL = $enterpriseConfPolicyIds -contains $confPolicy; 
		lyncPlusCAL = $_.EnterpriseVoiceEnabled -or $_.RemoteCallControlTelephonyEnabled
	}
}

# we can get a nice summary by counting each license type
$sums = $assignedUserLicenses | measure lyncStandardCAL,lyncEnterpriseCAL,lyncPlusCAL
# and extracting it from the measure using group & select
$sums | group Property | select Name,@{n='Count';e={$_.Group[0].Count}}

</code></pre>

In addition to the licensing for users, also keep in mind licensing for Lync Room Systems ([Get-CsMeetingRoom](https://technet.microsoft.com/en-us/library/jj205277.aspx)) and also for common area phones ([Get-CsCommonAreaPhone](https://technet.microsoft.com/en-us/library/gg412934.aspx)).

As an interesting side note, it's also possible to perform the same check without using the Lync PowerShell cmdlets. You can get the SQL instance that stores the CMS (and the conferencing policies) by querying the configuration naming context of AD for _(objectClass=msRTCSIP-GlobalTopologySetting)_ and reading the attribute _msRTCSIP-BackEndServer_. Then you can connect to the _xds_ database in this SQL instance query it for:

<pre class="hljs sql"><code>
SELECT Doc.Name,Item.Data FROM [Item] Item join Document Doc on Item.DocId = Doc.DocId where Doc.Name like '%MeetingPolicy%'

</code></pre>

You can then deserialize the returned XML and you have exactly the same value as from Get-CsConferencingPolicy.

Lastly you can get all the Lync objects from Active Directory as well. I like to use the query _(\|(msRTCSIP-Line=\*)(msRTCSIP-PrimaryUserAddress=\*))_ since it returns *all* Lync objects but you could further filter by objectClass if you wanted only users. The attribute _msRTCSIP-UserPolicies_ (which is a multi-value attribute) contains values in the form of [policyNumber]=[policyID]. The [policyNumber] for the conferencing policy is 1 so you just need to find the value that start with 1=. If there isn't one, then the global or site policy apply.

You can download a version I wrote in pure PowerShell that demonstrates this concept. The nice thing about PowerShell is that it's so very close to .NET that it makes experimenting with things like this very easy. If anyone is interested let me know and maybe I'll create a .NET library that does the above.

<a class="download" href="/content/Get-LyncUserLicensing.ps1"><i class="fa fa-file-text-o"></i> Get-LyncUserLicensing.ps1 <i class="fa fa-download"></i></a>
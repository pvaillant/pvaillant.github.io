--- 
layout: post
title: "Measuring Lync Conference Adoption"
comments: true
tags: ["PowerShell","Lync","sql","LcsCDR"]
---

I like data. There, I've said it and I'm not ashamed. The best decisions are made with good data. It helps take the decision making process from one of "I think" or "I hope" to "I know".

I often use data to help customers better understand their environment and their users. When you have more than a small number of users, you can't just walk around and ask the same question to everyone.

Recently I was working with a customer who had enabled all their users for every Lync feature quite some time ago. They were getting ready for an upgrade and wanted to re-gauge how the various Lync features were being used. 

Gauging adoption is important for so many reasons. With this data you can ensure that users are actually using the feature you've enabled them for. If they aren't, you can work with them to find out why and either correct it or adjust the expected model. This last is key because all of the sizing for a product as complex as Lync is based on a [user models](https://technet.microsoft.com/en-us/library/gg398811.aspx).

The first place I started with is how many people are hosting conferences and how many people are attending conferences. It's important to gauge attendance as well as hosting because they have different implications. The great news is all the data you need is in the LcsCDR database!

Conference attendees can be retrieved using:

<pre><code class="hljs sql">
use LcsCDR;

with localUsers as (
	select distinct UserUri
	from Registration r join Users u on r.UserId = u.UserId
), confsAndUsers as (
    select 
        ConferenceStartTime, ConferenceEndTime, o.UserUri as orgUserUri, u.UserUri
    from Conferences c
        join Users o on c.OrganizerId = o.UserId
        join McuJoinsAndLeaves jl on jl.SessionIdTime = c.SessionIdTime and jl.SessionIdSeq = c.SessionIdSeq
        join Users u on jl.UserId = u.UserId
        join Mcus m on jl.McuId = m.McuId
        join UriTypes ut on m.McuTypeId = ut.UriTypeId
        left join FocusJoinsAndLeaves fjl on 
            fjl.SessionIdTime = c.SessionIdTime and fjl.SessionIdSeq = c.SessionIdSeq and fjl.UserId = jl.UserId
        left join ClientVersions cv on 
            fjl.ClientVerId = cv.VersionId
    where 
        (ut.UriType = 'conf:audio-video' or ut.UriType = 'conf:applicationsharing' or ut.UriType = 'conf:data-conf')
        and cv.ClientType != 256 and cv.ClientType != 16396
    group by ConferenceStartTime,ConferenceEndTime,o.UserUri,u.UserUri
)

select
    COUNT(*) as ParticipantCount, cu.UserUri
from
    confsAndUsers cu join localUsers lu on cu.UserUri = lu.UserUri
group by cu.UserUri

</code></pre>

What I'm doing at the start here is getting a list of _local users_ by getting the list of all users who have logged into this system. I do this because if an external user joins a meeting via federation, we have no means of knowing in the join/leave information and we only want to report on local users who have participated in meetings. Then I get a list of all the conferences and their organizers/participants. And lastly I select how many unique conferences each local user has participated in.

One value I sometimes also include is the cv.Version which is the User-Agent string that identifies what kind of client the user was using. This can be useful in knowing if users have a preference for what kind of client/device they connect to meetings with.

Similarly, conference organizers can be retrieved using:

<pre><code class="hljs sql">
use LcsCDR;

with confsAndUsers as (
    select 
        ConferenceStartTime, ConferenceEndTime, o.UserUri as orgUserUri, u.UserUri
    from Conferences c
        join Users o on c.OrganizerId = o.UserId
        join McuJoinsAndLeaves jl on jl.SessionIdTime = c.SessionIdTime and jl.SessionIdSeq = c.SessionIdSeq
        join Users u on jl.UserId = u.UserId
        join Mcus m on jl.McuId = m.McuId
        join UriTypes ut on m.McuTypeId = ut.UriTypeId
        left join FocusJoinsAndLeaves fjl on 
            fjl.SessionIdTime = c.SessionIdTime and fjl.SessionIdSeq = c.SessionIdSeq and fjl.UserId = jl.UserId
        left join ClientVersions cv on 
            fjl.ClientVerId = cv.VersionId
    where 
        (ut.UriType = 'conf:audio-video' or ut.UriType = 'conf:applicationsharing' or ut.UriType = 'conf:data-conf')
        and cv.ClientType != 256 and cv.ClientType != 16396
    group by ConferenceStartTime,ConferenceEndTime,o.UserUri,u.UserUri
),
confsAndAttendeeCounts as (
    select 
        ConferenceStartTime,
        CONVERT(varchar,(ConferenceEndTime - ConferenceStartTime),108) as Duration,
        orgUserUri as OrganizerUri,
        COUNT(*) as AttendeeCount
    from confsAndUsers
    group by ConferenceStartTime,ConferenceEndTime,orgUserUri having COUNT(*) > 1
)

select 
    COUNT(*) as HostingCount,
    MIN(AttendeeCount) as MinAttendeeCount,
    AVG(AttendeeCount) as AvgAttendeeCount,
    MAX(AttendeeCount) as MaxAttendeeCount,
    OrganizerUri as UserUri
from confsAndAttendeeCounts 
group by OrganizerUri

</code></pre>

This returns all users who hosted conferences, along with how many conferences they hosted and the minimum, average and maximum number of participants. In this case we don't need _localUsers_ since only local users are able to host meetings in the first place. One note: when I say _conferences_ I mean audio/video conference or application/desktop sharing (so *not* multi-party IM). This corresponds to the Lync Enterprise CAL.

Since both of these are dependant on the LcsCDR data, they are both subject to the standard warning that the time period you're able to retrieve is set by the retention period of the cdr configuration (maybe I should have post just on that...). Once nice thing is these SQL scripts are compatible with both Lync 2010 and 2013.

Like many of my other SQL scripts, I also have a PowerShell script for this: [Get-LyncConferenceAdoption.ps1](/content/Get-LyncConferenceAdoption.ps1). In case you're wondering, I like the PowerShell script version mainly so I never have to open the SQL Management Studio to run it. It's also nice to be able to use PowerShell to dive into the data and slice is up on the fly. Plus you can easily export it to Excel with [Export-CSV](https://technet.microsoft.com/en-us/library/hh849932.aspx).

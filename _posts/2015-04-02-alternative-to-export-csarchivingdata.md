---
layout: post
title: "Alternative to Export-CsArchivingData"
comments: true
tags: ["Lync","PowerShell","sql","LcsLog"]
---

Have you heard about the Lync Archiving role? If not, it's the compliance and [e-discovery](http://en.wikipedia.org/wiki/Electronic_discovery) component of Lync. It's similar to the [litigation hold](https://technet.microsoft.com/en-us/library/ff637980.aspx) functionality available in Exchange. You configure archiving with a number of policy options like whether to notify federated partners of the archiving, retention period, archiving requirement (eg block msgs if they can't be archived), etc. Refer to the documentation for [Set-CsArchivingConfiguration](https://technet.microsoft.com/en-us/library/gg413030.aspx) for a more complete list of the settings.

It's also important to understand what archiving stores and what it doesn't. It stores instant messages, either P2P or in conferences but nothing else. No files transferred, no audio, no video nor screensharing.

Archiving should also not be confused with conversation history. Conversation history is stored in Exchange and is what users access as their record of the conversation. It can also be deleted by the end user themselves which is not desirable for archiving.

Once you've got it configured and running it just works away in the background, but when you need to access it, then what? This is where [Export-CsArchivingData](https://technet.microsoft.com/en-us/library/gg398452.aspx) comes in. You specify a database & output folder plus optionally a start/end date & user URI, and it creates multiple Outlook Express Electronic Mail (EML) file (.EML file extension) in the output folder. That's ok, but what if you want something different? SQL to the rescue!

Archiving is stored in the LcsLog database. Sadly there's no schema documentation available on TechNet but you can use the following query to get messages that a person either sent or got. It works in both Lync 2010 and Lync 2013.

<pre class="hljs sql"><code>
use LcsLog
declare @start datetime = '2015-01-01 00:00:00'
declare @end datetime = '2015-01-31 00:00:00'
declare @useruri nvarchar(max)

select
	m.MessageIdTime Time, f.UserUri FromUser, t.UserUri ToUser, 'p2p' Type, ct.ContentType, m.Body
from Messages m
	join Users f on m.FromId = f.UserId
	join Users t on m.ToId = t.UserId
	join ContentTypes ct on m.ContentTypeId = ct.ContentTypeId
where
	m.MessageIdTime >= @start and m.MessageIdTime < @end
	and (@useruri is null or (f.UserUri = @useruri or t.UserUri = @useruri))
UNION ALL
select
	m.Date Time, f.UserUri FromUser, t.UserUri ToUser, 'conference' Type, ct.ContentType, m.Body
from ConferenceMessages m
	join Users f on m.FromId = f.UserId
	join ConferenceMessageRecipientList rl on rl.MessageId = m.MessageId
	join Users t on rl.UserId = t.UserId
	join ContentTypes ct on m.ContentTypeId = ct.ContentTypeId
where
	m.Date >= @start and m.Date < @end
	and (@useruri is null or (f.UserUri = @useruri or t.UserUri = @useruri))
order by Time

</code></pre>

Substitute your desired date range, bearing in mind that the time is in UTC and optionally specify a @useruri in the form of _user@domain.com_.

The P2P messages are fairly straight forward but the conference is a little quirky. That's because of the way conference participants are stored. As such, you need to join the conferences tables with the participants table and the conference messages table to get all the information. This query will cause the query to take a little while to return data if no @useruri is specified.

Last note, since this is in the LcsLog database, you'll need to run this as a user in RTCComponentUniversalServices or another group with specific access to the SQL instance or that database.

You can also use the same PowerShell technique as in [Last Login for a SIP URI](/2015/02/22/last-login-for-a-sip-uri.html) to run this via PowerShell.

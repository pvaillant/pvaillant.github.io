--- 
layout: post
title: "Find That Troublesome Wi-Fi AP"
comments: true
tags: ["Lync","sql","QoEMetrics","Wi-Fi"]
---

Soft clients are one of the best things about VoIP phone systems and the Lync client is no exception. Being able to have everything on one device gives the solution such portability and mobility. Most of the time this mobility, at least within an office environment, is also made possible because of WiFi.

Fun fact, when Lync 2010 was released, voice and video over WiFi wasn't officially support (well [voice/video weren't validated over Wi-Fi](http://blogs.technet.com/b/nexthop/archive/2012/10/26/lync-wi-fi-deployment-guide-for-real-time-communications-workloads.aspx)). I'm sure that didn't stop people from doing it anyway but its still a fun fact.

Along came Lync 2013 with support, and in also the Lync SDN API which made it even better. Well does it? The Lync SDN API is great as long as you have either an HP, or an ~~aruba~~HP, Wi-Fi network, but what if you have something else? QoEMetrics to the rescue!

Part of the data that Lync sends to QoE is the [BSSID](http://en.wikipedia.org/wiki/BSSID) of the wireless access point that its connected to. You can use this data to group together all the calls that went through each access point in your network. In addition, because of the way the data is stored, you can distinguish inbound and outbound streams. You would think this makes a difference but it does.

I wrote this query while working with a customer who was getting reports of call problems that seemed overwhelming. We started by grouping the QoE reports by logical site and quickly realized that one site only seemed to be having problems. When we first dug into that site there didn't seem to be a pattern until finally we grouped by BSSID and the pieces fell into place. Backed with this data that showed two APs as the common factor the problem was quickly resolved.

<pre class="hljs sql"><code>
use QoEMetrics;

declare @endtime datetime = CURRENT_TIMESTAMP;
declare @begintime datetime = DATEADD(day, -7, @endtime);

declare @SitePrefixes table (prefix nvarchar(max) COLLATE Latin1_General_CI_AI, name nvarchar(max) COLLATE Latin1_General_CI_AI);
insert into @SitePrefixes values ('10.10.%','Edmonton'), ('10.20.%','Toronto'), ('10.0.%','Datacenter');

with cdrs as (
	Select
		CallerSubIp.IpAddress CallerSubnet, CalleeSubIp.IpAddress CalleeSubnet, 
		callerBssid.MacAddress CallerBssid, calleeBssid.MacAddress CalleeBssid, 
		a.SenderIsCallerPAI AudioSenderIsCallerPAI,
		a.PacketLossRate*100.0 AudioPktLossRatePct, a.PacketLossRateMax*100.0 AudioPktLossRateMaxPct
	FROM 
		Session s
		inner join MediaLine m on s.ConferenceDateTime = m.ConferenceDateTime and s.SessionSeq = m.SessionSeq
		left join AudioStream a on 
			m.ConferenceDateTime = a.ConferenceDateTime and m.SessionSeq = a.SessionSeq and m.MediaLineLabel = a.MediaLineLabel
		left join dbo.IpAddress CallerSubIp on m.CallerSubnet = CallerSubIp.IpAddressKey
		left join dbo.IpAddress CalleeSubIp on m.CalleeSubnet = CalleeSubIp.IpAddressKey
		left join MacAddress callerBssid on m.CallerBssid = callerBssid.MacAddressKey
		left join MacAddress calleeBssid on m.CalleeBssid = calleeBssid.MacAddressKey
	Where 
		((callerBssid.MacAddress is not null or calleeBssid.MacAddress is Not null)) and 
		s.ConferenceDateTime >= @begintime and s.ConferenceDateTime < @endtime
), subnets as (
	select 
		case 
			when p.name is null then s.Subnet
			else p.name
		end as Site,
		s.Subnet
	from
		(select distinct CallerSubnet Subnet from cdrs
		 UNION
		 select distinct CalleeSubnet Subnet from cdrs) s
		left join @SitePrefixes p on s.Subnet like p.prefix
)

select 
	callerSub.Site CallerSubnet, CallerBssid, calleeSub.Site CalleeSubnet, CalleeBssid, 
	case
		when AudioSenderIsCallerPAI = 1 then 'caller-to-callee'
		else 'callee-to-caller'
	end as Direction, count(*) cnt,
	min(AudioPktLossRatePct) MinPktLossPct, avg(AudioPktLossRatePct) AvgPktLossPct, max(AudioPktLossRatePct) MaxPktLossPct,
	min(AudioPktLossRateMaxPct) MinPktLossMaxPct, avg(AudioPktLossRateMaxPct) AvgPktLossMaxPct, max(AudioPktLossRateMaxPct) MaxPktLossMaxPct
from cdrs
	join subnets callerSub on CallerSubnet = callerSub.Subnet
	join subnets calleeSub on CalleeSubnet = calleeSub.Subnet
where AudioPktLossRatePct is not null
group by callerSub.Site, CallerBssid, calleeSub.Site, CalleeBssid, AudioSenderIsCallerPAI having count(*) > 5
order by avg(AudioPktLossRatePct) desc

</code></pre>

This query returns caller/callee site & access point MAC address, direction of the audio stream (remember there are 2 for each call, caller -> callee and callee -> caller) along with min/average/max packet loss percentages. There's actually 2 sets of packet loss stats, one is over the average over the whole of the stream and the second is the max of the packet loss samples over the individual streams. The second is important because not all calls are all bad; calls can also have periods of packet loss which result in audio quality problems that end users are just as ready to describe as a 'bad call' as a call where the whole call suffers from packet loss.

This query makes extensive use of common table expressions to keep everything clean. You can adjust the date range if you want something other than the last 7 days but I find any more than this problems don't stand out and any less you're likely to miss non-persistent issues. Also add IP patterns for your sites (in the _insert into @SitePrefixes_ line instead of the 3 sample values I have) and the results at the end will be labeled with your site names instead of subnets. Keep in mind these are SQL patterns so % is the wildcard character.

<#
.SYNOPSIS
	Get Lync conferencing adoption statistics from the monitoring database(s).
	
.OUTPUTS
	For each user who hosted a conference, there's a DataRow with the following properties:
	UserUri, HostingCount, MinAttendeeCount, AvgAttendeeCount, MaxAttendeeCount, ParticipantCount
	
.NOTES
	Version 1.0.0 (2015-03-03)
	Written by Paul Vaillant
	
.LINK
	http://paul.vaillant.ca/help/Get-LyncConferenceAdoption.html
#>

[CmdletBinding()]
param()

$sql = @"
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
        and cv.ClientType != 256
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
),
localUsers as (
	select distinct UserUri
	from Registration r join Users u on r.UserId = u.UserId
),
orgStats as (
	select 
		COUNT(*) as HostingCount,
		MIN(AttendeeCount) as MinAttendeeCount,
		AVG(AttendeeCount) as AvgAttendeeCount,
		MAX(AttendeeCount) as MaxAttendeeCount,
		OrganizerUri as UserUri
	from confsAndAttendeeCounts 
	group by OrganizerUri
),
partStats as (
	select COUNT(*) as ParticipantCount, UserUri
	from confsAndUsers
	where UserUri in (select UserUri from localUsers)
	group by UserUri
)

select
	u.UserUri, 
	case when os.HostingCount is null then 0 else os.HostingCount end HostingCount, 
	case when os.MinAttendeeCount is null then 0 else os.MinAttendeeCount end MinAttendeeCount, 
	case when os.AvgAttendeeCount is null then 0 else os.AvgAttendeeCount end AvgAttendeeCount, 
	case when os.MaxAttendeeCount is null then 0 else os.MaxAttendeeCount end MaxAttendeeCount,
	case when ps.ParticipantCount is null then 0 else ps.ParticipantCount end ParticipantCount
from
	localUsers u
	left join orgStats os on u.UserUri = os.UserUri
	join partStats ps on u.UserUri = ps.UserUri
"@

$ds = New-Object System.Data.DataSet

[array]$dbs = Get-CsService -MonitoringDatabase
if(!$dbs) {
	Write-Error "No Monitoring Databases returned by Get-CsService"
	exit
}

$dbs | foreach {
	$dbSvr = if($_.SqlInstanceName) { $_.PoolFQDN + "\" + $_.SqlInstanceName } else { $_.PoolFqdn }
	$connStr = "Server=" + $dbSvr + ";Integrated Security=True"
	$conn = New-Object System.Data.SqlClient.SqlConnection $connStr

	if ($PSBoundParameters.Verbose) { 
		$conn.FireInfoMessageEventOnUserErrors=$true 
		$handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] { Write-Verbose "$($_)" } 
		$conn.add_InfoMessage($handler) 
	} 

	$conn.open()

	$cmd = New-Object System.Data.SqlClient.SqlCommand $sql,$conn
	$da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
	[void]$da.fill($ds) 
	$conn.Close()
}

if($dbs.Count -eq 1) {
	$ds.Tables[0] | sort UserUri
} else {
	# detect and combine any duplicate rows
	$uniqUserUris = $ds.Tables[0] | %{ $_.UserUri } | sort -unique
	foreach($uu in $uniqUserUris) { 
		$rows = $ds.Tables[0] | where { $_.UserUri -eq $uu }
		$stats = $rows | measure HostingCount,MinAttendeeCount,MaxAttendeeCount,ParticipantCount -Maximum -Minimum -Sum
		$total = $($rows | %{ $_.HostingCount * $_.AvgAttendeeCount } | measure -sum).Sum
		$hCnt = $($stats | where { $_.Property -eq "HostingCount" }).Sum
		$minACnt = $($stats | where { $_.Property -eq "MinAttendeeCount" }).Minimum
		$maxACnt = $($stats | where { $_.Property -eq "MaxAttendeeCount" }).Minimum
		$pCnt = $($stats | where { $_.Property -eq "ParticipantCount" }).Sum
		$avgACnt = if($total -gt 0) { [Math]::Round($total / $hCnt) } else { 0 }
		[pscustomobject]@{UserUri = $uu; HostingCount = $hCnt; MinAttendeeCount = $minACnt; AvgAttendeeCount = $avgACnt; MaxAttendeeCount = $maxACnt; ParticipantCount = $pCnt}
	}
}
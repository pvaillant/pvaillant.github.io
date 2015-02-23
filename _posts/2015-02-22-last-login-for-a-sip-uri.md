--- 
layout: post
title: "Last Login for a SIP URI"
comments: true
tags: ["PowerShell","Lync","sql","LcsCDR"]
---

Ever wanted to know when the last time someone logged in was? Ever wanted from where a user last logged in? Or even what client or client version someone is using? You could ask the user to provide this information but that would probably annoy them and give you information with a varying degree of accuracy. I always suggest you never ask users for something that you can figure out yourself and in this case all the information you need is in the LcsCDR database.

What is the LcsCDR database? It's one of the two databases of the Monitoring role in Lync. It's also in both Lync 2010 and Lync 2013, although the schema changed slightly between the two versions. The schema is available on [TechNet](https://technet.microsoft.com/en-us/library/gg398570.aspx) if you're really interested. The following query will retrieve the last 10 logins (aka registrations) for a given user SIP URI.

<pre><code class="hljs sql">
USE LcsCDR
SELECT TOP 10
    r.RegisterTime,
    r.DeRegisterTime,
    drt.DeRegisterReason,
    cv.Version as ClientVersion,
    r.IpAddress,
    r.ResponseCode,
    s.ServerFQDN as Registrar,
    p.PoolFQDN as Pool,
    e.EdgeServer,
    dbo.FormatMacAddr(d.MacAddress) as MacAddress,
    m.Manufacturer,
    hv.Version as HardwareVersion
FROM 
    Registration as r
    join Users as u on r.UserId = u.UserId
    join ClientVersions as cv on r.ClientVersionId = cv.VersionId
    join Servers as s on r.RegistrarId = s.ServerId
    join Pools as p on r.PoolId = p.PoolId
    left outer join EdgeServers as e on r.EdgeServerId = e.EdgeServerId
    left outer join DeRegisterType as drt on r.DeRegisterTypeId = drt.DeRegisterTypeId
    left outer join Devices as d on r.DeviceId = d.DeviceId
    left outer join Manufacturers as m on d.ManufacturerId = m.ManufacturerId
    left outer join HardwareVersions as hv on d.HardwareVersionId = hv.VersionId
WHERE 
    u.UserUri = 'john.doe@domain.com'
ORDER BY
    r.RegisterTime DESC

</code></pre>

One quick note: if you were just interested in Lync 2013, this query could be made a little simplier by using the RegistrationView instead of the Registration table and joining a bunch of other tables. Unfortunately the RegistrationView in Lync 2010 is very different so by writing it out like this it's portable* between the two (* Lync 2010 doesn't have an IpAddress field in the Registration table so just remove that line).

Replace _john.doe@domain.com_ and run this against the database for the pool the user is located in and you should get back the user's last 10 logins. You can replace _10_ with how ever many logins you want, or remove _TOP 10_ to get all their logins (up to the configured retention; see [Get-CsCdrConfiguration](https://technet.microsoft.com/en-us/library/gg398298.aspx)).

A few notes: 
 * you check [TechNet](https://technet.microsoft.com/en-us/library/gg398142.aspx) for a list of possible DeRegisterReason
 * while ResponseCode will normally be 200 (OK), sometimes it can be something else. Check out the [list of SIP response codes](http://en.wikipedia.org/wiki/List_of_SIP_response_codes) in those cases
 * MacAddress, Manufacturer and HardwareVersion will only have values if the user was logged in on a handset

In large environments with multiple pools, or in cases where users are moved around, you can use Get-CsService to get a list of monitoring databases and run this query against all of them. PowerShell can definitely make this task much easier:

<pre><code class="hljs powershell">
$sql = @"
    ....
"@
$ds = New-Object System.Data.DataSet
Get-CsService -MonitoringDatabase | foreach {
    $dbSvr = if($_.SqlInstanceName) { 
        $_.PoolFQDN + "\" + $_.SqlInstanceName 
    } else { 
        $_.PoolFqdn 
    }
    $connStr = "Server=" + $dbSvr + ";Integrated Security=True"
    $conn = New-Object System.Data.SqlClient.SqlConnection $connStr
    $conn.open()
    $cmd = New-Object System.Data.SqlClient.SqlCommand $sql,$conn
    $da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
    [void]$da.fill($ds) 
    $conn.Close()
}
$ds.Tables[0] | sort RegisterTime -Descending | select -Last 10

</code></pre>

You can actually download this SQL that uses a version of this PowerShell (with nice parameters and Lync 2010/2013 database detection) to run it against all Monitoring databases: ([Get-LyncLogins.ps1](/content/Get-LyncLogins.ps1)). Just drop it on a machine with the Lync PowerShell module and run it as a user that has access to the LcsCDR database (CSAdministrator member).

	Get-LyncLogins.ps1 -UserUri john.doe@domain.com -Last 10

Want to get some data out of Lync but not sure how? Let me know and I'll try to write some PowerShell and/or SQL for it.
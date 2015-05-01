<#
.SYNOPSIS
	Get a list of the last X number of logins for a user
	
.PARAMETER UserUri
	The SIP address of the user to return logins for

.PARAMETER Last
	Number of last logins to return

.OUTPUTS
	For each login, there's a DataRow with the following properties:
	RegisterTime, DeRegisterTime, DeRegisterReason, ClientVersion, ResponseCode,
	Registrar, Pool, EdgeServer, MacAddress, Manufacturer, HardwareVersion
	
	If the monitoring server is 2013, there's also an IpAddress property

.EXAMPLE
	Get-LyncLogins.ps1 -UserUri john.doe@example.com
	Get the last 10 logins for john.doe@example.com
	
.NOTES
	Version 1.0.0 (2015-02-22)
	Written by Paul Vaillant
	
.LINK
	http://paul.vaillant.ca/help/Get-LyncLogins.html
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory=$true,Position=0)][string]$UserUri,
	[Parameter()][ValidateRange(0,100)][int]$Last = 10
)

$top = if($Last -gt 0) { "TOP $Last" }
$sqlTplt = @"
USE LcsCDR
SELECT $top
	r.RegisterTime,
	r.DeRegisterTime,
	drt.DeRegisterReason,
	cv.Version as ClientVersion,
	{0}
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
	u.UserUri = @UserUri
ORDER BY
	r.RegisterTime DESC
"@
$sql2010 = $sqlTplt -f ""
$sql2013 = $sqlTplt -f "r.IpAddress,"

$ds = New-Object System.Data.DataSet

Get-CsService -MonitoringDatabase | foreach {
	$dbSvr = if($_.SqlInstanceName) { $_.PoolFQDN + "\" + $_.SqlInstanceName } else { $_.PoolFqdn }
	$connStr = "Server=" + $dbSvr + ";Integrated Security=True"
	$conn = New-Object System.Data.SqlClient.SqlConnection $connStr

	if ($PSBoundParameters.Verbose) { 
		$conn.FireInfoMessageEventOnUserErrors=$true 
		$handler = [System.Data.SqlClient.SqlInfoMessageEventHandler] { Write-Verbose "$($_)" } 
		$conn.add_InfoMessage($handler) 
	} 

	$conn.open()
	
	$sql = "SELECT Value from DbConfigInt where Name = 'DbVersionSchema'"
	$cmd = New-Object System.Data.SqlClient.SqlCommand $sql,$conn
	[int]$dbVer = $cmd.ExecuteScalar();
	
	if($dbVer -lt 39) {
		Write-Verbose "$dbSvr DB schema version $dbVer; using Lync 2010 query"
		$sql = $sql2010
	} else {
		Write-Verbose "$dbSvr DB schema version $dbVer; using Lync 2013 query"
		$sql = $sql2013
	}
	
	$cmd = New-Object System.Data.SqlClient.SqlCommand $sql,$conn
	$cmd.Parameters.AddWithValue("@UserUri", $UserUri) | out-null
	$da = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
	[void]$da.fill($ds) 
	$conn.Close()
}

$rows = $ds.Tables[0] | sort RegisterTime -Descending
if($Last -gt 0) {
	$rows | select -first $Last
} else {
	$rows
}
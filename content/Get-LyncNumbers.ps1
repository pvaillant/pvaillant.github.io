[CmdletBinding()]
param(
	[Parameter(Mandatory=$true,Position=0)][ValidateRange(1000000000,9999999999)][long]$SipPilotNumber,
	[Parameter()][System.Management.Automation.PSCredential]$Credential = $(Get-Credential),
	[Parameter()][switch]$IncludeNumberTranslations = $false
)

###############################################################################
## VALIDATE Credential
###############################################################################

if(-not $Credential) {
	Write-Error "Credential is required"
	exit
}

###############################################################################
## LOAD THE LYNC POWERSHELL MODULE
###############################################################################

# Load the Lync PowerShell module, but only if it's not already loaded
if(-not $(Get-Module -ListAvailable | where Name -eq "Lync")) {
	Write-Error "Lync PowerShell module not available"
	exit
	# Alternatively add param for FE FQDN and connect remotely?
	#$sess = New-PSSession -ConnectionUri https://<FrontEnd Pool FQDN>/ocspowershell -Credential $AdminUsername -EA SilentlyContinue
	# -or-
	#$sess = New-PSSession -ConnectionUri https://<FrontEnd Pool FQDN>/ocspowershell -Authentication NegotiateWithImplicitCredential -EA SilentlyContinue
	#Import-PSSession -Session $sess | Out-Null
}
if(-not $(Get-Module Lync)) {
	Import-Module Lync -Verbose:$false 
}

###############################################################################
## GET ALL THE DIDS ON THE SPECIFIED SIP TRUNK PILOT
###############################################################################

# $wsdl = "https://api.thinktel.ca/SOAP.svc?wsdl"
# $proxy = New-WebServiceProxy -URI $wsdl -Namespace "ThinkTel.API.SOAP" -class Ucontrol -Credential $Credential
# $dids = $proxy.ListSipTrunkDids($pilot, $true, $0, $true, 100000, $true)

$wc = New-Object System.Net.WebClient
$wc.Credentials = $Credential.GetNetworkCredential()
$sipTrunkDidsUrl = "https://api.thinktel.ca/REST.svc/SipTrunks/{0}/Dids?PageFrom=0&PageSize=100000" -f $SipPilotNumber
$didsXml = $wc.DownloadString($sipTrunkDidsUrl)
if(-not $didsXml) {
	Write-Error "Failed to list DIDs on SIP Pilot $SipPilotNumber"
	exit
}
$didsList = [xml]$didsXml
if(-not $didsList -or -not $didsList.ArrayOfTerseNumber) {
	Write-Error "Failed to load or parse DIDs on SIP Pilot $SipPilotNumber"
	exit
}
$rawDids = $didsList.ArrayOfTerseNumber.TerseNumber | %{ $_.Number }

# then for each DID, see if it's translated by the switch
$dids = New-Object System.Collections.ArrayList
$dids.Add($SipPilotNumber) | Out-Null
if($IncludeNumberTranslations) {
	foreach($did in $rawDids) {
		$sipTrunkDidUrl = "https://api.thinktel.ca/REST.svc/SipTrunks/{0}/Dids/{1}" -f $SipPilotNumber,$did
		$didXml = $wc.DownloadString($sipTrunkDidUrl)
		$d = $([xml]$didXml).Did
		if($d.TranslatedNumber) {
			$dids.Add($d.TranslatedNumber) | Out-Null
		} elseif($d.Number) {
			$dids.Add($d.Number) | Out-Null
		} else {
			$dids.Add($did) | Out-Null
		}
	}
} else {
	$dids.AddRange($rawDids)
}
$availableDids = $dids | Sort -Unique

###############################################################################
## GET ALL THE DIDS ASSIGNED ANYWHERE IN LYNC
###############################################################################

function NewLyncNumber {
	param($Type,$LineUri,$Name,$SipAddress,$Identity)

	# clean up LineUri and look it up in $availableDids to see if it's "on trunk"
	$OnTrunk = $false
	$did = $null
	# parse the uri; drop the schema (tel:) and take only the main part (ignoring any ;ext=...)
	if($LineUri -match '^tel:\+1') {
		[long]$did = $LineUri.Substring(6) -split ';' | select -first 1
		$OnTrunk = $availableDids -contains $did
	}
	[pscustomobject]@{Type = $Type; LineURI = $LineUri; DisplayName = $Name; SipAddress = $SipAddress; Identity = $Identity; OnTrunk = $OnTrunk; DID = $did; City = $null}
}
function NewLyncNumberFromAdContact {
	param($Type,$Contact)
	NewLyncNumber $Type $Contact.LineURI $Contact.DisplayName $Contact.SipAddress $Contact.Identity
}

# Microsoft.Rtc.Management.ADConnect.Schema.ADUser
$userUris = Get-CsUser -Filter {LineURI -ne $Null} -WarningAction SilentlyContinue | % { NewLyncNumberFromAdContact "User" $_ }
$plUris = Get-CsUser -Filter {PrivateLine -ne $Null} -WarningAction SilentlyContinue | % { NewLyncNumberFromAdContact "User-PrivateLine" $_ }

# Microsoft.Rtc.Management.ADConnect.Schema.OCSADAnalogDeviceContact
$analogUris = Get-CsAnalogDevice -Filter {LineURI -ne $Null} -WarningAction SilentlyContinue | % { NewLyncNumberFromAdContact "AnalogDevice" $_ }

# Microsoft.Rtc.Management.ADConnect.Schema.OCSADCommonAreaPhoneContact
$caUris = Get-CsCommonAreaPhone -Filter {LineURI -ne $Null} -WarningAction SilentlyContinue | % { NewLyncNumberFromAdContact "CommonAreaPhone" $_ }

# Microsoft.Rtc.Rgs.Management.WritableSettings.Workflow
$rgsUris = Get-CsRgsWorkflow | ?{ $_.lineuri } -WarningAction SilentlyContinue | % { 
	NewLyncNumber "RgsWorkflow" $_.LineURI $_.Name $_.PrimaryUri $_.Identity
}

# Microsoft.Rtc.Management.Xds.AccessNumber
$dialinUris = Get-CsDialInConferencingAccessNumber -Filter {LineURI -ne $Null} -WarningAction SilentlyContinue | % { 
	NewLyncNumber "DialInConferencingAccessNumber" $_.LineURI $_.DisplayName $_.PrimaryUri $_.Identity
}

# Microsoft.Rtc.Management.ADConnect.Schema.OCSADExUmContact
$exumUris = Get-CsExUmContact -Filter {LineURI -ne $Null} -WarningAction SilentlyContinue | % { NewLyncNumberFromAdContact "ExUmContact" $_ }

# Microsoft.Rtc.Management.ADConnect.Schema.OCSADApplicationContact
$tepUris = Get-CsTrustedApplicationEndpoint -Filter {LineURI -ne $Null} -WarningAction SilentlyContinue | % { NewLyncNumberFromAdContact "TrustedApplicationEndpoint" $_ }

# Microsoft.Rtc.Management.ADConnect.Schema.OCSADMeetingRoom
$lrsUris = Get-CsMeetingRoom -Filter {LineURI -ne $Null} -WarningAction SilentlyContinue | % { NewLyncNumberFromAdContact "MeetingRoom" $_ }

# combine all results together
$allNumbers = New-Object System.Collections.ArrayList 
foreach($list in @($userUris,$plUris,$analogUris,$caUris,$rgsUris,$dialinUris,$exumUris,$tepUris,$lrsUris)) {
	if($list -and $list.Length -gt 0) {
		$allNumbers.AddRange($list)
	}
}

###############################################################################
## ADD ALL 'AVAILABLE' NUMBERS TO $allNumbers
###############################################################################

$existingDids = $allNumbers | %{ $_.DID }
$availableDids | where { $existingDids -notcontains $_ } | foreach {
	$n = [pscustomobject]@{Type = "Available"; LineURI = ""; DisplayName = ""; SipAddress = ""; Identity = ""; OnTrunk = $true; DID = $_; City = $null}
	$allNumbers.Add($n) | Out-Null
}

###############################################################################
## LOOKUP ALL THE RATE CENTER FOR ALL DIDS
###############################################################################

$lcgUri = "http://www.localcallingguide.com/xmlprefix.php?npa={0}&nxx={1}"

# create a map of unique NPA/NXX numbers
$npaNxxs = $allNumbers | %{ $_.DID.ToString().Substring(0,6) } | sort -Unique
foreach($npanxx in $npaNxxs) {
	$rc = $null
	if($npanxx -match "^8(00|88|77|66|55|44|33|22)") {
		$rc = "Toll-free"
	} else {
		[xml]$lcgXml = $wc.DownloadString($($lcgUri -f $npanxx.Substring(0,3),$npanxx.Substring(3,3)))
		if($lcgXml -and $lcgXml.root.prefixdata) {
			$rc = $lcgXml.root.prefixdata.rc + ", " + $lcgXml.root.prefixdata.region
		}
	}
	if($rc) {
		$allNumbers | where { $_.DID -match "^$npanxx" } | foreach {
			$_.City = $rc
		}
	} else {
		Write-Warning "Failed to identity city of phone numbers starting with $npanxx"
	}
}

###############################################################################
## RETURN RESULTS
###############################################################################

$allNumbers
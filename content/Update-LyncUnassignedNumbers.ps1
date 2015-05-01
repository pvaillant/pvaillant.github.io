<#
.SYNOPSIS
	Keeps unassigned number entries current with all numbers available on the SIP Trunk
	
.PARAMETER SipPilotNumber
	10 digit SIP Trunk pilot number

.PARAMETER Credential
	PSCredential object (like returned from Get-Credential) for the SipPilotNumber

.PARAMETER IncludeNumberTranslations
	Include number translations in the report. This will significantly slow down the report.

.PARAMETER Announcement
	The announcement to use for any new unassigned number entries that are created

.PARAMETER Force
	Removes unused unassigned number entries
	
.EXAMPLE
	Update-LyncUnassignedNumbers.ps1 -SipPilotNumber 7005551212 -Announcement "number-unassigned"
	This will prompt for credentials for the SIP trunk, connect and create any missing unassigned number entries using the announcement "number-unassigned".
	
.EXAMPLE
	Update-LyncUnassignedNumbers.ps1 -SipPilotNumber 7005551212 -Announcement $(Get-CsAnnouncement -Identity "number-unassigned")
	
	Same as above but uses the announcement object instead of looking up the announcement.
	
.NOTES
	Version 1.0.0 (2015-04-10)
	Written by Paul Vaillant
	
.LINK
	http://paul.vaillant.ca/help/Update-LyncUnassignedNumbers.html
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory=$true)][ValidateRange(1000000000,9999999999)][long]$SipPilotNumber,
	[Parameter()][System.Management.Automation.PSCredential]$Credential = $(Get-Credential),
	[Parameter()][switch]$IncludeNumberTranslations = $false,
  [Parameter(Mandatory=$true)]$Announcement,
	[Parameter()][switch]$Force = $false
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

if($Announcement.GetType() -ne [Microsoft.Rtc.Management.WritableConfig.Settings.AnnouncementServiceSettings.Announcement]) {
	$Announcement = Get-CsAnnouncement -Identity $Announcement
	if(-not $Announcement) {
		throw "Failed to resolve Announcement"
	}
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
## GET ALL THE CURRENT UNASSIGNED NUMBER ENTRIES
###############################################################################

$csUnassignedNumbers = Get-CsUnassignedNumber
$unassignedNums = $csUnassignedNumbers | %{
  [long]$start = $_.NumberRangeStart.Substring(2)
  [long]$end = $_.NumberRangeEnd.Substring(2)
  $start..$end
}

###############################################################################
## CREATE UNASSIGNED NUMBER ENTRIES FOR EACH AVAILABLE DID
###############################################################################

$aServer = $Announcement.Identity.Split('/')[0].Split(':')[2]
$availableDids | where { $unassignedNums -notcontains $_ } | foreach {
	$lbl = "###-###-####" -f $([long]$_)
	Write-Verbose "New-CsUnassignedNumber $lbl"
  New-CsUnassignedNumber -Identity $lbl -NumberRangeStart "+1$_" -NumberRangeEnd "+1$_" `
		-AnnouncementService $aServer -AnnouncementName $Announcement.Name | Out-Null
}

$unassignedNums | where { $availableDids -notcontains $_ } | foreach {
	$num = $_
	if($Force) {
		[array]$uan = $csUnassignedNumbers | where { $num -ge [long]$($_.NumberRangeStart.Substring(2)) -and $num -le [long]$($_.NumberRangeEnd.Substring(2)) }
		if($uan -and $uan.Length -eq 1) {
			if($uan.NumberRangeStart -eq $uan.NumberRangeEnd) {
				Write-Verbose "Remove-CsUnassignedNumber $($uan.Identity)"
				$uan | Remove-CsUnassignedNumber
			} else {
				Write-Warning "CsUnassignedNumber $($uan.Identity) includes $num which is no longer on the SIP trunk"
			}
		} else {
			Write-Error "Failed to locate CsUnassignedNumber for $num"
		}
	} else {
  	Write-Warning "Unassigned number $num is not on the SIP trunk; use -Force to remove it"
	}
}

#New-CsAnnouncement -identity $(get-csservice -ApplicationServer | select -first 1).identity `
#  -Name "Unassigned" -Language en-us `
#  -TextToSpeechPrompt "The number you're trying to reach is unassigned. Please try again"

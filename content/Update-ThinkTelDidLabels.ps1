<#
.SYNOPSIS
	Keeps uControl DID labels up to date with their assigned usage in Lync/Skype for Business

.PARAMETER SipPilotNumber
	10 digit SIP Trunk pilot number

.PARAMETER Credential
	PSCredential object (like returned from Get-Credential) for the SipPilotNumber

.EXAMPLE
	Update-ThinkTelDidLabels.ps1 -SipPilotNumber 7005551212
	This will prompt for credentials for the SIP trunk, connect and update all DID labels.

.NOTES
	Version 1.0.0 (2015-05-19)
	Written by Paul Vaillant

.LINK
	http://paul.vaillant.ca/help/Update-ThinkTelDidLabels.html
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Parameter(Mandatory=$true)][ValidateRange(1000000000,9999999999)][long]$SipPilotNumber,
	[Parameter()][System.Management.Automation.PSCredential]$Credential = $(Get-Credential)
)

###############################################################################
## Step 1: get the DIDs from uControl
###############################################################################

$sipTrunkDidsUrl = "https://api.thinktel.ca/REST.svc/SipTrunks/{0}/Dids?PageFrom=0&PageSize=100000" -f $SipPilotNumber
$didsList = Invoke-RestMethod -URI $sipTrunkDidsUrl -Credential $Credential -Method GET -ContentType "text/xml"
if(-not $didsList -or -not $didsList.ArrayOfTerseNumber) {
	Write-Error "Failed to load or parse DIDs on SIP Pilot $SipPilotNumber"
	exit
}

$existingLabels = @{}
$didsList.ArrayOfTerseNumber.TerseNumber | foreach {
  $existingLabels.Add($_.Number, $_.Label)
}

###############################################################################
## Step 2: get assigned usage from Lync/Skype for Business
###############################################################################

$currentLabels = @()
function AddCurrentLabel($telUri, $label) {
  if($telUri -notmatch '^tel:+1') {
    Write-Warning "Skipping $telUri ($label) because it doesn't start with tel:+1"
  } elseif($telUri -match ';ext=') {
    Write-Warning "Skipping $telUri ($label) because it contains an extension"
  } else {
    # $telUri will start with tel:+1 so let's skip that
    $number = $telUri.Substring(6)
    $currentLabels.Add($number, $label)
  }
}
Get-CsUser -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($_.LineURI, "User " + $_.SipAddress)
}
Get-CsUser -Filter {PrivateLine -ne $Null} | foreach {
  AddCurrentLabel($_.PrivateLine, "User " + $_.SipAddress + " (private line)")
}
Get-CsAnalogDevice -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($_.LineURI, "Analog Device " + $_.DisplayName)
}
Get-CsCommonAreaPhone -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($_.LineURI, "Common Area Phone " + $_.DisplayName)
}
Get-CsRgsWorkflow | ?{ $_.LineURI } | foreach {
  AddCurrentLabel($_.LineURI, "RGS Workflow " + $_.PrimaryAddress)
}
Get-CsDialInConferencingAccessNumber -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($_.LineURI, "Dial In Conf Number " + $_.DisplayName)
}
Get-CsExUmContact -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($_.LineURI, "ExUmContact " + $_.DisplayName)
}
Get-CsTrustedApplicationEndpoint -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($_.LineUri, "Trusted App Endpoint " + $_.SipAddress)
}
Get-CsMeetingRoom -Filter {LineURI -ne $Null} | foreach {
  AddCurrentLabel($_.LineURI, "Meeting Room " + $_.SipAddress)
}

###############################################################################
## Step 3: figure out which labels need to be updated
###############################################################################

$newLabels = @{}
foreach($num in $currentLabels.Keys) {
  if($existingLabels.ContainsKey($num)) {
    # this is a valid number on the trunk
    if($currentLabels[$num] -ne $existingLabels[$num]) {
      # the label needs to be updated
      $newLabels.Add($num, $currentLabels[$num])
    }
  } else {
    # this is not a number on the trunk
    Write-Warning "Skipping $num since it isn't on the trunk"
  }
}

###############################################################################
## Step 4: update each label that needs to be updated
###############################################################################

foreach($num in $newLabels.Keys) {
  $label = $newLabels[$num]
  Write-Verbose "Updating $num ($label)"

  # we actually need to start by getting the current number information
  # this ensures we don't clear out an existing number translation
  $sipTrunkDidUrl = "https://api.thinktel.ca/REST.svc/SipTrunks/{0}/Dids/{1}" -f $SipPilotNumber,$num
  $d = Invoke-RestMethod -URI $sipTrunkDidUrl -Credential $Credential -Method GET -ContentType "text/xml"
  if(-not $d -or $d.Number -ne $num) {
	Write-Error "Failed to load information for DID $num"
	continue
  }

  # update the DID label
  $d.Did.Label = $label

  # now POST this back to $sipTrunkDidUrl
  if($PSCmdlet.ShouldProcess($num,"Update DID label")) {
		Invoke-RestMethod -URI $sipTrunkDidUrl -Credential $Credential -Method "PUT" -ContentType "text/xml" -Body $d
  }
}

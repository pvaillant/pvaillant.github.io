[CmdletBinding(DefaultParametersetName="console")]
param(
	[Parameter(ParameterSetName="gui")][switch]$GUI,
	[Parameter(ParameterSetName="console")][string]$FilePath,
	[Parameter()][string[]]$EdgeServer,
	[Parameter()][pscredential]$Credential,
	[Parameter(ValueFromPipeline=$true)]$InputObject
)

function Read-LyncEventLog {
	param(
		[Parameter(Mandatory=$true)][string]$Server, 
		[Parameter(Mandatory=$true)][int]$EventId, 
		[Parameter(Mandatory=$true)][string]$Regex, 
		[int]$Limit = 0, 
		[int]$Skip = 0,
		[pscredential]$Credential
	)
	if($Credential) {
		$msgs = gwmi win32_ntlogevent -Filter "LogFile = 'Lync Server' and EventCode = $EventId" -ComputerName $Server -Credential $Credential
	} else {
		$msgs = Get-EventLog "Lync Server" -ComputerName $Server -EA SilentlyContinue | ?{$_.EventId -eq $EventId}
	}
	if($Limit -gt 0) {
		$msgs = $msgs[$Skip..$Limit]
	} elseif($Skip -gt 0) {
		$Limit = $msgs.Count
		$msgs = $msgs[$Skip..$Limit]
	}
	$msgs | %{ $_.Message -split '[\r\n]' | ?{ $_ -match $Regex } | %{ $matches } }
}

# FUTURE: should we add count/first date/last date to give more information?
# FUTURE: if we have access to monitoring db, dip to see who's talking (or how many users)
function New-LyncAutodiscoveredDomain {
	param(
		[Parameter(Mandatory=$true)][string]$Domain, 
		[string]$EdgeServer, 
		[bool]$RateLimited=$false, 
		[string]$Comment, 
		[string]$Action="Allow",
		[string]$ProxyFqdn
	)
	
	$d = [pscustomobject]@{Domain = $Domain; ProxyFqdn = $ProxyFqdn; RateLimited = $RateLimited; Comment = $Comment; Action = $Action; EdgeServer = $EdgeServer}

	if(-not $ProxyFqdn) {
		$srv = Resolve-DnsName "_sipfederationtls._tcp.$Domain" SRV -EA SilentlyContinue
		if(-not $srv) {
			$d.ProxyFqdn = $EdgeServer
			$d.Comment = "DNS SRV doesn't exist"
		}
	}
		
	$d
}

function Get-LyncAutodiscoveredDomains {
	param(
		[Parameter(Mandatory=$true)][string[]]$EdgeServer,
		[pscredential]$Credential
	)

	$domains = @{ }
	$rateLimitedEdges = @()
	
	foreach($es in $EdgeServer) {
		Read-LyncEventLog -Server $es -Credential $Credential -EventId 14601 -Regex "\bName: (?<edge>[^;]+); Domains: (?<domain>[A-Z0-9.-]+\.[A-Z]+)\b" | foreach {
			if(!$domains[$_['domain']]) {
				$domain = New-LyncAutodiscoveredDomain -Domain $_['domain'] -EdgeServer $_['edge']
				$domains[$domain.Domain] = $domain
			}
		}
		Read-LyncEventLog -Server $es -Credential $Credential -EventId 14603 -Regex '\bCertificate Subject: "(?<subj>[^"]+)"' -Limit 1 | foreach {
			$_['subj'] -split ',' | foreach {
				$edge = $_.Trim()
				if($edge -match "^[^\s]+$" -and $edge -match '[^.]+\.[^.]+\.[^.]+' -and $rateLimitedEdges -notcontains $edge) {
					$rateLimitedEdges += $edge
					$matchedDomains = $domains.Values | ?{ $_.EdgeServer -eq $edge }
					if($matchedDomains) {
						$matchedDomains | foreach {
							Write-Verbose "updating rate limited on $($_.Domain) via $edge"
							$_.RateLimited = $true
						}
					} else {
						Write-Warning "$edge is rate limited but isn't an edge for a domain in the auto-discovered list"
					}
				}
			}
		}
	}
	
	# this is used as the DataSource (which must implement IList) so $domains.Values isn't enough
	$values = $domains.Values | sort -Property Domain
	$list = New-Object System.Collections.ArrayList
	$list.AddRange($values)
	$list
}

function Write-LyncFederatedDomainsScript {
	param([string]$OutputFile)
	
	Begin {
		# clear file if it exists
		if((-not [String]::IsNullOrEmpty($OutputFile)) -and (Test-Path -Path $OutputFile)) {
			Remove-Item $OutputFile
		}
	}

	Process {
		# once for each pipeline input
		$cmd = $null
		if($_.Action -eq "Allow") {
			$cmd = "if(Get-CsAllowedDomain -Identity '" + $_.Domain + "' -ErrorAction SilentlyContinue) {`n" +
				"   Write-Warning '" + $_.Domain + " is already allowed'`n" +
				"} else {`n" +
				"   New-CsAllowedDomain -Domain '" + $_.Domain + "'" + $(if($_.ProxyFqdn) { " -ProxyFqdn '" + $_.ProxyFqdn + "'" })
		} elseif($_.Action -eq "Block") {
			$cmd = "if(Get-CsBlockedDomain -Identity '" + $_.Domain + "' -ErrorAction SilentlyContinue) {`n" +
				"   Write-Warning '" + $_.Domain + " is already blocked'`n" +
				"} else {`n" +
				"   New-CsBlockedDomain -Domain '" + $_.Domain + "'"
		}
		if($cmd) {
			if($_.Comment) {
				$cmd = $cmd + " -Comment '" + $_.Comment + "'"
			}
			$cmd = $cmd + "`n}`n"

			if($OutputFile) {
				$cmd | Out-File $OutputFile -Append
			} else {
				Write-Host $cmd
			}
		}
	}
}

function GenerateButton {
	param([string]$Text, [int]$Width=75, [int]$Height=23, [int]$X, [int]$Y, [int]$TabIndex)
	$btn = New-Object System.Windows.Forms.Button 
	$btn.TabIndex = $TabIndex
	$btn.Size = New-Object System.Drawing.Size($Width,$Height)
	$btn.UseVisualStyleBackColor = $true
	$btn.Text = $Text
	$btn.Location = New-Object System.Drawing.Point -Property @{ X=$X; Y=$Y }
	$btn
}

function GenerateForm {
	Begin {
		# or Load("System.Windows.Forms, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b77a5c561934e089")
		[Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null 
		# or Load("System.Drawing, Version=2.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a")
		[Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null 
		[System.Windows.Forms.Application]::EnableVisualStyles()
		
		$form = New-Object System.Windows.Forms.Form 
		$form.Text = "Update-LyncFederatedDomains"
		$form.ClientSize = New-Object System.Drawing.Size(804,509)
		
		$btnClose = GenerateButton -Text "Close" -X 716 -Y 474 -TabIndex 3
		$btnClose.Anchor = "Bottom","Right"
		$btnClose_OnClick = { $form.Close() }
		$btnClose.add_Click($btnClose_OnClick)
		$form.Controls.Add($btnClose)
		
		$btnSave = GenerateButton -Text "Save" -X 12 -Y 474 -TabIndex 2
		$btnSave.Anchor = "Bottom","Left"
		$btnSave_OnClick = {
			$dialog = New-Object System.Windows.Forms.SaveFileDialog
			$dialog.Title = "Save file as..."
			$dialog.Filter = "PowerShell scripts (*.ps1)|*.ps1|All files|*.*"
			$dialog.RestoreDirectory = $true
			if($dialog.ShowDialog() -eq 'OK') {
				$grid.Rows | foreach { 
					$d = New-LyncAutodiscoveredDomain -Domain $_.Cells[0].Value -ProxyFqdn $_.Cells[1].Value -Comment $_.Cells[3].Value -Action $_.Cells[4].Value
					$d
				} | Write-LyncFederatedDomainsScript -OutputFile $dialog.FileName
				$form.Close()
			}
		}
		$btnSave.add_Click($btnSave_OnClick)
		$form.Controls.Add($btnSave)

		$grid = New-Object System.Windows.Forms.DataGridView 
		$grid.Anchor = "Top","Bottom","Left","Right"
		$grid.AllowDrop = $false
		$grid.AllowUserToAddRows = $false
		$grid.AllowUserToDeleteRows = $false
		$grid.MultiSelect = $false
		$grid.TabIndex = 0
		$grid.ColumnHeadersHeightSizeMode = "AutoSize";
		$grid.Location = new-object System.Drawing.Point 12,12
		$grid.Margin = new-object System.Windows.Forms.Padding 3,3,3,20
		$grid.Size = new-object System.Drawing.Size 780,439
		$grid.ColumnCount = 4
		$grid.ColumnHeadersVisible = $true
		
		$grid.Columns[0].Name = "Domain"
		$grid.Columns[0].ReadOnly = $true
		$grid.Columns[0].Width = 190
		
		$grid.Columns[1].Name = "ProxyFqdn"
		$grid.Columns[1].ReadOnly = $true
		$grid.Columns[1].Width = 190
		
		$grid.Columns[2].Name = "RateLimited"
		$grid.Columns[2].ReadOnly = $true
		$grid.Columns[2].Width = 90
		
		$grid.Columns[3].Name = "Comment"
		$grid.Columns[3].Width = 190

		$action = New-Object System.Windows.Forms.DataGridViewComboBoxColumn
		$action.HeaderText = "Action"
		$action.AutoComplete = $false
		$action.Items.AddRange("Allow", "Ignore", "Block")
		$grid.Columns.Add($action) | Out-Null
		$grid.Columns[4].Width = 60
		
		$form.Controls.Add($grid)
	}
	
	Process {
		$grid.Rows.Add(@($_.Domain,$_.ProxyFqdn,$_.RateLimited,"","Allow")) | Out-Null
	}

	End {
		$form.ShowDialog() | Out-Null
	}
}

if($PsCmdlet.ParameterSetName -eq "gui" -and [Threading.Thread]::CurrentThread.GetApartmentState() -ne "STA") {
	Write-Error "Please run powershell with the -sta parameter; powershell -sta $($MyInvocation.InvocationName)"
	exit
}

if($InputObject) {
	$domains = $Input
} else {
	if($(Get-Service RtcSrv -EA SilentlyContinue | where { $_.displayname -match 'access edge' })) {
		Write-Verbose "Auto-detected local Access Edge"
		[array]$EdgeServer = @("localhost")
	} else {
		# else see if this machine has the Lync PowerShell module
		if($(Get-Module -ListAvailable | where Name -eq 'Lync')) {
			[array]$EdgeServer = Get-CsPool | where Services -match EdgeServer | select Computers -ExpandProperty Computers | 
				where { Test-Connection $_ -Quiet }
			if(-not $EdgeServer) {
				Write-Error "Failed to successfully connect to any EdgeServers as returned by Get-CsPool"
				exit
			} else {
				$EdgeServer | foreach { Write-Verbose "Auto-detected Edge Server $_" }
			}
		} else {
			Write-Error "Failed to detect local Access Edge service or Lync PowerShell module; please specify -EdgeServer"
			exit
		}
	}

	$domains = Get-LyncAutodiscoveredDomains -EdgeServer $EdgeServer -Credential $Credential
}

switch ($PsCmdlet.ParameterSetName)
{
	"gui" {
		$domains | GenerateForm 
		break
	}
	"console" {
		if($FilePath) {
			$domains | Write-LyncFederatedDomainsScript -OutputFile $FilePath
		} else {
			$domains
		}
		break
	}
}
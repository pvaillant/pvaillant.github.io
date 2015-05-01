<#
.SYNOPSIS
	Gets the help content for a command name, or path to .ps1 file, and converts it to a markdown file.
	
.PARAMETER Command
	Name of a cmdlet or path to a .ps1 file

.PARAMETER FrontMatter
	Specify to include Jekyll compatible Front Matter in the output

.PARAMETER OutputDir
	Directory where to output the files

.PARAMETER Index
	Specify to generate an index.md file with links to all the help files generated
	
.EXAMPLE
	ls .\content\*.ps1 | ConvertTo-HelpMarkdown.ps1 -FrontMatter -Index
	Generate markdown help for all the script files in the content directory of a Jekyll site
	
.NOTES
	Version 1.0.0 (2015-05-01)
	Written by Paul Vaillant
	Inspired by Out-HTML http://poshcode.org/1612
	
.LINK
	http://paul.vaillant.ca/help/ConvertTo-HelpMarkdown.html
#>

param(
	[Parameter(Mandatory=$true, ValueFromPipeline=$true)][string]$Command,
	[Parameter()][switch]$FrontMatter = $false,
	[Parameter()][string]$OutputDir = "./help",
	[Parameter()][switch]$Index = $false
)

BEGIN {
	if(!$(Test-Path $OutputDir)) {
		mkdir $OutputDir | out-null
	}
	function EscapeHtml($str) {
		$str.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;")
	}
	function Append {
		param(
			[Parameter(Mandatory=$true, ValueFromPipeline=$true)][AllowEmptyString()][string[]]$in,
			[Parameter(Mandatory=$true, Position=0)][string]$fileName
		)
		PROCESS {
			foreach($i in $in) {
				if ($i -eq $null) {
					$i = ""
				} else {
					$i = $($i.ToString().Trim() -split "`n" | %{ $_.Trim() }) -Join $("<br/>" + [System.Environment]::NewLine)
				}
				if($i[0] -ne '<') {
					# don't escape if it starts in html 
					$i = EscapeHtml $i
					# and restore and forced line breaks broken by the above escaping
					$i = $i.Replace("&lt;br/&gt;" + [System.Environment]::NewLine, "<br/>" + [System.Environment]::NewLine)
				}
				$i | Out-File $fileName -Append -Encoding ASCII
			}
		}
	}
	$Commands = @()
}

PROCESS {
	foreach ($cmd in $Command) {
		$help = Get-Help $cmd -Full
		$name = $($help.Name | Split-Path -Leaf) -split '\.' | Select -First 1
		$fileName = Join-Path $OutputDir $($name + ".md")
		$Commands += $name
		if(Test-Path $fileName) {
			rm $fileName -Confirm:$false
		}
		if($FrontMatter) {
			"---","title : Get-Help $name","layout : layout","---","" | Append $fileName
		}
		
		"# $name", $help.synopsis, "" | Append $fileName

		if($help.Syntax) {
			$syntax = $help.syntax | Out-String
			$path = $help.name | Split-Path
			$syntax = $syntax.Replace($path + "\","").Replace([Environment]::NewLine,"")
			"## Syntax","<code>$(EscapeHtml($syntax.Trim()))</code>","" | Append $fileName
		}
		
		if($help.Description) {
			$description = $help.Description | Out-String
			"## Detailed Description",$description,"" | Append $fileName
		}
		
		if($help.parameters) {
			"## Parameters" | Append $fileName
			"<table class=""table table-condensed table-striped"">" | Append $fileName
			"<thead><tr><th>Name</th><th>Description</th><th>Required?</th><th>Pipeline Input?</th><th>Default Value</th></tr></thead>" | Append $fileName
			"<tbody>" | Append $fileName
			foreach ($p in $help.parameters.parameter) {
				$desc = $($p.Description | Out-String).Trim()
				"<tr valign=""top""><td>$($p.Name)</td><td>$desc</td><td>$($p.Required)</td><td>$($p.PipelineInput)</td><td>$($p.DefaultValue)</td></tr>" | Append $fileName
			}
			"</table>","" | Append $fileName
		}
		
		# Input Type
		if ($help.inputTypes) {
			$inputTypes = $help.inputTypes | Out-String
			"## Input Type",$inputTypes,"" | Append $fileName
		}
   
		# Return Type
		if ($help.returnValues) {
			$returnValues = $help.returnValues | Out-String
			"## Return Values",$returnValues,"" | Append $fileName
		}
		  
		# Notes
		if ($help.alertSet) {
			$notes = $help.alertSet | Out-String
			"## Notes",$notes,"" | Append $fileName
		}
   
		# Examples
		if ($help.examples) {
			"## Examples","" | Append $fileName
			foreach ($example in $help.examples.example) {
				"### $($example.title.Trim(@('-',' ')))" | Append $fileName
				"<code>$($example.code.Trim())</code>" | Append $fileName
				$remarks = $($example.remarks | Out-String).Trim()
				if($remarks) {
					"",$remarks | Append $fileName
				}
				"" | Append $fileName
			}
		}
	}
}

END {
	if($Index) {
		$fileName = Join-Path $OutputDir "index.md"
		if(Test-Path $fileName) {
			rm $fileName -Confirm:$false
		}
		if($FrontMatter) {
			"---","title : Get-Help","layout : layout","---","" | Append $fileName
		}
		"# Get-Help","" | Append $fileName
		foreach($cmd in $Commands) {
			" * [$cmd]($cmd.html)" | Append $fileName
		}
	}
}

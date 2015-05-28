---
layout: post
title: "Create a PDF from Images with PowerShell"
comments: true
tags: ["PowerShell","Pester","Office"]
---

I don't know how your organization is but my experience is that all organizations have processes and invariably one, or more, of those processes can be [byzantine](http://www.urbandictionary.com/define.php?term=BYZANTINE). I experienced this first hand recently when I was asked to provide PDF versions of expense receipts.

# My Workflow

So what I've been doing is taking a picture of receipts using my Windows Phone, which is set to upload a copy of my pictures to my OneDrive and then I was sending those pictures in. This was very easy and very convenient for me since I travel with my phone. I didn't need to wait to get back into the office and I didn't need yet another device in my bag or need to stop and setup something connected to my laptop. How to provide PDFs without completely doing away with my convinience?

NOTE: for my purposes these are receipts, but the same could apply for anything that you're taking a picture of but want to convert into Word or PDF format, possibly with additional content.

# Word.Application

This is the [Apollo 13](http://en.wikipedia.org/wiki/Apollo_13_%28film%29) moment where they put one of everything that they have in the capsule on the table in front of the engineers and ask them to come up with a way to put a square filter in a round hole.

I have Office, and Word can insert images into a document and save it as a PDF, so now I just have to automate the process.

So first thing is that I want some flexibility in how I call this, specifically so I can use _[ls](https://technet.microsoft.com/library/hh847897%28v=wps.630%29.aspx)_ and _[where](https://technet.microsoft.com/library/6a70160b-cf62-48df-ae5b-0a9b173013b4%28v=wps.630%29.aspx)_ to select the files I want, so I need to be able to accept images from the pipeline. Sometimes I also want to create a single document instead of more than one, and sometimes I want to remove the images once they have been converted, so I have a parameters for those options.

<pre class="hljs powershell"><code>
[CmdletBinding()]
param(
	[Parameter(ValueFromPipeline=$true)][string[]]$Images,
	[Parameter()][string]$CombinedFilename
)

</code></pre>

Next I do the initial setup of creating a new instance of Word. I also setup some variables for use in the combined file case.

<pre class="hljs powershell"><code>
BEGIN {
	$word = New-Object -ComObject Word.Application

	$doc = $null
	$first = $true
	if($CombinedFilename) {
		Write-Verbose "Creating combined document"
		$doc = $word.Documents.Add()
	}
}

</code></pre>

# Creating Documents and Saving Them

Now we need to actually create the documents. For each images, we create a new document as needed, use [AddPicture](https://msdn.microsoft.com/en-us/library/microsoft.office.interop.word.inlineshapes.addpicture%28v=office.14%29.aspx) to add it to the current document and either save/close the document (if they are separate documents) or insert a new page for combined documents.

<pre class="hljs powershell"><code>
PROCESS {
	foreach($img in $Images) {
		if(!$doc) {
			$doc = $word.Documents.Add()
		}

		#6 is [Microsoft.Office.Interop.Word.wdunits]::wdstory
		$word.Selection.EndKey(6) | Out-Null
		$word.Selection.InlineShapes.AddPicture($img) | Out-Null
		if($CombinedFilename) {
			if($first) {
				$first = $false
			} else {
				$word.Selection.InsertNewPage()
			}
		}

		if(!$CombinedFilename) {
			$pdf = $img.Substring(0, $img.LastIndexOf('.')) + ".pdf"
			#17 is [microsoft.office.interop.word.WdSaveFormat]::wdFormatPDF
			$doc.SaveAs([ref]$pdf, [ref]17)
			#0 is [microsoft.office.interop.word.wdsaveoptions]::wdDoNotSaveChanges
			$doc.Close([ref]0)
			$doc = $null
		}
	}
}

One thing to note; I'm using the numeric value for [WdSaveFormat](https://msdn.microsoft.com/en-us/library/microsoft.office.interop.word.wdsaveformat(v=office.14).aspx) and [WdSaveOptions](https://msdn.microsoft.com/en-us/library/microsoft.office.interop.word.wdsaveoptions%28v=office.14%29.aspx) for testability. Specifically, I want to be able to test my scripts without having Word installed or the COM interop classes loaded.

# Wrapping It Up

With all the hard work done, now it's just about saving the combined file, if that's what we're creating, and quitting Word.

<pre class="hljs powershell"><code>
END {
	if($CombinedFilename) {
		$doc.SaveAs([ref]$CombinedFilename, [ref]17)
		#0 is [microsoft.office.interop.word.wdsaveoptions]::wdDoNotSaveChanges
		$doc.Close([ref]0)
	}

	#0 is [microsoft.office.interop.word.wdsaveoptions]::wdDoNotSaveChanges
	$word.Quit([ref]0)
	$word = $null
}

</code></pre>

# Let's Not Forget Testing

I've talked about testing before so let's not forget this important part. The testing in this case is a little different than the last time. This time we need to create [Mocks](http://en.wikipedia.org/wiki/Mock_object). No problem, [Pester supports mocking](https://github.com/pester/Pester/wiki/Mocking-with-Pester).

The first step is to setup functions to mimic the Word APIs we're going to call. One stub function for each thing we're going to test happened.

<pre class="hljs powershell"><code>
function QuitWord { param($opts) }
function AddDocument { }
function AddPicture { param($path) }
function InsertNewPage { }
function SaveDocument { param($path, $opts) }
function CloseDocument { param($opts) }

</code></pre>

Next is some helper functions to make the mock statements cleaner. Note that some of the Word methods use reference parameters so in PowerShell we use \[ref\] but that results in a [PSReference](https://msdn.microsoft.com/en-us/library/system.management.automation.psreference%28v=vs.85%29.aspx) type object. Pester would have a hard time matching those with the ParameterFilter so before the call to the stub function, I unwrap the value from the PSReference object.

<pre class="hljs powershell"><code>
function NewDocument {
  $doc = New-Object psobject
  $doc | Add-Member -MemberType ScriptMethod -Name "SaveAs" -Value {
    param([ref]$path,[ref]$opts)
    SaveDocument $path.Value $opts.Value
  }
  $doc | Add-Member -MemberType ScriptMethod -Name "Close" -Value {
    param([ref]$opts)
    CloseDocument $opts.Value
  }
  return $doc
}

function NewWordApp {
  $docs = New-Object psobject
  $docs | Add-Member -MemberType ScriptMethod -Name "Add" -Value { AddDocument }

  $shapes = new-object psobject
  $shapes | Add-Member -MemberType ScriptMethod -Name "AddPicture" -Value {
    param($path)
    AddPicture $path
  }

  $sel = New-Object psobject @{InlineShapes = $shapes}
  $sel | Add-Member -MemberType ScriptMethod -Name "EndKey" -Value {
    param($opts)
    # ... no-op
  }
  $sel | Add-Member -MemberType ScriptMethod -Name "InsertNewPage" -Value {
    InsertNewPage
  }

  $word = New-Object psobject @{Visible = $false; Documents = $docs; Selection = $sel}
  $word | Add-Member -MemberType ScriptMethod -Name "Quit" -Value {
    param([ref]$opts)
    QuitWord $opts.Value
  }

  return $word
}

</code></pre>

Finally the actual tests. You can see one mock statement for each of our stub functions.

<pre class="hljs powershell"><code>
Describe "Convert-JpgToPdf.ps1" {
  Mock New-Object { NewWordApp } -Verifiable -ParameterFilter { $ComObject -eq 'Word.Application' }

  Mock QuitWord { param($opts) }
  Mock AddDocument { NewDocument }
  Mock AddPicture { param($path) }
  Mock InsertNewPage { }
  Mock SaveDocument { param($path, $opts) }
  Mock CloseDocument { param($opts) }

  Context "Images on the command line as separate documents" {
    $images = @("fake-image1.jpg", "fake-image2.jpg")
    & $cmd -Images $images

    It "creates a word instance" {
      Assert-VerifiableMocks
    }

    It "creates 2 documents each with 1 image" {
      Assert-MockCalled AddDocument -Exactly -Times 2
      foreach($img in $images) {
        Assert-MockCalled AddPicture -ParameterFilter { $path -eq $img }
      }
      Assert-MockCalled InsertNewPage -Exactly -Times 0
      Assert-MockCalled SaveDocument -Exactly -Times 2
      foreach($img in $images) {
        $pdf = $img -replace '\.jpg$','.pdf'
        Assert-MockCalled SaveDocument -ParameterFilter { $path -eq $pdf -and $opts -eq 17 }
      }
      Assert-MockCalled CloseDocument -Exactly -Times 2 -ParameterFilter { $opts -eq 0 }
    }

    It "closes word nicely" {
      Assert-MockCalled QuitWord -Exactly -Times 1 -ParameterFilter { $opts -eq 0 }
    }
  }
}

</code></pre>

There's also a context for images on the command line as a combined document and the same (separate and combined document) contexts for images from the pipeline. See [Convert-JpgToPdf.Tests.ps1](https://github.com/pvaillant/pvaillant.github.io/blob/master/content/Convert-JpgToPdf.Tests.ps1) for all the tests.

# Mocks, mocks, mocks, baked beans and mocks

There are other ways to achieve similar results. When I first wrote these tests I didn't have the 6 stub functions. Instead I added the fake $doc to a script: scoped array each time I created it and in the _It_, I looped over it to make sure they were as expected. Sadly that didn't work. I had a number of Write-Verbose statements, and I could see that they were being created and added but the array was empty when I checked it after.

A change in Pester 3.0 turned out the be the cause. From [What's New in Pester 3.0](https://github.com/pester/Pester/wiki/What%27s-New-in-Pester-3.0%3F)

"Tests.ps1 scripts are now executed in a separate scope than Pester's internal code, preventing some types of bugs that would occur when a test script happened to define a function or variable name that matched something Pester uses internally (or mock calls to a function that Pester needs internally.)""

So the script: scope of my array was the issue. Not wanting to pollute my global scope restructured my tests to use all mocks instead.

# Download the Script

<a class="download" href="/content/Convert-JpgToPdf.ps1"><i class="fa fa-file-text-o"></i> Convert-JpgToPdf.ps1 <i class="fa fa-download"></i></a>

# Download the Tests

<a class="download" href="/content/Convert-JpgToPdf.Tests.ps1"><i class="fa fa-file-text-o"></i> Convert-JpgToPdf.Tests.ps1 <i class="fa fa-download"></i></a>

# run this test file using Invoke-Pester

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
$cmd = "$here\$sut"

# word.{visible=, .Quit([int])}
# word.Documents.{Add()}
# word.Selection.{EndKey([int]), InlineShapes.AddPicture([string]), InsertNewPage()}}
# doc.{saveas([string],[int]), .close([int])}

# functions to be mocked later
function QuitWord { param($opts) }
function AddDocument { }
function AddPicture { param($path) }
function InsertNewPage { }
function SaveDocument { param($path, $opts) }
function CloseDocument { param($opts) }

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

  Context "Images on the command line as a combined document" {
    $images = @("fake-image1.jpg", "fake-image2.jpg")
    & $cmd -Images $images -CombinedFilename "test.pdf"

    It "creates a word instance" {
      Assert-VerifiableMocks
    }

    It "creates 1 documents each with 2 image" {
      Assert-MockCalled AddDocument -Exactly -Times 1
      foreach($img in $images) {
        Assert-MockCalled AddPicture -ParameterFilter { $path -eq $img }
      }
      Assert-MockCalled InsertNewPage -Exactly -Times 1
      Assert-MockCalled SaveDocument -Exactly -Times 1
      Assert-MockCalled SaveDocument -ParameterFilter { $path -eq "test.pdf" -and $opts -eq 17 }
      Assert-MockCalled CloseDocument -Exactly -Times 1 -ParameterFilter { $opts -eq 0 }
    }

    It "closes word nicely" {
      Assert-MockCalled QuitWord -Exactly -Times 1 -ParameterFilter { $opts -eq 0 }
    }
  }

  Context "Images on the pipeline line as separate documents" {
    $images = @("fake-image1.jpg", "fake-image2.jpg")
    $images | & $cmd

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

  Context "Images on the pipeline line as a combined document" {
    $images = @("fake-image1.jpg", "fake-image2.jpg")
    $images | & $cmd -CombinedFilename "test.pdf"

    It "creates a word instance" {
      Assert-VerifiableMocks
    }

    It "creates 1 documents each with 2 image" {
      Assert-MockCalled AddDocument -Exactly -Times 1
      foreach($img in $images) {
        Assert-MockCalled AddPicture -ParameterFilter { $path -eq $img }
      }
      Assert-MockCalled InsertNewPage -Exactly -Times 1
      Assert-MockCalled SaveDocument -Exactly -Times 1
      Assert-MockCalled SaveDocument -ParameterFilter { $path -eq "test.pdf" -and $opts -eq 17 }
      Assert-MockCalled CloseDocument -Exactly -Times 1 -ParameterFilter { $opts -eq 0 }
    }

    It "closes word nicely" {
      Assert-MockCalled QuitWord -Exactly -Times 1 -ParameterFilter { $opts -eq 0 }
    }
  }
}

---
layout: post
title: "Testing Your PowerShell Scripts"
comments: true
tags: ["PowerShell","Testing","Pester"]
---

Continuing from the exciting week last week at [Microsoft Ignite 2015](http://ignite.microsoft.com) in Chicago, I have to say that one of the things I was most amazed with was [Jeffery Snover](https://twitter.com/jsnover)'s announcement that the next version of Windows would ship with open-source software! I think secretly he was very thrilled by this as well because every session of his that I was in, I noted that he mentioned this over and over again. Maybe it's not the open-source aspect that he was most interested in, rather what this software is.

[Pester](https://github.com/pester/Pester), the software included now with Windows 10, is a testing framework for PowerShell. Testing is a key part of software development, as any dev will tell you, and it make sense given Microsoft's increased focus on making PowerShell dev friendly (see the class keyword as another great example of this). And making it dev friendly is a key part of the new push for [DevOps](http://en.wikipedia.com/wiki/DevOps) in Windows.

## A Pester Overview

So I thought I'd talk about how to test a PowerShell script using the example from my latest post [Classifying Phone Numbers](/2015/05/11/classifying-phone-numbers.html). The first thing you need to do is create a tests file. The convention here is to have the same file name but with a suffix of .tests.ps1 instead of .ps1. For example, for a script file called Get-PhoneNumberClass.ps1, the tests file would be called Get-PhoneNumberClass.Tests.ps1.

Next, let's look inside this tests file:

<pre class="hljs powershell"><code>
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
$cmd = "$here\$sut"

Describe "My-Script" {
  Context "...the name of my context..." {
    It "...does something..." {
      $result = & $cmd
      $result.Value | Should Be "my expected value"
    }
  }
}

</code></pre>

This style of testing is referred to as [Behavior driven development](http://en.wikipedia.org/wiki/Behavior-driven_development) and abbreviated as BDD.

The idea is to look at it logically,
 1. Describe: this is the high level thing (like a script or function) that's being _described_ (tested)
 2. Context: a specific context, or scenario, within the larger system
 3. It: a specific aspect or behavior within the context
 4. Should: an expected result of the behavior

## Get-PhoneNumberClass.Tests.ps1

Let's take a look at some real-world tests. In my last post I created a script that would use regular expressions to classify phone numbers into Gold, Silver, Bronze and Ordinary classes based on how _nice_ the number looks.

The first thing are the various test cases; you need to have some inputs and expected outputs that will help test the various paths within your script.

<pre class="hljs powershell"><code>
$TestCases = @(
    @{Number = 7000011222; Class = "Gold"; Reason = "doubleTriple"},
    @{Number = 7000033440; Class = "Gold"; Reason = "doubleDouble0"},
    @{Number = 7000005555; Class = "Gold"; Reason = "same4"},
    @{Number = 7000006660; Class = "Gold"; Reason = "triple0"},
    @{Number = 7000007890; Class = "Gold"; Reason = "sequential4"},
    @{Number = 7005242110; Class = "Silver"; Reason = "double0"},
    @{Number = 7005242007; Class = "Silver"; Reason = "bond"},
    @{Number = 7005223434; Class = "Silver"; Reason = "twoDigitPattern"},
    @{Number = 7005224511; Class = "Bronze"; Reason = "double"},
    @{Number = 7005242390; Class = "Bronze"; Reason = "endsIn0"},
    @{Number = 7002398201; Class = "Ordinary"; Reason = ""}
)

</code></pre>

In this case there are a number of different kinds of number patterns that will trigger the different classes so I have included an example of each.

Next I want to make sure that if I pass a number on the command line, it returns the correct class.

<pre class="hljs powershell"><code>
Context "When numbers are passed by the command line" {
    It "identifies <Number> as <Class>" -TestCases $TestCases {
        param($Number, $Class, $Reason)

        $c = & $cmd -Number $Number
        $c | Should Be $Class
    }
}

</code></pre>

Since there's also a flag that will cause the script to return extra details, I want to make sure I test that as well.

<pre class="hljs powershell"><code>
Context "When numbers are passed by the command line with Details" {
    It "identifies &lt;Number> as &lt;Class> because of &lt;Reason>" -TestCases $TestCases {
        param($Number, $Class, $Reason)

        $c = & $cmd -Number $Number -Details
        $c.Number | Should Be $Number
        $c.Class | Should Be $Class
        $c.Reason | Should Be $Reason
    }
}

</code></pre>

Lastly, since my script can also takes input from the pipeline instead of the command line, I want to test that scenario too.

<pre class="hljs powershell"><code>
Context "When numbers are passed by the pipeline" {
    It "identifies &lt;Number> as &lt;Class> because of &lt;Reason>" -TestCases $TestCases {
        param($Number, $Class, $Reason)

        $c = $Number | & $cmd
        $c.Number | Should Be $Number
        $c.Class | Should Be $Class
        $c.Reason | Should Be $Reason
    }

    It "identifies all numbers in the pipeline" {
        $results = $TestCases | %{ $_.Number } | & $cmd
        foreach($t in $TestCases) {
            $r = $results | ? Number -eq $t.Number
            #$r | Should Exist
            $r.Number | Should Be $t.Number
            $r.Class  | Should Be $t.Class
            $r.Reason | Should Be $t.Reason
        }
    }
}

</code></pre>

## Running Your Tests

Now that we have a test file created we need to run it. If you're on Windows 10 then you can just run _Invoke-Pester_ from the folder that has your tests file in it. If you're not on Windows 10 then you'll need to install Pester. Pester is a PowerShell modules so the easiest way is to download the latest release ([3.3.8](https://github.com/pester/Pester/archive/3.3.8.zip)), unzip it and run:

<pre class="hljs powershell"><code>Import-Module c:\path\to\pester-3.3.8\pester.psd1</code></pre>

Or you can also easily install it using [Chocolatey](https://chocolatey.org/) since there is a [Pester package](https://chocolatey.org/packages/pester).

Once that's done you'll be able to call Invoke-Pester. When you do, you should see something like the following:

<pre>
PS C:\path\to\tests> Invoke-Pester
Describing Get-PhoneNumberClass
   Context When numbers are passed by the command line
    [+] identifies 7000011222 as Gold 82ms
    [+] identifies 7000033440 as Gold 22ms
    [+] identifies 7000005555 as Gold 20ms
    [+] identifies 7000006660 as Gold 19ms
    [+] identifies 7000007890 as Gold 19ms
    [+] identifies 7005242110 as Silver 21ms
    [+] identifies 7005242007 as Silver 24ms
    [+] identifies 7005223434 as Silver 21ms
    [+] identifies 7005224511 as Bronze 22ms
    [+] identifies 7005242390 as Bronze 23ms
    [+] identifies 7002398201 as Ordinary 24ms
   Context When numbers are passed by the command line with Details
    [+] identifies 7000011222 as Gold because of doubleTriple 63ms
    [+] identifies 7000033440 as Gold because of doubleDouble0 22ms
    [+] identifies 7000005555 as Gold because of same4 22ms
    [+] identifies 7000006660 as Gold because of triple0 23ms
    [+] identifies 7000007890 as Gold because of sequential4 23ms
    [+] identifies 7005242110 as Silver because of double0 22ms
    [+] identifies 7005242007 as Silver because of bond 21ms
    [+] identifies 7005223434 as Silver because of twoDigitPattern 22ms
    [+] identifies 7005224511 as Bronze because of double 23ms
    [+] identifies 7005242390 as Bronze because of endsIn0 22ms
    [+] identifies 7002398201 as Ordinary because of  22ms
   Context When numbers are passed by the pipeline
    [+] identifies 7000011222 as Gold because of doubleTriple 65ms
    [+] identifies 7000033440 as Gold because of doubleDouble0 271ms
    [+] identifies 7000005555 as Gold because of same4 26ms
    [+] identifies 7000006660 as Gold because of triple0 22ms
    [+] identifies 7000007890 as Gold because of sequential4 22ms
    [+] identifies 7005242110 as Silver because of double0 22ms
    [+] identifies 7005242007 as Silver because of bond 26ms
    [+] identifies 7005223434 as Silver because of twoDigitPattern 25ms
    [+] identifies 7005224511 as Bronze because of double 27ms
    [+] identifies 7005242390 as Bronze because of endsIn0 26ms
    [+] identifies 7002398201 as Ordinary because of  29ms
    [+] identifies all numbers in the pipeline 125ms
Tests completed in 2.42s
Passed: 34 Failed: 0 Skipped: 0 Pending: 0
</pre>

Now, when you make changes to your scripts in the future, you'll have confidence that you haven't broken something that was working.

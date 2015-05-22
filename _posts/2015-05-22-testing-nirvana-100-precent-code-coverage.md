---
layout: post
title: "Testing Nirvana - 100% Code Coverage"
comments: true
tags: ["PowerShell","Testing","Pester"]
---

In my last post I introduced testing a PowerShell scripts, now lets take that a little deeper and improve on the testing.

  "Improve on the testing" you say, "how is that possible?"

When you are testing a script, or function or any piece of code, you want to be sure not only to test the _main path_, the normal case, but all the different execution paths. Every _if_ statement takes the execution through a different sequence and if there are some without test cases then you might have issues (that's fancy for bugs) that are going to bite you later on.

There are a couple of different ways to go about doing this.

## Test Driven Development

One option is to write your tests before you write your code (something called Test Driven Development or [TDD](http://en.wikipedia.org/wiki/TDD)). If you're following this style of development then you're creating a test before you even add a parameter or think about processing one kind of data differently. This option is also very good for the testability (that's fancy for how easy it is to test) of your implementation because it forces you to find a way to test before you even start writing, rather than struggling to find a way to test something you've already written, and possibly having to go back and rewrite it to make it testable.

## Code Coverage

Another option, which is particularly useful if you are writing your tests after the fact, is to use the Code Coverage feature of Pester. What is [Code Coverage](http://en.wikipedia.org/wiki/Code_coverage)? Code coverage means what percentage of your code is covered by tests. A particular line of code is considered covered if it is executed by one or more test cases. Having 100% code coverage should be your ideal goal although sometimes it's not possible. If you really aren't able to achieve 100% code coverage you should be sure it's for the right reasons and seriously consider if it may be because the implementation isn't testable rather than the test case not being testable.

## Dead Code

Code coverage, when you are using it after the fact, can also help discover dead code. I once read an article that _software developer_ was a terrible term because it made it sound like there was a definate end. Instead, the article proposed the term _software gardener_ because software can be very much like a living thing that grows but also needs pruning. When you have parts of your application that are no longer used, the _right thing &trad;_ to do isn't to leave them there but to remove them. Besides, if you ever needed them again, you could just checkout an older copy of your code from your SCM (you are using some kind of [Revision Control](http://en.wikipedia.org/wiki/Revision_control) tool like [Git](http://git-scm.com) aren't you?).

## So How Did I Do?

A quick check of the code coverage of the tests from my last example shows less than 100%. Let's dig into why.

<pre class="hljs powershell"><code>
PS> Invoke-Pester .\Get-PhoneNumberClass.Tests.ps1 -CodeCoverage .\Get-PhoneNumberClass.ps1

Code coverage report:
Covered 67.97 % of 128 analyzed commands in 1 file.

Missed commands:

File                     Function     Line Command
----                     --------     ---- -------
Get-PhoneNumberClass.ps1 ClassifySlow  156 Write-Verbose "Classifying $number (slow)"
Get-PhoneNumberClass.ps1 ClassifySlow  157 $class = "Ordinary"
Get-PhoneNumberClass.ps1 ClassifySlow  158 $reason = ""
Get-PhoneNumberClass.ps1 ClassifySlow  159 @("Gold","Silver","Bronze")
Get-PhoneNumberClass.ps1 ClassifySlow  159 "Gold","Silver","Bronze"
Get-PhoneNumberClass.ps1 ClassifySlow  160 $CLASSES[$c].GetEnumerator()
Get-PhoneNumberClass.ps1 ClassifySlow  160 foreach {...
Get-PhoneNumberClass.ps1 ClassifySlow  161 if($number -match $_.Value) {...
Get-PhoneNumberClass.ps1 ClassifySlow  162 $class = $c
Get-PhoneNumberClass.ps1 ClassifySlow  163 $reason = $_.Key
Get-PhoneNumberClass.ps1 ClassifySlow  168 @{Number = $number; Class = $class; Reason = $reason}
Get-PhoneNumberClass.ps1 ClassifySlow  168 Number = $number
Get-PhoneNumberClass.ps1 ClassifySlow  168 Class = $class
Get-PhoneNumberClass.ps1 ClassifySlow  168 Reason = $reason
Get-PhoneNumberClass.ps1               196 $numbers = 0..$RunSize | %{ Get-Random -Minimum 1991000000 -Maximum 99999...
Get-PhoneNumberClass.ps1               196 $numbers = 0..$RunSize | %{ Get-Random -Minimum 1991000000 -Maximum 99999...
Get-PhoneNumberClass.ps1               196 Get-Random -Minimum 1991000000 -Maximum 9999999999
Get-PhoneNumberClass.ps1               198 Measure-Command { foreach($n in $numbers) { ClassifyFast $n | out-null } }
Get-PhoneNumberClass.ps1               198 $numbers
Get-PhoneNumberClass.ps1               198 ClassifyFast $n
Get-PhoneNumberClass.ps1               198 out-null
Get-PhoneNumberClass.ps1               199 select @{n='Name';e={'Fast'}},TotalMilliseconds
Get-PhoneNumberClass.ps1               199 n = 'Name'
Get-PhoneNumberClass.ps1               199 e = {'Fast'}
Get-PhoneNumberClass.ps1               199 'Fast'
Get-PhoneNumberClass.ps1               201 Measure-Command { foreach($n in $numbers) { ClassifySlow $n | out-null } }
Get-PhoneNumberClass.ps1               201 $numbers
Get-PhoneNumberClass.ps1               201 ClassifySlow $n
Get-PhoneNumberClass.ps1               201 out-null
Get-PhoneNumberClass.ps1               202 select @{n='Name';e={'Slow'}},TotalMilliseconds
Get-PhoneNumberClass.ps1               202 n = 'Name'
Get-PhoneNumberClass.ps1               202 e = {'Slow'}
Get-PhoneNumberClass.ps1               202 'Slow'
Get-PhoneNumberClass.ps1               204 Measure-Command { foreach($n in $numbers) { ClassifySlowOptimized $n | ou...
Get-PhoneNumberClass.ps1               204 $numbers
Get-PhoneNumberClass.ps1               204 ClassifySlowOptimized $n
Get-PhoneNumberClass.ps1               204 out-null
Get-PhoneNumberClass.ps1               205 select @{n='Name';e={'Slow Optimized'}},TotalMilliseconds
Get-PhoneNumberClass.ps1               205 n = 'Name'
Get-PhoneNumberClass.ps1               205 e = {'Slow Optimized'}
Get-PhoneNumberClass.ps1               205 'Slow Optimized'

</code></pre>

Right away I can see that this points to two sections in my script; section 1 is lines 156 - 168 (the function ClassifySlow) and section 2 is lines 196-205 (this is the part of PROCESS dealing with the -Test flag).

How to remedy this? I've got a couple options here. I could remove both sections, actually I could go further and remove the -Slow option as well. Since this would introduce an incompatible backwards change (you couldn't call the script with -Test and get the behavior you currently expected) that would mean bumping this to version 2.0.0. If you're unfamilar with versioning, I strongly recommend reading [Semantic Versioning](http://semver.org/) and following it as a standard. If you are familar with SemVer then you'll have recognized this already. Another option would be to add test cases that covered both sections. And a third option would be a little of both. That's actually the option I'm going to go for.

For section 1 I'm just going to remove it since that version of the Classify function was one I did purely to compare the performance of different approaches and the only place it's used currently is by the -Test section. For section 2, I'll add a test case to cover this function:

<pre class="hljs powershell"><code>
Context "When a performance test is specified" {
    $ExpectedAlgorithms = @("Fast", "Slow")
    It "returns a list of algorithms and their total milliseconds" {
        [array]$results = & $cmd -Test
        $results.Length | Should Be $ExpectedAlgorithms.Length
        foreach($algo in $ExpectedAlgorithms) {
            $r = $results | where Name -eq $algo
            # in the latest Pester this is the same as
            # $r | Should Exist
            $r | Should Not Be $null
            $r.TotalMilliseconds | Should Match "^\d+\.\d+$"
        }
    }
}

</code></pre>

From a semantic versioning perspective, given that the output of -Test is an array of hashes with the algorithm name and a time taken, I interpret this to be a patch level change; a backwards compatible bug fix. If the output of -Test had been an object with each algorithm as a property like this:

<pre class="hljs powershell"><code>
PS> [pscustomobject]@{Fast = 0.234; Slow = 0.345; SlowOptimized = 0.456}

 Fast  Slow SlowOptimized
 ----  ---- -------------
0.234 0.345         0.456

</code></pre>

Then that would have been a backwards incompatible change.

## What's The Coverage Now?

So with those changes, what's the coverage look like?

<pre class="hljs powershell"><code>
PS> Invoke-Pester .\Get-PhoneNumberClass.Tests.ps1 -CodeCoverage .\Get-PhoneNumberClass.ps1

Code coverage report:
Covered 100.00 % of 106 analyzed commands in 1 file.

</code></pre>

Now that's what I want to see!

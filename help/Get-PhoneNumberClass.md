---
title : Get-Help Get-PhoneNumberClass
layout : layout
---

# Get-PhoneNumberClass
Classifies phone numbers based on the gold/silver/bronze classifications

## Syntax
<code>Get-PhoneNumberClass.ps1 [-Number] &lt;Int64&gt; [-Details] [-Slow] [&lt;CommonParameters&gt;]Get-PhoneNumberClass.ps1 [-Pipeline &lt;Int64[]&gt;] [-Slow] [&lt;CommonParameters&gt;]Get-PhoneNumberClass.ps1 -Test [-RunSize &lt;Int32&gt;] [-Slow] [&lt;CommonParameters&gt;]</code>

## Parameters
<table class="table table-condensed table-striped">
<thead><tr><th>Name</th><th>Description</th><th>Required?</th><th>Pipeline Input?</th><th>Default Value</th></tr></thead>
<tbody>
<tr valign="top"><td>Number</td><td>A phone number (digits only) to test</td><td>true</td><td>false</td><td>0</td></tr>
<tr valign="top"><td>Details</td><td>Returns detailed results for a single Number instead of just the class</td><td>false</td><td>false</td><td>False</td></tr>
<tr valign="top"><td>Pipeline</td><td>An array of phone numbers to test</td><td>false</td><td>true (ByValue)</td><td></td></tr>
<tr valign="top"><td>Test</td><td></td><td>true</td><td>false</td><td>False</td></tr>
<tr valign="top"><td>RunSize</td><td></td><td>false</td><td>false</td><td>100</td></tr>
<tr valign="top"><td>Slow</td><td>Uses the alternate method of of classifying numbers that's slower. This is for demonstration and shouldn't ever<br/>
normally be used</td><td>false</td><td>false</td><td>False</td></tr>
</tbody></table>

## Notes
Version 1.0.0 (2015-05-08)<br/>
Written by Paul Vaillant<br/>
Classifications come from @StaleHansen from his #msignite presenatation

## Examples

### EXAMPLE 1
<code>Get-PhoneNumberClass.ps1 7005551212</code>

Figure out what the class is for a given number (7005551212 in this case)<br/>
This returns just the class of the specified number

### EXAMPLE 2
<code>Get-PhoneNumberClass.ps1 7005551212 -Details</code>

Figure out what the class is for a given number (7005551212 in this case)<br/>
This returns an object with the Number, Class and Reason for classification

### EXAMPLE 3
<code>Get-ListOfPhoneNumbers | Get-PhoneNumberClass.ps1</code>

Classifies all numbers returned by the Get-ListOfPhoneNumbers command<br/>
Returns an object for each of the numbers with the Number, Class and Reason for classification


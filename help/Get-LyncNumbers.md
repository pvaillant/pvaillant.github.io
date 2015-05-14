---
title : Get-Help Get-LyncNumbers
layout : layout
---

# Get-LyncNumbers
Get a list of all numbers in Lync and on a ThinkTel SIP trunk.

## Syntax
<code>Get-LyncNumbers.ps1 [-SipPilotNumber] &lt;Int64&gt; [-Credential &lt;PSCredential&gt;] [-IncludeNumberTranslations] [&lt;CommonParameters&gt;]</code>

## Parameters
<table class="table table-condensed table-striped">
<thead><tr><th>Name</th><th>Description</th><th>Required?</th><th>Pipeline Input?</th><th>Default Value</th></tr></thead>
<tbody>
<tr valign="top"><td>SipPilotNumber</td><td>10 digit SIP Trunk pilot number</td><td>true</td><td>false</td><td>0</td></tr>
<tr valign="top"><td>Credential</td><td>PSCredential object (like returned from Get-Credential) for the SipPilotNumber</td><td>false</td><td>false</td><td>$(Get-Credential)</td></tr>
<tr valign="top"><td>IncludeNumberTranslations</td><td>Include number translations in the report. This will significantly slow down the report.</td><td>false</td><td>false</td><td>False</td></tr>
</tbody></table>

## Return Values
For each number, either in Lync or on the SIP trunk, there's a PSCustomObject with the following properties:<br/>
Type, LineURI, DisplayName, SipAddress, Identity, OnTrunk, DID, City

## Notes
Version 1.0.0 (2015-03-12)<br/>
Written by Paul Vaillant

## Examples

### EXAMPLE 1
<code>Get-LyncNumbers.ps1 -SipPilotNumber 7005551212 | Export-Csv .\lync-numbers.csv -NoTypeInformation</code>

Get all the numbers in Lync and on ThinkTel SIP Trunk 7005551212 and write them to .\lync-numbers.csv. You will be<br/>
prompted for credentials for this SIP Trunk.


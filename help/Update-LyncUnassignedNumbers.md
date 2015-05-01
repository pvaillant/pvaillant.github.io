---
title : Get-Help Update-LyncUnassignedNumbers
layout : layout
---

# Update-LyncUnassignedNumbers
Keeps unassigned number entries current with all numbers available on the SIP Trunk

## Syntax
<code>Update-LyncUnassignedNumbers.ps1 [-SipPilotNumber] &lt;Int64&gt; [[-Credential] &lt;PSCredential&gt;] [-IncludeNumberTranslations] [-Announcement] &lt;Object&gt; [-Force] [&lt;CommonParameters&gt;]</code>

## Parameters
<table class="table table-condensed table-striped">
<thead><tr><th>Name</th><th>Description</th><th>Required?</th><th>Pipeline Input?</th><th>Default Value</th></tr></thead>
<tbody>
<tr valign="top"><td>SipPilotNumber</td><td>10 digit SIP Trunk pilot number</td><td>true</td><td>false</td><td>0</td></tr>
<tr valign="top"><td>Credential</td><td>PSCredential object (like returned from Get-Credential) for the SipPilotNumber</td><td>false</td><td>false</td><td>$(Get-Credential)</td></tr>
<tr valign="top"><td>IncludeNumberTranslations</td><td>Include number translations in the report. This will significantly slow down the report.</td><td>false</td><td>false</td><td>False</td></tr>
<tr valign="top"><td>Announcement</td><td>The announcement to use for any new unassigned number entries that are created</td><td>true</td><td>false</td><td></td></tr>
<tr valign="top"><td>Force</td><td>Removes unused unassigned number entries</td><td>false</td><td>false</td><td>False</td></tr>
</table>

## Notes
Version 1.0.0 (2015-04-10)<br/>
Written by Paul Vaillant

## Examples

### EXAMPLE 1
<code>Update-LyncUnassignedNumbers.ps1 -SipPilotNumber 7005551212 -Announcement "number-unassigned"</code>

This will prompt for credentials for the SIP trunk, connect and create any missing unassigned number entries using the<br/>
announcement "number-unassigned".

### EXAMPLE 2
<code>Update-LyncUnassignedNumbers.ps1 -SipPilotNumber 7005551212 -Announcement $(Get-CsAnnouncement -Identity "number-unassigned")</code>

Same as above but uses the announcement object instead of looking up the announcement.


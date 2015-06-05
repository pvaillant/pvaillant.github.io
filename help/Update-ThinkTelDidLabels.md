---
title : Get-Help Update-ThinkTelDidLabels
layout : layout
---

# Update-ThinkTelDidLabels
Keeps uControl DID labels up to date with their assigned usage in Lync/Skype for Business

## Syntax
<code>Update-ThinkTelDidLabels.ps1 [-SipPilotNumber] &lt;Int64&gt; [[-Credential] &lt;PSCredential&gt;] [-WhatIf] [-Confirm] [&lt;CommonParameters&gt;]</code>

## Parameters
<table class="table table-condensed table-striped">
<thead><tr><th>Name</th><th>Description</th><th>Required?</th><th>Pipeline Input?</th><th>Default Value</th></tr></thead>
<tbody>
<tr valign="top"><td>SipPilotNumber</td><td>10 digit SIP Trunk pilot number</td><td>true</td><td>false</td><td>0</td></tr>
<tr valign="top"><td>Credential</td><td>PSCredential object (like returned from Get-Credential) for the SipPilotNumber</td><td>false</td><td>false</td><td>$(Get-Credential)</td></tr>
<tr valign="top"><td>WhatIf</td><td></td><td>false</td><td>false</td><td></td></tr>
<tr valign="top"><td>Confirm</td><td></td><td>false</td><td>false</td><td></td></tr>
</tbody></table>

## Notes
Version 1.0.0 (2015-05-19)<br/>
Written by Paul Vaillant

## Examples

### EXAMPLE 1
<code>Update-ThinkTelDidLabels.ps1 -SipPilotNumber 7005551212</code>

This will prompt for credentials for the SIP trunk, connect and update all DID labels.


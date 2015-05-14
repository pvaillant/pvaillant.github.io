---
title : Get-Help Get-LyncLogins
layout : layout
---

# Get-LyncLogins
Get a list of the last X number of logins for a user

## Syntax
<code>Get-LyncLogins.ps1 [-UserUri] &lt;String&gt; [-Last &lt;Int32&gt;] [&lt;CommonParameters&gt;]</code>

## Parameters
<table class="table table-condensed table-striped">
<thead><tr><th>Name</th><th>Description</th><th>Required?</th><th>Pipeline Input?</th><th>Default Value</th></tr></thead>
<tbody>
<tr valign="top"><td>UserUri</td><td>The SIP address of the user to return logins for</td><td>true</td><td>false</td><td></td></tr>
<tr valign="top"><td>Last</td><td>Number of last logins to return</td><td>false</td><td>false</td><td>10</td></tr>
</tbody></table>

## Return Values
For each login, there's a DataRow with the following properties:<br/>
RegisterTime, DeRegisterTime, DeRegisterReason, ClientVersion, ResponseCode,<br/>
Registrar, Pool, EdgeServer, MacAddress, Manufacturer, HardwareVersion<br/>
<br/>
If the monitoring server is 2013, there's also an IpAddress property

## Notes
Version 1.0.0 (2015-02-22)<br/>
Written by Paul Vaillant

## Examples

### EXAMPLE 1
<code>Get-LyncLogins.ps1 -UserUri john.doe@example.com</code>

Get the last 10 logins for john.doe@example.com


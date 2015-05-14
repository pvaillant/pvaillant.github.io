---
title : Get-Help Update-LyncFederatedDomains
layout : layout
---

# Update-LyncFederatedDomains
Updates allowed and blocked federated domains based on Edge event log entries.

## Syntax
<code>Update-LyncFederatedDomains.ps1 [-FilePath &lt;String&gt;] [-EdgeServer &lt;String[]&gt;] [-Credential &lt;PSCredential&gt;] [-InputObject &lt;Object&gt;] [&lt;CommonParameters&gt;]Update-LyncFederatedDomains.ps1 [-GUI] [-EdgeServer &lt;String[]&gt;] [-Credential &lt;PSCredential&gt;] [-InputObject &lt;Object&gt;] [&lt;CommonParameters&gt;]</code>

## Parameters
<table class="table table-condensed table-striped">
<thead><tr><th>Name</th><th>Description</th><th>Required?</th><th>Pipeline Input?</th><th>Default Value</th></tr></thead>
<tbody>
<tr valign="top"><td>GUI</td><td>If specified, display domains extracted from event log using a GUI</td><td>false</td><td>false</td><td>False</td></tr>
<tr valign="top"><td>FilePath</td><td>File path for resulting script with allowed and blocked domain statements</td><td>false</td><td>false</td><td></td></tr>
<tr valign="top"><td>EdgeServer</td><td>FQDN of edge server to connect to</td><td>false</td><td>false</td><td></td></tr>
<tr valign="top"><td>Credential</td><td>Credentials to use to connect to edge server</td><td>false</td><td>false</td><td></td></tr>
<tr valign="top"><td>InputObject</td><td></td><td>false</td><td>true (ByValue)</td><td></td></tr>
</tbody></table>

## Input Type
Exactly the same as the outputs

## Return Values
An array of PSCustomObjects with the following properties:<br/>
Domain, ProxyFqdn, RateLimited, Comment, Action, EdgeServer

## Notes
Version 1.0.0 (2015-03-12)<br/>
Written by Paul Vaillant

## Examples

### EXAMPLE 1
<code>Update-LyncFederatedDomains.ps1 -GUI</code>

Connect to either the localhost (if it is an edge server) or to the auto-detected edge server (using Get-CsPool)

### EXAMPLE 2
<code>Update-LyncFederatedDomains.ps1 -EdgeServer "edge.domain.local" -Credential $(Get-Credential)</code>

Connect to the specified edge server using the specified credentials

### EXAMPLE 3
<code>Update-LyncFederatedDomains.ps1 | where { $_.Domain -match acme } | Update-LyncFederatedDomains.ps1 -FilePath .\path\to\update-federation.ps1</code>

Parse event log entries for missing federation domains, find the ones that match 'acme' and create an update script.


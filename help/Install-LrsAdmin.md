---
title : Get-Help Install-LrsAdmin
layout : layout
---

# Install-LrsAdmin
Downloads and installs Lync Room System admin web interface, along with all dependencies.

## Syntax
<code>Install-LrsAdmin.ps1 [[-LrsAppUser] &lt;String&gt;] [[-LrsAppUserOU] &lt;String&gt;] [[-LrsSupportAdminGroup] &lt;String&gt;] [[-LrsSupportAdminGroupOU] &lt;String&gt;] [[-LrsFullAccessAdminGroup] &lt;String&gt;] [[-LrsFullAccessAdminGroupOU] &lt;String&gt;] [[-PoolName] &lt;String&gt;] [[-SipDomain] &lt;String&gt;] [&lt;CommonParameters&gt;]</code>

## Parameters
<table class="table table-condensed table-striped">
<thead><tr><th>Name</th><th>Description</th><th>Required?</th><th>Pipeline Input?</th><th>Default Value</th></tr></thead>
<tbody>
<tr valign="top"><td>LrsAppUser</td><td>Name of the user who the app will run as. This user will be created if it doesn't exist.</td><td>false</td><td>false</td><td>LRSApp</td></tr>
<tr valign="top"><td>LrsAppUserOU</td><td>Active Directory OU to create the user in. This must already exist.</td><td>false</td><td>false</td><td>CN=Users</td></tr>
<tr valign="top"><td>LrsSupportAdminGroup</td><td>Name of the group that will get read-only support role assigned. This group will be created if it doesn't exist.</td><td>false</td><td>false</td><td>LRSSupportAdminGroup</td></tr>
<tr valign="top"><td>LrsSupportAdminGroupOU</td><td>Active Directory OU to create the group in. This must already exist.</td><td>false</td><td>false</td><td>CN=Users</td></tr>
<tr valign="top"><td>LrsFullAccessAdminGroup</td><td>Name of the group that will get full admin role assigned. This group will be created if it doesn't exist.</td><td>false</td><td>false</td><td>LRSFullAccessAdminGroup</td></tr>
<tr valign="top"><td>LrsFullAccessAdminGroupOU</td><td>Active Directory OU to create the group in. This must already exist.</td><td>false</td><td>false</td><td>CN=Users</td></tr>
<tr valign="top"><td>PoolName</td><td>Name of the Lync pool the LrsAppUser will be enabled in. This will be auto-detected if it isn't specified.</td><td>false</td><td>false</td><td></td></tr>
<tr valign="top"><td>SipDomain</td><td>SIP Domain to assign to LrsAppUser when it's enabled for Lync.</td><td>false</td><td>false</td><td></td></tr>
</table>

## Notes
Version 1.0.0 (2015-01-05)<br/>
Written by Paul Vaillant<br/>
http://technet.microsoft.com/en-us/library/dn436324.aspx


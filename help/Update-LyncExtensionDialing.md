---
title : Get-Help Update-LyncExtensionDialing
layout : layout
---

# Update-LyncExtensionDialing
Updates a Lync dial plan to include normalization rules for all users with assigned extensions.

## Syntax
<code>Update-LyncExtensionDialing.ps1 [[-DialPlan] &lt;String&gt;] [[-NormalizationRulePrefix] &lt;String&gt;] [&lt;CommonParameters&gt;]</code>

## Parameters
<table class="table table-condensed table-striped">
<thead><tr><th>Name</th><th>Description</th><th>Required?</th><th>Pipeline Input?</th><th>Default Value</th></tr></thead>
<tbody>
<tr valign="top"><td>DialPlan</td><td>Identity of the DialPlan to update</td><td>false</td><td>false</td><td>Global</td></tr>
<tr valign="top"><td>NormalizationRulePrefix</td><td>Prefix used to identify normalization rules to be managed</td><td>false</td><td>false</td><td>Ext</td></tr>
</table>

## Notes
Version 1.0.0 (2015-04-17)<br/>
Written by Paul Vaillant

## Examples

### EXAMPLE 1
<code>Update-LyncExtensionDialing.ps1</code>

It's so straight forward, you don't need any parameters

### EXAMPLE 2
<code>Update-LyncExtensionDialing.ps1 -DialPlan RedmondOffice</code>

This will update the RedmondOffice dial plan.


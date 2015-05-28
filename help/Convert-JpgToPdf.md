---
title : Get-Help Convert-JpgToPdf
layout : layout
---

# Convert-JpgToPdf
Converts JPG images to PDF using MS Word

## Syntax
<code>Convert-JpgToPdf.ps1 [[-Images] &lt;String[]&gt;] [[-CombinedFilename] &lt;String&gt;] [&lt;CommonParameters&gt;]</code>

## Parameters
<table class="table table-condensed table-striped">
<thead><tr><th>Name</th><th>Description</th><th>Required?</th><th>Pipeline Input?</th><th>Default Value</th></tr></thead>
<tbody>
<tr valign="top"><td>Images</td><td>Path to images to be converted</td><td>false</td><td>true (ByValue)</td><td></td></tr>
<tr valign="top"><td>CombinedFilename</td><td>Optional filename to output a single document with one image per page</td><td>false</td><td>false</td><td></td></tr>
</tbody></table>

## Notes
Version 1.0.0 (2015-05-27)<br/>
Written by Paul Vaillant

## Examples

### EXAMPLE 1
<code>ls .\pictures\*.jpg | Convert-JpgToPdf.ps1 -CombinedFilename .\pictures.pdf</code>

Generate a single pictures.pdf with one images per page


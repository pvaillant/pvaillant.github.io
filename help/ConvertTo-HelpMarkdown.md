---
title : Get-Help ConvertTo-HelpMarkdown
layout : layout
---

# ConvertTo-HelpMarkdown
Gets the help content for a command name, or path to .ps1 file, and converts it to a markdown file.

## Syntax
<code>ConvertTo-HelpMarkdown.ps1 [-Command] &lt;String&gt; [-FrontMatter] [[-OutputDir] &lt;String&gt;] [-Index] [&lt;CommonParameters&gt;]</code>

## Parameters
<table class="table table-condensed table-striped">
<thead><tr><th>Name</th><th>Description</th><th>Required?</th><th>Pipeline Input?</th><th>Default Value</th></tr></thead>
<tbody>
<tr valign="top"><td>Command</td><td>Name of a cmdlet or path to a .ps1 file</td><td>true</td><td>true (ByValue)</td><td></td></tr>
<tr valign="top"><td>FrontMatter</td><td>Specify to include Jekyll compatible Front Matter in the output</td><td>false</td><td>false</td><td>False</td></tr>
<tr valign="top"><td>OutputDir</td><td>Directory where to output the files</td><td>false</td><td>false</td><td>./help</td></tr>
<tr valign="top"><td>Index</td><td>Specify to generate an index.md file with links to all the help files generated</td><td>false</td><td>false</td><td>False</td></tr>
</table>

## Notes
Version 1.0.0 (2015-05-01)<br/>
Written by Paul Vaillant<br/>
Inspired by Out-HTML http://poshcode.org/1612

## Examples

### EXAMPLE 1
<code>ls .\content\*.ps1 | ConvertTo-HelpMarkdown.ps1 -FrontMatter -Index</code>

Generate markdown help for all the script files in the content directory of a Jekyll site


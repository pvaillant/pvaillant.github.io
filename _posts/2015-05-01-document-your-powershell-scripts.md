---
layout: post
title: "Document Your PowerShell Scripts"
comments: true
tags: ["PowerShell"]
---

I was inspired by old war posters with this title. Can't you picture the classic Uncle Sam with his finger out and a caption that reads "I want YOU to document your scripts!"? Or maybe you could twist it a different way and it would be motivational poster with the kitten running thought the fields captioned with "every time you release a script without documentation, a kitten dies" (it's a thing they tell me).

Today we're talking about documenting PowerShell scripts. I love that you can embed the documentation directly into the script and that Get-Help formats it all for you and makes it nice. 

> Quick tip #1: you can access the help by adding -? to the end of any cmdlet. EG Get-Command -?

> Quick tip #2: if you're coming from the Unix world, fear not. Microsoft has created an alias 'man' for Get-Help so everything is as it should be.

The inline documentation takes the form of a comment block (I like to use <# and #>, but you can just comment every line starting with # if you want) at the start of the file. Then within that block you can specify different pieces of information including:

 * **.SYNOPSIS** – a brief explanation of what the script or function does
 * **.DESCRIPTION** – a more detailed explanation of what the script or function does
 * **.PARAMETER <name>** – an explanation of a specific parameter. You should have have one of these sections for each parameter the script or function uses.
 * **.EXAMPLE** – an example of how to use the script or function. You can have multiple .EXAMPLE sections if you want to provide more than one example.
 * **.INPUTS** - Description and types of objects that can be piped to the function or script
 * **.OUTPUTS** - Description and type of the objects that the cmdlet returns
 * **.NOTES** – any miscellaneous notes on using the script
 * **.LINK** – If you include a URL beginning with http:// or https://, it will be opened automatically when Get-Help is called with –online 

You can get more details in [about Comment Based Help](
https://technet.microsoft.com/en-us/library/hh847834.aspx) (or by running _Get-Help about\_Comment\_Based\_Help_). There's also another good reference on MSDN [How to Write Cmdlet Help](https://msdn.microsoft.com/en-us/library/aa965353%28VS.85%29.aspx).

So this is to say that I'm doing my part to save the kittens. All the scripts on my site now include documentation. You can check it out in my new [Get-Help](/help/index.html) section. I also created a tool, well a PowerShell script, called [ConvertTo-HelpMarkdown](/help/ConvertTo-HelpMarkdown.html) that will read out the inline documentation and create a markdown page that, as in my case, can be converted to HTML. You can download it from my [scripts](/scripts.html) page if you'd like.
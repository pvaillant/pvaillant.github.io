--- 
layout: post
title: "Lync Backup Script"
comments: true
tags: ["Lync","PowerShell","projects"]
---

Oh Lync, let me count the ways I love thee. Top of the list would be how I can manage everything with PowerShell. For an administrator, it's not just about being able to do things without having to wait for a GUI, but it's also about being able to create scripts and to automate or simplify the tasks that have to be done every day.

Who doesn't like sitting back while a machine does all the hard work instead of feverishly clicking buttons and being frustrated at the responsiveness of the GUI?

PowerShell is also great for being able to get information, like the current configuration of the various parts of a Lync deployment. There are a few scripts out there already that leverage the Lync PowerShell cmdlets to create a snapshot of an environment but I was looking for something more. I wanted to be able to track how an environment changed. I wanted to be notified about those changes too so that I, and anyone else I was managing that environment with, would know when anyone else made a change. Big systems aren't managed by one person after all. 

In the Cisco/networking world this has been around for a long time. The typical example is [RANCID](http://en.wikipedia.org/wiki/RANCID_(software)). The way RANCID works is by storing configs in CVS or SVN (those are [version control](http://en.wikipedia.org/wiki/Revision_control) systems if you aren't familiar with those acronyms). Why can't we do something similar for Lync?

Enter [Backup-Lync.ps1](https://github.com/thinktel/Backup-Lync).

It runs as a scheduled task on any machine that has the Lync PowerShell module installed and access to the Lync environment. It uses the various get-cs* PowerShell cmdlets to get data, System.Linq.Xml to format the files nicely (basically to prettify the XML so that it's on multiple lines rather than being all one big giant line) and [GIT](http://en.wikipedia.org/wiki/Git_(software)) via libgit2sharp (a .NET interface to [libgit2](https://libgit2.github.com/)) as it's version control system. 

In addition to the configuration data, it can also keep track of user data (contacts, conferences, etc). It keeps these in one file per user and is extremely handy if someone deletes contacts by accident or if a user is disabled accidentally. It's amazing how fast Disable-CsUser will purge out all the users data.

Give it a try and let me know what you think.

<a class="download" href="https://raw.githubusercontent.com/ThinkTel/Backup-Lync/master/Backup-Lync.ps1"><i class="fa fa-file-text-o"></i> Backup-Lync.ps1 <i class="fa fa-download"></i></a>
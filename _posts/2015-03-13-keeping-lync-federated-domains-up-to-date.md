--- 
layout: post
title: "Keeping Lync Federated Domains Up To Date"
comments: true
tags: ["PowerShell","Lync"]
---

Federation is one of the best features of Lync. It let's you connect with people outside your organization and get things done fast. Check out the [Lync Directory](http://lyncdirectory.com/) for a sampling of organizations that are openly federated with Lync.

'Open' federation, what does that mean? When you try to connect to user@domain.com, and @domain.com is not a SIP Domain in your Lync environment, and you have enabled _partner domain discovery_ (which is an Access Edge Configuration option), Lync will look up the DNS SRV record _\_sipfederationtls.\_tcp.domain.com_ and connect to the remote Lync environment.

There are a number of safe guards built in. There's a great reference of [Federation Safeguards for Lync](https://technet.microsoft.com/en-us/library/gg195674%28v=ocs.14%29.aspx) on Technet. It says Lync 2010, but it gives you a sense of what's going on. The key thing to note is that auto-discovered partners are subject to rate limiting. If there's another Lync environment that you're communicating heavily with, at some point you're likely to run into these rate limits. 

End user's will see them manifest as presence not updating, or IM messages not being sent or received. In the Edge Server event log, you'll see event ID 14603 indicating that a remote partner has been rate limited and event ID 14601 showing all autodiscovered partners.

How do you fix this? You use [New-CsAllowedDomain](https://technet.microsoft.com/en-us/library/gg398628.aspx) to approve the domain for federation. Sure you could do it one domain at a time, but PowerShell to the rescue!

You can use PowerShell to parse out the event log entries and call New-CsAllowedDomain. It can be a little tricky since the event log entries are on the Edge Server and you can't run New-CsAllowedDomain on the Edge Server. I wrote a script [Update-LyncFederatedDomains.ps1](/content/Update-LyncFederatedDomains.ps1) that gives you a few options.

**Option 1**: run on the Edge server and generate a script that you can run on the Front End. You can either use the -GUI option to get an interface that let's you pick which domains to include in the script, or you can have the domains returned as PowerShell objects, filter them and use Update-LyncFederatedDomains to write them out to a script.

<pre><code class="hljs powershell">Update-LyncFederatedDomains.ps1 -GUI</code></pre>

<pre><code class="hljs powershell">Update-LyncFederatedDomains.ps1 | where Domain -match '.com$' | Update-LyncFederatedDomains.ps1 -FilePath .\path\to\front-end-script.ps1</code></pre>

**Option 2**: run it on a machine like the Front-End that can call New-CsAllowedDomain. You have the same option as above to either use a GUI or to use the command line, but you'll probably need to specify credentials to connect to the Edge server using -Credential. The script will attempt to automatically detect the Edge server, but if you want to force it, use -EdgeServer. In the second example below, it will take all discovered domains and try to call New-CsAllowedDomain in the generated script.

<pre><code class="hljs powershell">Update-LyncFederatedDomains.ps1 -GUI -EdgeServer my-edge.acme.com -Credential $(Get-Credential)</code></pre>

<pre><code class="hljs powershell">Update-LyncFederatedDomains.ps1 -Credential $(Get-Credential) -FilePath .\path\tp\front-end-script.ps1</code></pre>

In the case where you use -GUI, you'll need to click the _Save_ button to generate the file. Then, whether you ran -GUI or used -FilePath, run the generated script and good bye rate limiting messages!

Happy keeping your federated domains approved!
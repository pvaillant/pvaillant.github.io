--- 
layout: post
title: "ThinkTel in the NuGet"
comments: true
tags: ["ThinkTel","uControl","NuGet"]
---

Maybe a better title would have been _"ThinkTel uControl libraries now available via NuGet"_ but I was going for more of a _"ThinkTel in the house"_ feel. Because literary license[^1]. Before we get to the actual content, *DISCLAIMER: I work for ThinkTel*. That said, all views are my own.

Ok, with all that out of the way, if you are a [ThinkTel](http://thinktel.ca) customer this might be worth checking out. There are 2 libraries available via [NuGet](http://nuget.org) to help you manage your ThinkTel services:

 * [ThinkTel.uControl.Api](http://nuget.org/packages/ThinkTel.uControl.Api/)
 * [ThinkTel.uControl.Cdrs](http://nuget.org/packages/ThinkTel.uControl.Cdrs/)
 
Both are .NET interfaces to our uControl system. If you aren't a ThinkTel customer, or don't know what uControl is, here's a quick synopsis. ThinkTel is a [CLEC](http://en.wikipedia.org/wiki/Competitive_local_exchange_carrier) phone company in Canada (among other things) and uControl is our real-time service management portal that lets customers do things like create new SIP trunks, manage bindings, order [DIDs](http://en.wikipedia.org/wiki/Direct_inward_dial) and update v911 address information. If you you want to know more feel free to contact me or your account manager.

On to the interesting things. In addition to being a web portal, uControl is also a RESTful API so you don't have to use our web interface, you can call the API from within your own systems. Our customers can do this for various reason; integrating phone number management with user provisioning/HR systems, automated service reconciliation, charge back accounting of usage to departments, wholesale level integration for rebranding purposes and many, many more scenarios.

There's much more that our API can do then we have exposed in this library but it has all the basic things in it. If you are interested in something you can do in uControl but don't see it in the API, or are curious about how you could use it for your own purposes but aren't sure where to start, feel free to contact me.

Next up; using uControl via PowerShell!

[^1]: [English Has a New Preposition, Because Internet](http://www.theatlantic.com/technology/archive/2013/11/english-has-a-new-preposition-because-internet/281601/)

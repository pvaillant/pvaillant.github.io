--- 
layout: post
title: "Lync Utility Belt"
tags: ["Lync","Outlook","Lync-SDK","Philips-Hue","dotnet"]
comments: true
---

People want to come in to my office all day long. Which is fine, except when I'm on my wireless headset, listening to someone, which of course looks like I'm not on the phone, so they start talking.
Before you ask, yes I've seen the [Busylight](http://www.busylight.com/), I have one in fact, but never really liked it. So I set out to make something different. 

![On-air light](/assets/images/on-air-light.jpg)

I was inspired by the idea of an on-air light that I could hang above my door so that my current status could be seen by people walking by. I had been wanting to get a [Philips Hue](http://meethue.com) light bulb and I figured this would be the perfect opportunity. I could even take it a step further then just on/off since the Philips Hue is an RGB LED bulb (it can show many different colors). It's a neat system where you connect a base station to the network and then it becomes the API end point for controlling multiple individual light bulbs.

![Philips Hue light bulb](/assets/images/hue-bulb.jpg)

After getting my starter kit, I found a great library [Q42.HueApi](https://github.com/Q42/Q42.HueApi) and start to code up my app. I didn't want anything too heavy, so it's a systray only application. It uses the [Microsoft Lync 2013 SDK](http://www.microsoft.com/en-us/download/details.aspx?id=36824) to connect to Lync and get notified of presence updates. That way, when you pick up the phone and your presence goes to _'in a call'_, the app sends a color change command to the Hue light bulb. It also 

Once I had that going, I figured it would also be nice to connect it to Outlook so that my Lync presence would go _'off work'_ after the day is over, so I added that as well. And lastly, I often wonder where a phone number is from if I don't recognize the number so I added a toast notification for incoming calls that shows what city the number is from. The data is via [Local Calling Guide](http://localcallingguide.com].

So why call it the Lync Utility Belt?

![Lync Utility Belt logo](/assets/images/lyncutilitybelt-logo.png)

Well, where would Batman be without his...

Check it out on GitHub [LyncUtilityBelt](https://github.com/pvaillant/LyncUtilityBelt) you can also download the binary below. You'll need .NET 4.5+.

<a class="download" href="https://github.com/pvaillant/LyncUtilityBelt/releases/download/v1.0.0/LyncUtilityBelt-1.0.0.zip"><i class="fa fa-file-text-o"></i> LyncUtilityBelt-1.0.0.zip <i class="fa fa-download"></i></a>

BTW: On-air light picture is from [http://www.freeimages.com/photo/190552](http://www.freeimages.com/photo/190552)